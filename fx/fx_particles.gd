## The particles block (GLOSSARY: Block; VFX lab ticket 05, spec Q2, Q9):
## sparks moved from their spawn time, the reference's technique. Each
## particle's birth, direction, speed and life are hashed from the cast's
## seed and its index, and where it is at a time is worked out from them
## alone (`at`): no state carried from frame to frame, so a frame step back,
## a replay and every peer draw the same sparks. Drawn as camera-facing
## soft dots in one MultiMesh, additive.
##
## The technique is LinearAbiltyCastingThreeJS's (MIT; THIRD_PARTY_LICENSES.md).
## Looks only: the simulation never reads it.
class_name FxParticles
extends MultiMeshInstance3D

## The most particles one block draws (its MultiMesh's size).
const MAX := 128


## The knobs at a sensible spray of sparks: `count` of them born over
## `spawn_s` after the impact, flying `speed_m_s` (give or take
## `speed_jitter` of it) within `cone` (0 straight along `dir`, 1 a whole
## hemisphere round it) for `life_s` (give or take `life_jitter`), pulled
## down `up` by `gravity_m_s2`, `size_m` across, shrinking as they fade.
## An optional `swirl` (turns a second, 0 when left out) carries them round
## `up` through the origin as they fly: a tornado's sand grains.
## With `ring_m` over 0 (ticket 06, the lightning ring) each is born at a
## hashed point round a ring that wide about the impact, level with it
## (round `up`), and flies out from it: its `dir` then leans out from the
## ring by as much as it points along `dir`.
## A ring may be only an arc (the sand slash): `ring_up` tilts it (round
## `up` when left out; gravity still pulls down `up`), `ring_start` and
## `ring_span` (radians, FxRibbon.ring_frame's) bound it (all the way round
## when left out), and with `ring_follow` each is born where a front
## sweeping the arc over `spawn_s` is at its birth.
## Born on a ring, `ring_lean` (1 when left out) is how far its `dir` leans
## out from it: 0 sends them straight along `dir` (the flame strike's
## flames rising straight from its rim).
## With `born_before_s` (none when left out) none born at or after it shows,
## and those born before fly on: a stream that stops (the fireball's trail
## at its impact).
static func default_knobs() -> Dictionary:
	return {
		"count": 24, "spawn_s": 0.05, "speed_m_s": 6.0, "speed_jitter": 0.5, "life_s": 0.5, "life_jitter": 0.4,
		"cone": 0.7, "gravity_m_s2": 6.0, "size_m": 0.06, "dir": Vector3.UP, "up": Vector3.UP, "ring_m": 0.0,
	}


## Every particle `age` seconds after the impact with `seed`: {offset (from
## the impact, m), size (m), alpha (1 at birth, 0 unborn or gone)}.
static func at(knobs: Dictionary, seed: int, age: float) -> Array:
	var offsets := PackedVector3Array()
	var sizes := PackedFloat64Array()
	var alphas := PackedFloat64Array()
	fill(knobs, seed, age, offsets, sizes, alphas)
	var out := []
	for i in offsets.size():
		out.append({"offset": offsets[i], "size": float(sizes[i]), "alpha": float(alphas[i])})
	return out


## at()'s particles into `offsets`, `sizes` and `alphas` (resized to the
## count; perf pass 17: no dictionary per grain, the knobs read once).
static func fill(knobs: Dictionary, seed: int, age: float, offsets: PackedVector3Array, sizes: PackedFloat64Array,
		alphas: PackedFloat64Array) -> void:
	var grains := Plan.new()
	plan(knobs, seed, grains)
	place(grains, age, offsets, sizes, alphas)


## What of each grain never changes with time, worked out once a cast (the
## core mother's volcanoes, 2026-10-29: twelve flame strikes a frame spent
## most of it hashing each grain's birth, life and flight again each frame).
class Plan:
	## Each grain's birth and life (s), where it starts (from the impact) and
	## its velocity (m/s).
	var born := PackedFloat64Array()
	var life := PackedFloat64Array()
	var start := PackedVector3Array()
	var velocity := PackedVector3Array()
	var up := Vector3.UP
	var gravity := 0.0
	var swirl := 0.0
	var size_m := 0.0
	var until := INF


