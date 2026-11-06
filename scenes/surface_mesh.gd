## Flat shapes laid on the ground (lava-ball ticket 09; the spike report's
## item 2): a disc, a ring or a ring sector round a ground point, built in
## the frame SurfaceDraw.frame gives that point (x right, y up, -z the
## heading), so a view draws it under that frame. Each vertex is the flat
## shape's point laid off the middle along the surface (Ground.offset: its
## distance and bearing kept, as the sim measures a reach) and lifted
## `lift` out along the up there.
## - On the level ground (not Ground.curved) the very triangles the flat
##   views draw (Telegraphs._ring_mesh, Telegraphs.sector_mesh), lifted.
## - On a curved ground the radial edges are cut into STEP_M pieces, so no
##   triangle is long enough to sag into the rock or float off it.
## A round ground is the same all round, so a view may build a shape once
## and draw it under any point's frame (Kept). Presentation only.
class_name SurfaceMesh
extends RefCounted

## The longest radial edge on a curved ground (m): a 0.5 m chord of the
## 29 m ball sags about a millimetre.
const STEP_M := 0.5
## Shapes a Kept holds at most (all dropped past it).
const KEPT_MAX := 400
## A laid shape (Kept.laid) is built again only once its place moves this
## far (m) or its way turns this much (degrees).
const PLACE_M := 0.1
const PLACE_DEG := 1.0


## A view's laid shapes, each built once per ground and shape and drawn
## under any point's frame (the ball is the same all round): a growing or
## shrinking disc snaps its radius to `step_m` so it reuses them.
class Kept:
	var _on: Ground
	var _shapes := {}

	## The ring `inner` to `outer` m, `lift` over the ground, as laid round
	## `point` on `ground`.
	func ring(ground: Ground, point: Vector3, inner: float, outer: float, lift: float) -> Mesh:
		return _kept(ground, "r|%.3f|%.3f|%.3f" % [inner, outer, lift], func() -> Mesh:
			return SurfaceMesh.ring(ground, point, ground.heading_at(point), inner, outer, lift))

	## The sector (SurfaceMesh.sector) along -Z of the frame at `point`.
	func sector(ground: Ground, point: Vector3, inner: float, outer: float, angle_deg: float, width: float,
			lift: float) -> Mesh:
		return _kept(ground, "s|%.3f|%.3f|%.3f|%.3f|%.3f" % [inner, outer, angle_deg, width, lift],
			func() -> Mesh: return SurfaceMesh.sector(ground, point, ground.heading_at(point), inner, outer,
				angle_deg, width, lift))

	## The strip (SurfaceMesh.strip) from `point` along `ahead`.
	func strip(ground: Ground, point: Vector3, ahead: Vector3, length: float, width: float, edge: float,
			lift: float) -> Mesh:
		return _kept(ground, "l|%.3f|%.3f|%.3f|%.3f" % [length, width, edge, lift],
			func() -> Mesh: return SurfaceMesh.strip(ground, point, ahead, length, width, edge, lift))

	## The flat shape `make` builds (known as `shape`) laid from `point` along `ahead`
	## (SurfaceMesh.laid), drawn under the frame at `point` heading `ahead`.
	## Kept per place too: on the climb's cone a shape's lie changes with
	## where it is (snapped to PLACE_M and PLACE_DEG).
	func laid(ground: Ground, point: Vector3, ahead: Vector3, shape: String, make: Callable, lift: float) -> Mesh:
		var at := point.snapped(Vector3.ONE * PLACE_M)
		var way := ahead.snapped(Vector3.ONE * deg_to_rad(PLACE_DEG))
		return _kept(ground, "f|%s|%.3f|%s|%s" % [shape, lift, at, way],
			func() -> Mesh: return SurfaceMesh.laid(ground, point, ahead, make.call(), lift))

	func _kept(ground: Ground, key: String, build: Callable) -> Mesh:
		if ground != _on or _shapes.size() >= KEPT_MAX:
			_on = ground
			_shapes = {}
		if not _shapes.has(key):
			_shapes[key] = build.call()
		return _shapes[key]


## `radius` snapped to `step_m` steps (at least one step): a growing disc's
## kept sizes.
static func snapped_radius(radius: float, step_m: float) -> float:
	return maxf(step_m, snappedf(radius, step_m))


