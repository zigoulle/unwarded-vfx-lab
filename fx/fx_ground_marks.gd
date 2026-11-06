## The ground marks block (GLOSSARY: Block; VFX lab ticket 05, grill Q14,
## ADR 0006): a scorch and the streaks of sparks thrown across the ground
## under an impact, laid through the ground seam (SurfaceMesh.layer: each
## vertex walked out along the surface from the ground point, in the frame
## SurfaceDraw.frame gives it), so on the lava ball, the cone and the lab's
## curved test patch they wrap the surface instead of floating off it; on
## the level ground they are flat. The streaks' bearings and lengths are
## hashed from the cast's seed; the scorch holds most of its life then
## fades, the streaks glow only at first (`fade`). Built once per ground
## point and knobs, faded from the impact's time alone. Drawn under every
## enemy ground mark (GroundDrawOrder, ticket 08).
##
## As cracks (ticket 06, the lightning ring; knob `cracks` 1, 0 by default):
## the streaks are dark cracks split in the floor instead, zigzagging across
## their bearing by `jag` (a share of the radius) and each forking once,
## drawn dark over the floor and lasting as the scorch does.
## Looks only: the simulation never reads it.
class_name FxGroundMarks
extends Node3D

const SCORCH_SHADER := preload("res://fx/shaders/fx_scorch.gdshader")
## How far over the ground they are laid (m): clear of the floor's facets.
const LIFT_M := 0.04
## The streaks: where they start (a share of the scorch's radius), how far
## they run (shares of it, the least and the most) and how wide (a share).
const STREAK_FROM := 0.35
const STREAK_MIN := 1.2
const STREAK_MAX := 2.4
const STREAK_WIDTH := 0.06
## The longest piece of a streak on a curved ground (m), as SurfaceMesh's.
const STEP_M := SurfaceMesh.STEP_M
## The share of its life the scorch holds before fading, and of its life the
## streaks glow.
const HOLD := 0.6
const GLOW := 0.25
## Cracks: the pieces each zigzags in (at least), where along it its fork
## leaves (a share), how far that runs (a share of the crack) and how wide
## it turns off (rad); how wide a crack is (a share of the radius); its colour.
const CRACK_PIECES := 7
const FORK_AT := 0.45
const FORK_LENGTH := 0.4
const FORK_TURN := 0.6
const CRACK_WIDTH := 0.035
const CRACK_COLOUR := Color(0.03, 0.02, 0.04)


## A scorch `radius_m` across (0: none) with `streaks` streaks of sparks
## round it, lasting `life_s`; `cracks` 1: dark cracks, `jag` zigzagged,
## instead of the streaks.
static func default_knobs() -> Dictionary:
	return {"radius_m": 0.6, "streaks": 6, "life_s": 1.5, "cracks": 0, "jag": 0.2}


## Whether `knobs` ask for cracks rather than streaks of sparks.
static func cracked(knobs: Dictionary) -> bool:
	return int(knobs.get("cracks", 0)) == 1


## The ground point under `point` (an impact, maybe in the air): on a curved
## ground the surface beneath it, on the level ground straight down to
## `level_y` (the floor's height there).
static func under(ground: Ground, point: Vector3, level_y: float) -> Vector3:
	if ground.curved_at(point):
		return ground.clamp_to_floor(point)
	return Vector3(point.x, level_y, point.z)


## The scorch: a disc `radius` m round `point` (a ground point) heading
## `heading`, `lift` over the ground, in the frame there.
static func scorch_mesh(ground: Ground, point: Vector3, heading: Vector3, radius: float, lift: float) -> ArrayMesh:
	return SurfaceMesh.ring(ground, point, heading, 0.0, radius, lift)