## `knobs`' grains for the cast with `seed` into `out` (at()'s numbers).
static func plan(knobs: Dictionary, seed: int, out: Plan) -> void:
	var count := clampi(int(knobs["count"]), 0, MAX)
	out.born.resize(count)
	out.life.resize(count)
	out.start.resize(count)
	out.velocity.resize(count)
	var dir: Vector3 = (knobs["dir"] as Vector3).normalized()
	var up: Vector3 = (knobs["up"] as Vector3).normalized()
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT).normalized()
	var other := dir.cross(side)
	var s := FxRibbon.seed_value(seed)
	var ring := float(knobs.get("ring_m", 0.0))
	var arc := FxRibbon.ring_frame((knobs.get("ring_up", up) as Vector3).normalized())
	var arc_0: Vector3 = arc[0]
	var arc_1: Vector3 = arc[1]
	var arc_start := float(knobs.get("ring_start", 0.0))
	var arc_span := float(knobs.get("ring_span", TAU))
	var follow: bool = knobs.get("ring_follow", false)
	var spawn_s := float(knobs["spawn_s"])
	var life_s := float(knobs["life_s"])
	var life_jitter := float(knobs["life_jitter"])
	var cone := float(knobs["cone"])
	var speed_m_s := float(knobs["speed_m_s"])
	var speed_jitter := float(knobs["speed_jitter"])
	var lean := float(knobs.get("ring_lean", 1.0))
	out.up = up
	out.gravity = float(knobs["gravity_m_s2"])
	out.swirl = float(knobs.get("swirl", 0.0))
	out.size_m = float(knobs["size_m"])
	out.until = float(knobs.get("born_before_s", INF))
	for i in count:
		out.born[i] = spawn_s * _rand(s, i, 0)
		out.life[i] = life_s * (1.0 - life_jitter * _rand(s, i, 1))
		var start := Vector3.ZERO
		var axis := dir
		var across_a := side
		var across_b := other
		if ring > 0.0:
			var share := _rand(s, i, 0) if follow else _rand(s, i, 5)
			var bearing := arc_start + arc_span * share
			var outward: Vector3 = arc_0 * cos(bearing) + arc_1 * sin(bearing)
			start = outward * ring
			axis = (outward * lean + dir).normalized()
			across_a = axis.cross(up if absf(axis.dot(up)) < 0.99 else outward).normalized()
			across_b = axis.cross(across_a)
		# Uniform over the cone's cap: the angle off its axis, then round it.
		var off_axis := cone * PI / 2.0 * sqrt(_rand(s, i, 2))
		var round_it := TAU * _rand(s, i, 3)
		var way := (axis * cos(off_axis) + (across_a * cos(round_it) + across_b * sin(round_it)) * sin(off_axis)) 			.normalized()
		out.start[i] = start
		out.velocity[i] = way * (speed_m_s * (1.0 - speed_jitter * _rand(s, i, 4)))


## `grains` `age` s after the impact into `offsets`, `sizes` and `alphas`.
static func place(grains: Plan, age: float, offsets: PackedVector3Array, sizes: PackedFloat64Array,
		alphas: PackedFloat64Array) -> void:
	var count := grains.born.size()
	offsets.resize(count)
	sizes.resize(count)
	alphas.resize(count)
	var up := grains.up
	var gravity := grains.gravity
	var turn := TAU * grains.swirl
	var size_m := grains.size_m
	var until := grains.until
	for i in count:
		var born := grains.born[i]
		var life := grains.life[i]
		var a := age - born
		if a < 0.0 or a >= life or life <= 0.0 or born >= until:
			offsets[i] = Vector3.ZERO
			sizes[i] = 0.0
			alphas[i] = 0.0
			continue
		var offset := grains.start[i] + grains.velocity[i] * a - up * 0.5 * gravity * a * a
		if turn != 0.0:
			offset = offset.rotated(up, turn * a)
		var left := 1.0 - a / life
		offsets[i] = offset
		sizes[i] = size_m * (0.4 + 0.6 * left)
		alphas[i] = left


## Whether any of `knobs`' particles may be alive `age` s after the impact
## (at()'s bounds: each is born within spawn_s and lives at most life_s,
## give or take its jitter); false: at() finds every one unborn or gone.
static func alive_at(knobs: Dictionary, age: float) -> bool:
	if clampi(int(knobs["count"]), 0, MAX) == 0:
		return false
	var spawn := float(knobs["spawn_s"])
	var life := float(knobs["life_s"])
	var longest := maxf(life, life * (1.0 - float(knobs["life_jitter"])))
	return age >= minf(spawn, 0.0) and age < maxf(spawn, 0.0) + longest


