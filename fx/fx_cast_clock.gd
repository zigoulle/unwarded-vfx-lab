## A cast's clock in the game (VFX lab ticket 05): the seconds since a cast,
## the time an effect is drawn at (show_at; its shaders' `fx_t`, never the
## engine's TIME). It runs on the game's view clock (GameClock), so an
## effect holds behind the pause menu as the world's shaders do. The lab
## keeps its own clock (0.1x, frame steps back), fed by GameClock too.
## Looks only: the simulation never reads it.
class_name FxCastClock
extends RefCounted

var _start := 0.0


## A cast now: its time starts from 0, or from `already_s` for a cast first
## seen that long after it began (a dash drawn from its third tick).
func cast(already_s: float = 0.0) -> void:
	_start = GameClock.seconds() - already_s


## The game's seconds since the cast (paused time left out).
func time() -> float:
	return GameClock.seconds() - _start
