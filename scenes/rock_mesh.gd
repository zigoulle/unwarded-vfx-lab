## Low-poly, flat-shaded rock pieces for the arena, appended to a
## SurfaceTool so a whole set of rocks draws as one mesh: columnar mesas,
## pointed crags, cut stone blocks, floor slabs and the volcano cone. Every
## face gets its own normal (faceted look) and a vertex COLOR the rock
## shaders read: r = shade (0 dark .. 1 light), g = lava glow on the face.
## Looks only.
class_name RockMesh
extends RefCounted


## A flat polygon (points in order round it), split into a fan and turned so
## its normal points along `outward`.
static func face(st: SurfaceTool, points: PackedVector3Array, outward: Vector3, color: Color) -> void:
	var centre := Vector3.ZERO
	for p in points:
		centre += p
	centre /= points.size()
	for i in points.size():
		tri(st, centre, points[i], points[(i + 1) % points.size()], outward, color)


## One triangle facing `outward` (Godot draws clockwise-seen-from-the-front
## faces), with its own flat normal.
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, color: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		return
	if n.dot(outward) > 0.0:
		var t := b
		b = c
		c = t
	else:
		n = -n
	n = n.normalized()
	for p in [a, b, c]:
		st.set_normal(n)
		st.set_color(color)
		st.add_vertex(p)


## A rock column or mesa: a jittered `sides`-gon `radius` wide extruded from
## `bottom_y` to `top_y`, its sides broken by a kink part way up (cut rock
## faces) and its top a shallow faceted dome. `shade` 0..1 tints it.
static func add_prism(st: SurfaceTool, rng: RandomNumberGenerator, centre: Vector2, radius: float, top_y: float,
		bottom_y: float, sides: int, shade: float, glow: float = 0.0) -> void:
	var start := rng.randf() * TAU
	# Twice the corners, every other one set back: the grooves between columns.
	var count := sides * 2
	var top: PackedVector3Array = []
	var lip: PackedVector3Array = []
	var kink: PackedVector3Array = []
	var bottom: PackedVector3Array = []
	var kink_y := lerpf(bottom_y, top_y, rng.randf_range(0.5, 0.85))
	var bevel := minf(0.12 * radius, 0.5)
	for i in count:
		var angle := start + TAU * (float(i) + rng.randf_range(-0.2, 0.2)) / count
		var dir := Vector2(cos(angle), sin(angle))
		var r := radius * rng.randf_range(0.9, 1.08) * (0.86 if i % 2 else 1.0)
		var y := top_y + rng.randf_range(-0.06, 0.06) * radius
		var at := centre + dir * (r - bevel)
		top.append(Vector3(at.x, y, at.y))
		at = centre + dir * r
		lip.append(Vector3(at.x, y - bevel, at.y))
		var k := centre + dir * r * rng.randf_range(1.0, 1.1)
		kink.append(Vector3(k.x, kink_y + rng.randf_range(-0.4, 0.4), k.y))
		var b := centre + dir * r * rng.randf_range(1.08, 1.3)
		bottom.append(Vector3(b.x, bottom_y, b.y))
	for i in count:
		var j := (i + 1) % count
		var mid := (lip[i] + lip[j]) / 2.0
		var out := Vector3(mid.x - centre.x, 0.0, mid.z - centre.y)
		var s := clampf(shade + rng.randf_range(-0.14, 0.14), 0.0, 1.0)
		var upper := Color(s * 0.85, glow * 0.4, 0.0)
		var lower := Color(s * 0.65, glow, 0.0)
		var rim := Color(clampf(s + 0.25, 0.0, 1.0), 0.0, 0.0)
		tri(st, top[i], lip[i], lip[j], out + Vector3(0, radius, 0), rim)
		tri(st, top[i], lip[j], top[j], out + Vector3(0, radius, 0), rim)
		tri(st, lip[i], kink[i], kink[j], out, upper)
		tri(st, lip[i], kink[j], lip[j], out, upper)
		tri(st, kink[i], bottom[i], bottom[j], out, lower)
		tri(st, kink[i], bottom[j], kink[j], out, lower)
	# Top: a fan round a slightly raised, off-centre peak.
	var peak := Vector3(centre.x + rng.randf_range(-0.2, 0.2) * radius, top_y + radius * rng.randf_range(0.03, 0.1),
		centre.y + rng.randf_range(-0.2, 0.2) * radius)
	for i in count:
		var s := clampf(shade + 0.12 + rng.randf_range(-0.1, 0.1), 0.0, 1.0)
		tri(st, peak, top[i], top[(i + 1) % count], Vector3.UP, Color(s, 0.0, 0.0))


