## The debris block (GLOSSARY: Block; VFX lab ticket 07, grill Q17, spec Q9):
## the game's own rock meshes (RockMesh, drawn with the arena's rock shader)
## instanced on a seeded path. Each piece's start, size and tumble are hashed
## from the cast's seed and its index, and where it is at a time is worked
## out from them alone (`at`), as the particles are: any frame in any order,
## the same on every peer and replay.
##
## The path is the tornado's spiral: a funnel from `radius_near_m` round at
## its foot to `radius_far_m` at `height_m`, turning `turns_per_s` and
## climbing `rise_m_s`, a piece leaving the top coming round again at the
## foot (shrunk to nothing at both ends, so none pops). Later paths (the
## slam's flying tiles, the treant's splinters) come with their recipes.
## Looks only: the simulation never reads it.
class_name FxDebris
extends Node3D

## The most pieces one block draws.
const MAX := 48
## The arena's rock look (flat-shaded facets, the shade in the vertex colour).
const ROCK_SHADER := preload("res://scenes/rock.gdshader")
## How many rock shapes the pieces share (a MultiMesh each).
const SHAPES := 3
## The share of the funnel's height at each end over which a piece grows in
## and shrinks out.
const ENDS := 0.1


## The knobs at a sensible spiral of rocks: `count` pieces `size_m` across
## (give or take `size_jitter` of it), on a funnel `radius_near_m` round at
## its foot and `radius_far_m` at its top `height_m` up (each piece off it by
## up to `radius_jitter` of its radius), turning `turns_per_s` and climbing
## `rise_m_s`, tumbling `tumble` radians a second; their facets shaded from
## `colour_dark` to `colour_light`.
static func default_knobs() -> Dictionary:
	return {
		"count": 12, "size_m": 0.3, "size_jitter": 0.5, "radius_near_m": 0.6, "radius_far_m": 2.5,
		"radius_jitter": 0.15, "height_m": 5.0, "turns_per_s": 0.6, "rise_m_s": 1.2, "tumble": 3.0,
		"colour_dark": Color(0.22, 0.17, 0.14), "colour_light": Color(0.55, 0.45, 0.36),
	}


## Every piece `t` seconds into the effect with `seed`: its transform from
## the funnel's foot (the axis up +Y), scaled to its size.
static func at(knobs: Dictionary, seed: int, t: float) -> Array:
	var out := []
	var count := clampi(int(knobs["count"]), 0, MAX)
	var height := maxf(float(knobs["height_m"]), 0.01)
	var s := FxRibbon.seed_value(seed)
	for i in count:
		var up := fposmod(_rand(s, i, 0) + float(knobs["rise_m_s"]) * t / height, 1.0)
		var radius := lerpf(float(knobs["radius_near_m"]), float(knobs["radius_far_m"]), up) \
			* (1.0 + float(knobs["radius_jitter"]) * (_rand(s, i, 1) * 2.0 - 1.0))
		var angle := TAU * (_rand(s, i, 2) + float(knobs["turns_per_s"]) * t)
		var size := float(knobs["size_m"]) * (1.0 - float(knobs["size_jitter"]) * _rand(s, i, 3)) \
			* smoothstep(0.0, ENDS, up) * smoothstep(0.0, ENDS, 1.0 - up)
		var axis := Vector3(_rand(s, i, 4) - 0.5, _rand(s, i, 5) - 0.5, _rand(s, i, 6) - 0.5)
		axis = axis.normalized() if axis.length() > 0.001 else Vector3.UP
		var spin := float(knobs["tumble"]) * (0.5 + _rand(s, i, 7)) * t + TAU * _rand(s, i, 8)
		var turned := Basis(axis, spin).scaled(Vector3.ONE * size)
		out.append(Transform3D(turned, Vector3(cos(angle) * radius, up * height, sin(angle) * radius)))
	return out


## Piece `i`'s `k`th random number, 0..1, from the seed's value `s`.
static func _rand(s: float, i: int, k: int) -> float:
	return FxNoise.hash11(s * 2.414 + float(i) * 5.77 + float(k) * 91.31)


