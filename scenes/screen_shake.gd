## The camera shake (front-end ticket 03): a small, chunky jolt on heavy
## moments, your ground shake landing on enemies (your stagger-tier hit),
## being staggered yourself, and a heavy slam landing within the feel page's
## [shake] near_m of you (slam_near: a boss's, its split pieces', the golem's
## staggering slam). Its strength and length are the [shake] knobs (strength
## 0 removes it); the settings' screen-shake toggle (`enabled`, on by
## default) switches it off.
##
## Chunky: the offset jumps to a new random spot STEP_S apart instead of
## sliding, and shrinks to nothing over the length. Presentation only: its
## randomness is its own, never the simulation's, and main.gd adds the
## offset to the local camera only.
class_name ScreenShake
extends RefCounted

## How long the camera holds each jolt before jumping to the next.
const STEP_S := 1.0 / 30.0

## The settings' screen-shake toggle; off, the camera never moves.
var enabled := true

var _strength := 0.0
var _length := 0.0
var _left := 0.0
var _step_left := 0.0
var _jolt := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## Starts a shake from the feel page's [shake] values ({strength_m,
## length_s}); a stronger one running keeps going.
func kick(shake: Dictionary) -> void:
	var strength := float(shake.get("strength_m", 0.0))
	var length := float(shake.get("length_s", 0.0))
	if strength <= 0.0 or length <= 0.0 or (_left > 0.0 and _strength * _left / _length >= strength):
		return
	_strength = strength
	_length = length
	_left = length
	_step_left = 0.0

## The camera's offset this frame, `delta` seconds after the last; zero when
## off or still.
func offset(delta: float) -> Vector3:
	if not enabled:
		_left = 0.0
	if _left <= 0.0:
		return Vector3.ZERO
	_step_left -= delta
	if _step_left <= 0.0:
		_step_left = STEP_S
		var size := _strength * _left / _length
		_jolt = Vector3(_rng.randf_range(-size, size), _rng.randf_range(-size, size), _rng.randf_range(-size, size))
	_left -= delta
	if _left <= 0.0:
		return Vector3.ZERO
	return _jolt
