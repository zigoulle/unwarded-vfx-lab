## The ring arena's pooled one-shot effects (zone SOP 6c-6d), built with the
## arena (before the network clock starts: loading the packs and compiling
## their shaders would otherwise stall the first spawns) and played by
## ZoneLooks and RingArenaView:
##
## - Vent eruption (`erupt`): a knowercoder `3d_fire` column (its shader
##   recoloured to lava: vent_fire.gdshader) shooting up and
##   dying down, Kenney `flame` and `fire` licks, molten blobs (`circle_05`)
##   and a puff of dark smoke (`smoke_04`); about a person tall at
##   `[zone_look] vent_eruption_size` 1. (Binbun's ExplosionFX `ground` was
##   tried: its particles are sized in world units, so scaling the node does
##   not shrink it, and its 2 m white fireball swamped the small vent.)
## - Lava splash (`splash`): molten blobs (Kenney `circle_05`) and flame
##   licks thrown up from the lava: where an enemy climbs out, and the
##   ambient spurts.
## - Rock dust (`dust`): Kenney `smoke_04` puffs and `dirt_02` chips: a
##   pillar taking a slam, breaking, or rising again.
## - Ambient spurts (`step`): every `[zone_look] spurt_every_s` or so, a
##   splash at a random spot on the lava (pit or outer lava).
##
## Every effect is skipped when its spot is off screen (the timers keep
## running), each pool is fixed (the oldest effect is reused when all are
## busy), and the packs' lights and sounds are stripped (ImpactLooks.strip).
## Every pool is tracked under the effect intensity's "zone.lava"
## (EffectIntensity): more, bigger, brighter licks and blobs as it rises; Low's
## fewer licks are scaled the same. Looks only.
class_name RingFx
extends RefCounted

const FIRE_SCENE := "res://vfx/knowercoder-3d-fire-and-smoke/Scenes/3d_fire.tscn"
## The pack's flame shader recoloured to lava (vent_fire.gdshader).
const FIRE_SHADER := preload("res://scenes/vent_fire.gdshader")
const KENNEY_DIR := ImpactLooks.KENNEY_DIR
const POOL_ERUPTIONS := 3
const POOL_SPLASHES := 5
const POOL_DUST := 4
## The fire column: how long it lasts, and its height share of the
## knowercoder flame at the peak (its lit part is about the lower half of
## its 1.75 m cylinder, so 2 x shows a flame about a person tall).
const ERUPTION_S := 1.1
const FIRE_PEAK := 2.0
## The share of ambient spurts that leap from the pit (the rest from the
## outer lava).
const PIT_SPURTS := 0.35
const LAVA_TINT := Color(1.0, 0.55, 0.15)
const SMOKE_TINT := Color(0.12, 0.08, 0.07, 0.7)
const BLOB_TINT := Color(1.0, 0.62, 0.22, 1.0)
const DUST_COLOR := Color(0.32, 0.26, 0.24, 0.8)
const CHIP_COLOR := Color(0.16, 0.12, 0.12, 1.0)

var _parent: Node3D
var _eruptions: Array = []
var _splashes: Array[Node3D] = []
var _dusts: Array[Node3D] = []
var _next := {"eruption": 0, "splash": 0, "dust": 0}
var _spurt_in_s := 1.0
var _rng := RandomNumberGenerator.new()


func _init(parent: Node3D, low_quality: bool) -> void:
	_parent = parent
	var fire := load(FIRE_SCENE) as PackedScene
	for i in POOL_ERUPTIONS:
		_eruptions.append(_eruption_node(fire, low_quality))
	for i in POOL_SPLASHES:
		_splashes.append(_splash_node(low_quality))
	for i in POOL_DUST:
		_dusts.append(_dust_node())


## A spot on open lava for an ambient spurt, from two numbers in [0, 1): in
## the pit (PIT_SPURTS of them) or out on the outer lava, never on the ring
## or by a bridge, and at least a metre off the cave wall.
static func spurt_spot(tuning: Dictionary, u: float, v: float) -> Vector2:
	var pit := RingArena.pit_radius(tuning)
	var outer := RingArena.outer_radius(tuning)
	var wall := RingArena.wall_radius(tuning)
	var spot: Vector2
	if u < PIT_SPURTS:
		spot = RingArena.at_angle(360.0 * u / PIT_SPURTS, maxf(0.0, pit - 1.0) * sqrt(v))
	else:
		var r := outer + 0.8 + v * maxf(0.0, wall - outer - 1.8)
		spot = RingArena.at_angle(360.0 * (u - PIT_SPURTS) / (1.0 - PIT_SPURTS), r)
		for bridge: Dictionary in RingArena.bridges(tuning):
			var dir: Vector2 = bridge["dir"]
			var across := absf(spot.dot(Vector2(-dir.y, dir.x)))
			if spot.dot(dir) > 0.0 and across < float(bridge["half_width_m"]) + 1.0:
				# Beside a bridge: the same distance out, a quarter turn round.
				spot = Vector2(-spot.y, spot.x)
	return spot


