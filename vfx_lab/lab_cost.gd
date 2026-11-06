## The lab's cost readout (spec story 20, Q10).
## - census: what an effect draws, counted from its visible nodes: its
##   see-through layers (each mesh drawn with a transparent or additive
##   material), its particles (GPU and CPU particles' amounts, and each
##   instance of a MultiMesh) and its triangles; for its budget (FxBudget,
##   ticket 08) the see-through layers covering FxBudget.SCREEN_SHARE of the
##   screen or more from the camera, and its full-screen passes (a shown
##   full-rect Control: a full-screen flash).
## - the GPU meter: the main viewport's measured GPU time (as the perf
##   bench's BenchProbe reads it) averaged over `window` frames with the
##   effect shown, then `window` frames with it hidden; the difference is the
##   effect's share. Node-free: the lab feeds it a sample each drawn frame.
extends RefCounted

## Frames measured each way.
var window := 30

var _on: Array[float] = []
var _off: Array[float] = []
var _measuring := false


## Counts what `root` and the nodes under it draw now, seen from `camera`
## (null: no layer counted over the screen).
static func census(root: Node, camera: Camera3D = null) -> Dictionary:
	var out := {"transparent_layers": 0, "particles": 0, "triangles": 0, "screen_layers": 0, "full_screen": 0}
	_count(root, out, camera)
	return out


## Adds `node` and everything shown under it to the census `out` (see
## census): hidden branches skipped.
static func _count(node: Node, out: Dictionary, camera: Camera3D) -> void:
	if node is Node3D and not (node as Node3D).visible:
		return
	if node is CanvasLayer and not (node as CanvasLayer).visible:
		return
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is Control and _full_rect(node as Control):
		out["full_screen"] += 1
	if node is MultiMeshInstance3D:
		var multimesh := (node as MultiMeshInstance3D).multimesh
		var shown := _instances(multimesh)
		if multimesh != null and shown > 0:
			out["particles"] += shown
			out["triangles"] += _triangles(multimesh.mesh) * shown
			if _see_through(node as GeometryInstance3D, multimesh.mesh):
				out["transparent_layers"] += 1
				out["screen_layers"] += _over_screen(node as VisualInstance3D, camera)
	elif node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			out["triangles"] += _triangles(mesh)
			if _see_through(node as GeometryInstance3D, mesh):
				out["transparent_layers"] += 1
				out["screen_layers"] += _over_screen(node as VisualInstance3D, camera)
	elif node is GPUParticles3D or node is CPUParticles3D:
		if node.emitting:
			out["particles"] += int(node.amount)
			out["transparent_layers"] += 1
	for child in node.get_children():
		_count(child, out, camera)


## A Control stretched over its whole layer (a full-screen pass).
static func _full_rect(control: Control) -> bool:
	return control.anchor_left == 0.0 and control.anchor_top == 0.0 and control.anchor_right == 1.0 			and control.anchor_bottom == 1.0


## 1 when `shown`'s bounds cover FxBudget.SCREEN_SHARE of `camera`'s screen
## or more (or reach behind it: it is around the camera), else 0.
static func _over_screen(shown: VisualInstance3D, camera: Camera3D) -> int:
	if camera == null or not camera.is_inside_tree() or not shown.is_inside_tree():
		return 0
	var box := shown.global_transform * shown.get_aabb()
	var screen := camera.get_viewport().get_visible_rect()
	var rect := Rect2()
	for i in 8:
		var corner := box.get_endpoint(i)
		if camera.is_position_behind(corner):
			return 1
		var at := camera.unproject_position(corner)
		rect = Rect2(at, Vector2.ZERO) if i == 0 else rect.expand(at)
	var covered := rect.intersection(screen).get_area()
	return 1 if covered >= FxBudget.SCREEN_SHARE * screen.get_area() else 0


## How many of `multimesh`'s instances draw (0 with none).
static func _instances(multimesh: MultiMesh) -> int:
	if multimesh == null:
		return 0
	return multimesh.instance_count if multimesh.visible_instance_count < 0 else multimesh.visible_instance_count


## `mesh`'s triangles over all its surfaces (0 with none).
static func _triangles(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var total := 0
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		var count: int = indices.size() if indices != null and indices.size() > 0 else arrays[Mesh.ARRAY_VERTEX].size()
		total += count / 3
	return total


## Whether `instance` draws see-through: its override or a surface of
## `mesh` is transparent (_transparent).
static func _see_through(instance: GeometryInstance3D, mesh: Mesh) -> bool:
	if _transparent(instance.material_override):
		return true
	for i in mesh.get_surface_count():
		if _transparent(mesh.surface_get_material(i)):
			return true
	return false


## Whether `material` blends: alpha or a non-mix blend on a base
## material; a shader that writes ALPHA or blends.
static func _transparent(material: Material) -> bool:
	if material is BaseMaterial3D:
		var base := material as BaseMaterial3D
		return base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
				or base.blend_mode != BaseMaterial3D.BLEND_MODE_MIX
	if material is ShaderMaterial and (material as ShaderMaterial).shader != null:
		var code := (material as ShaderMaterial).shader.code
		return code.contains("ALPHA") or code.contains("blend_add")
	return false


## Starts a measure: `window` frames on, then `window` off.
func start() -> void:
	_on.clear()
	_off.clear()
	_measuring = true


## Whether the effect shows on the next frame measured (always, outside a
## measure).
func effect_on() -> bool:
	return not _measuring or _on.size() < window


## This frame's GPU time (ms), with the effect as effect_on said.
func sample(gpu_ms: float) -> void:
	if not _measuring:
		return
	if _on.size() < window:
		_on.append(gpu_ms)
	else:
		_off.append(gpu_ms)
		if _off.size() >= window:
			_measuring = false


## Whether a measure is under way.
func measuring() -> bool:
	return _measuring


## Whether the last measure is complete.
func done() -> bool:
	return not _measuring and _off.size() >= window


## The last measure: the mean GPU time on and off (ms), and the difference.
func report() -> Dictionary:
	var on := _mean(_on)
	var off := _mean(_off)
	return {"gpu_on_ms": on, "gpu_off_ms": off, "gpu_effect_ms": on - off}


## The mean of `values` (0 with none).
static func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += v
	return total / values.size()
