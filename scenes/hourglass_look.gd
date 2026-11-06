## The ultimate's hourglass (mage step 6c; spec, Mage step 3 grill rulings):
## a see-through sand-gold hologram hourglass standing round the mage, its
## height [look] hourglass_size times his. While he casts, sand pours from
## the top bulb into the bottom one as the cast charges; as the slow begins
## the pour finishes and the glass shatters into shards over [look]
## hourglass_shatter_s (the screen's sand tint, UltimateHud, takes over);
## then a faint hourglass stays over him for the rest of his slow ("I'm in
## ult"): hourglass_marker_own for your own mage, hourglass_marker_other for
## the other players'.
##
## Read from synced state only (state()): the avatar's move and move frame
## (the cast), its ultimate cooldown (ticks since the cast completed,
## since_fired) and the world's slow. Visual only.
##
## Built in code because the sand follows the cast's progress: the bulbs are
## a lathed profile (LatheMesh) under a fresnel glass shader derived from
## Binbun's shield shell (hourglass_glass.gdshader); plates and pillars are
## plain meshes; the shards one MultiMesh; the sparkles a CPUParticles3D of
## Kenney star_06 (CC0). No lights.
class_name HourglassLook
extends Node3D

## Of the sand, the share poured by the cast's last frame; the rest pours in
## the first POUR_FINISH_SHARE of the shatter time, then the glass breaks.
const POUR_AT_CAST_END := 0.8
const POUR_FINISH_SHARE := 0.4
## The marker fades in over this many ticks after the shatter.
const MARKER_FADE_TICKS := 15
## The shape, as shares of the hourglass's height: plates, bulbs and neck.
const PLATE_R := 0.31
const PLATE_H := 0.03
const PILLAR_R := 0.01
const PILLAR_AT := 0.285
## The bulbs' profile (radius, height) from the bottom plate to the top one.
const PROFILE := [Vector2(0.2, 0.03), Vector2(0.25, 0.08), Vector2(0.272, 0.17), Vector2(0.268, 0.27),
	Vector2(0.235, 0.38), Vector2(0.17, 0.49), Vector2(0.09, 0.57), Vector2(0.05, 0.62), Vector2(0.09, 0.67),
	Vector2(0.17, 0.75), Vector2(0.225, 0.84), Vector2(0.235, 0.92), Vector2(0.2, 0.97)]
const NECK_Y := 0.62
const TOP_SAND_TOP := 0.9
const PILE_H := 0.12
const PILE_R := 0.25
const STREAM_R := 0.008
const SHARDS := 24
const SHARD_SPEED := 1.5
## Colours: the glass's frame and the sand (HDR: brighter than 1 glows).
const FRAME_COLOR := Color(1.0, 0.8, 0.38, 0.9)
const PLATE_COLOR := Color(1.0, 0.78, 0.36, 0.22)
const SAND_COLOR := Color(1.0, 0.8, 0.42, 0.85)
const SHARD_COLOR := Color(1.0, 0.86, 0.5, 0.75)
const SPARKLE_TEX := preload("res://vfx/kenney-particle-pack/PNG (Transparent)/star_06.png")
const GLASS_SHADER := preload("res://scenes/hourglass_glass.gdshader")

var _glass_mat: ShaderMaterial
var _frame_mat: StandardMaterial3D
var _plate_mat: StandardMaterial3D
var _sand_mat: StandardMaterial3D
var _shard_mat: StandardMaterial3D
var _bulbs: MeshInstance3D
var _frame: Node3D
var _top_sand: MeshInstance3D
var _pile: MeshInstance3D
var _stream: MeshInstance3D
var _shards: MultiMeshInstance3D
var _sparkles: CPUParticles3D
## The shards' flight: per shard {from, velocity, spin axis}, unit height.
var _flight: Array = []
var _height_m := -1.0
## Its colours (the constants, unless a recipe tints it: set_colours).
var _frame_color := FRAME_COLOR
var _plate_color := PLATE_COLOR
var _sand_color := SAND_COLOR
var _shard_color := SHARD_COLOR


func _init() -> void:
	name = "Hourglass"
	_build()
	visible = false