## A pointed crag `height` tall: three jittered rings narrowing to a leaning
## tip, like the reference's shards.
static func add_crag(st: SurfaceTool, rng: RandomNumberGenerator, base: Vector3, radius: float, height: float,
		shade: float, glow: float = 0.0) -> void:
	var sides := rng.randi_range(4, 6)
	var lean := Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25)) * radius
	var start := rng.randf() * TAU
	var rings: Array[PackedVector3Array] = []
	var heights := [-0.6, height * rng.randf_range(0.3, 0.45), height * rng.randf_range(0.6, 0.75)]
	var scales := [1.0, rng.randf_range(0.6, 0.8), rng.randf_range(0.25, 0.45)]
	for k in 3:
		var ring: PackedVector3Array = []
		for i in sides:
			var angle := start + TAU * (float(i) + rng.randf_range(-0.2, 0.2)) / sides
			var r: float = radius * scales[k] * rng.randf_range(0.85, 1.15)
			var y: float = heights[k]
			ring.append(base + Vector3(cos(angle) * r, y, sin(angle) * r) + lean * (y / height))
		rings.append(ring)
	var tip := base + Vector3(0, height, 0) + lean
	for k in 2:
		for i in sides:
			var j := (i + 1) % sides
			var a := rings[k][i]
			var b := rings[k][j]
			var out := Vector3(a.x + b.x - 2.0 * base.x, 0.0, a.z + b.z - 2.0 * base.z)
			var s := clampf(shade + rng.randf_range(-0.15, 0.15), 0.0, 1.0)
			var color := Color(s, glow if k == 0 else 0.0, 0.0)
			tri(st, a, rings[k + 1][i], rings[k + 1][j], out, color)
			tri(st, a, rings[k + 1][j], b, out, color)
	for i in sides:
		var j := (i + 1) % sides
		var a := rings[2][i]
		var b := rings[2][j]
		var out := Vector3(a.x + b.x - 2.0 * base.x, 0.3 * radius, a.z + b.z - 2.0 * base.z)
		var s := clampf(shade + 0.1 + rng.randf_range(-0.15, 0.15), 0.0, 1.0)
		tri(st, a, tip, b, out, Color(s, 0.0, 0.0))


## A cluster: one big crag with a few smaller ones leaning round its foot.
static func add_crag_cluster(st: SurfaceTool, rng: RandomNumberGenerator, base: Vector3, size: float,
		shade: float, glow: float = 0.0) -> void:
	add_crag(st, rng, base, size * 0.45, size * rng.randf_range(1.4, 2.4), shade, glow)
	for i in rng.randi_range(1, 3):
		var angle := rng.randf() * TAU
		var at := base + Vector3(cos(angle), 0, sin(angle)) * size * rng.randf_range(0.45, 0.8)
		add_crag(st, rng, at, size * rng.randf_range(0.2, 0.3), size * rng.randf_range(0.5, 1.1), shade, glow)


## A cut stone block (ruins, pillars, bridge stones): a box `size` big at
## `centre`, turned `yaw` radians, its corners chipped a little.
static func add_block(st: SurfaceTool, rng: RandomNumberGenerator, centre: Vector3, size: Vector3, yaw: float,
		shade: float, chip: float = 0.06) -> void:
	add_block_turned(st, rng, centre, size, Basis(Vector3.UP, yaw), shade, chip)