## The streaks of sparks round `point` with `knobs` and `seed`, `lift` over
## the ground, in the frame there; null with none.
static func sparks_mesh(ground: Ground, point: Vector3, heading: Vector3, knobs: Dictionary, seed: int,
		lift: float) -> ArrayMesh:
	var count := int(knobs["streaks"])
	var radius := float(knobs["radius_m"])
	if count <= 0 or radius <= 0.0:
		return null
	var lay := SurfaceMesh.layer(ground, point, heading, lift)
	var curved := ground.curved_at(point)
	var s := FxRibbon.seed_value(seed)
	var vertices := PackedVector3Array()
	if cracked(knobs):
		for i in count:
			_add_crack(vertices, lay, curved, knobs, s, i)
		return _mesh_of(vertices)
	var width := radius * STREAK_WIDTH
	for i in count:
		var bearing := TAU * (float(i) + FxNoise.hash11(s + float(i) * 3.7)) / count
		var reach := radius * lerpf(STREAK_MIN, STREAK_MAX, FxNoise.hash11(s * 1.3 + float(i) * 9.1))
		var from := radius * STREAK_FROM
		var along := Vector3(sin(bearing), 0.0, -cos(bearing))
		var across := Vector3(cos(bearing), 0.0, sin(bearing))
		var pieces := 1 if not curved else maxi(1, ceili((reach - from) / STEP_M))
		for k in pieces:
			var a := lerpf(from, reach, float(k) / pieces)
			var b := lerpf(from, reach, float(k + 1) / pieces)
			# Tapering to a point at its far end.
			var wa := width * (1.0 - float(k) / pieces)
			var wb := width * (1.0 - float(k + 1) / pieces)
			var p0: Vector3 = lay.call(along * a - across * wa)
			var p1: Vector3 = lay.call(along * a + across * wa)
			var p2: Vector3 = lay.call(along * b + across * wb)
			var p3: Vector3 = lay.call(along * b - across * wb)
			vertices.append_array([p0, p1, p2, p0, p2, p3])
	return _mesh_of(vertices)


## Crack `i` (of `knobs`, the seed's value `s`) laid through `lay`: a
## zigzag out on its bearing, tapering, with a fork leaving it part way.
static func _add_crack(vertices: PackedVector3Array, lay: Callable, curved: bool, knobs: Dictionary, s: float,
		i: int) -> void:
	var count := int(knobs["streaks"])
	var radius := float(knobs["radius_m"])
	var jag := float(knobs.get("jag", 0.2)) * radius
	var width := radius * CRACK_WIDTH
	var bearing := TAU * (float(i) + FxNoise.hash11(s + float(i) * 3.7)) / count
	var reach := radius * lerpf(STREAK_MIN, STREAK_MAX, FxNoise.hash11(s * 1.3 + float(i) * 9.1))
	var from := radius * STREAK_FROM
	var pieces := CRACK_PIECES if not curved else maxi(CRACK_PIECES, ceili((reach - from) / STEP_M))
	var along := Vector2(sin(bearing), -cos(bearing))
	var across := Vector2(cos(bearing), sin(bearing))
	var knots := PackedVector2Array()
	for k in pieces + 1:
		# Pinned at its start, zigzagging each knot after it.
		var off := 0.0 if k == 0 else (FxNoise.hash11(s * 2.1 + float(i) * 17.3 + float(k) * 5.9) - 0.5) * 2.0 * jag
		knots.append(along * lerpf(from, reach, float(k) / pieces) + across * off)
	_add_strip(vertices, lay, knots, width)
	# The fork: off one side, a share of its length, from its knot there.
	var at := clampi(roundi(pieces * FORK_AT), 1, pieces - 1)
	var side := 1.0 if FxNoise.hash11(s * 3.3 + float(i) * 11.7) > 0.5 else -1.0
	var turn := along.rotated(side * FORK_TURN)
	var length := (reach - from) * FORK_LENGTH
	var fork_pieces := maxi(3, ceili(length / STEP_M) if curved else 3)
	var fork := PackedVector2Array()
	for k in fork_pieces + 1:
		var off := 0.0 if k == 0 else (FxNoise.hash11(s * 4.7 + float(i) * 13.1 + float(k) * 7.3) - 0.5) * jag
		fork.append(knots[at] + turn * length * float(k) / fork_pieces + turn.orthogonal() * off)
	_add_strip(vertices, lay, fork, width * (1.0 - float(at) / pieces))


## A strip along `knots` (on the ground's plane, x and -z) `width` wide at
## its first, tapering to a point at its last, laid through `lay`.
static func _add_strip(vertices: PackedVector3Array, lay: Callable, knots: PackedVector2Array, width: float) -> void:
	var n := knots.size() - 1
	for k in n:
		var a := knots[k]
		var b := knots[k + 1]
		var normal := (b - a).orthogonal().normalized()
		var wa := width * (1.0 - float(k) / n)
		var wb := width * (1.0 - float(k + 1) / n)
		var p0: Vector3 = lay.call(_flat(a - normal * wa))
		var p1: Vector3 = lay.call(_flat(a + normal * wa))
		var p2: Vector3 = lay.call(_flat(b + normal * wb))
		var p3: Vector3 = lay.call(_flat(b - normal * wb))
		vertices.append_array([p0, p1, p2, p0, p2, p3])


