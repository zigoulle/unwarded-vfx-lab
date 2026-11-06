## Low versions (VFX lab ticket 08; grill Q10; P-O: "max graphics first,
## then tuned down for Low"): every preset is made for max graphics, and its
## Low version is made from it by one rule that knows no recipe, so a
## recipe added later gets one too:
## - a whole-number knob (a count: strands, sparks, streaks...) is halved,
##   rounded up, never below 1 (0 stays 0);
## - a knob naming a glow pass or halo ("glow", "halo" in its name) is 0:
##   no extra glow pass (FxGlow hides at 0);
## - a knob naming a full-screen pass ("full_screen") is 0;
## - no bloom;
## - the core knobs (colours, size, timing, intensity) are kept.
## Then P-O's adjustments (the preset's `low`, edited in the lab) override
## the rule's. The game draws the Low version at Low graphics (for_graphics).
## Node-free, pure static.
class_name FxLow
extends RefCounted

## Knob names that are a glow pass or a full-screen pass (off at Low).
const GLOW_WORDS: Array[String] = ["glow", "halo"]
const FULL_SCREEN_WORD := "full_screen"

## The graphics preset the game draws at now (GraphicsSettings' HIGH,
## MEDIUM, LOW, CUSTOM): main.gd sets it as it applies the graphics; a move
## playing a preset draws for_graphics(preset, game_graphics).
static var game_graphics := GraphicsSettings.HIGH


## `preset`'s Low version: a new preset (the max graphics one untouched).
static func low_version(preset: FxPreset) -> FxPreset:
	var out := preset.duplicate(true) as FxPreset
	out.knobs = derived(preset.knobs)
	out.bloom = 0.0
	for knob: String in preset.low:
		if out.knobs.has(knob) or not FxPreset.is_core(knob):
			out.knobs[knob] = preset.low[knob]
		else:
			out.set(knob, preset.low[knob])
	return out


## The rule's Low knobs made from the max graphics `knobs`.
static func derived(knobs: Dictionary) -> Dictionary:
	var out := knobs.duplicate(true)
	for knob: String in knobs:
		var value: Variant = knobs[knob]
		if knob.contains(FULL_SCREEN_WORD):
			out[knob] = 0 if typeof(value) == TYPE_INT else 0.0
		elif GLOW_WORDS.any(func(word: String) -> bool: return knob.contains(word)):
			out[knob] = 0 if typeof(value) == TYPE_INT else 0.0
		elif typeof(value) == TYPE_INT and int(value) > 1:
			out[knob] = ceili(int(value) / 2.0)
	return out


## The preset the game draws at graphics preset `graphics` (GraphicsSettings'
## HIGH, MEDIUM, LOW, CUSTOM): the Low version at LOW, else the preset.
static func for_graphics(preset: FxPreset, graphics: String) -> FxPreset:
	if preset == null or graphics != GraphicsSettings.LOW:
		return preset
	return low_version(preset)
