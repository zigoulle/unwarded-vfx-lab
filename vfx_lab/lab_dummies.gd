## The lab's dummies (ticket 03, grill Q15): game enemies posed in their
## idle, no AI, picked from the enemy roster (Enemies.TYPES: those with a
## look of their own, the baked EnemyModels and the procedural blobs). Each
## stands on a ring of its hurt area, the simulation's from its tuning row
## (CombatSim._hit_point: a blob's drawn body, Blob.hurt_radius_m; the
## others are hit at their feet, a point, marked by a small dot ring), so
## an effect's drawn reach can be held against the hit. With the flinch on,
## an impact landing near one makes it flinch: its hit clip and a lean away,
## looks only (it never moves). Nothing here runs the simulation.
extends Node3D

## How far past its hurt ring an impact still flinches a dummy (m, on the
## ground).
const FLINCH_NEAR_M := 1.5
## How long a flinch lasts: the game's hit reaction (s).
const FLINCH_S := EnemyClips.REACT_S
## The flinch's lean away from the impact at its deepest (degrees) and how
## long it takes to come back (s).
const LEAN_DEG := 10.0
const LEAN_S := 0.35
## A blob's flinch: how much it squashes at the hit.
const BLOB_FLINCH_SQUASH := 0.25
## A point's mark: the small ring under an enemy hit at its feet (m).
const POINT_MARK_M := 0.18
## Pick reach round a dummy as a share of its size, when its ring is smaller.
const PICK_SHARE := 0.35
const RING_WIDTH_M := 0.06
const RING_COLOR := Color(1.0, 0.85, 0.2, 0.85)
const POINT_COLOR := Color(1.0, 0.45, 0.2, 0.85)
## A ring floats this far over the ground so it draws over the floor.
const RING_LIFT_M := 0.03

## Impacts flinch the dummies near them (K in the lab).
var flinch_on := true

var _tuning: Dictionary
## Per dummy: {type, row, root (Node3D on the ground), model, ring, size,
## hurt, flinch_s (-1: none), away (Vector3, flat), clock, pose}.
var _dummies: Array[Dictionary] = []


## The dummies of `tuning`'s roster (their enemy rows and the look's sizes); none placed yet.
func _init(tuning: Dictionary) -> void:
	name = "Dummies"
	_tuning = tuning
	var look: Dictionary = tuning.get("look", {})
	for type: String in EnemyModel.SCENES:
		EnemyModel.set_type_look(type, float(look.get("enemy_outline", 0.5)), float(look.get("enemy_lift", 0.1)),
			float(look.get("outline_width_px", 2.0)))


## The enemy types a dummy can be, in the roster's order.
static func kinds() -> Array:
	var out := []
	for type: String in Enemies.TYPES:
		if EnemyModel.SCENES.has(type) or Enemies.behaviour_of(type) == Enemies.BLOB:
			out.append(type)
	return out


## The hurt area round an enemy of `type` with `row` (m): your hits reach it
## anywhere within this of its middle; 0, at its feet only.
static func hurt_radius_m(type: String, row: Dictionary) -> float:
	if BeeSwarm.is_swarm(type):
		return float(row["cluster_radius_m"])
	if Enemies.behaviour_of(type) == Enemies.BLOB:
		return Blob.hurt_radius_m(row)
	return 0.0


## A dummy of `type` standing at `at`; its index.
func add(type: String, at: Vector3) -> int:
	var row := Enemies.row_of(_tuning, type)
	var root := Node3D.new()
	root.name = "Dummy%d" % _dummies.size()
	add_child(root)
	var size := float(row.get("model_size_m", 2.0))
	var model: Node3D
	if EnemyModel.SCENES.has(type):
		var enemy := EnemyModel.new(type)
		enemy.set_size(size)
		enemy.position.y = float(row.get("fly_height_m", row.get("float_height_m", 0.0)))
		model = enemy
	else:
		var blob := BlobModel.new()
		var look: Dictionary = _tuning.get("look", {})
		blob.set_outline(float(look.get("enemy_outline", 0.5)), float(look.get("outline_width_px", 2.0)))
		blob.show_shape(size, 1.0, 0.0)
		model = blob
	root.add_child(model)
	RingArenaView.light_as_character(model)
	var hurt := hurt_radius_m(type, row)
	var ring := _ring(hurt if hurt > 0.0 else POINT_MARK_M, RING_COLOR if hurt > 0.0 else POINT_COLOR)
	root.add_child(ring)
	root.position = at
	_dummies.append({"type": type, "row": row, "root": root, "model": model, "ring": ring, "size": size,
		"hurt": hurt, "flinch_s": -1.0, "away": Vector3.ZERO, "clock": 0.0, "pose": {"clip": "idle"}})
	_show(_dummies.size() - 1, 0.0)
	return _dummies.size() - 1


## How many dummies stand.
func count() -> int:
	return _dummies.size()


## Dummy `i`'s enemy type.
func type_of(i: int) -> String:
	return _dummies[i]["type"]


## Where dummy `i` stands (its feet).
func position_of(i: int) -> Vector3:
	return (_dummies[i]["root"] as Node3D).position


