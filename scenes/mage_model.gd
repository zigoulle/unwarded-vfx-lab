## The mage's model (ticket 17): Tripo's mage, re-rigged with Rigify and keyed
## in Blender, with the hourglass staff in his right fist, playing the pose MageClips picks. Built from res://assets/mage/
## (written by tools/blender/bake_mage.py; see docs/dev-notes/art-pipeline.md).
##
## Each move gets its own copy of its source clip, named after the move, with
## the move's MageClips.MOVES markers ("start", "hit", "end") written on it;
## `markers` reads them back, so the clip's markers are what the retiming
## uses. The AnimationPlayer runs on a manual clock: show_pose puts the clip
## at the exact time MageClips asks for, with a short crossfade when the clip
## changes. Nothing here feeds the simulation.
class_name MageModel
extends CharacterModel

const SCENE := preload("res://assets/mage/mage.glb")
const STAFF := preload("res://assets/mage/mage-staff.glb")
const CLIPS_JSON := "res://assets/mage/mage-clips.json"
const OUTLINE_SHADER := preload("res://scenes/outline.gdshader")
## Tripo's materials come in fully metallic (metallic 1 times the ORM
## texture); with no sky reflections in the arena that draws him darker.
## His materials are drawn this metallic instead (0 = matte).
const METALLIC := 0.15
## The GLB's mage faces +Z; the avatar faces -Z.
const FACING_YAW := PI
## Crossfade between clips (s).
const BLEND_S := 0.1
## The cloth's springs (Godot's SpringBoneSimulator3D, per chain; skeleton
## units, the model's own metres): how hard each bone returns to the clip's
## pose, how much of its swing it loses a frame, its ring's radius against
## the legs. Presentation only.
const CLOTH_STIFFNESS := {"robe_front": 2.5, "robe_back": 1.8, "scarf": 3.0}
const CLOTH_DRAG := 0.35
const CLOTH_RADIUS := 0.012
## Leg colliders the robe panels slide over (bone, radius): thighs and knees.
const CLOTH_COLLIDERS := [["DEF-thigh.L", 0.045], ["DEF-thigh.L.001", 0.045], ["DEF-shin.L", 0.04],
	["DEF-thigh.R", 0.045], ["DEF-thigh.R.001", 0.045], ["DEF-shin.R", 0.04]]
## A jump further than this (m, drawn) between two frames is a teleport
## (respawn): the cloth starts again from the clip's pose.
const CLOTH_TELEPORT_M := 3.0
## The staff-tip socket: the top of the hourglass head in mage-staff.glb's
## frame (+Y runs up the shaft from the grip, metres).
const STAFF_TIP := Vector3(0.0, 0.39, 0.0)
## The sand trail's colour (its opacity is the feel page's), as seen on
## screen: vertex and instance colours reach the shaders as linear values,
## so it is converted where it is drawn (the trail read pale cream before).
const TRAIL_COLOR := Color(1.0, 0.72, 0.28)
## The sand look (playtest ruling 7): the ribbon's shader, and the Kenney
## Particle Pack (CC0) textures for its grain, its streaks and the grains.
const TRAIL_SHADER := preload("res://scenes/sand_trail.gdshader")
const TRAIL_GRAIN_TEX := preload("res://vfx/kenney-particle-pack/PNG (Transparent)/smoke_01.png")
const TRAIL_STREAK_TEX := preload("res://vfx/kenney-particle-pack/PNG (Transparent)/trace_04.png")
const GRAIN_TEX := preload("res://vfx/kenney-particle-pack/PNG (Transparent)/circle_05.png")
## The grains' colour: a paler sand than the ribbon, so they read over it.
const GRAIN_COLOR := Color(1.0, 0.85, 0.55)
## Rows smoothed in between trail samples in high quality (low: none).
const TRAIL_SUBDIVISIONS := 3
## His light slashes' preset knob ([section, key]: [mage.look]
## sand_slash_fx) and the moves it plays on, from the table the VFX lab
## reads too (FxMoves), so the two cannot disagree.
static var SLASH_FX_KNOB: Array = FxMoves.knob_of("mage", "light_1")
static var SLASH_MOVES: Array = FxMoves.moves_of(FxSandSlash.RECIPE)
## Slashes kept ready: a new one starts while the last still fades.
const SLASH_POOL := 2
## His moves' lab effects (VFX all-spells; FxMoves pairs each recipe with
## its move and the knob on his page naming its preset): recipe -> the
## script drawing it.
static var MOVE_FX_SCRIPTS := {
	FxGroundShake.RECIPE: FxGroundShake,
	FxWhirlwind.RECIPE: FxWhirlwind,
	FxTornado.RECIPE: FxTornado,
	FxBlink.RECIPE: FxBlink,
	FxTimeSlow.RECIPE: FxTimeSlow,
}
## The recipes that draw the staff's sand trail themselves (the whirlwind's
## swirl): a move playing one keeps the trail off.
const TRAIL_RECIPES: Array[String] = [FxWhirlwind.RECIPE]