## What shows for one player (`view`) with the [look] values `look`:
## {phase: "" | "cast" | "shatter" | "marker", pour (0 to 1: the sand run
## through), shatter (0 to 1: the break's progress), opacity (0 to 1)}.
## view: cast_frame (the cast's move frame, 0 = not casting), cast_frames,
## tick_factor, since_fired (ticks since his cast completed, -1 none; see
## since_fired), slow_left (the world's slow ticks), slow_frames (the slow
## one ultimate adds), own (the local player's mage).
static func state(view: Dictionary, look: Dictionary) -> Dictionary:
	var none := {"phase": "", "pour": 0.0, "shatter": 0.0, "opacity": 0.0}
	var factor := float(view.get("tick_factor", 0.0))
	var cast_frame := int(view.get("cast_frame", 0))
	if cast_frame > 0:
		var frames := maxf(1.0, float(view.get("cast_frames", 1)))
		var t := clampf((cast_frame - 1 + factor) / frames, 0.0, 1.0)
		return {"phase": "cast", "pour": POUR_AT_CAST_END * t, "shatter": 0.0, "opacity": 1.0}
	var since := int(view.get("since_fired", -1))
	if since < 0:
		return none
	var shatter_ticks := roundi(float(look.get("hourglass_shatter_s", 0.5)) * MoveKit.TICK_HZ)
	if since < shatter_ticks:
		var t := clampf((since + factor) / shatter_ticks, 0.0, 1.0)
		return {"phase": "shatter", "pour": lerpf(POUR_AT_CAST_END, 1.0, clampf(t / POUR_FINISH_SHARE, 0.0, 1.0)),
			"shatter": clampf((t - POUR_FINISH_SHARE) / (1.0 - POUR_FINISH_SHARE), 0.0, 1.0), "opacity": 1.0}
	if since >= int(view.get("slow_frames", 0)) or int(view.get("slow_left", 0)) <= 0:
		return none
	var faint := float(look.get("hourglass_marker_own" if view.get("own", true) else "hourglass_marker_other", 0.2))
	var fade_in := clampf((since - shatter_ticks + factor) / MARKER_FADE_TICKS, 0.0, 1.0)
	return {"phase": "marker", "pour": 1.0, "shatter": 0.0, "opacity": faint * fade_in}


## Ticks since this player's cast completed, from its ultimate cooldown
## (`cooldown_left`, synced) and the cooldown one cast starts
## (the game's simulation): 0 on the tick it fires, -1 while
## charged (or casting).
static func since_fired(cooldown_left: int, cooldown_frames: int) -> int:
	if cooldown_left <= 0 or cooldown_frames <= 0:
		return -1
	return maxi(0, cooldown_frames - cooldown_left - 1)


## Draws `shown` (state()) for a mage `mage_height_m` tall with [look] `look`.
func show_state(shown: Dictionary, mage_height_m: float, look: Dictionary) -> void:
	var opacity := float(shown["opacity"])
	visible = shown["phase"] != "" and opacity > 0.0
	if not visible:
		if _sparkles:
			_sparkles.emitting = false
		_shards.visible = false
		return
	var height := maxf(0.1, float(look.get("hourglass_size", 1.6)) * mage_height_m)
	if not is_equal_approx(height, _height_m):
		_height_m = height
		scale = Vector3.ONE * height
	var shatter := float(shown["shatter"])
	# The glass and frame go as the break starts; the shards fly and fade.
	var whole := opacity * (1.0 - smoothstep(0.0, 0.15, shatter))
	_glass_mat.set_shader_parameter("opacity", whole)
	_frame_mat.albedo_color = Color(_frame_color, _frame_color.a * whole)
	_plate_mat.albedo_color = Color(_plate_color, _plate_color.a * whole)
	_sand_mat.albedo_color = Color(_sand_color, _sand_color.a * whole)
	_bulbs.visible = whole > 0.0
	_frame.visible = whole > 0.0
	_show_sand(float(shown["pour"]), whole > 0.0)
	_show_shards(shatter, opacity)
	if _sparkles:
		_sparkles.emitting = shown["phase"] == "cast" or (shown["phase"] == "shatter" and shatter == 0.0)


## Drops its own sparkles (a recipe drawing its own: FxTimeSlow).
func drop_sparkles() -> void:
	if _sparkles:
		_sparkles.free()
		_sparkles = null


## A recipe's tint (FxTimeSlow): the sand and shards in `sand`, the frame
## and plates in `frame` (their own opacities kept).
func set_colours(sand: Color, frame: Color) -> void:
	_sand_color = Color(sand, SAND_COLOR.a)
	_shard_color = Color(sand.lerp(Color.WHITE, 0.3), SHARD_COLOR.a)
	_frame_color = Color(frame, FRAME_COLOR.a)
	_plate_color = Color(frame, PLATE_COLOR.a)


