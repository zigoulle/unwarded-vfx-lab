## The lab's floor: what the caster stands on, the game's own volcano ring
## arena (RingArenaView: its floor, pillars, vents, lava, light and
## darkness), built where the game builds it (its floor shaders read the
## world position: the hot band toward the lava's edges, the lava's flow
## round its centre), the caster standing on the ring halfway across
## (stand_spot). KINDS lists the floors the lab offers: a new floor is a
## builder in `build` and a name here.
## Looks only.
extends RefCounted

const KINDS := ["ring"]
## The floor's level (level_round): read over this far round the
## stand spot (m: the widest marks' reach), on a grid this fine (m), from the
## tops no more than this over the spot's (m: slabs, not pillars or trees).
const LEVEL_REACH_M := 8.0
const LEVEL_STEP_M := 0.25
const LEVEL_BAND_M := 0.25
## The cells (m) tops_at sorts its points into.
const CELL_M := 0.5


## The floor `kind` with `tuning` (the merged tuning pages).
static func build(kind: String, tuning: Dictionary) -> Node3D:
	match kind:
		"ring":
			return _ring(tuning)
	push_error("no floor %s" % kind)
	return Node3D.new()


## Whether the floor lights itself (its own WorldEnvironment and lights): the
## lab then hides its own.
static func brings_light(floor: Node) -> bool:
	return not floor.find_children("*", "WorldEnvironment", true, false).is_empty()

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