# markers (per move: the clip copy it plays and its markers in seconds,
# MageClips.pose), stride_m_per_s (the run clip's stride at this model's
# scale) and height_m (set_look) are CharacterModel's.

var _player: AnimationPlayer
var _pivot: Node3D
var _model: Node3D
var _meshes: Array[MeshInstance3D] = []
var _overlay: StandardMaterial3D
var _clip := ""
var _loop_time := 0.0
var _stride_at_1_m := 1.0
var _outlines: Array[ShaderMaterial] = []
var _dressed: Array[BaseMaterial3D] = []
var _skeleton: Skeleton3D
## The staff's bone, and the staff's place on it (bone space).
var _staff_bone := -1
var _staff_on_bone := Transform3D.IDENTITY
## The sand trail (StaffTrail), drawn in world space; its [trail] values.
var _trail := StaffTrail.new()
var _trail_mesh: MeshInstance3D
var _trail_draw: ImmediateMesh
var _trail_material: ShaderMaterial
## The sand grains the trail sheds (one pooled MultiMesh instance each).
var _grains: MultiMeshInstance3D
var _trail_look := {"light_width_m": 0.3, "heavy_width_m": 0.75, "fade_s": 0.12, "heavy_fade_s": 0.12, "opacity": 0.75,
	"grain_count": 0, "grain_size_m": 0.06, "grain_life_s": 0.45}
var _trail_subdivisions := TRAIL_SUBDIVISIONS
## The kind of swing the trail was fed this frame ("" none; trail_kind).
var _trail_kind := ""
## His light slashes' preset (VFX all-spells ticket 01): [mage.look]
## sand_slash_fx names a saved sand slash preset, and his light slashes play
## that recipe in place of the staff's sand trail; "" (or a name with no
## saved preset, logged once) keeps the trail. The recipes drawing it (a
## pool: the next slash starts while the last fades), each one's cast clock
## (FxCastClock: holds behind the pause menu) and seed (the move's event; -1
## none yet), the one cast last, and whether low quality draws its Low
## version.
var _slash_fx := FxMovePreset.new(SLASH_FX_KNOB, FxSandSlash.RECIPE,
	"[mage] his light slashes keep the staff's sand trail instead: ")
var _slashes: Array[FxSandSlash] = []
var _slash_clocks: Array[FxCastClock] = []
var _slash_seeds: Array[int] = []
var _slash_last := 0
## The robe tails and the scarf on spring bones (mage-clips.json "cloth"),
## and whether hitstop holds them.
var _cloth: SpringBoneSimulator3D
var _cloth_held := false
var _last_origin := Vector3.INF
var _drawn := {}
## His moves' lab effects (FxMoveEffect), by move; the ground they lay
## marks on (set_effect_ground; null: none), and whether he draws at low
## quality (set_trail_look: their Low versions too).
var _move_fx := {}
var _fx_ground: Ground
var _fx_low := false
## How tall his tornado may be drawn ([look] tornado_height_m, m).
var _tornado_height_m := 2.5
## Per move run along his path (set_path: the blink), its cast's seed and
## where he stood on its first frame: [seed, feet].
var _fx_from := {}