## One drawn frame: the eruptions' fire columns grow and die down, and the
## ambient spurts' timer runs (a spurt only shows on screen).
func step(delta: float, tuning: Dictionary) -> void:
	for one: Dictionary in _eruptions:
		if one["age"] < 0.0:
			continue
		one["age"] = float(one["age"]) + delta
		var t := float(one["age"]) / ERUPTION_S
		var fire: Node3D = one["fire"]
		fire.visible = t < 1.0
		if t >= 1.0:
			one["age"] = -1.0
			continue
		# Shoots up in the first fifth, then sinks back.
		var h := FIRE_PEAK * (smoothstep(0.0, 0.18, t) * (1.0 - smoothstep(0.45, 1.0, t)))
		var size := float(one["size"])
		fire.scale = Vector3(1.5 * size, maxf(0.001, h * size), 1.5 * size)
	_spurt_in_s -= delta
	if _spurt_in_s <= 0.0:
		var every := float(tuning.get("zone_look", {}).get("spurt_every_s", 1.5))
		_spurt_in_s = every * _rng.randf_range(0.4, 1.6)
		var spot := spurt_spot(tuning, _rng.randf(), _rng.randf())
		splash(Vector3(spot.x, RingArenaView.LAVA_Y, spot.y), _rng.randf_range(0.7, 1.2), true)


## Shows the first effect of every pool at `at`, playing, so their shaders
## compile while the arena warms up (RingArenaView); `cool` hides them again.
func warm(at: Vector3) -> void:
	var one: Dictionary = _eruptions[0]
	(one["root"] as Node3D).position = at
	(one["root"] as Node3D).visible = true
	(one["fire"] as Node3D).visible = true
	(one["fire"] as Node3D).scale = Vector3.ONE * 0.5
	for emitter: CPUParticles3D in one["licks"]:
		emitter.restart()
	for node: Node3D in [_splashes[0], _dusts[0]]:
		node.position = at
		node.visible = true
		for emitter: CPUParticles3D in node.get_children():
			emitter.restart()


func cool() -> void:
	for one: Dictionary in _eruptions:
		(one["root"] as Node3D).visible = false
		(one["fire"] as Node3D).visible = false
		one["age"] = -1.0
	for node: Node3D in _splashes + _dusts:
		node.visible = false


## A vent erupting at `at` (its spot on the floor), `size` times a person
## tall.
func erupt(at: Vector3, size: float) -> void:
	if size <= 0.0 or not _seen(at, 2.0):
		return
	var one: Dictionary = _eruptions[_take("eruption", _eruptions.size())]
	var root: Node3D = one["root"]
	root.position = at
	root.visible = true
	one["age"] = 0.0
	one["size"] = size
	for emitter: CPUParticles3D in one["licks"]:
		emitter.initial_velocity_min = float(emitter.get_meta("speed")) * 0.6 * size
		emitter.initial_velocity_max = float(emitter.get_meta("speed")) * size
		emitter.restart()


## Molten blobs and flame licks thrown up from the lava at `at`; `high` for a
## spurt leaping well up, else a low splash (an enemy climbing out).
func splash(at: Vector3, size: float, high: bool = false) -> void:
	if not _seen(at, 1.5):
		return
	var node := _splashes[_take("splash", _splashes.size())]
	node.position = at
	node.visible = true
	for emitter: CPUParticles3D in node.get_children():
		var lift := (5.5 if high else 3.2) * size
		emitter.initial_velocity_min = lift * 0.6
		emitter.initial_velocity_max = lift
		emitter.restart()


## Rock dust and chips thrown out at `at`, about `radius` metres.
func dust(at: Vector3, radius: float) -> void:
	if not _seen(at, radius + 1.0):
		return
	var node := _dusts[_take("dust", _dusts.size())]
	node.position = at
	node.visible = true
	for emitter: CPUParticles3D in node.get_children():
		emitter.emission_sphere_radius = maxf(0.2, radius * 0.5)
		emitter.initial_velocity_min = radius * 0.8
		emitter.initial_velocity_max = radius * 2.0
		emitter.restart()


## True when `at` (or the space up to `reach` metres above it) is in the
## current camera's view; with no camera (headless), never.
func _seen(at: Vector3, reach: float) -> bool:
	return RingFx.on_screen(_parent, at, reach)


## True when a spot (or the space `reach` metres above it) is in view of the
## camera drawing `node`'s viewport. Off-screen culling for every repeated
## effect of the ring arena.
static func on_screen(node: Node, at: Vector3, reach: float) -> bool:
	if node == null or not node.is_inside_tree():
		return false
	var camera := node.get_viewport().get_camera_3d()
	if camera == null:
		return false
	return camera.is_position_in_frustum(at) or camera.is_position_in_frustum(at + Vector3(0, reach, 0))


func _take(kind: String, size: int) -> int:
	var i: int = _next[kind]
	_next[kind] = (i + 1) % size
	return i


# --- Building the pools -------------------------------------------------------