## As add_block, turned by any `basis` (arch stones follow the curve).
static func add_block_turned(st: SurfaceTool, rng: RandomNumberGenerator, centre: Vector3, size: Vector3,
		basis: Basis, shade: float, chip: float = 0.06) -> void:
	var h := size / 2.0
	var c: PackedVector3Array = []
	for corner in 8:
		var sx := 1.0 if corner & 1 else -1.0
		var sy := 1.0 if corner & 2 else -1.0
		var sz := 1.0 if corner & 4 else -1.0
		var jitter := Vector3(rng.randf_range(-chip, chip), rng.randf_range(-chip, chip), rng.randf_range(-chip, chip))
		c.append(centre + basis * (Vector3(sx * h.x, sy * h.y, sz * h.z) + jitter * size.length() * 0.5))
	# Corner index bits: 1 = +x, 2 = +y, 4 = +z.
	var faces := [[0, 1, 5, 4, Vector3.DOWN], [2, 3, 7, 6, Vector3.UP], [0, 1, 3, 2, Vector3.FORWARD],
		[4, 5, 7, 6, Vector3.BACK], [0, 2, 6, 4, Vector3.LEFT], [1, 3, 7, 5, Vector3.RIGHT]]
	for f: Array in faces:
		var s := clampf(shade + rng.randf_range(-0.08, 0.08) + (0.12 if f[4] == Vector3.UP else 0.0), 0.0, 1.0)
		face(st, PackedVector3Array([c[f[0]], c[f[1]], c[f[2]], c[f[3]]]), basis * (f[4] as Vector3), Color(s, 0.0, 0.0))


## The volcano: a faceted cone `height` tall on a base `radius` wide at
## `base`, flanks concave and ridged, opening into a crater `crater_radius`
## wide that dips back down inside.
static func add_volcano(st: SurfaceTool, rng: RandomNumberGenerator, base: Vector3, radius: float, height: float,
		crater_radius: float) -> void:
	var sides := 26
	var ring_count := 14
	# Ridges and bulges run down the whole flank (the same per sector on
	# every ring): radius jumps between rings would make the shader's lava
	# streams jog sideways.
	var sector_bulge: PackedFloat32Array = []
	var sector_angle: PackedFloat32Array = []
	for i in sides:
		sector_bulge.append(rng.randf_range(0.92, 1.08) * (1.1 if i % 2 == 0 else 0.93))
		sector_angle.append(TAU * (float(i) + rng.randf_range(-0.2, 0.2)) / sides)
	var rings: Array[PackedVector3Array] = []
	for k in ring_count + 1:
		var t := float(k) / ring_count
		var ring: PackedVector3Array = []
		for i in sides:
			var angle := sector_angle[i] + rng.randf_range(-0.01, 0.01)
			var r := crater_radius + (radius - crater_radius) * pow(1.0 - t, 1.7)
			r *= lerpf(sector_bulge[i], 1.0, t * 0.6) * rng.randf_range(0.98, 1.02)
			var y := height * t + (rng.randf_range(-0.012, 0.012) * height if k > 0 and k < ring_count else 0.0)
			ring.append(base + Vector3(cos(angle) * r, y, sin(angle) * r))
		rings.append(ring)
	for k in ring_count:
		for i in sides:
			var j := (i + 1) % sides
			var a := rings[k][i]
			var b := rings[k][j]
			var out := Vector3(a.x + b.x - 2.0 * base.x, radius * 0.4, a.z + b.z - 2.0 * base.z)
			var s := clampf(0.5 + rng.randf_range(-0.25, 0.25), 0.0, 1.0)
			tri(st, a, rings[k + 1][i], rings[k + 1][j], out, Color(s, 0.0, 0.0))
			tri(st, a, rings[k + 1][j], b, out, Color(clampf(s + rng.randf_range(-0.15, 0.15), 0.0, 1.0), 0.0, 0.0))
	# Crater: from the rim down and in to a floor.
	var floor_y := base.y + height * 0.9
	var inner: PackedVector3Array = []
	for i in sides:
		var p := rings[ring_count][i]
		inner.append(Vector3(lerpf(base.x, p.x, 0.55), floor_y, lerpf(base.z, p.z, 0.55)))
	for i in sides:
		var j := (i + 1) % sides
		var a := rings[ring_count][i]
		var b := rings[ring_count][j]
		var inward := Vector3(2.0 * base.x - a.x - b.x, crater_radius, 2.0 * base.z - a.z - b.z)
		tri(st, a, inner[i], inner[j], inward, Color(0.3, 1.0, 0.0))
		tri(st, a, inner[j], b, inward, Color(0.3, 1.0, 0.0))