## A soft round dot (white, fading to clear at its rim): a spark's sprite.
static func soft_dot() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.35, Color(1, 1, 1, 0.8))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	return texture


## Particle `i`'s `k`th random number, 0..1, from the seed's value `s`.
## FxNoise.hash11 worked out in place, step for step (perf pass 17: its
## calls cost ~2 us a number, six a grain a frame).
static func _rand(s: float, i: int, k: int) -> float:
	var p := (s * 1.618 + float(i) * 7.31 + float(k) * 113.17) * 0.1031
	p -= floorf(p)
	p *= p + 33.33
	p *= p + p
	return p - floorf(p)


var _material := StandardMaterial3D.new()
var _flat := false
## fill()'s arrays, kept from draw to draw (no allocation a frame).
var _offsets := PackedVector3Array()
var _sizes := PackedFloat64Array()
var _alphas := PackedFloat64Array()
## Its grains' plan (plan()) and the seed and knobs (their hash) it was made
## for: made again only when either changes.
var _plan := Plan.new()
var _plan_seed := 0
var _plan_knobs := -1
var _origin := Vector3.ZERO
## The up its last drawn particles rose and fell along (their knobs' "up").
var _up := Vector3.UP


## Builds its instanced quads (one MultiMesh), hidden until they spawn.
func _init() -> void:
	name = "Particles"
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = MAX
	multimesh.visible_instance_count = 0
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_material.billboard_keep_scale = true
	_material.vertex_color_use_as_albedo = true
	_material.albedo_texture = soft_dot()
	material_override = _material


## The up its particles were last drawn rising along (a curved ground's at
## the effect: playtest 2026-10-25 #12; world up on level ground).
func up() -> Vector3:
	return _up


## Flat (`on`): hard-edged dots that cover what is behind them, never
## adding light (sand grains, flat cel tones); else the sparks' soft
## additive dots.
func set_flat(on: bool) -> void:
	_flat = on
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX if on else BaseMaterial3D.BLEND_MODE_ADD
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR if on else BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.alpha_scissor_threshold = 0.5


## Draws `knobs`' particles `age` s after an impact at `origin` (world) with
## `seed`, tinted `colour` (its alpha: their brightness).
func show_at(knobs: Dictionary, seed: int, age: float, origin: Vector3, colour: Color) -> void:
	_up = (knobs["up"] as Vector3).normalized()
	if not alive_at(knobs, age):
		# None born yet or all gone (perf pass 17: every recipe draws its
		# blocks each frame, before its impact and after, and at() worked out
		# each grain to find none).
		multimesh.visible_instance_count = 0
		visible = false
		return
	var knobs_hash := knobs.hash()
	if seed != _plan_seed or knobs_hash != _plan_knobs:
		plan(knobs, seed, _plan)
		_plan_seed = seed
		_plan_knobs = knobs_hash
	place(_plan, age, _offsets, _sizes, _alphas)
	_origin = origin
	var shown := 0
	var grains := multimesh
	for i in _offsets.size():
		var alpha := _alphas[i]
		if alpha <= 0.0:
			continue
		grains.set_instance_transform(shown, Transform3D(Basis.from_scale(Vector3.ONE * _sizes[i]),
			origin + _offsets[i]))
		# Flat grains keep their colour's alpha (a hard edge would cut a fading
		# one off at once); they shrink away instead.
		grains.set_instance_color(shown, Color(colour, colour.a if _flat else colour.a * alpha))
		shown += 1
	grains.visible_instance_count = shown
	visible = shown > 0
	if shown > 0:
		# As far as one can fly and fall in its life, and a margin.
		var life := float(knobs["life_s"])
		var reach := float(knobs.get("ring_m", 0.0)) + float(knobs["speed_m_s"]) * life 			+ 0.5 * float(knobs["gravity_m_s2"]) * life * life
		custom_aabb = AABB(origin, Vector3.ZERO).grow(reach + 1.0)


## The grains it shows now (for the tests): each one's transform, in order.
func drawn() -> Array:
	var out := []
	if not visible:
		return out
	for i in _offsets.size():
		if _alphas[i] > 0.0:
			out.append(Transform3D(Basis.from_scale(Vector3.ONE * _sizes[i]), _origin + _offsets[i]))
	return out