func _eruption_node(fire_scene: PackedScene, low_quality: bool) -> Dictionary:
	var root := Node3D.new()
	root.visible = false
	_parent.add_child(root)
	var fire := fire_scene.instantiate() as Node3D
	var recoloured := ShaderMaterial.new()
	recoloured.shader = FIRE_SHADER
	var pack := (fire as GeometryInstance3D).material_override as ShaderMaterial
	for key: String in ["top_radius", "bottom_radius", "center_radius", "center_position", "cylinder_height",
			"bottom_curve", "_vibrate_amplitude", "_vibrate_frequency", "_speed", "_scale"]:
		recoloured.set_shader_parameter(key, pack.get_shader_parameter(key))
	(fire as GeometryInstance3D).material_override = recoloured
	# Scaled from the vent up (the flame's foot is its origin).
	var holder := Node3D.new()
	holder.add_child(fire)
	holder.visible = false
	root.add_child(holder)
	var licks: Array[CPUParticles3D] = []
	var many := 1 if low_quality else 2
	# [texture, tint, amount, quad, scale range, life, gravity, spread, speed, glow]
	for part: Array in [
			["flame_02.png", LAVA_TINT, 6 * many, 1.3, Vector2(0.7, 1.3), 0.6, Vector3(0, 1.0, 0), 10.0, 5.0, true],
			["fire_01.png", LAVA_TINT, 4 * many, 1.6, Vector2(0.7, 1.1), 0.5, Vector3(0, 0.5, 0), 40.0, 1.8, true],
			["circle_05.png", BLOB_TINT, 6 * many, 0.22, Vector2(0.5, 1.0), 0.9, Vector3(0, -9.8, 0), 25.0, 6.5, true],
			["smoke_04.png", SMOKE_TINT, 3 * many, 1.4, Vector2(0.6, 1.3), 1.4, Vector3(0, 1.2, 0), 20.0, 1.6, false]]:
		var emitter := _emitter(part[0], part[1], part[2], part[3], part[4], part[5], part[6], part[7], part[9])
		emitter.set_meta("speed", part[8])
		licks.append(emitter)
		root.add_child(emitter)
	EffectIntensity.track(root, "zone.lava")
	return {"root": root, "fire": holder, "licks": licks, "age": -1.0, "size": 1.0}


func _splash_node(low_quality: bool) -> Node3D:
	var node := Node3D.new()
	node.visible = false
	node.add_child(_emitter("circle_05.png", BLOB_TINT, 7 if low_quality else 14, 0.2, Vector2(0.5, 1.2), 1.0,
		Vector3(0, -9.8, 0), 22.0, true))
	node.add_child(_emitter("flame_05.png", LAVA_TINT, 3 if low_quality else 6, 0.7, Vector2(0.5, 1.0), 0.5,
		Vector3(0, -1.0, 0), 20.0, true))
	_parent.add_child(node)
	return EffectIntensity.track(node, "zone.lava") as Node3D


func _dust_node() -> Node3D:
	var node := Node3D.new()
	node.visible = false
	node.add_child(_emitter("smoke_04.png", DUST_COLOR, 12, 1.1, Vector2(0.7, 1.5), 1.2, Vector3(0, 0.4, 0), 80.0,
		false))
	node.add_child(_emitter("dirt_02.png", CHIP_COLOR, 10, 0.3, Vector2(0.4, 0.9), 0.8, Vector3(0, -9.8, 0), 70.0,
		false))
	_parent.add_child(node)
	return EffectIntensity.track(node, "zone.lava") as Node3D


## A one-shot burst of Kenney `texture` billboards going up (spread `spread`
## degrees), `amount` of them, each `quad_m` wide times a scale in `scale`,
## living `life` s under `gravity`; `glow` draws them added (molten), else
## mixed (dust).
func _emitter(texture: String, color: Color, amount: int, quad_m: float, scale: Vector2, life: float,
		gravity: Vector3, spread: float, glow: bool) -> CPUParticles3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = load(KENNEY_DIR + texture)
	var quad := QuadMesh.new()
	quad.size = Vector2(quad_m, quad_m)
	quad.material = material
	var emitter := CPUParticles3D.new()
	emitter.mesh = quad
	emitter.emitting = false
	emitter.one_shot = true
	emitter.amount = maxi(1, amount)
	emitter.lifetime = life
	emitter.explosiveness = 0.85
	emitter.local_coords = false
	emitter.direction = Vector3.UP
	emitter.spread = spread
	emitter.gravity = gravity
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = 0.25
	emitter.initial_velocity_min = 2.0
	emitter.initial_velocity_max = 4.0
	emitter.angle_min = 0.0
	emitter.angle_max = 360.0
	emitter.scale_amount_min = scale.x
	emitter.scale_amount_max = scale.y
	var fade := Gradient.new()
	fade.set_color(0, Color(color.r * (1.4 if glow else 1.0), color.g * (1.1 if glow else 1.0),
		color.b * (1.0 if glow else 1.0), color.a))
	fade.set_color(1, Color(color, 0.0))
	emitter.color_ramp = fade
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return emitter