## Rolling dark ground from `inner` metres out to `outer` round `centre`,
## faceted, climbing gently toward the horizon; the lava stops under its
## inner edge.
static func add_far_ground(st: SurfaceTool, rng: RandomNumberGenerator, centre: Vector3, inner: float,
		outer: float) -> void:
	var sectors := 40
	var rings := 7
	var points := []
	for k in rings + 1:
		var row: PackedVector3Array = []
		var t := float(k) / rings
		var r := lerpf(inner, outer, t * t)
		for i in sectors:
			var angle := TAU * (float(i) + rng.randf_range(-0.3, 0.3)) / sectors
			var rr := r * rng.randf_range(0.94, 1.06) if k > 0 else r
			var y := (rng.randf_range(-0.8, 0.4) if k == 0 else rng.randf_range(-2.0, 6.0) + t * t * 90.0)
			row.append(centre + Vector3(cos(angle) * rr, y, sin(angle) * rr))
		points.append(row)
	for k in rings:
		for i in sectors:
			var j := (i + 1) % sectors
			var s := rng.randf_range(0.1, 0.4)
			tri(st, points[k][i], points[k + 1][i], points[k + 1][j], Vector3.UP, Color(s, 0.0, 0.0))
			tri(st, points[k][i], points[k + 1][j], points[k][j], Vector3.UP,
				Color(clampf(s + rng.randf_range(-0.1, 0.1), 0.0, 1.0), 0.0, 0.0))


## The fighting floor: a square `size_m` wide of irregular basalt slabs
## (a jittered grid, some cells merged), each slab a shallow faceted top a
## little apart from its neighbours with short sides, so the glow plane
## below shows through the seams. Tops stay within a few centimetres of 0.
static func add_floor_slabs(st: SurfaceTool, rng: RandomNumberGenerator, size_m: float, slab_m: float,
		gap_m: float) -> void:
	var n := maxi(2, roundi(size_m / slab_m))
	var cell := size_m / n
	var half := size_m / 2.0
	var corner := []
	for j in n + 1:
		var row := []
		for i in n + 1:
			var p := Vector2(-half + i * cell, -half + j * cell)
			if i > 0 and i < n:
				p.x += rng.randf_range(-0.3, 0.3) * cell
			if j > 0 and j < n:
				p.y += rng.randf_range(-0.3, 0.3) * cell
			row.append(p)
		corner.append(row)
	var used := {}
	for j in n:
		for i in n:
			if used.has(Vector2i(i, j)):
				continue
			used[Vector2i(i, j)] = true
			var outline: Array[Vector2] = []
			var roll := rng.randf()
			if roll < 0.22 and i + 1 < n and not used.has(Vector2i(i + 1, j)):
				used[Vector2i(i + 1, j)] = true
				outline = [corner[j][i], corner[j][i + 1], corner[j][i + 2], corner[j + 1][i + 2], corner[j + 1][i + 1],
					corner[j + 1][i]]
			elif roll < 0.4 and j + 1 < n and not used.has(Vector2i(i, j + 1)):
				used[Vector2i(i, j + 1)] = true
				outline = [corner[j][i], corner[j][i + 1], corner[j + 1][i + 1], corner[j + 2][i + 1], corner[j + 2][i],
					corner[j + 1][i]]
			else:
				outline = [corner[j][i], corner[j][i + 1], corner[j + 1][i + 1], corner[j + 1][i]]
			_add_slab(st, rng, outline, gap_m)


## The ring arena's floor (zone SOP 6b): the ring between `inner` and
## `outer` metres from the centre paved with irregular basalt slabs about
## `slab_m` across, as add_floor_slabs does the square: concentric bands
## with wavy borders, each cut into slabs at jittered angles. Every slab
## reaches its sides down to `bottom_y`, so the ring's edges are a ragged
## faceted cliff into the lava.
static func add_ring_slabs(st: SurfaceTool, rng: RandomNumberGenerator, inner: float, outer: float, slab_m: float,
		gap_m: float, bottom_y: float) -> void:
	for outline: Array[Vector2] in ring_slab_outlines(rng, inner, outer, slab_m):
		_add_slab(st, rng, outline, gap_m, bottom_y)


