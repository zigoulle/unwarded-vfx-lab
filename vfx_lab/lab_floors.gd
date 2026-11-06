## The lab's floors (spec stories 4-5, Q14, Q16): what the caster stands on,
## from the game's own scenery and materials, each with its walkable top at
## its stand spot (stand_spot: the lab's origin but on the ring):
## - ring: the ring arena itself (RingArenaView, its light and darkness
##   too), where the game builds it (its floor shaders read the world
##   position: the hot band toward the lava's edges, the lava's flow round
##   its centre), the caster standing on the ring halfway across;
## - islands: a swatch of the islands' basalt slabs (VolcanoZoneView's
##   basalt) over their glowing seams, lava round it;
## - ash_forest: the ash forest's ground with its haze layers and a few of
##   its trees (AshForestView);
## - ash: the bare ash ground;
## - lava: a pool of the ring's outer lava;
## - curved: the lava ball's faceted rock (BallArenaView.planet_mesh), its
##   top at the origin, for ground marks on curved ground.
## Looks only.
extends RefCounted

const KINDS := ["ring", "islands", "ash_forest", "ash", "lava", "curved"]
## A swatch's size (m).
const SWATCH_M := 24.0
## The islands' slabs (VolcanoZoneView's island floor).
const SLAB_M := 2.6
const SLAB_GAP_M := 0.07
## Where the ash forest's trees stand round the origin (m, turn rad, size).
const TREES := [[Vector2(-4.0, -5.0), 0.4, 1.0], [Vector2(5.0, -3.5), 2.1, 0.85], [Vector2(3.0, 6.0), 4.0, 1.1]]
const SEED := 26
## The floor's level (level_round): read over this far round the
## stand spot (m: the widest marks' reach), on a grid this fine (m), from the
## tops no more than this over the spot's (m: slabs, not pillars or trees).
const LEVEL_REACH_M := 8.0
const LEVEL_STEP_M := 0.25
const LEVEL_BAND_M := 0.25
## The cells (m) tops_at sorts its points into.
const CELL_M := 0.5


## The floor `kind` with `tuning` (the world's, VolcanoZone.scaled).
static func build(kind: String, tuning: Dictionary) -> Node3D:
	match kind:
		"ring":
			return _ring(tuning)
		"islands":
			return _islands(tuning)
		"ash_forest":
			return _ash(tuning, true)
		"ash":
			return _ash(tuning, false)
		"lava":
			return _lava(tuning)
		"curved":
			return _curved(tuning)
	push_error("no floor %s" % kind)
	return Node3D.new()


## Whether the floor lights itself (its own WorldEnvironment and lights): the
## lab then hides its own.
static func brings_light(floor: Node) -> bool:
	return not floor.find_children("*", "WorldEnvironment", true, false).is_empty()


## The lava ball's radius (m) with `tuning`.
static func curved_radius(tuning: Dictionary) -> float:
	return float(tuning.get("ball", {}).get("radius_m", 29.0))


## Where the caster stands on floor `kind` with `tuning` (x, z): on the
## ring halfway across it (the arena's centre at the origin, as in the
## game), on every other floor the origin.
static func stand_spot(kind: String, tuning: Dictionary) -> Vector2:
	if kind == "ring":
		return Vector2((RingArena.pit_radius(tuning) + RingArena.outer_radius(tuning)) / 2.0, 0.0)
	return Vector2.ZERO


## The height of the floor's top straight above or below `spot` (x, z; m):
## the highest of its opaque meshes' triangles there, as placed (-INF: none).
static func top_at(floor: Node3D, spot: Vector2 = Vector2.ZERO) -> float:
	return tops_at(floor, PackedVector2Array([spot]))[0]


## The floor's level round `spot` (x, z; m), where the caster stands and the
## effects lay their marks: the highest of its tops over LEVEL_REACH_M round
## it, leaving out anything more than LEVEL_BAND_M over the spot's top (a
## pillar, a tree). On a slab floor the spot can fall in the seam between
## two slabs or on a low slab: marks laid at that height sink under the
## slabs round it (P-O, 2026-10-23: the ground shake's cracks unseen on the
## ring arena). The spot's top with nothing round it.
static func level_round(floor: Node3D, spot: Vector2 = Vector2.ZERO) -> float:
	var points := PackedVector2Array()
	var n := ceili(LEVEL_REACH_M / LEVEL_STEP_M)
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var p := Vector2(i, j) * LEVEL_STEP_M
			if p.length() <= LEVEL_REACH_M:
				points.append(spot + p)
	var tops := tops_at(floor, points)
	var base := top_at(floor, spot)
	if not is_finite(base):
		return base
	var level := base
	for top in tops:
		if is_finite(top) and top <= base + LEVEL_BAND_M:
			level = maxf(level, top)
	return level


