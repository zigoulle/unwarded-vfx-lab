## The burst block (GLOSSARY: Block; VFX lab ticket 05): a ring of light
## thrown out from an impact, fast at first and slowing, fading as it goes.
## Grown and faded from the time since the impact alone (`at`), so any frame
## is drawn in any order. A camera-facing quad with a soft ring, additive;
## or, for a shockwave thrown along the floor (show_laid: the ground shake's,
## the whirlwind's), the same ring laid on the ground through the ground
## seam (SurfaceMesh.layer, as FxGroundMarks: it wraps curved ground), so no
## half of it sinks into the floor. Looks only: the simulation never reads it.
class_name FxBurst
extends MeshInstance3D

## How far over the ground a laid ring sits (m): over the ground marks'
## scorch and cracks (FxGroundMarks.LIFT_M), clear of the floor's facets.
const LAID_LIFT_M := 0.07


## The burst `age` s after its impact with knobs {radius_m (0: off),
## length_s}: {radius (m), alpha (1 at the impact, 0 out of it)}.
static func at(knobs: Dictionary, age: float) -> Dictionary:
	var radius := float(knobs["radius_m"])
	var length := float(knobs["length_s"])
	if radius <= 0.0 or length <= 0.0 or age < 0.0 or age >= length:
		return {"radius": 0.0, "alpha": 0.0}
	var left := 1.0 - age / length
	return {"radius": radius * (1.0 - left * left * left), "alpha": left * left}


## A soft ring (white, clear inside and out): the burst's sprite.
static func ring() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 0.85, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.15), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


var _material := StandardMaterial3D.new()
var _laid_material := StandardMaterial3D.new()
var _quad := QuadMesh.new()
## The laid disc's ground, point and radius it was built for.
var _laid_for := ""
var _laid_mesh: ArrayMesh


## Builds its glowing billboard quad, hidden until an impact.
func _init() -> void:
	name = "Burst"
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.size = Vector2(2.0, 2.0)
	mesh = _quad
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_material.billboard_keep_scale = true
	_material.albedo_texture = ring()
	material_override = _material
	# Laid on the ground: the same ring, its radius slid in by the texture's
	# scale over a disc built once at its full size; outside the ring clear
	# (the texture clamped, not repeated). With the player's ground effects
	# (GroundDrawOrder), under every enemy mark.
	_laid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_laid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_laid_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_laid_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_laid_material.texture_repeat = false
	_laid_material.render_priority = GroundDrawOrder.PLAYER_EFFECTS
	_laid_material.albedo_texture = _material.albedo_texture
	visible = false


## Draws the burst `age` s after an impact at `origin` (world), tinted
## `colour` (its alpha: its brightness).
func show_at(knobs: Dictionary, age: float, origin: Vector3, colour: Color) -> void:
	var now := at(knobs, age)
	visible = float(now["alpha"]) > 0.0
	if not visible:
		return
	# Set only when changed: assigning a mesh or material each frame costs
	# (playtest 2026-10-25 #3: a crowd of Fire bomb explosions).
	if mesh != _quad:
		mesh = _quad
		material_override = _material
	transform = Transform3D(Basis.from_scale(Vector3.ONE * maxf(float(now["radius"]), 0.001)), origin)
	_material.albedo_color = Color(colour, colour.a * float(now["alpha"]))


## Draws the burst `age` s after an impact at `centre` (world) as a ring
## thrown out along the floor: laid on `ground` under it (FxGroundMarks.under,
## its level floor at `level_y`), or with no ground flat round `centre`
## across `up`. Tinted `colour` (its alpha: its brightness).
func show_laid(knobs: Dictionary, age: float, ground: Ground, centre: Vector3, level_y: float, up: Vector3,
		colour: Color) -> void:
	var now := at(knobs, age)
	visible = float(now["alpha"]) > 0.0
	if not visible:
		return
	var full := float(knobs["radius_m"])
	var point := centre
	var heading := Vector3.FORWARD
	if ground != null:
		point = FxGroundMarks.under(ground, centre, level_y)
		heading = ground.heading_at(point)
	# A level or flat disc is the same wherever it lies: built once per size.
	var curved := ground != null and ground.curved_at(point)
	var key := "%d|%s|%.4f" % [ground.get_instance_id() if ground != null else 0, str(point) if curved else "", full]
	if key != _laid_for:
		_laid_for = key
		_laid_mesh = laid_disc(ground, point, heading, full, LAID_LIFT_M)
	if mesh != _laid_mesh:
		mesh = _laid_mesh
	if material_override != _laid_material:
		material_override = _laid_material
	if ground != null:
		transform = SurfaceDraw.frame(ground, point, heading)
	else:
		var n := up.normalized() if up.length_squared() > 0.000001 else Vector3.UP
		var ahead := FxRibbon.ring_frame(n)[0] as Vector3
		transform = Transform3D(Basis(ahead.cross(n), n, -ahead), point)
	# The ring's edge at the radius now: the texture's edge slid in to it.
	var scale := full / maxf(float(now["radius"]), 0.001)
	_laid_material.uv1_scale = Vector3(scale, scale, 1.0)
	_laid_material.uv1_offset = Vector3(0.5 - 0.5 * scale, 0.5 - 0.5 * scale, 0.0)
	_laid_material.albedo_color = Color(colour, colour.a * float(now["alpha"]))


## A disc `radius` m round `point` (a ground point, heading `heading`) laid
## `lift` over `ground` in the frame there (SurfaceMesh's seam; flat with no
## ground), cut every SurfaceMesh.STEP_M out on a curved one; its UVs the
## flat layout over the disc's width (0.5, 0.5 its middle).
static func laid_disc(ground: Ground, point: Vector3, heading: Vector3, radius: float, lift: float) -> ArrayMesh:
	var lay: Callable = (func(p: Vector3) -> Vector3: return Vector3(p.x, p.y + lift, p.z)) if ground == null 		else SurfaceMesh.layer(ground, point, heading, lift)
	var cuts := 1
	if ground != null and ground.curved_at(point):
		cuts = maxi(1, ceili(radius / SurfaceMesh.STEP_M))
	var turns := SurfaceMesh.SEGMENTS
	var grid: Array[PackedVector3Array] = []
	var uvs: Array[PackedVector2Array] = []
	for j in cuts + 1:
		var r := radius * float(j) / cuts
		var row := PackedVector3Array()
		var row_uv := PackedVector2Array()
		for i in turns + 1:
			var a := TAU * i / turns
			var flat := Vector3(sin(a), 0.0, -cos(a)) * r
			row.append(lay.call(flat))
			row_uv.append(Vector2(0.5, 0.5) + Vector2(flat.x, flat.z) / maxf(2.0 * radius, 0.001))
		grid.append(row)
		uvs.append(row_uv)
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	for i in turns:
		for j in cuts:
			for k: Vector2i in [Vector2i(j, i), Vector2i(j + 1, i), Vector2i(j + 1, i + 1),
					Vector2i(j, i), Vector2i(j + 1, i + 1), Vector2i(j, i + 1)]:
				vertices.append(grid[k.x][k.y])
				uv.append(uvs[k.x][k.y])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out
