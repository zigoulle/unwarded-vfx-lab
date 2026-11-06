## The ribbon block (GLOSSARY: Block; VFX lab ticket 04, spec Q2): a static
## strip shaped in its vertex shader (res://fx/shaders/fx_ribbon.gdshader)
## into a bolt: strands fanned round an axis that sags, kinked by linear
## noise, re-struck `restrike` times a second. The same block makes the
## lightning line, and later the lightning ring and the tornado's spiral.
##
## The shape is a pure function of (shape, seed, time): `point` works it out
## on the CPU exactly as the shader does, so the blocks' data can be checked
## headless and any frame drawn in any order (Q9); the seed comes from the
## cast, so every peer and every replay draws the same bolt (Q8).
##
## Bent into a ring (ticket 06, the lightning ring): with `ring_radius` over
## 0 its axis is no longer the line from origin to target but an arc of that
## radius round the origin, level with it, from `ring_start` (radians round
## its up, `ring_up`, 0 ahead, -Z) on for `ring_span` (TAU: all the way
## round, its two ends meeting); the fan, the kinks and the sag then work
## across the arc (out from the ring and up). 0, the default: a line.
##
## The maths is ported from LinearAbiltyCastingThreeJS by mohamedachrefelouafi
## (src/materials/LightningMaterial.js, MIT; THIRD_PARTY_LICENSES.md).
## Looks only: the simulation never reads it.
class_name FxRibbon
extends Node3D

const SHADER := preload("res://fx/shaders/fx_ribbon.gdshader")
## The same strip in flat cel tones with hard edges, covering what is
## behind it and never adding light (the tornado's sand; grill Q11's ruling
## for sand: no glow).
const CEL_SHADER := preload("res://fx/shaders/fx_ribbon_cel.gdshader")
## Knots along each strand (the strip's segments).
const SEGMENTS := 48
## The bounds' margin round the two ends (m): the fan, the sag and the kinks
## stay inside it.
const BOUNDS_MARGIN_M := 2.5

var _mesh: ArrayMesh
var _strands := -1
var _core: MeshInstance3D
var _passes: Array[MeshInstance3D] = []
var _shader: Shader = SHADER


## `cel`: drawn in flat cel tones (CEL_SHADER), else as light (SHADER).
func _init(cel: bool = false) -> void:
	name = "Ribbon"
	_shader = CEL_SHADER if cel else SHADER
	_core = add_pass("Core", {"glow_pass": false, "width_scale": 1.0, "pass_opacity": 1.0, "screen_cap": 0.0})


## The shape's knobs as the shader names them, at the reference's values:
## a sensible bolt before a recipe sets its own.
static func default_shape() -> Dictionary:
	return {
		"sag": 0.2, "restrike": 24.0, "strands": 5,
		"spread": 0.75, "spread_near": 0.05, "spread_curve": 1.6, "twist": 0.45, "twist_speed": 0.8,
		"jitter": 0.34, "jitter_scale": 0.85, "octaves": 4, "jitter_falloff": 0.55, "crawl": 3.2,
		"pinch": 0.14, "converge": 0.8,
		"width": 0.085, "width_tip": 0.5, "width_curve": 1.0, "core_width": 2.1, "core_sharp": 3.4,
		"glow_falloff": 2.4, "strand_flash": 0.5,
		"flicker": 0.3, "flicker_speed": 34.0, "tip_glow": 2.0, "tip_length": 0.08, "branch_dim": 0.72,
		"opacity": 1.0, "glow": 2.3,
		"colour_core": Color(1.0, 1.0, 1.0), "colour_inner": Color(0.78, 0.92, 1.0),
		"colour_outer": Color(0.22, 0.62, 1.0), "colour_halo": Color(0.04, 0.24, 0.78),
		"progress": 1.0, "fade": 1.0, "radial_min": 0.0,
		"ring_radius": 0.0, "ring_start": 0.0, "ring_span": TAU, "ring_up": Vector3.UP,
	}


