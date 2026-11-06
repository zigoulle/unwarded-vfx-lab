## The trail block (GLOSSARY: Block; enemy-vfx ticket 01): a stream of soft
## additive dots shed behind a moving point, the fireball's flames and
## embers, `count` alive at once. Each instance holds one particle at a
## time, reborn every life with the next one, its life, direction and speed
## hashed from the cast's seed and its number (FxParticles' numbers), so any
## frame is drawn from (knobs, seed, time) alone: a frame step back, a
## replay and every peer draw the same. The whole stream is worked out on
## the GPU (fx_trail.gdshader) from a dozen uniforms a frame: a crowd of
## projectiles costs the CPU almost nothing (FxParticles works its grains
## out one by one, ~0.4 ms a fireball). `at` is its CPU twin, for the tests.
## Looks only: the simulation never reads it.
class_name FxTrail
extends MultiMeshInstance3D

## The most particles one stream draws (its MultiMesh's size).
const MAX := 64
const SHADER := preload("res://fx/shaders/fx_trail.gdshader")


## The knobs at a sensible stream: `count` alive at once, each living
## `life_s` (give or take `life_jitter` of it, never longer), flying
## `speed_m_s` (give or take `speed_jitter`) along `dir` within `cone` (0
## straight, 1 a whole hemisphere), pulled down `up` by `gravity_m_s2`
## (negative: rising), `size_m` across, shrinking as they fade; none born
## at or after `born_before_s` (the stream stopped).
## With `burst_s` (none when left out) it is a burst, not a stream: each
## slot holds one particle only, born within `burst_s` of the start (its
## time hashed), and once they burn out nothing is left (the Fire bomb's
## embers, playtest 2026-10-25 #3: a crowd of kills stays cheap).
## With `disc_m` (0 when left out; the fire puddle's flames, polish step 9)
## each is born at a hashed point within a disc that wide round the origin,
## level with it (across `up`), and flies from there.
static func default_knobs() -> Dictionary:
	return {"count": 24, "life_s": 0.4, "life_jitter": 0.3, "speed_m_s": 1.0, "speed_jitter": 0.0, "cone": 0.1,
		"gravity_m_s2": 0.0, "size_m": 0.1, "dir": Vector3.BACK, "up": Vector3.UP, "born_before_s": INF}


## Every slot's particle `since` s after the stream began with `seed`:
## {offset (from the origin, m), size (m), alpha (1 at birth, 0 none)}; as
## the shader works it out.
static func at(knobs: Dictionary, seed: int, since: float) -> Array:
	var out := []
	var count := clampi(int(knobs["count"]), 0, MAX)
	var life_full := maxf(float(knobs["life_s"]), 0.001)
	var dt := life_full / maxf(count, 1)
	var s := FxRibbon.seed_value(seed)
	var dir: Vector3 = (knobs["dir"] as Vector3).normalized()
	var up: Vector3 = (knobs["up"] as Vector3).normalized()
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT).normalized()
	var other := dir.cross(side)
	var until := float(knobs.get("born_before_s", INF))
	var burst := float(knobs.get("burst_s", -1.0))
	var disc := float(knobs.get("disc_m", 0.0))
	var flat_a := up.cross(Vector3.FORWARD if absf(up.z) < 0.99 else Vector3.RIGHT).normalized()
	var flat_b := up.cross(flat_a)
	for slot in count:
		var n := floorf((since - slot * dt) / life_full)
		var k := slot + count * n
		var born := k * dt
		if burst >= 0.0:
			n = 0.0
			k = slot
			born = burst * FxParticles._rand(s, int(k), 0)
		var life := life_full * (1.0 - float(knobs["life_jitter"]) * FxParticles._rand(s, int(k), 1))
		var a := since - born
		if n < 0.0 or a < 0.0 or a >= life or born >= until:
			out.append({"offset": Vector3.ZERO, "size": 0.0, "alpha": 0.0})
			continue
		var off_axis := float(knobs["cone"]) * PI / 2.0 * sqrt(FxParticles._rand(s, int(k), 2))
		var round_it := TAU * FxParticles._rand(s, int(k), 3)
		var way := (dir * cos(off_axis) + (side * cos(round_it) + other * sin(round_it)) * sin(off_axis)).normalized()
		var speed := float(knobs["speed_m_s"]) * (1.0 - float(knobs["speed_jitter"]) * FxParticles._rand(s, int(k), 4))
		var left := 1.0 - a / life
		var born_at := Vector3.ZERO
		if disc > 0.0:
			var r := disc * sqrt(FxParticles._rand(s, int(k), 5))
			var round_disc := TAU * FxParticles._rand(s, int(k), 6)
			born_at = (flat_a * cos(round_disc) + flat_b * sin(round_disc)) * r
		out.append({"offset": born_at + way * speed * a - up * 0.5 * float(knobs["gravity_m_s2"]) * a * a,
			"size": float(knobs["size_m"]) * (0.4 + 0.6 * left), "alpha": left})
	return out


