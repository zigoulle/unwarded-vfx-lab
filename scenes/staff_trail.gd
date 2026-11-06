## The sand slash trail behind the staff during a swing (ticket 17, mage
## polish; playtest ruling 7). Godot has no TrailRenderer (Unity's); this is
## the trail: the head's recent positions, each with the point `width` metres
## down the shaft, drawn as a ribbon that fades from opaque (newest) to clear
## (fade_s old), and the sand grains it sheds from the head: a fixed pool of
## `grain_count`, one more every GRAIN_STEP_M the head travels (the oldest
## reused when the pool is full), each falling and fading over grain_life_s.
## It is drawn along the staff only, never from the sim's hit shape.
## Node-free; MageModel feeds it from the staff-tip socket and draws strip()
## and grains(). Ages only run while the swing runs: hitstop freezes the
## trail, grains included, with the pose. Presentation only: nothing here
## feeds the simulation.
class_name StaffTrail
extends RefCounted

## How long a sample takes to fade out (s; [trail] fade_s, feel page).
var fade_s := 0.12
## How many grains can be in the air at once (the pool; [trail] grain_count).
var grain_count := 0
## How long a grain falls before it is gone (s; [trail] grain_life_s).
var grain_life_s := 0.4
## The up where the mage stands: grains fall along its negative and drift
## across the head's way about it (world up on the level ground; on the
## lava ball MageModel sets the up at his feet).
var up := Vector3.UP

# Newest last: {"tip": Vector3, "base": Vector3, "age": float, "u": float}.
var _samples: Array[Dictionary] = []
# The pool, in shedding order: {"position", "velocity": Vector3, "age": float}.
var _grains: Array[Dictionary] = []
# Head path travelled since the last grain (m), and the path's total length.
var _since_grain := 0.0
var _path_m := 0.0
var _shed := 0


## Closer than this (m) to the last sample's head is no new sample.
const MIN_STEP_M := 0.002
## A grain is shed every this far (m) the head travels.
const GRAIN_STEP_M := 0.12
## How a grain moves: it leaves the head drifting down and a little to the
## side (m/s, the side varies grain to grain), and falls (m/s/s).
const GRAIN_DROP_M_PER_S := 0.4
const GRAIN_SPREAD_M_PER_S := 0.35
const GRAIN_GRAVITY := 4.0


## A new sample: the staff head and the ribbon's inner edge, world space.
## A head that has not moved (a pose held in hitstop) adds nothing. A moving
## head sheds grains along the way it went.
func add(tip: Vector3, base: Vector3) -> void:
	if not _samples.is_empty() and _samples[-1]["tip"].distance_to(tip) < MIN_STEP_M:
		return
	if not _samples.is_empty():
		var from: Vector3 = _samples[-1]["tip"]
		var step := from.distance_to(tip)
		_path_m += step
		_shed_along(from, tip, step)
	_samples.append({"tip": tip, "base": base, "age": 0.0, "u": _path_m})


## Ages every sample and grain by `delta` seconds (0 while frozen), lets the
## grains fall, and forgets the faded.
func advance(delta: float) -> void:
	for sample in _samples:
		sample["age"] += delta
	while not _samples.is_empty() and _samples[0]["age"] > fade_s:
		_samples.pop_front()
	if delta <= 0.0:
		return
	for grain in _grains:
		grain["age"] += delta
		grain["velocity"] += -up * GRAIN_GRAVITY * delta
		grain["position"] += grain["velocity"] * delta
	while not _grains.is_empty() and _grains[0]["age"] > grain_life_s:
		_grains.pop_front()


func size() -> int:
	return _samples.size()


func clear() -> void:
	_samples.clear()
	_grains.clear()
	_since_grain = 0.0


## The live grains, oldest first: "position" (world space) and "alpha" (1
## just shed, 0 at the end of its life).
func grains() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for grain in _grains:
		out.append({"position": grain["position"], "alpha": clampf(1.0 - grain["age"] / grain_life_s, 0.0, 1.0)})
	return out


## The ribbon as a triangle strip, newest first: "points" alternates head and
## inner edge per row, "alphas" each point's opacity (1 newest, 0 faded), "us"
## each point's distance along the head's path (m; the same for the head and
## its inner edge, fixed once drawn, so a texture sticks to the ribbon).
## `subdivisions` extra rows between samples, on a Catmull-Rom curve through
## them (0: straight segments, the low quality). Fewer than 2 samples: empty.
func strip(subdivisions: int) -> Dictionary:
	var points := PackedVector3Array()
	var alphas := PackedFloat32Array()
	var us := PackedFloat32Array()
	var n := _samples.size()
	if n < 2:
		return {"points": points, "alphas": alphas, "us": us}
	for i in range(n - 1, -1, -1):
		_row(points, alphas, us, _samples[i]["tip"], _samples[i]["base"], _samples[i]["age"], _samples[i]["u"])
		if i == 0:
			break
		for s in subdivisions:
			var t := float(s + 1) / float(subdivisions + 1)
			# From sample i back to i - 1; the neighbours either side shape the curve.
			var p0 := _samples[mini(i + 1, n - 1)]
			var p1 := _samples[i]
			var p2 := _samples[i - 1]
			var p3 := _samples[maxi(i - 2, 0)]
			_row(points, alphas, us, _catmull(p0["tip"], p1["tip"], p2["tip"], p3["tip"], t),
				_catmull(p0["base"], p1["base"], p2["base"], p3["base"], t), lerpf(p1["age"], p2["age"], t),
				lerpf(p1["u"], p2["u"], t))
	return {"points": points, "alphas": alphas, "us": us}


## Sheds a grain every GRAIN_STEP_M of the head's way from `from` to `to`
## (`step` m), on that way; the pool's oldest makes room when it is full.
func _shed_along(from: Vector3, to: Vector3, step: float) -> void:
	if grain_count <= 0:
		return
	var along := GRAIN_STEP_M - _since_grain
	while along <= step:
		var at := from.lerp(to, along / step)
		# The side drift varies grain to grain, the same way every run.
		var side := sin(float(_shed) * 12.9898) * 43758.5453
		side = (side - floorf(side)) * 2.0 - 1.0
		var across := (to - from).cross(up).normalized() * side * GRAIN_SPREAD_M_PER_S
		if _grains.size() >= grain_count:
			_grains.pop_front()
		_grains.append({"position": at, "velocity": -up * GRAIN_DROP_M_PER_S + across, "age": 0.0})
		_shed += 1
		along += GRAIN_STEP_M
	_since_grain = step - (along - GRAIN_STEP_M)


func _row(points: PackedVector3Array, alphas: PackedFloat32Array, us: PackedFloat32Array, tip: Vector3,
		base: Vector3, age: float, u: float) -> void:
	var alpha := clampf(1.0 - age / fade_s, 0.0, 1.0)
	points.append(tip)
	points.append(base)
	alphas.append(alpha)
	alphas.append(alpha)
	us.append(u)
	us.append(u)


static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	return p1.cubic_interpolate(p2, p0, p3, t)
