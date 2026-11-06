## A surface of revolution round +Y from a profile of (radius, height)
## points, bottom to top: the hourglass's bulbs (HourglassLook) and the
## tornado's bands (TornadoLook). UV.x runs once round (0 to 1), UV.y up the
## profile (0 at its first point, 1 at its last); normals point outward.
## Looks only.
class_name LatheMesh
extends RefCounted


static func build(profile: PackedVector2Array, segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var rows := profile.size()
	for j in rows:
		# The profile's slope here, for the normal (outward and up or down).
		var a: Vector2 = profile[maxi(j - 1, 0)]
		var b: Vector2 = profile[mini(j + 1, rows - 1)]
		var along := (b - a).normalized()
		var out := Vector2(along.y, -along.x)
		for i in segments + 1:
			var turn := TAU * i / segments
			var round_dir := Vector3(sin(turn), 0.0, cos(turn))
			vertices.append(round_dir * profile[j].x + Vector3.UP * profile[j].y)
			normals.append((round_dir * out.x + Vector3.UP * out.y).normalized())
			uvs.append(Vector2(float(i) / segments, float(j) / maxf(1.0, rows - 1)))
	for j in rows - 1:
		for i in segments:
			var k := j * (segments + 1) + i
			var up := k + segments + 1
			indices.append_array([k, up, k + 1, k + 1, up, up + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
