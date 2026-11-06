## A move's lab effect kicking the game's screen shake (VFX all-spells
## ticket 03: the shake block, FxShake, kicked only the lab's camera
## before). Watches the effect drawn each frame: when its cast's time
## passes the impact (going on, not stepping back), the effect's shake_kick
## is kept until its holder takes it (take) for the local camera's
## ScreenShake (ScreenShake.take_from), which the settings' screen-shake
## toggle switches off. A kick of strength 0 (a preset's shake off) is
## none. One kept at most: an avatar no camera follows never piles them up.
## Forward only, like the shake's own jolts: a replay or a frame step back
## never re-shakes (VFX lab grill Q9). Looks only: the simulation never
## reads it.
class_name FxShakeKicks
extends RefCounted

var _seed := -1
var _last := -INF
var _kept := {}


## `effect` (a recipe's node: impact_time, shake_kick) drawn at `t` seconds
## into the cast with `seed` (below 0: none).
func see(seed: int, t: float, effect: Node) -> void:
	if seed < 0 or not effect.has_method("shake_kick"):
		return
	if seed != _seed:
		_seed = seed
		_last = -INF
	var impact := float(effect.call("impact_time"))
	if _last < impact and t >= impact:
		var kick: Dictionary = effect.call("shake_kick")
		if float(kick.get("strength_m", 0.0)) > 0.0 and float(kick.get("length_s", 0.0)) > 0.0:
			_kept = kick
	_last = t


## The kick kept since the last take ({strength_m, length_s}), or {}.
func take() -> Dictionary:
	var out := _kept
	_kept = {}
	return out