func _init() -> void:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CLIPS_JSON))
	# The pivot takes the spin, lean and per-move turn; the model under it is
	# scaled and turned to face -Z.
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_model = SCENE.instantiate()
	_model.rotation.y = FACING_YAW
	_pivot.add_child(_model)
	_stride_at_1_m = float(info["run_stride_m_per_s"])
	_player = _model.find_children("*", "AnimationPlayer", true, false)[0]
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library := _player.get_animation_library("")
	for clip: String in info["clips"]:
		if info["clips"][clip]["loop"]:
			library.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for move: String in MageClips.MOVES:
		var row: Dictionary = MageClips.MOVES[move]
		var copy: Animation = library.get_animation(row["clip"]).duplicate()
		copy.loop_mode = Animation.LOOP_NONE
		# Markers share a name per time: a held pose (start = hit = end) is
		# one marker, and a cast's end is its hit.
		for key in ["hit", "start", "end"]:
			# Clamped: an end marker on the last frame sits a hair past the float32 length.
			var at := minf(float(row[key]) / MageClips.CLIP_FPS, copy.length)
			if copy.get_marker_at_time(at) == &"":
				copy.add_marker(key, at)
		library.add_animation(move, copy)
		var read := row.duplicate()
		for key in ["start", "hit", "end"]:
			read[key] = copy.get_marker_time(copy.get_marker_at_time(minf(float(row[key]) / MageClips.CLIP_FPS, copy.length)))
		markers[move] = read
	var skeleton: Skeleton3D = _model.find_children("*", "Skeleton3D", true, false)[0]
	_skeleton = skeleton
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(mesh)
	_attach_staff(skeleton, info["staff"])
	_build_trail()
	_build_slashes()
	_build_cloth(info.get("cloth", []))
	_overlay = StandardMaterial3D.new()
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dress_meshes()
	set_look(MageLook.BASE_HEIGHT_M, Color.WHITE, 0.5, 0.0)
	_build_move_fx()


## A lab effect per move of his FxMoves names with a knob on his page (each
## move of a family its own: the second spin starts while the first's swirl
## still fades), its recipe's node a child of his (hidden until a preset
## plays), told its move when the recipe draws each its own way.
func _build_move_fx() -> void:
	for recipe: String in FxMoves.MOVES:
		var slot: Dictionary = FxMoves.MOVES[recipe]
		if slot["character"] != Kit.MAGE or (slot["knob"] as Array).is_empty() or not MOVE_FX_SCRIPTS.has(recipe):
			continue
		for move: String in FxMoves.moves_of(recipe):
			var drawing: Node3D = (MOVE_FX_SCRIPTS[recipe] as GDScript).new()
			if "move" in drawing:
				drawing.set("move", move)
			add_child(drawing)
			_move_fx[move] = FxMoveEffect.new(recipe, slot["knob"], drawing,
				"[mage] his %s" % move.replace("_", " "))


## Readability (P-O's ruling: too dark at the pulled-back camera): each mesh
## gets its own copy of its materials, less metallic and glowing a little in
## its own colours (the lift), with the outline drawn over them as a next
## pass (an inverted hull, outline.gdshader).
## The staff (already in _meshes) gets the same. No extra light: a light per
## mage stalled a client window when it first lit (3-player smoke, rollback
## past netfox's history), and lights would pool on the floor.
func _dress_meshes() -> void:
	for mesh in _meshes:
		for i in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(i)
			if source == null:
				continue
			var dressed: Material = source.duplicate()
			if dressed is BaseMaterial3D:
				var base := dressed as BaseMaterial3D
				base.metallic = METALLIC
				base.emission_enabled = true
				base.emission = Color.WHITE
				base.emission_texture = base.albedo_texture
				base.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
				_dressed.append(base)
			var outline := ShaderMaterial.new()
			outline.shader = OUTLINE_SHADER
			dressed.next_pass = outline
			_outlines.append(outline)
			mesh.set_surface_override_material(i, dressed)


## How he is drawn (MageLook; the [look] values): height metres tall, the
## outline in color (the player's slot colour) at strength `outline` (0 to
## 1) and `width_px` screen pixels wide, his own colours glowing at lift
## (0 = none). The staff, on his hand, scales with him. Looks only.
func set_look(height: float, color: Color, outline: float, lift: float, width_px: float = 2.0) -> void:
	height_m = height
	_model.scale = Vector3.ONE * MageLook.model_scale(height)
	stride_m_per_s = _stride_at_1_m * MageLook.model_scale(height)
	for material in _outlines:
		material.set_shader_parameter("outline_color", color)
		material.set_shader_parameter("strength", outline)
		material.set_shader_parameter("width_px", width_px)
	for material in _dressed:
		material.emission_energy_multiplier = lift