## The slabs' outlines (ground points round each slab) for add_ring_slabs:
## the bands' borders wave a little (shared by both bands, so the slabs
## tile the ring), and the first and last reach EDGE_OVER_M past the ring's
## edges so the floor covers the whole walkable ring.
static func ring_slab_outlines(rng: RandomNumberGenerator, inner: float, outer: float, slab_m: float) -> Array:
	var bands := maxi(1, roundi((outer - inner) / slab_m))
	var step := (outer - inner) / bands
	# Each inner border's wave: [amplitude, lobes, phase] twice over.
	var waves: Array = []
	for j in bands + 1:
		waves.append([step * rng.randf_range(0.08, 0.16), rng.randi_range(5, 11), rng.randf() * TAU,
			step * rng.randf_range(0.03, 0.07), rng.randi_range(17, 29), rng.randf() * TAU])
	var border := func(j: int, a: float) -> float:
		if j == 0:
			return inner - EDGE_OVER_M
		if j == bands:
			return outer + EDGE_OVER_M
		var w: Array = waves[j]
		return inner + j * step + w[0] * sin(w[1] * a + w[2]) + w[3] * sin(w[4] * a + w[5])
	var outlines: Array = []
	for j in bands:
		var mid := inner + (j + 0.5) * step
		var count := maxi(6, roundi(TAU * mid / slab_m))
		var start := rng.randf() * TAU
		var cuts: Array[float] = []
		var skews: Array[float] = []
		for i in count:
			cuts.append(start + TAU * (float(i) + rng.randf_range(-0.3, 0.3)) / count)
			skews.append(rng.randf_range(-0.25, 0.25) * step / mid)
		for i in count:
			var a0 := cuts[i]
			var a1 := cuts[(i + 1) % count] + (TAU if i + 1 == count else 0.0)
			var s0 := skews[i]
			var s1 := skews[(i + 1) % count]
			var outline: Array[Vector2] = []
			var pieces := maxi(2, ceili((a1 - a0) * mid / ARC_STEP_M))
			for k in pieces + 1:
				var a := lerpf(a0, a1, float(k) / pieces)
				outline.append(Vector2(sin(a), cos(a)) * border.call(j, a))
			for k in range(pieces, -1, -1):
				var a := lerpf(a0 + s0, a1 + s1, float(k) / pieces)
				outline.append(Vector2(sin(a), cos(a)) * border.call(j + 1, a))
			outlines.append(outline)
	return outlines


## Any floor `outline` (a closed polygon on the ground: an island, the
## connector cave) paved with irregular basalt slabs about `slab_m` across,
## as add_ring_slabs paves the ring. Slab sides on the outline (its shore)
## carry the lava's glow (vertex COLOR.g 1): the lit rim where the rock
## meets the lava. Every slab reaches its sides down to `bottom_y`.
static func add_polygon_slabs(st: SurfaceTool, rng: RandomNumberGenerator, outline: PackedVector2Array, slab_m: float,
		gap_m: float, bottom_y: float) -> void:
	for piece: Array in _slab_pieces(rng, outline, slab_m):
		var points: Array[Vector2] = []
		points.assign(Array(piece[0]))
		# Only a slab the outline cut can have a side on the shore.
		_add_slab(st, rng, points, gap_m, bottom_y, outline if piece[1] else PackedVector2Array())


## The slabs' outlines for add_polygon_slabs: a jittered grid (corners
## shared, so the slabs tile), turned at a random angle, some cells merged
## in pairs, cut by `outline`. Together they cover the polygon exactly.
static func polygon_slab_outlines(rng: RandomNumberGenerator, outline: PackedVector2Array, slab_m: float) -> Array:
	return _slab_pieces(rng, outline, slab_m).map(func(piece: Array) -> PackedVector2Array: return piece[0])


## polygon_slab_outlines' slabs as [outline, cut (true when the polygon's
## edge cut it)].
static func _slab_pieces(rng: RandomNumberGenerator, outline: PackedVector2Array, slab_m: float) -> Array:
	var turn := rng.randf() * PI
	var x_axis := Vector2(cos(turn), sin(turn))
	var y_axis := Vector2(-x_axis.y, x_axis.x)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p: Vector2 in outline:
		var q := Vector2(p.dot(x_axis), p.dot(y_axis))
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	lo -= Vector2.ONE * slab_m
	var nx := ceili((hi.x - lo.x) / slab_m) + 2
	var ny := ceili((hi.y - lo.y) / slab_m) + 1
	var corners: Array = []
	for j in ny + 1:
		var row: Array = []
		for i in nx + 1:
			var g := lo + Vector2(i, j) * slab_m + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)) * slab_m
			row.append(x_axis * g.x + y_axis * g.y)
		corners.append(row)
	var out: Array = []
	for j in ny:
		var i := 0
		while i < nx:
			var cell := PackedVector2Array()
			if i + 1 < nx and rng.randf() < 0.35:
				cell = PackedVector2Array([corners[j][i], corners[j][i + 1], corners[j][i + 2], corners[j + 1][i + 2],
					corners[j + 1][i + 1], corners[j + 1][i]])
				i += 2
			else:
				cell = PackedVector2Array([corners[j][i], corners[j][i + 1], corners[j + 1][i + 1], corners[j + 1][i]])
				i += 1
			var pieces := Geometry2D.intersect_polygons(cell, outline)
			var whole := pieces.size() == 1 and absf(absf(_signed_area(pieces[0])) - absf(_signed_area(cell))) < 0.001
			for piece: PackedVector2Array in pieces:
				if piece.size() >= 3 and absf(_signed_area(piece)) > 0.02:
					out.append([piece, not whole])
	return out