## The height of the floor's top straight above or below each of `points`
## (x, z): the highest of its opaque meshes' triangles
## there, as placed (-INF: none).
static func tops_at(floor: Node3D, points: PackedVector2Array) -> PackedFloat32Array:
	var tops := PackedFloat32Array()
	tops.resize(points.size())
	tops.fill(-INF)
	var reach := Rect2(points[0], Vector2.ZERO)
	# The points by cell, so a triangle tests only those under it.
	var cells := {}
	for k in points.size():
		reach = reach.expand(points[k])
		var cell := Vector2i((points[k] / CELL_M).floor())
		if not cells.has(cell):
			cells[cell] = PackedInt32Array()
		cells[cell].append(k)
	for node in [floor] + floor.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance == null or instance.mesh == null or not instance.visible or _see_through(instance):
			continue
		var xform := _placed(instance, floor)
		var box := xform * instance.mesh.get_aabb()
		if not Rect2(box.position.x, box.position.z, box.size.x, box.size.z).grow(0.001).intersects(reach, true):
			continue
		for i in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(i)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var raw: Variant = arrays[Mesh.ARRAY_INDEX]
			var indices: PackedInt32Array = raw if raw != null else PackedInt32Array()
			var count := indices.size() if indices.size() > 0 else vertices.size()
			for t in range(0, count - 2, 3):
				var a := xform * vertices[indices[t] if indices.size() > 0 else t]
				var b := xform * vertices[indices[t + 1] if indices.size() > 0 else t + 1]
				var c := xform * vertices[indices[t + 2] if indices.size() > 0 else t + 2]
				var lo := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)))
				var hi := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))
				if not Rect2(lo, hi - lo).grow(0.001).intersects(reach, true):
					continue
				var from := Vector2i((lo.max(reach.position) / CELL_M).floor())
				var to := Vector2i((hi.min(reach.end) / CELL_M).floor())
				for x in range(from.x, to.x + 1):
					for z in range(from.y, to.y + 1):
						for k: int in cells.get(Vector2i(x, z), PackedInt32Array()):
							var p := Vector3(points[k].x, 0.0, points[k].y)
							var y := _height_over_origin(a - p, b - p, c - p)
							if not is_nan(y) and y > tops[k]:
								tops[k] = y
	return tops


## `instance`'s transform relative to the space `floor` stands in.
static func _placed(instance: Node3D, floor: Node3D) -> Transform3D:
	var xform := Transform3D()
	var node: Node = instance
	while node != null:
		if node is Node3D:
			xform = (node as Node3D).transform * xform
		if node == floor:
			break
		node = node.get_parent()
	return xform


