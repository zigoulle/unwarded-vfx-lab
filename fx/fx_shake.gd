## The camera shake block (GLOSSARY: Block; VFX lab ticket 05, grill Q13):
## an impact kicks the game's own screen shake (ScreenShake: chunky jolts
## shrinking over its length, off with the settings' screen-shake toggle),
## never a shake of its own. Off by default in a preset (strength 0). The
## shake's jolts are random (its own, never the simulation's), so it plays
## forward only: a frame step back or a replay doesn't re-shake (grill Q9).
## Node-free, pure static. Looks only: the simulation never reads it.
class_name FxShake
extends RefCounted


## Off (strength 0).
static func default_knobs() -> Dictionary:
	return {"strength_m": 0.0, "length_s": 0.25}


## What an impact kicks ScreenShake.kick with, from knobs {strength_m (0:
## off), length_s}: {strength_m, length_s}, the feel page's [shake] knobs.
static func kick_of(knobs: Dictionary) -> Dictionary:
	return {"strength_m": maxf(float(knobs["strength_m"]), 0.0), "length_s": maxf(float(knobs["length_s"]), 0.0)}