static func _signed_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in points.size():
		area += points[i].cross(points[(i + 1) % points.size()])
	return area / 2.0


## True when the ground segment `a`-`b` lies along `outline`'s edge (both
## ends within a few centimetres of it).
static func _on_outline(a: Vector2, b: Vector2, outline: PackedVector2Array) -> bool:
	return _edge_distance(a, outline) < 0.05 and _edge_distance(b, outline) < 0.05 \
		and _edge_distance((a + b) / 2.0, outline) < 0.05


static func _edge_distance(p: Vector2, outline: PackedVector2Array) -> float:
	var best := INF
	for i in outline.size():
		var q := Geometry2D.get_closest_point_to_segment(p, outline[i], outline[(i + 1) % outline.size()])
		best = minf(best, p.distance_to(q))
	return best


## How far the ring's floor slabs reach past its edges (m), and how finely
## their curved sides follow the ring (m of arc per straight piece).
const EDGE_OVER_M := 0.15
const ARC_STEP_M := 0.9


## A stalactite hanging from `top`: rings narrowing down `length` metres to a
## point, leaning a little. Faces lit as facing out and down.
static func add_stalactite(st: SurfaceTool, rng: RandomNumberGenerator, top: Vector3, radius: float, length: float,
		shade: float) -> void:
	var sides := rng.randi_range(4, 6)
	var start := rng.randf() * TAU
	var lean := Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2)) * radius
	var depths := [-0.5, length * rng.randf_range(0.3, 0.45), length * rng.randf_range(0.6, 0.75)]
	var scales := [1.0, rng.randf_range(0.55, 0.75), rng.randf_range(0.2, 0.4)]
	var rings: Array[PackedVector3Array] = []
	for k in 3:
		var ring: PackedVector3Array = []
		for i in sides:
			var angle := start + TAU * (float(i) + rng.randf_range(-0.2, 0.2)) / sides
			var r: float = radius * scales[k] * rng.randf_range(0.85, 1.15)
			var d: float = depths[k]
			ring.append(top + Vector3(cos(angle) * r, -d, sin(angle) * r) + lean * (d / length))
		rings.append(ring)
	var tip := top + Vector3(0, -length, 0) + lean
	for k in 2:
		for i in sides:
			var j := (i + 1) % sides
			var a := rings[k][i]
			var b := rings[k][j]
			var out := Vector3(a.x + b.x - 2.0 * top.x, -0.2 * radius, a.z + b.z - 2.0 * top.z)
			var s := clampf(shade + rng.randf_range(-0.12, 0.12), 0.0, 1.0)
			tri(st, a, rings[k + 1][i], rings[k + 1][j], out, Color(s, 0.0, 0.0))
			tri(st, a, rings[k + 1][j], b, out, Color(s, 0.0, 0.0))
	for i in sides:
		var j := (i + 1) % sides
		var a := rings[2][i]
		var b := rings[2][j]
		var out := Vector3(a.x + b.x - 2.0 * top.x, -0.4 * radius, a.z + b.z - 2.0 * top.z)
		tri(st, a, tip, b, out, Color(clampf(shade - 0.1, 0.0, 1.0), 0.0, 0.0))


## add_prism built round the origin and placed by `xform` (a tilted column,
## a leaning wall crag): the same rock, any lean.
static func add_prism_placed(st: SurfaceTool, rng: RandomNumberGenerator, xform: Transform3D, radius: float,
		top_y: float, bottom_y: float, sides: int, shade: float, glow: float = 0.0) -> void:
	var piece := SurfaceTool.new()
	piece.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_prism(piece, rng, Vector2.ZERO, radius, top_y, bottom_y, sides, shade, glow)
	st.append_from(piece.commit(), 0, xform)