## The staff in the fist: placed at its rest grip in skeleton space, then
## carried by the bone that skins the fist (DEF-hand.R, the right hand).
func _attach_staff(skeleton: Skeleton3D, staff: Dictionary) -> void:
	var bone := skeleton.find_bone(staff["bone"])
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = staff["bone"]
	skeleton.add_child(attachment)
	var q: Array = staff["rotation_xyzw"]
	var g: Array = staff["grip_position"]
	var rest := Transform3D(Basis(Quaternion(q[0], q[1], q[2], q[3])).scaled(Vector3.ONE * float(staff["scale"])),
		Vector3(g[0], g[1], g[2]))
	var instance: Node3D = STAFF.instantiate()
	instance.transform = skeleton.get_bone_global_rest(bone).affine_inverse() * rest
	attachment.add_child(instance)
	_staff_bone = bone
	_staff_on_bone = instance.transform
	# The staff-tip socket (the trail's head), for anything else that wants it.
	var tip := Marker3D.new()
	tip.name = "StaffTip"
	tip.position = STAFF_TIP
	instance.add_child(tip)
	for mesh: MeshInstance3D in instance.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(mesh)


## How long `clip` lasts (s).
func clip_length(clip: String) -> float:
	return _player.get_animation(clip).length


## Shows `pose` (MageClips.pose) `delta` seconds after the last call.
func show_pose(pose: Dictionary, delta: float) -> void:
	var clip: String = pose["clip"]
	if clip != _clip:
		_player.play(clip, BLEND_S if _clip != "" else 0.0)
		_clip = clip
		_loop_time = 0.0
	var time: float = pose["time"]
	if time < 0.0:
		# On its own clock: loops, or plays once and holds its last pose.
		var length := _player.get_animation(clip).length
		_loop_time += delta * float(pose["rate"])
		_loop_time = minf(_loop_time, length) if pose.get("once", false) else fposmod(_loop_time, length)
		time = _loop_time
	# Run the crossfade on by the frame's delta, then show the clip at exactly
	# `time` (wrap and a swing's first frame included; the seek re-applies the
	# pose at zero delta, keeping the crossfade's weight).
	_player.advance(delta)
	_player.seek(time, true, true)
	# The clip's own turn goes on the model (under the lean), the spin and
	# lean on the pivot above it.
	_model.rotation.y = FACING_YAW + deg_to_rad(float(pose["yaw_deg"]))
	_pivot.rotation = Vector3(float(pose["lean"]), float(pose["spin"]), 0.0)
	_advance_cloth(pose.get("frozen", false), delta)
	var trail: String = pose.get("trail", "")
	if (_slash_fx.preset != null and clip in SLASH_MOVES) or (plays_move_fx(clip)
			and (_move_fx[clip] as FxMoveEffect).recipe() in TRAIL_RECIPES):
		# His move draws its own sand (a light slash's crescent, the whirlwind's
		# swirl): the staff's trail stays off.
		trail = ""
	_show_trail(trail, pose.get("frozen", false), delta)
	_show_move_fx(pose.get("fx_cast", {}), pose.get("fx_slow", {}))
	_show_slashes(pose.get("fx_cast", {}))


## His kit's move presets ([mage.look]: each move's knob, FxMoves), read on
## every kit read (CharacterModel.read_kit).
func read_kit(kit: CombatSim, _look: Dictionary) -> void:
	var look := kit.look_data() if kit else {}
	_tornado_height_m = float(look.get("tornado_height_m", _tornado_height_m))
	for move: String in _move_fx:
		var knob: Array = FxMoves.knob_of(Kit.MAGE, move)
		(_move_fx[move] as FxMoveEffect).set_preset_name(str(look.get(knob[1], "")))
	set_sand_slash_fx(str(look.get(SLASH_FX_KNOB[1], "")))


## Whether `move` plays its lab preset (CharacterModel.plays_move_fx).
func plays_move_fx(move: String) -> bool:
	return _move_fx.has(move) and (_move_fx[move] as FxMoveEffect).playing()