## A point `p` of the marks' flat layout (x across, y along) on the level XZ plane.
static func _flat(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y)


## A triangle mesh of `vertices` (three a triangle), no indices.
static func _mesh_of(vertices: PackedVector3Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## How they show `age` s after the impact: {scorch (1 laid, 0 gone), glow
## (the streaks' heat, 1 white hot, 0 cooled)}.
static func fade(knobs: Dictionary, age: float) -> Dictionary:
	var life := float(knobs["life_s"])
	if float(knobs["radius_m"]) <= 0.0 or life <= 0.0 or age < 0.0 or age >= life:
		return {"scorch": 0.0, "glow": 0.0}
	var x := age / life
	var scorch := 1.0 if x <= HOLD else 1.0 - (x - HOLD) / (1.0 - HOLD)
	var glow := maxf(0.0, 1.0 - x / GLOW)
	return {"scorch": scorch, "glow": glow * glow}


var _scorch := MeshInstance3D.new()
var _sparks := MeshInstance3D.new()
var _scorch_material := ShaderMaterial.new()
var _sparks_material := StandardMaterial3D.new()
## The ground point, knobs and seed the meshes were built for.
var _built_for: Array = []


## Builds the scorch and the streaks (hidden until an impact), drawn at
## the player effects' order under every enemy mark (GroundDrawOrder).
func _init() -> void:
	name = "GroundMarks"
	top_level = true
	visible = false
	_scorch.name = "Scorch"
	_scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scorch_material.shader = SCORCH_SHADER
	# Under every enemy ground mark (GroundDrawOrder): never hides a danger.
	_scorch_material.render_priority = GroundDrawOrder.PLAYER_EFFECTS
	_scorch.material_override = _scorch_material
	add_child(_scorch)
	_sparks.name = "Sparks"
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sparks_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sparks_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sparks_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_sparks_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_sparks_material.render_priority = GroundDrawOrder.PLAYER_EFFECTS
	_sparks.material_override = _sparks_material
	add_child(_sparks)


## The scorch's mesh (for the cost readout and tests).
func scorch() -> MeshInstance3D:
	return _scorch


## The streaks' mesh (for the cost readout and tests).
func sparks() -> MeshInstance3D:
	return _sparks


## Lays them `age` s after an impact at `impact` (world) with `seed` on
## `ground` (null: none), its level floor at `level_y`, the streaks in
## `colour` (cracks: dark, toward the colour by the knobs' `crack_tint`).
func show_at(knobs: Dictionary, seed: int, age: float, ground: Ground, impact: Vector3, level_y: float,
		colour: Color) -> void:
	var now := fade(knobs, age)
	visible = ground != null and float(now["scorch"]) > 0.0
	if not visible:
		return
	var point := under(ground, impact, level_y)
	var heading := ground.heading_at(point)
	# Its knobs by their hash: printing them each frame cost more than the
	# rest of it (the core mother's volcanoes, 2026-10-29).
	var key := [ground.get_instance_id(), point, knobs.hash(), seed]
	if key != _built_for:
		_built_for = key
		_scorch.mesh = scorch_mesh(ground, point, heading, float(knobs["radius_m"]), LIFT_M)
		_sparks.mesh = sparks_mesh(ground, point, heading, knobs, seed, LIFT_M * 1.25)
	transform = SurfaceDraw.frame(ground, point, heading)
	_scorch_material.set_shader_parameter("radius", float(knobs["radius_m"]))
	_scorch_material.set_shader_parameter("seed", FxRibbon.seed_value(seed))
	_scorch_material.set_shader_parameter("fade", float(now["scorch"]))
	_scorch_material.set_shader_parameter("glow", float(now["glow"]))
	_scorch_material.set_shader_parameter("tint", colour)
	if cracked(knobs):
		# Dark, split in the floor: they last as the scorch does.
		_sparks_material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		_sparks.visible = _sparks.mesh != null
		# `crack_tint` 0 (the default) dark, 1 the colour (the ground shake's sand).
		var tint := clampf(float(knobs.get("crack_tint", 0.0)), 0.0, 1.0)
		_sparks_material.albedo_color = Color(CRACK_COLOUR.lerp(Color(colour, 1.0), tint), float(now["scorch"]))
		return
	_sparks_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_sparks.visible = _sparks.mesh != null and float(now["glow"]) > 0.0
	_sparks_material.albedo_color = Color(colour, float(now["glow"]))