## How many shards fly as it breaks (0 to SHARDS; all by default).
func set_shards(count: int) -> void:
	_shards.multimesh.visible_instance_count = clampi(count, 0, SHARDS)


## The shards (one MultiMesh).
func shards() -> MultiMeshInstance3D:
	return _shards


## The sand `pour` of the way through: the top cone sinking to the neck, the
## pile at the bottom rising, the stream between while it runs.
func _show_sand(pour: float, shown: bool) -> void:
	var left := 1.0 - pour
	_top_sand.visible = shown and left > 0.01
	if _top_sand.visible:
		var top := NECK_Y + (TOP_SAND_TOP - NECK_Y) * sqrt(left)
		_top_sand.scale = Vector3(_radius_at(top), top - NECK_Y, _radius_at(top))
		_top_sand.position.y = NECK_Y
	_pile.visible = shown and pour > 0.01
	if _pile.visible:
		_pile.scale = Vector3(PILE_R * sqrt(pour), PILE_H * pour, PILE_R * sqrt(pour))
	_stream.visible = shown and pour > 0.0 and pour < 1.0
	if _stream.visible:
		var bottom := PLATE_H + PILE_H * pour
		_stream.scale = Vector3(1.0, NECK_Y - bottom, 1.0)
		_stream.position.y = bottom


func _show_shards(shatter: float, opacity: float) -> void:
	var multimesh := _shards.multimesh
	_shards.visible = shatter > 0.0 and shatter < 1.0 and multimesh.visible_instance_count != 0
	if not _shards.visible:
		return
	_shard_mat.albedo_color = Color(_shard_color, _shard_color.a * opacity * (1.0 - shatter * shatter))
	for i in SHARDS:
		var f: Dictionary = _flight[i]
		var t := shatter * 0.6
		var at: Vector3 = f["from"] + f["velocity"] * t + Vector3.DOWN * 0.5 * t * t
		var turn := Basis(f["axis"], shatter * 9.0) * Basis.from_scale(Vector3.ONE * float(f["size"]) * (1.0 - 0.5 * shatter))
		multimesh.set_instance_transform(i, Transform3D(turn, at))


## The bulb's radius at height `y` (shares of the height), on PROFILE.
static func _radius_at(y: float) -> float:
	for i in range(1, PROFILE.size()):
		var a: Vector2 = PROFILE[i - 1]
		var b: Vector2 = PROFILE[i]
		if y <= b.y:
			return lerpf(a.x, b.x, clampf((y - a.y) / maxf(0.0001, b.y - a.y), 0.0, 1.0))
	return PROFILE[PROFILE.size() - 1].x


# --- Building it (once per player, unit height; scaled to his) ---------------