## The cast's seed as the shader hashes it: small, so a float holds it exactly.
static func seed_value(seed: int) -> float:
	return float(posmod(seed, 4096)) * 0.73


## The side the fan starts from: level, across the bolt.
static func side_of(from: Vector3, to: Vector3) -> Vector3:
	var side := (to - from).cross(Vector3.UP)
	return side.normalized() if side.length() > 0.0001 else Vector3.RIGHT


## Strand `strand`'s point `along` (0 at `from`, 1 at `to`; bent into a
## ring, 0 and 1 its arc's two ends) at `t` seconds with `seed`: the
## shader's bolt_point, worked out the same way.
static func point(shape: Dictionary, from: Vector3, to: Vector3, along: float, strand: int, seed: int,
		t: float) -> Vector3:
	var ring := float(shape.get("ring_radius", 0.0))
	var axis: Vector3
	var span: float
	var n1: Vector3
	var n2: Vector3
	var up := Vector3.UP
	if ring > 0.0:
		up = (shape.get("ring_up", Vector3.UP) as Vector3).normalized()
		var arc := ring_frame(up)
		var span_angle := float(shape.get("ring_span", TAU))
		var angle := float(shape.get("ring_start", 0.0)) + along * span_angle
		n1 = arc[0] * cos(angle) + arc[1] * sin(angle)
		n2 = up
		axis = from + n1 * ring
		span = maxf(ring * absf(span_angle), 0.01)
	else:
		var delta := to - from
		span = maxf(delta.length(), 0.01)
		var dir := delta / span
		var side := side_of(from, to)
		n1 = side - dir * side.dot(dir)
		n1 = n1.normalized() if n1.length() > 0.0001 else dir.cross(Vector3.UP).normalized()
		n2 = dir.cross(n1).normalized()
		axis = from.lerp(to, along)
	var strike := floorf(t * maxf(float(shape["restrike"]), 0.01))
	var strand_seed := FxNoise.hash11(strand * 7.13 + seed_value(seed) + strike * 3.77) * 97.0
	var strands := float(shape["strands"])
	var radial := lerpf(float(shape.get("radial_min", 0.0)), 1.0, 0.0 if strands <= 1.0 else strand / (strands - 1.0))

	axis += up * float(shape["sag"]) * sin(along * PI)
	var pinch := maxf(float(shape["pinch"]), 0.001)
	var ends := smoothstep(0.0, pinch, along) 		* lerpf(1.0, smoothstep(0.0, pinch, 1.0 - along), clampf(float(shape["converge"]), 0.0, 1.0))
	var offset := _kink(shape, along, strand_seed, span, t) * float(shape["jitter"]) * ends
	var angle := strand_seed * TAU + (along * float(shape["twist"]) + t * float(shape["twist_speed"])) * TAU
	var reach := lerpf(float(shape["spread_near"]), float(shape["spread"]),
		pow(clampf(along, 0.0, 1.0), maxf(float(shape["spread_curve"]), 0.01)))
	offset += Vector2(cos(angle), sin(angle)) * reach * radial
	return axis + n1 * offset.x + n2 * offset.y


## A ring's two directions in its plane round `up`: [ahead (-Z, or +X when
## up is along Z), and a quarter turn on from it]; the shader's the same.
static func ring_frame(up: Vector3) -> Array:
	var ref := Vector3(0.0, 0.0, -1.0) if absf(up.z) < 0.99 else Vector3(1.0, 0.0, 0.0)
	var ahead := (ref - up * ref.dot(up)).normalized()
	return [ahead, up.cross(ahead)]