## The height of triangle (a, b, c) over the origin's vertical, NAN when it
## does not cover it.
static func _height_over_origin(a: Vector3, b: Vector3, c: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ac := Vector2(c.x - a.x, c.z - a.z)
	var ao := Vector2(-a.x, -a.z)
	var det := ab.x * ac.y - ab.y * ac.x
	if absf(det) < 0.000001:
		return NAN
	var u := (ao.x * ac.y - ao.y * ac.x) / det
	var v := (ab.x * ao.y - ab.y * ao.x) / det
	if u < 0.0 or v < 0.0 or u + v > 1.0:
		return NAN
	return a.y + u * (b.y - a.y) + v * (c.y - a.y)


## Whether `instance`'s override draws see-through (not a floor to stand on).
static func _see_through(instance: MeshInstance3D) -> bool:
	var material := instance.material_override
	if material is BaseMaterial3D:
		return (material as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	if material is ShaderMaterial and (material as ShaderMaterial).shader != null:
		return (material as ShaderMaterial).shader.code.contains("ALPHA")
	return false


## The ring arena's floor, pillars and lights (RingArenaView), from `tuning`.
static func _ring(tuning: Dictionary) -> Node3D:
	var view := RingArenaView.new()
	view.name = "Floor"
	view.tuning = tuning
	return view


## A swatch of the islands' ground, in its zone look.
static func _islands(tuning: Dictionary) -> Node3D:
	var look: Dictionary = tuning.get("zone_look", {})
	var root := Node3D.new()
	root.name = "Floor"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	RockMesh.add_floor_slabs(st, rng, SWATCH_M * 0.6, SLAB_M, SLAB_GAP_M)
	var basalt := RingArenaView._material(RingArenaView.BASALT_SHADER)
	basalt.set_shader_parameter("stone_dark", Color(0.11, 0.09, 0.11))
	basalt.set_shader_parameter("stone_light", Color(0.32, 0.26, 0.29))
	basalt.set_shader_parameter("half_size_m", 100000.0)
	basalt.set_shader_parameter("hot_band_m", 1.0)
	basalt.set_shader_parameter("glow", float(look.get("floor_crack_glow", 0.2)))
	var ground := RingArenaView._mesh(st.commit(), basalt)
	ground.name = "Ground"
	root.add_child(ground)
	var seam := RingArenaView._material(RingArenaView.SEAM_SHADER)
	var crack_glow := float(look.get("floor_crack_glow", 0.2))
	seam.set_shader_parameter("half_size_m", 100000.0)
	seam.set_shader_parameter("brightness", 0.5 * crack_glow)
	seam.set_shader_parameter("hot", Color(0.9, 0.28, 0.06) * crack_glow)
	seam.set_shader_parameter("cool", Color(0.06, 0.015, 0.01))
	seam.set_shader_parameter("patches", 0.15)
	root.add_child(RingArenaView._mesh(RingArenaView._annulus(0.0, SWATCH_M * 0.45, -0.12), seam))
	root.add_child(_lava_sheet(tuning, RingArenaView.LAVA_Y))
	return root


## A swatch of ash ground; the ash forest's floor when `forest`.
static func _ash(tuning: Dictionary, forest: bool) -> Node3D:
	var look: Dictionary = tuning.get("ash_forest_look", {})
	var root := Node3D.new()
	root.name = "Floor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(SWATCH_M, SWATCH_M)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = AshForestView.GROUND_COLOR
	mat.roughness = 1.0
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.material_override = mat
	root.add_child(ground)
	if not forest:
		return root
	var trees := MultiMeshInstance3D.new()
	trees.name = "Trees"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = AshForestView.tree_mesh()
	multimesh.instance_count = TREES.size()
	for i in TREES.size():
		var slot := {"position": TREES[i][0], "rotation": TREES[i][1], "scale": TREES[i][2]}
		multimesh.set_instance_transform(i, AshForestView.tree_transform(slot, look))
	trees.multimesh = multimesh
	trees.material_override = AshForestView.bark_material(AshForestView.TREE_SHADER)
	root.add_child(trees)
	var heights := AshForestView.HAZE_HEIGHTS
	for i in heights.size():
		var haze_plane := PlaneMesh.new()
		haze_plane.size = Vector2(SWATCH_M, SWATCH_M)
		var haze := ShaderMaterial.new()
		haze.shader = AshForestView.HAZE_SHADER
		haze.render_priority = AshForestView.HAZE_PRIORITY
		haze.set_shader_parameter("colour", AshForestView.HAZE_COLOR)
		haze.set_shader_parameter("strength", AshForestView.HAZE_STRENGTH)
		haze.set_shader_parameter("soft_m", AshForestView.HAZE_SOFT_M)
		haze.set_shader_parameter("haze", float(look.get("haze", 0.3)))
		haze.set_shader_parameter("wave_haze", float(look.get("wave_haze", 0.85)))
		haze.set_shader_parameter("wave_every_s", float(look.get("wave_every_s", 50.0)))
		haze.set_shader_parameter("wave_s", float(look.get("wave_s", 12.0)))
		haze.set_shader_parameter("layer_share", 1.0 / heights.size())
		haze.set_shader_parameter("seed", float(i) * 17.3)
		haze.set_shader_parameter("centre", Vector2.ZERO)
		haze.set_shader_parameter("reach_m", SWATCH_M * 0.5)
		var layer := MeshInstance3D.new()
		layer.name = "Haze%d" % i
		layer.mesh = haze_plane
		layer.material_override = haze
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		layer.position = Vector3(0.0, heights[i], 0.0)
		root.add_child(layer)
	return root


## A swatch of the lava's look round a patch of floor to stand on.
static func _lava(tuning: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Floor"
	var sheet := _lava_sheet(tuning, 0.0)
	sheet.name = "Ground"
	root.add_child(sheet)
	return root


## The ring's outer lava (RingArenaView._add_lava) as a disc at `y`.
static func _lava_sheet(tuning: Dictionary, y: float) -> MeshInstance3D:
	var look: Dictionary = tuning.get("zone_look", {})
	var lava := RingArenaView._material(RingArenaView.LAVA_SHADER)
	lava.set_shader_parameter("brightness", float(look.get("outer_lava_brightness", 1.1)))
	lava.set_shader_parameter("crust_amount", 0.2)
	lava.set_shader_parameter("scale_m", 3.2)
	lava.set_shader_parameter("white_hot", Color(1.0, 0.62, 0.22))
	lava.set_shader_parameter("flow_speed", float(look.get("lava_flow_m_per_s", 0.5)))
	var sheet := RingArenaView._mesh(RingArenaView._annulus(0.0, SWATCH_M, y), lava)
	sheet.name = "Lava"
	return sheet


## The curved test patch: a cap of the lava ball (curved_radius), its top at the origin.
static func _curved(tuning: Dictionary) -> Node3D:
	var radius := curved_radius(tuning)
	var core := Vector3(0.0, -radius, 0.0)
	var root := Node3D.new()
	root.name = "Floor"
	root.position = core
	var planet := MeshInstance3D.new()
	planet.name = "Ground"
	planet.mesh = BallArenaView.planet_mesh(radius, BallArenaView.PLANET_LEVEL, BallArenaView.PLANET_SEED,
		float(tuning.get("ball_look", {}).get("facet_jitter_m", 0.08)))
	var rock := ShaderMaterial.new()
	rock.shader = BallArenaView.ROCK_SHADER
	BallArenaView.on_the_ball(rock, radius, core)
	rock.set_shader_parameter("crack_amount", 0.08)
	rock.set_shader_parameter("crack_cell_m", 1.2)
	planet.material_override = rock
	root.add_child(planet)
	return root