## His moves' presets' screen-shake kicks since the last take
## (CharacterModel.take_shake_kicks).
func take_shake_kicks() -> Array:
	var out := []
	for move: String in _move_fx:
		var kick := (_move_fx[move] as FxMoveEffect).take_shake_kick()
		if not kick.is_empty():
			out.append(kick)
	return out


## `move`'s lab effect's recipe node (null: none).
func move_fx(move: String) -> Node3D:
	return (_move_fx[move] as FxMoveEffect).node if _move_fx.has(move) else null


## Why `move`'s preset name did not resolve, or "" (none named, or found).
func move_fx_error(move: String) -> String:
	return (_move_fx[move] as FxMoveEffect).error() if _move_fx.has(move) else ""


## Checks: how many times `move`'s unresolved preset name was logged.
func move_fx_errors_logged(move: String) -> int:
	return (_move_fx[move] as FxMoveEffect).errors_logged() if _move_fx.has(move) else 0


## Checks: the seconds into its cast `move`'s effect was last drawn at.
func move_fx_time(move: String) -> float:
	return (_move_fx[move] as FxMoveEffect).time() if _move_fx.has(move) else -1000.0


## The ground under him (the run's: his effects' marks are laid on it).
func set_effect_ground(ground: Ground) -> void:
	_fx_ground = ground


## His moves' lab effects: `cast` (MageClips.move_cast; {} out of a swing)
## starts its move's, round his feet on his ground; every one plays on its
## own clock (a cast's cracks outlast the move). One standing round him and
## turned with him (set_base: the whirlwind's swirl) follows him only while
## its move plays, then stays where it was, fading. One run along his path
## (set_path: the blink's streak) keeps where he stood on its cast's first
## frame and follows him while its move plays, its burst staying where he
## landed.
## A channel's (the tornado) follows its channel ({} once the move is
## over) under the [look] height cap. His ultimate's (the time slow)
## follows his slow (`slow`, the pose's fx_slow: FxTimeSlow.set_slow),
## after the cast too.
func _show_move_fx(cast: Dictionary, slow: Dictionary = {}) -> void:
	var here := _world(self)
	var feet := here.origin
	for move: String in _move_fx:
		var fx: FxMoveEffect = _move_fx[move]
		var own: Dictionary = cast if cast.get("move", "") == move else {}
		if fx.node.has_method("set_centre"):
			fx.node.call("set_centre", feet)
		if fx.node.has_method("set_ground"):
			fx.node.call("set_ground", _fx_ground, feet.y)
		if fx.node.has_method("set_channel"):
			fx.node.call("set_channel", own.get("channel", {}), _tornado_height_m)
		if fx.node.has_method("set_slow"):
			fx.node.call("set_slow", slow)
		if fx.node.has_method("set_base") and not own.is_empty():
			fx.node.call("set_base", feet, here.basis)
		if fx.node.has_method("set_path") and not own.is_empty():
			var kept: Array = _fx_from.get(move, [-1, feet])
			if int(kept[0]) != int(own["seed"]):
				kept = [int(own["seed"]), feet]
				_fx_from[move] = kept
			fx.node.call("set_path", kept[1], feet, here.basis)
		fx.show(own, _fx_low)


## The robe tails and the scarf (rule 9): one SpringBoneSimulator3D on the
## skeleton, a setting per chain the bake lists (root to end, the end bone
## extended so it swings too), colliding with the thighs and knees. The
## skeleton's modifiers run on the model's own clock (show_pose advances
## them once a drawn frame, after the clip), so the cloth is smooth at
## display rate and steps exactly with the pose.
func _build_cloth(chains: Array) -> void:
	if chains.is_empty():
		return
	_skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	_cloth = SpringBoneSimulator3D.new()
	_cloth.name = "Cloth"
	_skeleton.add_child(_cloth)
	for pair: Array in CLOTH_COLLIDERS:
		var sphere := SpringBoneCollisionSphere3D.new()
		sphere.bone_name = pair[0]
		sphere.radius = pair[1]
		_cloth.add_child(sphere)
	_cloth.setting_count = chains.size()
	for i in chains.size():
		var chain: Dictionary = chains[i]
		_cloth.set_root_bone_name(i, chain["root"])
		_cloth.set_end_bone_name(i, chain["end"])
		_cloth.set_extend_end_bone(i, true)
		_cloth.set_end_bone_length(i, 0.05)
		_cloth.set_radius(i, CLOTH_RADIUS)
		_cloth.set_drag(i, CLOTH_DRAG)
		_cloth.set_stiffness(i, CLOTH_STIFFNESS.get(chain["chain"], 2.0))
		_cloth.set_gravity(i, 0.0)
		_cloth.set_enable_all_child_collisions(i, true)