## Strand `strand`'s knots from `from` to `to` (SEGMENTS + 1) at `t` with `seed`.
static func path(shape: Dictionary, from: Vector3, to: Vector3, strand: int, seed: int, t: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in SEGMENTS + 1:
		out.append(point(shape, from, to, float(i) / SEGMENTS, strand, seed, t))
	return out


## The kinks' offset across the axis at `along` (0..1) for the strand
## seeded `strand_seed` on a bolt `span` m long, `t` s in: octaves of
## linear value noise scrolled by the crawl (sharp corners), as the
## shader's.
static func _kink(shape: Dictionary, along: float, strand_seed: float, span: float, t: float) -> Vector2:
	var o := Vector2.ZERO
	var amp := 1.0
	var freq := maxf(float(shape["jitter_scale"]), 0.01) * span
	var scroll := t * float(shape["crawl"])
	var octaves := float(shape["octaves"])
	var falloff := float(shape["jitter_falloff"])
	for i in 5:
		var on := 1.0 if octaves - 1.0 >= float(i) else 0.0
		o.x += on * amp * FxNoise.vnoise(along * freq + scroll, strand_seed + 13.0 * i)
		o.y += on * amp * FxNoise.vnoise(along * freq + scroll * 1.17, strand_seed + 71.3 + 13.0 * i)
		amp *= falloff
		freq *= 2.0
		scroll *= 1.63
	return o


## The static strip: per strand, `segments` + 1 knots of two vertices each.
## UV = (along 0..1, edge -1 or 1), UV2.x = the strand; the shader places them.
static func strip_mesh(strands: int, segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var index := PackedInt32Array()
	for s in strands:
		var base := vertices.size()
		for i in segments + 1:
			var along := float(i) / segments
			for edge: float in [-1.0, 1.0]:
				vertices.append(Vector3.ZERO)
				uv.append(Vector2(along, edge))
				uv2.append(Vector2(s, 0.0))
		for i in segments:
			var a := base + i * 2
			index.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The core pass (the hot filament).
func core() -> MeshInstance3D:
	return _core


## Every pass drawing the strip (the core, then any glow pass).
func passes() -> Array[MeshInstance3D]:
	return _passes


## A pass drawing the same strip with its own `settings` (glow_pass,
## width_scale, pass_opacity, screen_cap): the glow pass is one (FxGlow).
func add_pass(pass_name: String, settings: Dictionary) -> MeshInstance3D:
	var drawn := MeshInstance3D.new()
	drawn.name = pass_name
	# World coordinates (the shader's own): the node's place never moves it.
	drawn.top_level = true
	drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = _shader
	for key: String in settings:
		material.set_shader_parameter(key, settings[key])
	drawn.material_override = material
	drawn.mesh = _mesh
	add_child(drawn)
	_passes.append(drawn)
	return drawn


## Draws `shape` from `from` to `to` (world), `t` seconds into the effect,
## with `seed`: every pass's uniforms, its strip (rebuilt only when the
## strands change) and its bounds.
func show_shape(shape: Dictionary, from: Vector3, to: Vector3, seed: int, t: float) -> void:
	var strands := maxi(int(shape["strands"]), 1)
	if strands != _strands:
		_strands = strands
		_mesh = strip_mesh(strands, SEGMENTS)
		for drawn in _passes:
			drawn.mesh = _mesh
	var bounds := AABB(from, Vector3.ZERO).expand(to).grow(BOUNDS_MARGIN_M)
	var ring := float(shape.get("ring_radius", 0.0))
	if ring > 0.0:
		bounds = AABB(from, Vector3.ZERO).grow(ring + BOUNDS_MARGIN_M)
	var side := side_of(from, to)
	for drawn in _passes:
		drawn.custom_aabb = bounds
		var material := drawn.material_override as ShaderMaterial
		for key: String in shape:
			material.set_shader_parameter(key, shape[key])
		material.set_shader_parameter("strands", float(strands))
		material.set_shader_parameter("octaves", float(shape["octaves"]))
		material.set_shader_parameter("fx_t", t)
		material.set_shader_parameter("seed", seed_value(seed))
		material.set_shader_parameter("origin", from)
		material.set_shader_parameter("target", to)
		material.set_shader_parameter("side_dir", side)