## A ring `inner` to `outer` m from `centre` (a disc when `inner` is 0),
## Telegraphs.SEGMENTS round.
static func ring(ground: Ground, centre: Vector3, heading: Vector3, inner: float, outer: float,
		lift: float = 0.0) -> ArrayMesh:
	var lay := layer(ground, centre, heading, lift)
	var radii := _radii(ground, centre, inner, outer)
	var turns := Telegraphs.SEGMENTS
	var grid: Array[PackedVector3Array] = []
	for r in radii:
		var row := PackedVector3Array()
		for i in turns + 1:
			var a := TAU * i / turns
			row.append(lay.call(Vector3(sin(a), 0.0, -cos(a)) * r))
		grid.append(row)
	var vertices := PackedVector3Array()
	for i in turns:
		for j in radii.size() - 1:
			vertices.append_array([grid[j][i], grid[j + 1][i], grid[j + 1][i + 1],
				grid[j][i], grid[j + 1][i + 1], grid[j][i + 1]])
	return _mesh(vertices)


## A ring sector `inner` to `outer` m out from `centre` along its heading,
## `angle_deg` wide: filled when `width` is 0, else only its edge (both
## arcs and both sides), `width` wide inward (Telegraphs.sector_mesh's).
static func sector(ground: Ground, centre: Vector3, heading: Vector3, inner: float, outer: float,
		angle_deg: float, width: float = 0.0, lift: float = 0.0) -> ArrayMesh:
	var lay := layer(ground, centre, heading, lift)
	var half := deg_to_rad(angle_deg) / 2.0
	var steps := maxi(4, ceili(Telegraphs.SEGMENTS * angle_deg / 360.0))
	var at := func(a: float, r: float) -> Vector3: return Vector3(sin(a) * r, 0.0, -cos(a) * r)
	var bands: Array = [[inner, outer]] if width <= 0.0 else [[inner, minf(outer, inner + width)],
		[maxf(inner, outer - width), outer]]
	var vertices := PackedVector3Array()
	for band: Array in bands:
		var radii := _radii(ground, centre, band[0], band[1])
		var grid: Array[PackedVector3Array] = []
		for r in radii:
			var row := PackedVector3Array()
			for i in steps + 1:
				row.append(lay.call(at.call(-half + 2.0 * half * i / steps, r)))
			grid.append(row)
		for i in steps:
			for j in radii.size() - 1:
				vertices.append_array([grid[j][i], grid[j + 1][i], grid[j + 1][i + 1],
					grid[j][i], grid[j + 1][i + 1], grid[j][i + 1]])
	if width > 0.0:
		var radii := _radii(ground, centre, inner, outer)
		for side in [-1.0, 1.0]:
			var d: Vector3 = at.call(side * half, 1.0)
			var n: Vector3 = Vector3(-d.z, 0.0, d.x) * -float(side)
			for j in radii.size() - 1:
				var r0 := radii[j]
				var r1 := radii[j + 1]
				vertices.append_array([lay.call(d * r0), lay.call(d * r1), lay.call(d * r1 + n * width),
					lay.call(d * r0), lay.call(d * r1 + n * width), lay.call(d * r0 + n * width)])
	return _mesh(vertices)


## A strip (a line mark) from `start` along its heading, `length` long and
## `width` across: filled when `edge` is 0, else only its edge, `edge` wide
## inward (Telegraphs.strip_rects). On a curved ground each rectangle is cut
## into pieces at most STEP_M on a side.
static func strip(ground: Ground, start: Vector3, heading: Vector3, length: float, width: float,
		edge: float = 0.0, lift: float = 0.0) -> ArrayMesh:
	var lay := layer(ground, start, heading, lift)
	var curved := ground.curved_at(start)
	var vertices := PackedVector3Array()
	for r: Array in Telegraphs.strip_rects(length, width, edge):
		var nx := 1 if not curved else maxi(1, ceili((float(r[1]) - float(r[0])) / STEP_M))
		var nz := 1 if not curved else maxi(1, ceili((float(r[3]) - float(r[2])) / STEP_M))
		for i in nx:
			var x0 := lerpf(r[0], r[1], float(i) / nx)
			var x1 := lerpf(r[0], r[1], float(i + 1) / nx)
			for j in nz:
				var z0 := lerpf(r[2], r[3], float(j) / nz)
				var z1 := lerpf(r[2], r[3], float(j + 1) / nz)
				var a: Vector3 = lay.call(Vector3(x0, 0.0, z1))
				var b: Vector3 = lay.call(Vector3(x1, 0.0, z1))
				var c: Vector3 = lay.call(Vector3(x1, 0.0, z0))
				var d: Vector3 = lay.call(Vector3(x0, 0.0, z0))
				vertices.append_array([a, b, c, a, c, d])
	return _mesh(vertices)


