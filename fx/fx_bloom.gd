## The optional bloom knob (VFX lab ticket 08; grill Q11, spec story 35):
## a preset's `bloom` turns on the scene's own glow (the Environment's) from
## its first level only, the half-resolution one (the blurrier levels cost
## more), at the knob times the effect's drawn intensity (it follows the
## effect intensity knob). Off by default (0); turned off, the scene's own
## glow is put back as it was. Low versions have none (FxLow). Looks only.
class_name FxBloom
extends RefCounted

## The glow levels an Environment has.
const LEVELS := 7
const _OWN_META := &"fx_bloom_own"


## Sets `environment`'s glow for a preset's `bloom` (0: off) at `intensity`.
static func apply(environment: Environment, bloom: float, intensity: float) -> void:
	if environment == null:
		return
	if bloom <= 0.0 or intensity <= 0.0:
		_restore(environment)
		return
	if not environment.has_meta(_OWN_META):
		var levels: Array[float] = []
		for level in LEVELS:
			levels.append(environment.get_glow_level(level))
		environment.set_meta(_OWN_META, {"enabled": environment.glow_enabled,
			"intensity": environment.glow_intensity, "levels": levels})
	environment.glow_enabled = true
	environment.glow_intensity = bloom * intensity
	for level in LEVELS:
		environment.set_glow_level(level, 1.0 if level == 0 else 0.0)


## The scene's own glow back (nothing when the bloom never changed it).
static func _restore(environment: Environment) -> void:
	if not environment.has_meta(_OWN_META):
		return
	var own: Dictionary = environment.get_meta(_OWN_META)
	environment.glow_enabled = own["enabled"]
	environment.glow_intensity = own["intensity"]
	var levels: Array = own["levels"]
	for level in LEVELS:
		environment.set_glow_level(level, levels[level])
	environment.remove_meta(_OWN_META)