## Hitstop holds the cloth where it is (no inertia, no pull back to the
## pose): the whole body is frozen, so the robe must not keep swinging or
## jitter on the held frame.
func _hold_cloth(held: bool) -> void:
	if _cloth == null or held == _cloth_held:
		return
	_cloth_held = held
	for i in _cloth.setting_count:
		var chain := String(_cloth.get_root_bone_name(i)).trim_prefix("DEF-").get_slice(".", 0)
		_cloth.set_drag(i, 1.0 if held else CLOTH_DRAG)
		_cloth.set_stiffness(i, 0.0 if held else CLOTH_STIFFNESS.get(chain, 2.0))


## Runs the skeleton's modifiers (the cloth) by `delta`.
func _advance_cloth(held: bool, delta: float) -> void:
	if _cloth == null:
		return
	_hold_cloth(held)
	var origin := _world(self).origin
	if _last_origin != Vector3.INF and origin.distance_to(_last_origin) > CLOTH_TELEPORT_M:
		_cloth.reset()
	_last_origin = origin
	_skeleton.advance(delta)


## `node`'s world transform; outside the scene tree (tests), the product of
## its parents' transforms.
func _world(node: Node3D) -> Transform3D:
	if node.is_inside_tree():
		return node.global_transform
	var t := node.transform
	var up := node.get_parent() as Node3D
	while up != null:
		t = up.transform * t
		up = up.get_parent() as Node3D
	return t


## Checks (tests): record the cloth as drawn. The skeleton puts its bones
## back to the clip's pose after the modifiers have drawn them, so the
## swung pose is only readable while skeleton_updated fires.
func watch_cloth() -> void:
	_skeleton.skeleton_updated.connect(_record_cloth)


## Checks: draw the skeleton now (it otherwise updates, modifiers included,
## at the end of the frame).
func update_skeleton_now() -> void:
	_skeleton.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)


func _record_cloth() -> void:
	for i in _skeleton.get_bone_count():
		_drawn[i] = _skeleton.get_bone_global_pose(i)


## The drawn (cloth included) global pose of `bone`, after watch_cloth.
func bone_global_pose(bone: String) -> Transform3D:
	return _world(_skeleton) * _drawn.get(_skeleton.find_bone(bone), Transform3D.IDENTITY)


## How far (radians) cloth `bone` has swung off the clip's pose, seen from
## the top of its chain (the clips hold the cloth at rest on its parent),
## after watch_cloth.
func cloth_offset(bone: String) -> float:
	var i := _skeleton.find_bone(bone)
	var chain: Array[int] = []
	while i >= 0 and String(_skeleton.get_bone_name(i)).get_slice(".", 0) == bone.get_slice(".", 0):
		chain.push_front(i)
		i = _skeleton.get_bone_parent(i)
	var animated: Transform3D = _drawn[i]
	for b in chain:
		animated = animated * _skeleton.get_bone_rest(b)
	var top: Vector3 = _drawn[chain[0]].origin
	var now: Vector3 = _drawn[chain[-1]].origin - top
	return now.angle_to(animated.origin - top)


## How long the trail of a `kind` ("light" or "heavy") swing takes to fade
## (s): [trail] heavy_fade_s for a heavy one (fade_s if the page has none),
## fade_s for a light one.
static func trail_fade_s(values: Dictionary, kind: String) -> float:
	if kind == "heavy":
		return float(values.get("heavy_fade_s", values["fade_s"]))
	return float(values["fade_s"])