func _build() -> void:
	_glass_mat = ShaderMaterial.new()
	_glass_mat.shader = GLASS_SHADER
	# A player effect round his feet: below every enemy ground mark
	# (GroundDrawOrder; spec story 37), the shards over the glass.
	_glass_mat.render_priority = GroundDrawOrder.PLAYER_EFFECTS
	_frame_mat = _flat_material(FRAME_COLOR)
	_plate_mat = _flat_material(PLATE_COLOR)
	_sand_mat = _flat_material(SAND_COLOR)
	_shard_mat = _flat_material(SHARD_COLOR)
	_shard_mat.render_priority = GroundDrawOrder.PLAYER_EFFECTS + 1
	_bulbs = _instance(LatheMesh.build(PackedVector2Array(PROFILE), 40), _glass_mat)
	_frame = Node3D.new()
	add_child(_frame)
	for y: float in [0.0, 1.0 - PLATE_H]:
		var plate := CylinderMesh.new()
		plate.top_radius = PLATE_R
		plate.bottom_radius = PLATE_R
		plate.height = PLATE_H
		plate.radial_segments = 40
		var node := _instance(plate, _plate_mat, _frame)
		node.position.y = y + PLATE_H / 2.0
		# A rim ring just inside each plate's edge, like the still's engraved rings.
		var rim := TorusMesh.new()
		rim.inner_radius = PLATE_R * 0.86
		rim.outer_radius = PLATE_R * 0.9
		var ring := _instance(rim, _frame_mat, _frame)
		ring.position.y = y + PLATE_H
		ring.scale = Vector3(1.0, 0.2, 1.0)
	for k in 3:
		var pillar := CylinderMesh.new()
		pillar.top_radius = PILLAR_R
		pillar.bottom_radius = PILLAR_R
		pillar.height = 1.0 - 2.0 * PLATE_H
		pillar.radial_segments = 8
		var node := _instance(pillar, _frame_mat, _frame)
		var turn := TAU * k / 3.0 + PI / 6.0
		node.position = Vector3(sin(turn) * PILLAR_AT, 0.5, cos(turn) * PILLAR_AT)
	# The top sand: a cone narrowing to the neck (unit, scaled by _show_sand).
	var cone := CylinderMesh.new()
	cone.top_radius = 1.0
	cone.bottom_radius = 0.2
	cone.height = 1.0
	cone.radial_segments = 24
	_top_sand = _instance(_offset_up(cone), _sand_mat)
	var heap := CylinderMesh.new()
	heap.top_radius = 0.15
	heap.bottom_radius = 1.0
	heap.height = 1.0
	heap.radial_segments = 24
	_pile = _instance(_offset_up(heap), _sand_mat)
	_pile.position.y = PLATE_H
	var line := CylinderMesh.new()
	line.top_radius = STREAM_R
	line.bottom_radius = STREAM_R
	line.height = 1.0
	line.radial_segments = 6
	_stream = _instance(_offset_up(line), _sand_mat)
	_build_shards()
	_build_sparkles()


## The shards: small glass triangles round the bulbs, one MultiMesh.
func _build_shards() -> void:
	var tri := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, -0.4, 0), Vector3(0.5, -0.3, 0), Vector3(0.05, 0.6, 0)])
	tri.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = tri
	multimesh.instance_count = SHARDS
	_shards = MultiMeshInstance3D.new()
	_shards.multimesh = multimesh
	_shards.material_override = _shard_mat
	_shards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shards.visible = false
	add_child(_shards)
	# The same flight every time (a fixed seed): out from the glass, a little up.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in SHARDS:
		var y := rng.randf_range(0.08, 0.92)
		var turn := TAU * (i + rng.randf()) / SHARDS
		var out := Vector3(sin(turn), 0.0, cos(turn))
		_flight.append({"from": out * _radius_at(y) + Vector3.UP * y,
			"velocity": (out + Vector3.UP * rng.randf_range(-0.1, 0.5)) * SHARD_SPEED * rng.randf_range(0.6, 1.2),
			"axis": Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5).normalized(),
			"size": rng.randf_range(0.08, 0.16)})


## Sparkles drifting round the glass while it charges (Kenney star_06).
## Its sparkles follow the effect intensity: its avatar tracks the hourglass
## (EffectIntensity.track, "mage.hourglass").
func _build_sparkles() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.render_priority = GroundDrawOrder.PLAYER_EFFECTS + 1
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.albedo_texture = SPARKLE_TEX
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	quad.material = material
	_sparkles = CPUParticles3D.new()
	_sparkles.mesh = quad
	_sparkles.emitting = false
	_sparkles.amount = 20
	_sparkles.lifetime = 0.6
	_sparkles.local_coords = true
	_sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_sparkles.emission_ring_axis = Vector3.UP
	_sparkles.emission_ring_height = 0.9
	_sparkles.emission_ring_radius = 0.33
	_sparkles.emission_ring_inner_radius = 0.28
	_sparkles.position.y = 0.5
	_sparkles.direction = Vector3.UP
	_sparkles.spread = 30.0
	_sparkles.gravity = Vector3.ZERO
	_sparkles.initial_velocity_min = 0.05
	_sparkles.initial_velocity_max = 0.15
	_sparkles.scale_amount_min = 0.6
	_sparkles.scale_amount_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.9, 0.6, 1.0))
	fade.set_color(1, Color(1.0, 0.8, 0.4, 0.0))
	_sparkles.color_ramp = fade
	_sparkles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sparkles)


## `mesh` (centred on its origin, 1 tall) moved so it stands on its origin.
static func _offset_up(mesh: PrimitiveMesh) -> Mesh:
	var arrays := mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		vertices[i].y += 0.5
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


static func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	material.render_priority = GroundDrawOrder.PLAYER_EFFECTS
	return material


func _instance(mesh: Mesh, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(node)
	return node