## Its drawn size (its row's model_size_m).
func size_of(i: int) -> float:
	return _dummies[i]["size"]


## Its hurt area's radius (m): its ring's.
func hurt_radius_of(i: int) -> float:
	return _dummies[i]["hurt"]


## The ring showing its hurt area.
func ring_of(i: int) -> Node3D:
	return _dummies[i]["ring"]


## The pose it was last shown in: {clip} ("idle", or "hit" while it flinches).
func pose_of(i: int) -> Dictionary:
	return _dummies[i]["pose"]


## Whether it is flinching now (looks only).
func flinching(i: int) -> bool:
	return float(_dummies[i]["flinch_s"]) >= 0.0


## Moves dummy `i`'s feet to `at` (a drag).
func move_to(i: int, at: Vector3) -> void:
	(_dummies[i]["root"] as Node3D).position = at


## Dummy `i` killed (`dead`: hidden, its ring too) or standing again (the
## Fire bomb's victim; looks only).
func set_dead(i: int, dead: bool) -> void:
	(_dummies[i]["root"] as Node3D).visible = not dead


## Whether dummy `i` is dead (hidden).
func dead(i: int) -> bool:
	return not (_dummies[i]["root"] as Node3D).visible


## Takes dummy `i` away.
func remove(i: int) -> void:
	var root: Node3D = _dummies[i]["root"]
	remove_child(root)
	root.free()
	_dummies.remove_at(i)


## The dummy whose ring (or, smaller than it, PICK_SHARE of its size) holds
## the ground point `at`, the nearest; -1 none.
func pick(at: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in _dummies.size():
		var d := _flat(at - position_of(i)).length()
		var reach := maxf(float(_dummies[i]["hurt"]), float(_dummies[i]["size"]) * PICK_SHARE)
		if d <= reach and d < best_d:
			best = i
			best_d = d
	return best


## An impact landed at `at`, reaching `reach` m round it (a ring's radius;
## 0 a point): with the flinch on, each dummy within FLINCH_NEAR_M of its
## hurt ring (on the ground) past that reach flinches away from it.
func impact(at: Vector3, reach: float = 0.0) -> void:
	if not flinch_on:
		return
	for d: Dictionary in _dummies:
		var off := _flat((d["root"] as Node3D).position - at)
		if off.length() <= reach + float(d["hurt"]) + FLINCH_NEAR_M:
			d["flinch_s"] = 0.0
			d["away"] = off.normalized() if off.length() > 0.001 else Vector3.BACK


## On by `delta` seconds: the idles play, the flinches run out.
func advance(delta: float) -> void:
	for i in _dummies.size():
		_show(i, delta)


## Dummy `i` `delta` s on: its idle (a blob's creep), or its flinch
## while one plays, leaning away from the impact.
func _show(i: int, delta: float) -> void:
	var d := _dummies[i]
	d["clock"] = float(d["clock"]) + delta
	var flinch := float(d["flinch_s"])
	if flinch >= 0.0:
		flinch += delta
		if flinch >= FLINCH_S:
			flinch = -1.0
		d["flinch_s"] = flinch
	d["pose"] = {"clip": "hit" if flinch >= 0.0 else "idle"}
	var model: Node3D = d["model"]
	var type: String = d["type"]
	if model is EnemyModel:
		var enemy := model as EnemyModel
		var state := {"phase": CombatSim.ENEMY_CHASE, "timer": 0, "attack": "", "reacting_s": flinch,
			"dead_s": -1.0}
		if type == "bat":
			enemy.show_wings(EnemyClips.wings(state, d["row"]), delta)
		else:
			enemy.show_pose(EnemyClips.pose(type, state, d["row"]), delta)
	else:
		var squash := 1.0 + BlobLooks.CREEP_SQUASH * sin(TAU * float(d["clock"]) / BlobLooks.CREEP_S)
		if flinch >= 0.0:
			squash *= 1.0 - BLOB_FLINCH_SQUASH * _lean(flinch)
		(model as BlobModel).show_shape(float(d["size"]), squash, 0.0)
	# The lean away from the impact: about the flat axis across it.
	var away: Vector3 = d["away"]
	model.basis = Basis.IDENTITY
	if flinch >= 0.0 and away != Vector3.ZERO:
		model.basis = Basis(Vector3.UP.cross(away).normalized(), deg_to_rad(LEAN_DEG) * _lean(flinch))


## The lean's share at `flinch_s` into a flinch: snaps out, eases back.
static func _lean(flinch_s: float) -> float:
	return clampf(1.0 - flinch_s / LEAN_S, 0.0, 1.0)


## `v` on the level plane (its height dropped).
static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## A flat ring `radius` m round the feet, drawn over the floor.
static func _ring(radius: float, color: Color) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(radius - RING_WIDTH_M * 0.5, 0.01)
	torus.outer_radius = radius + RING_WIDTH_M * 0.5
	torus.rings = 48
	torus.ring_segments = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.no_depth_test = true
	torus.material = material
	var ring := MeshInstance3D.new()
	ring.name = "HurtRing"
	ring.mesh = torus
	ring.scale = Vector3(1.0, 0.2, 1.0)
	ring.position.y = RING_LIFT_M
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ring