## The [trail] values (feel page) as the effect intensity draws them
## (PlayerAvatar hands them through EffectIntensity.trail_look) and the
## quality: low draws the ribbon with straight segments between samples
## instead of a smoothed curve.
func set_trail_look(values: Dictionary, low_quality: bool) -> void:
	_trail_look = values
	_trail.fade_s = float(values["fade_s"])
	# Brighter than its colour lifts the sand off the dark floor (the look stills).
	var glow := float(values.get("glow", 1.0))
	_trail_material.set_shader_parameter("glow", glow)
	((_grains.multimesh.mesh as PrimitiveMesh).material as StandardMaterial3D).albedo_color = Color(glow, glow, glow)
	_trail.grain_count = int(values.get("grain_count", 0))
	_trail.grain_life_s = float(values.get("grain_life_s", 0.45))
	_grains.multimesh.instance_count = _trail.grain_count
	_trail_subdivisions = 0 if low_quality else TRAIL_SUBDIVISIONS
	_fx_low = low_quality


## His light slashes' preset by `name` ([mage.look] sand_slash_fx; "" the
## staff's trail). A name with no saved preset fails clearly (FxMovePreset:
## printed once, kept as sand_slash_error) and the slashes keep the trail.
func set_sand_slash_fx(name: String) -> void:
	_slash_fx.use(name)


## Why his light slashes' preset name did not resolve, or "" (none, or found).
func sand_slash_error() -> String:
	return _slash_fx.error


## Checks: how many times an unresolved sand_slash_fx name was logged.
func sand_slash_errors_logged() -> int:
	return _slash_fx.logged


## The recipe his last light slash plays (drawn only while sand_slash_fx
## names a preset).
func sand_slash() -> FxSandSlash:
	return _slashes[_slash_last]


## Checks: the kind of swing ("light", "heavy") the staff's trail was fed
## this frame, "" none.
func trail_kind() -> String:
	return _trail_kind


func _build_slashes() -> void:
	for i in SLASH_POOL:
		var slash := FxSandSlash.new()
		slash.name = "SandSlash%d" % i
		slash.visible = false
		add_child(slash)
		_slashes.append(slash)
		_slash_clocks.append(FxCastClock.new())
		_slash_seeds.append(-1)


## His light slashes' preset (ticket 01): `cast` (MageClips.move_cast: the
## move's seed from its event, the seconds since it began when this pose
## shows it, its hit marker's seconds after it) starts a slash on the next
## recipe of the pool, on its own clock, for a light slash (SLASH_MOVES)
## whose seed is new; each slash stands round him while its move plays and
## stays where it was after, fading out. The Low version at low quality
## and at Low graphics.
func _show_slashes(cast: Dictionary) -> void:
	# A pool that didn't build (a script run without the autoloads) shows none.
	if _slashes.size() < SLASH_POOL:
		return
	var playing := -1
	if _slash_fx.preset != null and not cast.is_empty() and cast["move"] in SLASH_MOVES:
		playing = _slash_seeds.find(int(cast["seed"]))
		if playing < 0:
			playing = (_slash_last + 1) % SLASH_POOL
			_slash_last = playing
			_slash_seeds[playing] = int(cast["seed"])
			_slash_clocks[playing].cast(float(cast["since_s"]))
			_slashes[playing].impact_s = float(cast["hit_s"])
			_slashes[playing].move = cast["move"]
			_slashes[playing].hit = cast.get("hit", {})
	var preset := _slash_fx.drawn(GraphicsSettings.LOW if _fx_low else FxLow.game_graphics)
	var here := _world(self)
	for i in SLASH_POOL:
		var slash := _slashes[i]
		slash.visible = preset != null and _slash_seeds[i] >= 0
		if not slash.visible:
			slash.show_at(0, -1000.0)
			continue
		slash.preset = preset
		if i == playing:
			slash.set_base(here.origin, here.basis)
		slash.show_at(_slash_seeds[i], _slash_clocks[i].time())


func _build_trail() -> void:
	_trail_draw = ImmediateMesh.new()
	_trail_material = ShaderMaterial.new()
	_trail_material.shader = TRAIL_SHADER
	_trail_material.set_shader_parameter("grain_tex", TRAIL_GRAIN_TEX)
	_trail_material.set_shader_parameter("streak_tex", TRAIL_STREAK_TEX)
	_build_grains()
	_trail_mesh = MeshInstance3D.new()
	_trail_mesh.name = "StaffTrail"
	_trail_mesh.mesh = _trail_draw
	_trail_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# World space: the ribbon stays where the head passed as the body moves on.
	_trail_mesh.top_level = true
	add_child(_trail_mesh)