## Whether any of `knobs`' stream may be alive `since` s after it began.
static func alive_at(knobs: Dictionary, since: float) -> bool:
	if clampi(int(knobs["count"]), 0, MAX) == 0 or since < 0.0:
		return false
	if float(knobs.get("burst_s", -1.0)) >= 0.0:
		return since < float(knobs["burst_s"]) + float(knobs["life_s"])
	return since < minf(float(knobs.get("born_before_s", INF)), INF) + float(knobs["life_s"])


var _material := ShaderMaterial.new()
## The up its last drawn stream rose along (its knobs' "up").
var _up := Vector3.UP
## The knobs, seed, origin and colour its uniforms were last set from: a
## frame sets only what changed (playtest 2026-10-25 #3: a crowd of Fire
## bomb explosions; each uniform set costs).
var _knobs_set := {}
var _knobs_ref: Dictionary = {}
## show_at's last stream ([knobs, seed, origin, colour]) and whether its
## uniforms were all set for it (show_since).
var _last := []
var _set_up := false
var _seed_set := -1
var _origin_set := Vector3.INF
var _colour_set := Color(-1, -1, -1, -1)


## Builds its instanced quads (one MultiMesh, shaped by its shader), hidden
## until it streams.
func _init() -> void:
	name = "Trail"
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = quad
	multimesh.instance_count = MAX
	for i in MAX:
		multimesh.set_instance_transform(i, Transform3D.IDENTITY)
	multimesh.visible_instance_count = 0
	_material.shader = SHADER
	material_override = _material
	visible = false


## The up its stream was last drawn rising along (a curved ground's under
## it: playtest 2026-10-25 #12; world up on level ground).
func up() -> Vector3:
	return _up


## Draws `knobs`' stream `since` s after it began with `seed`, from `origin`
## (world: the head now), tinted `colour` (its alpha: their brightness).
func show_at(knobs: Dictionary, seed: int, since: float, origin: Vector3, colour: Color) -> void:
	_last = [knobs, seed, origin, colour]
	_set_up = false
	if not alive_at(knobs, since):
		multimesh.visible_instance_count = 0
		visible = false
		return
	_set_up = true
	var count := clampi(int(knobs["count"]), 0, MAX)
	multimesh.visible_instance_count = count
	visible = true
	_material.set_shader_parameter("since", since)
	# A read-only knobs dictionary handed again (a holder's cached knobs: the
	# fire puddle's trail of patches) cannot have changed: no compare.
	var same := knobs.is_read_only() and is_same(knobs, _knobs_ref)
	if (not same and knobs != _knobs_set) or seed != _seed_set:
		_knobs_ref = knobs
		_knobs_set = knobs.duplicate()
		_seed_set = seed
		_origin_set = Vector3.INF
		var life := float(knobs["life_s"])
		_material.set_shader_parameter("count", float(count))
		_material.set_shader_parameter("life_s", life)
		_material.set_shader_parameter("life_jitter", float(knobs["life_jitter"]))
		_material.set_shader_parameter("speed_m_s", float(knobs["speed_m_s"]))
		_material.set_shader_parameter("speed_jitter", float(knobs["speed_jitter"]))
		_material.set_shader_parameter("cone", float(knobs["cone"]))
		_material.set_shader_parameter("gravity", float(knobs["gravity_m_s2"]))
		_material.set_shader_parameter("size_m", float(knobs["size_m"]))
		_material.set_shader_parameter("born_before", minf(float(knobs.get("born_before_s", INF)), 1000000.0))
		_material.set_shader_parameter("burst_s", float(knobs.get("burst_s", -1.0)))
		_material.set_shader_parameter("disc_m", float(knobs.get("disc_m", 0.0)))
		_material.set_shader_parameter("seed", FxRibbon.seed_value(seed))
		_material.set_shader_parameter("dir", (knobs["dir"] as Vector3).normalized())
		_up = (knobs["up"] as Vector3).normalized()
		_material.set_shader_parameter("up", _up)
	if origin != _origin_set:
		_origin_set = origin
		_material.set_shader_parameter("origin", origin)
		# As far as one can fly and rise in its life, and a margin.
		var life_s := float(knobs["life_s"])
		var reach := float(knobs["speed_m_s"]) * life_s + 0.5 * absf(float(knobs["gravity_m_s2"])) * life_s * life_s
		custom_aabb = AABB(origin, Vector3.ZERO).grow(reach + float(knobs.get("disc_m", 0.0)) + float(knobs["size_m"])
			+ 1.0)
	if colour != _colour_set:
		_colour_set = colour
		_material.set_shader_parameter("colour", colour)


## The stream last handed to show_at (the same knobs, seed, origin and
## colour), `since` s after it began: only its clock moves, the cheap path
## for a holder's steady frame (the fire puddle's trail: dozens a frame).
## Nothing shows before a show_at.
func show_since(since: float) -> void:
	if _last.is_empty():
		return
	if not _set_up:
		show_at(_last[0], _last[1], since, _last[2], _last[3])
		return
	if not alive_at(_last[0], since):
		visible = false
		return
	visible = true
	_material.set_shader_parameter("since", since)


## Its shader's uniform `name` as last set (for the tests).
func uniform(param: String) -> Variant:
	return _material.get_shader_parameter(param)