## The ring arena's rock pillar (zone SOP 6b, the rock-pillar still), built
## round the origin from y = 0 up, `radius` the simulation's circle and
## `height` its drawn height: a chunky cluster of faceted columns (a main
## column, two lower ones leaning on it, small chunks round the foot), the
## same rock in every `stage` (the parts are rolled from `seed` before the
## stage changes them):
##   0 intact; 1 cracked: the top chipped off and tilted, a few chunks
##   fallen; 2 split: the main column broken in two leaning halves, a side
##   column fallen, rubble round it; 3 a broken stump in a ring of rubble.
## Its foot stays within about 1.25 x `radius` of the centre, the rubble a
## little further.
static func add_pillar(st: SurfaceTool, seed: int, radius: float, height: float, stage: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var main_r := radius * 0.78
	var main_seed := rng.randi()
	var sides: Array = []
	for k in 2:
		var angle := rng.randf() * TAU + k * PI * rng.randf_range(0.6, 0.9)
		sides.append({"at": Vector2(cos(angle), sin(angle)) * radius * 0.5, "r": radius * rng.randf_range(0.42, 0.5),
			"top": height * (rng.randf_range(0.62, 0.78) if k == 0 else rng.randf_range(0.42, 0.55)),
			"seed": rng.randi()})
	var feet: Array = []
	for k in 3:
		var angle := rng.randf() * TAU
		feet.append({"at": Vector2(cos(angle), sin(angle)) * radius * 0.72, "r": radius * rng.randf_range(0.26, 0.34),
			"top": height * rng.randf_range(0.12, 0.26), "seed": rng.randi()})
	var split_axis := rng.randf() * TAU
	var rubble_seed := rng.randi()
	var part := RandomNumberGenerator.new()
	# The main column.
	part.seed = main_seed
	match stage:
		INTACT_STAGE:
			add_prism(st, part, Vector2.ZERO, main_r, height, 0.0, 6, 0.55)
		CRACKED_STAGE:
			add_prism(st, part, Vector2.ZERO, main_r, height * 0.8, 0.0, 6, 0.55)
			# The chipped cap, knocked askew.
			var tilt := Basis(Vector3(cos(split_axis), 0, sin(split_axis)), 0.16)
			add_prism_placed(st, part, Transform3D(tilt, Vector3(0.12 * cos(split_axis + 1.6), height * 0.8 + 0.06,
				0.12 * sin(split_axis + 1.6))), main_r * 0.86, height * 0.13, -0.05, 6, 0.6)
		SPLIT_STAGE:
			add_prism(st, part, Vector2.ZERO, main_r, height * 0.5, 0.0, 6, 0.5)
			for k: float in [-1.0, 1.0]:
				var out := Vector3(cos(split_axis), 0, sin(split_axis)) * k
				var lean := Basis(Vector3(-out.z, 0, out.x), 0.12)
				add_prism_placed(st, part, Transform3D(lean, out * main_r * 0.45 + Vector3(0, height * 0.5 + 0.04, 0)),
					main_r * 0.52, height * (0.42 if k > 0 else 0.26), 0.0, 5, 0.5)
		_:
			add_prism(st, part, Vector2.ZERO, main_r * 1.02, STUMP_HEIGHT_M, 0.0, 6, 0.45)
	# The side columns: both stand, until the split drops one and the stump
	# leaves their feet.
	for k in sides.size():
		var side: Dictionary = sides[k]
		part.seed = side["seed"]
		var top: float = side["top"]
		if stage == CRACKED_STAGE and k == 1:
			top *= 0.85
		elif stage == SPLIT_STAGE and k == 1:
			continue
		elif stage == STUMP_STAGE:
			top = STUMP_HEIGHT_M * (0.7 if k == 0 else 0.45)
		add_prism(st, part, side["at"], side["r"], top, 0.0, 5, 0.45)
	for foot: Dictionary in feet:
		part.seed = foot["seed"]
		add_prism(st, part, foot["at"], foot["r"], minf(foot["top"], STUMP_HEIGHT_M * 0.6) if stage == STUMP_STAGE
			else foot["top"], 0.0, 5, 0.4)
	# Fallen chunks round the foot.
	part.seed = rubble_seed
	var chunks: int = [0, 4, 8, 12][clampi(stage, 0, 3)]
	for k in chunks:
		var angle := part.randf() * TAU
		var far := radius * part.randf_range(1.0, 1.25 if stage < STUMP_STAGE else 1.6)
		var size := radius * part.randf_range(0.1, 0.22) * (1.4 if k < 2 and stage >= SPLIT_STAGE else 1.0)
		add_block(st, part, Vector3(cos(angle) * far, size * 0.35, sin(angle) * far), Vector3(size, size * 0.8, size * 1.1),
			part.randf() * TAU, 0.4, 0.15)


## Pillar stages (add_pillar), and how tall the broken stump stands.
const INTACT_STAGE := 0
const CRACKED_STAGE := 1
const SPLIT_STAGE := 2
const STUMP_STAGE := 3
const STUMP_HEIGHT_M := 0.6


## The same mesh as `mesh`'s triangles with smooth normals (shared corners
## merged): the hull an outline pass pushes out without splitting at the
## facets' creases (outline.gdshader).
static func outline_hull(mesh: ArrayMesh) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in points:
		# Snapped so corners a centimetre apart weld into one.
		st.add_vertex(p.snapped(Vector3.ONE * 0.01))
	st.index()
	st.generate_normals()
	return st.commit()


static func _add_slab(st: SurfaceTool, rng: RandomNumberGenerator, outline: Array[Vector2], gap_m: float,
		bottom_y: float = -0.4, shore: PackedVector2Array = PackedVector2Array()) -> void:
	var centre := Vector2.ZERO
	for p in outline:
		centre += p
	centre /= outline.size()
	var tilt := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * 0.006
	var lift := rng.randf_range(-0.015, 0.015)
	var inner: PackedVector3Array = []
	var top: PackedVector3Array = []
	var bottom: PackedVector3Array = []
	for p in outline:
		var to_centre := (centre - p).normalized()
		var q := p + to_centre * gap_m
		var y := lift + tilt.dot(q - centre)
		top.append(Vector3(q.x, y - 0.05, q.y))
		var b := q + to_centre * 0.14
		inner.append(Vector3(b.x, y, b.y))
		bottom.append(Vector3(q.x, bottom_y, q.y))
	var shade := rng.randf_range(0.15, 0.85)
	var peak := Vector3(centre.x, lift + 0.02, centre.y)
	for i in top.size():
		var k := (i + 1) % top.size()
		var s := clampf(shade + rng.randf_range(-0.06, 0.06), 0.0, 1.0)
		tri(st, peak, inner[i], inner[k], Vector3.UP, Color(s, 0.0, 0.0))
		var out := Vector3((top[i].x + top[k].x) / 2.0 - centre.x, 0.0, (top[i].z + top[k].z) / 2.0 - centre.y)
		# On the shore (the slab's side on `shore`) the lava lights the side
		# and the bevel: COLOR.g.
		var lit := 1.0 if not shore.is_empty() and _on_outline(outline[i], outline[k], shore) else 0.0
		# The worn bevel round the slab's top catches the light.
		var bevel := Color(clampf(shade + 0.3, 0.0, 1.0), lit, 0.0)
		tri(st, inner[i], top[i], top[k], out + Vector3.UP, bevel)
		tri(st, inner[i], top[k], inner[k], out + Vector3.UP, bevel)
		tri(st, top[i], bottom[i], bottom[k], out, Color(shade * 0.5, lit, 0.0))
		tri(st, top[i], bottom[k], top[k], out, Color(shade * 0.5, lit, 0.0))


## A lava fall's sheet (smooth, with UVs: x across, y from the lip down):
## pours from `lip` over the edge in direction `out` and drops to `bottom_y`,
## bowing outward as it falls.
static func add_fall_sheet(st: SurfaceTool, lip: Vector3, out: Vector3, width: float, bottom_y: float) -> void:
	var across := out.cross(Vector3.UP).normalized()
	var drop := lip.y - bottom_y
	var rows := 10
	var cols := 4
	for r in rows:
		for c in cols:
			var quad := []
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var v := float(r + corner.y) / rows
				var u := float(c + corner.x) / cols
				var forward := out * (1.2 * sqrt(v) + 0.3 * sin(u * PI))
				var p := lip + across * (u - 0.5) * width * (1.0 + 0.35 * v) + forward + Vector3.DOWN * drop * v
				quad.append([p, Vector2(u, v)])
			for idx: int in [0, 1, 2, 0, 2, 3]:
				st.set_normal(out)
				st.set_uv(quad[idx][1])
				st.add_vertex(quad[idx][0])