func warm_up(look: Dictionary) -> void:
	set_tint(Color(Color.WHITE, 0.5))
	set_glow(Color.WHITE, look)
	_warm_ribbon(_trail_draw, _trail_material, true)
	_grains.multimesh.instance_count = 1
	_grains.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY, global_position))


## The up of the ground he stands on (PlayerAvatar, each frame): his sand
## grains fall along its negative (world up on the level ground).
func set_ground_up(up: Vector3) -> void:
	_trail.up = up


## The grains: camera-facing soft dots, one MultiMesh instance per grain of
## the pool, drawn in world space like the ribbon.
func _build_grains() -> void:
	var quad := QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = GRAIN_TEX
	quad.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	_grains = MultiMeshInstance3D.new()
	_grains.name = "SandGrains"
	_grains.multimesh = multimesh
	_grains.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grains.top_level = true
	add_child(_grains)


## Feeds the trail from the staff-tip socket while the swing trails (`kind`
## "light" or "heavy", MageClips.pose), ages it by `delta` unless hitstop
## holds the swing (`frozen`), and redraws it.
func _show_trail(kind: String, frozen: bool, delta: float) -> void:
	_trail_kind = kind
	if kind != "":
		_trail.fade_s = trail_fade_s(_trail_look, kind)
	_trail.advance(0.0 if frozen else delta)
	# Frozen, the held hit pose is still recorded once (StaffTrail drops repeats).
	if kind != "" and _staff_bone >= 0:
		var on_bone := _world(_skeleton) * _skeleton.get_bone_global_pose(_staff_bone) * _staff_on_bone
		var tip := on_bone * STAFF_TIP
		var down := (on_bone.origin - tip).normalized()
		var width := float(_trail_look["heavy_width_m" if kind == "heavy" else "light_width_m"])
		_trail.add(tip, tip + down * width)
	_show_grains()
	_trail_draw.clear_surfaces()
	var strip := _trail.strip(_trail_subdivisions)
	var points: PackedVector3Array = strip["points"]
	if points.size() < 4:
		return
	var alphas: PackedFloat32Array = strip["alphas"]
	var us: PackedFloat32Array = strip["us"]
	var opacity := float(_trail_look["opacity"])
	_trail_draw.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _trail_material)
	for i in points.size():
		# The inner edge (odd rows) fades out too, so the ribbon reads as a wake.
		var edge := 1.0 if i % 2 == 0 else 0.35
		_trail_draw.surface_set_color(Color(TRAIL_COLOR.srgb_to_linear(), opacity * edge))
		_trail_draw.surface_set_uv(Vector2(us[i], float(i % 2)))
		_trail_draw.surface_set_uv2(Vector2(alphas[i], 0.0))
		_trail_draw.surface_add_vertex(points[i])
	_trail_draw.surface_end()


## The live grains into the pool's instances (the rest hidden).
func _show_grains() -> void:
	var multimesh := _grains.multimesh
	var live := _trail.grains()
	var size := float(_trail_look.get("grain_size_m", 0.06))
	multimesh.visible_instance_count = mini(live.size(), multimesh.instance_count)
	for i in multimesh.visible_instance_count:
		var grain: Dictionary = live[i]
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * size), grain["position"]))
		multimesh.set_instance_color(i, Color(GRAIN_COLOR.srgb_to_linear(),
			float(grain["alpha"]) * float(_trail_look["opacity"])))


## The standard player glow (PlayerGlow) in `color`, or none (a clear
## colour): the shared material as the next pass after each outline.
func set_glow(color: Color, look: Dictionary) -> void:
	var glow: Material = PlayerGlow.material(color, look) if color.a > 0.0 else null
	for material in _outlines:
		material.next_pass = glow


## A see-through colour over the whole model (and staff), or none
## (Color(0, 0, 0, 0)): the invulnerable and hit-taken cues.
func set_tint(color: Color) -> void:
	_overlay.albedo_color = color
	for mesh in _meshes:
		mesh.material_overlay = _overlay if color.a > 0.0 else null