## Rock shape `variant`, about a metre across round its middle: the game's
## crags (RockMesh.add_crag) and a chipped block.
static func rock_mesh(variant: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 + variant
	if variant % SHAPES == 2:
		RockMesh.add_block(st, rng, Vector3.ZERO, Vector3(0.9, 0.7, 0.8), 0.4, 0.5, 0.2)
	else:
		RockMesh.add_crag(st, rng, Vector3(0.0, -0.45, 0.0), 0.5, 0.9, 0.5)
	return st.commit()


var _pieces: Array[MultiMeshInstance3D] = []
var _material := ShaderMaterial.new()
var _shown := 0


## Builds its rocks (one MultiMesh per rock shape, the volcano's rock
## shader with no lava glow), hidden until a cast.
func _init() -> void:
	name = "Debris"
	top_level = true
	_material.shader = ROCK_SHADER
	# No lava under it: no glow, no warm rim; only the facets' shades.
	_material.set_shader_parameter("lava_y", -1.0e6)
	_material.set_shader_parameter("glow", 0.0)
	_material.set_shader_parameter("rim", 0.0)
	for k in SHAPES:
		var drawn := MultiMeshInstance3D.new()
		drawn.name = "Rocks%d" % k
		drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		drawn.multimesh = MultiMesh.new()
		drawn.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		drawn.multimesh.mesh = rock_mesh(k)
		drawn.multimesh.instance_count = ceili(float(MAX) / SHAPES)
		drawn.multimesh.visible_instance_count = 0
		drawn.material_override = _material
		add_child(drawn)
		_pieces.append(drawn)


## A frame whose +Y is `up` (the funnel's axis along a curved ground's up;
## Basis.IDENTITY for world up), turned the least way from world up.
static func frame_along(up: Vector3) -> Basis:
	var n := up.normalized()
	var axis := Vector3.UP.cross(n)
	if axis.length() < 0.000001:
		return Basis.IDENTITY if n.y > 0.0 else Basis(Vector3.RIGHT, PI)
	return Basis(axis.normalized(), Vector3.UP.angle_to(n))


## Draws `knobs`' pieces `t` s into the effect with `seed`, the funnel's
## foot at `origin` (world), its axis along `frame`'s +Y (frame_along), each
## grown by `grow` (0: none drawn; a recipe's form and fade).
func show_at(knobs: Dictionary, seed: int, t: float, origin: Vector3, grow: float = 1.0,
		frame: Basis = Basis.IDENTITY) -> void:
	_material.set_shader_parameter("rock_dark", knobs["colour_dark"])
	_material.set_shader_parameter("rock_light", knobs["colour_light"])
	var counts: Array[int] = []
	counts.resize(SHAPES)
	counts.fill(0)
	_shown = 0
	if grow > 0.0:
		var drawn := at(knobs, seed, t)
		for i in drawn.size():
			var piece: Transform3D = drawn[i]
			var k := i % SHAPES
			_pieces[k].multimesh.set_instance_transform(counts[k],
				Transform3D(frame * piece.basis.scaled(Vector3.ONE * grow), origin + frame * piece.origin))
			counts[k] += 1
			_shown += 1
	var reach := maxf(float(knobs["radius_far_m"]), float(knobs["radius_near_m"])) \
		* (1.0 + float(knobs["radius_jitter"])) + float(knobs["size_m"])
	var bounds := AABB(origin - Vector3(reach, float(knobs["size_m"]), reach),
		Vector3(reach * 2.0, float(knobs["height_m"]) + float(knobs["size_m"]) * 2.0, reach * 2.0))
	if frame != Basis.IDENTITY:
		bounds = AABB(origin, Vector3.ZERO).grow(maxf(reach, float(knobs["height_m"]) + float(knobs["size_m"]) * 2.0))
	for k in SHAPES:
		_pieces[k].multimesh.visible_instance_count = counts[k]
		_pieces[k].custom_aabb = bounds
	visible = _shown > 0


## How many pieces it drew last.
func shown() -> int:
	return _shown


## Its rock shapes' instances (a MultiMesh each).
func pieces() -> Array[MultiMeshInstance3D]:
	return _pieces