## Flat `flat` (triangles on the XZ plane of the frame at `centre` heading
## `heading`: x right, -z ahead; a Telegraphs shape) laid along the surface
## round `centre`, `lift` out along the up: on the level ground the very
## triangles, lifted; on a curved one each triangle cut until no edge is
## longer than STEP_M, every vertex laid off the middle along the surface
## (layer). What bends a breath cone or a sweep with the ground (P-O
## 2026-10-29).
static func laid(ground: Ground, centre: Vector3, heading: Vector3, flat: Mesh, lift: float = 0.0) -> ArrayMesh:
	var source: PackedVector3Array = flat.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var lay := layer(ground, centre, heading, lift)
	var cut := PackedVector3Array()
	if ground.curved_at(centre):
		for i in range(0, source.size() - 2, 3):
			_cut(source[i], source[i + 1], source[i + 2], cut)
	else:
		cut = source
	var placed := {}
	var vertices := PackedVector3Array()
	vertices.resize(cut.size())
	for i in cut.size():
		var p := cut[i]
		if not placed.has(p):
			placed[p] = lay.call(p)
		vertices[i] = placed[p]
	return _mesh(vertices)


## Triangle `a`, `b`, `c` halved across its longest edge until none is
## longer than STEP_M, the pieces appended to `out` (each turned as it was).
static func _cut(a: Vector3, b: Vector3, c: Vector3, out: PackedVector3Array) -> void:
	var stack: Array[PackedVector3Array] = [PackedVector3Array([a, b, c])]
	var limit := STEP_M * STEP_M
	while not stack.is_empty():
		var t: PackedVector3Array = stack.pop_back()
		var ab := t[0].distance_squared_to(t[1])
		var bc := t[1].distance_squared_to(t[2])
		var ca := t[2].distance_squared_to(t[0])
		var longest := maxf(ab, maxf(bc, ca))
		if longest <= limit:
			out.append_array(t)
			continue
		# Rotate so the longest edge is t0-t1, then halve it.
		var p := t
		if bc == longest:
			p = PackedVector3Array([t[1], t[2], t[0]])
		elif ca == longest:
			p = PackedVector3Array([t[2], t[0], t[1]])
		var m := (p[0] + p[1]) * 0.5
		stack.append(PackedVector3Array([p[0], m, p[2]]))
		stack.append(PackedVector3Array([m, p[1], p[2]]))


## How far the surface lies below the frame at `centre` (heading
## `heading`) under the frame's point `step` off its origin (x right, y
## back): 0 on the level ground. What a straight thing laid across the
## curve (a rack's backdrop) sinks so its ends touch the ground.
static func drop(ground: Ground, centre: Vector3, heading: Vector3, step: Vector2) -> float:
	if not ground.curved_at(centre) or step == Vector2.ZERO:
		return 0.0
	var back := SurfaceDraw.frame(ground, centre, heading).affine_inverse()
	# The surface point whose spot in the frame lies under `step`: walked out
	# as far, then the walk stretched by how short of it the spot fell.
	var along := step
	var under := Vector3.ZERO
	for i in 4:
		under = back * ground.offset(centre, heading, along)
		var across := Vector2(under.x, under.z)
		if across.length_squared() < 0.000001:
			break
		along *= step.length() / across.length()
	return -under.y


## The flat point (x, z: the frame's x right, z back) laid on the surface,
## in the frame at `centre`, `lift` out along the up.
static func layer(ground: Ground, centre: Vector3, heading: Vector3, lift: float) -> Callable:
	if not ground.curved_at(centre):
		return func(p: Vector3) -> Vector3: return Vector3(p.x, p.y + lift, p.z)
	var frame := SurfaceDraw.frame(ground, centre, heading)
	var back := frame.affine_inverse()
	var ahead := -frame.basis.z
	return func(p: Vector3) -> Vector3:
		var on := ground.offset(centre, ahead, Vector2(p.x, p.z))
		return back * (on + ground.up_at(on) * lift)


## The radii a band `inner` to `outer` round `centre` is cut at: its two
## edges on the level ground, every STEP_M or less between them on a curved
## one.
static func _radii(ground: Ground, centre: Vector3, inner: float, outer: float) -> PackedFloat64Array:
	var cuts := 1 if not ground.curved_at(centre) else maxi(1, ceili((outer - inner) / STEP_M))
	var out := PackedFloat64Array([inner])
	for k in range(1, cuts):
		out.append(lerpf(inner, outer, float(k) / cuts))
	out.append(outer)
	return out


static func _mesh(vertices: PackedVector3Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
