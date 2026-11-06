## A preset (GLOSSARY): a named, saved set of a recipe's knobs, one resource
## file per recipe and name under res://fx/presets/<recipe>/<name>.tres
## (FxPresets; spec Q5). The shared core knobs every spell has come first;
## each block's own knobs sit in `knobs`. Looks only: the simulation never
## reads a preset.
##
## Re-read every frame (no change callbacks): an effect reads its preset's
## knobs each time it draws, so a slider moved in the VFX lab shows at once,
## even while paused.
class_name FxPreset
extends Resource

## The shared core knobs as the lab's sliders show them: knob -> [label, min,
## max]. The colours are pickers, not sliders (COLOUR_KNOBS).
const CORE_KNOBS := {
	"size": ["Size", 0.1, 4.0],
	"form_s": ["Form (s)", 0.0, 2.0],
	"hold_s": ["Hold (s)", 0.0, 3.0],
	"fade_s": ["Fade (s)", 0.0, 3.0],
	"intensity": ["Intensity", 0.0, 2.0],
	"trigger_offset_s": ["Trigger offset (s)", -0.5, 0.5],
}
## The shared knobs the lab keeps under Advanced, the same way.
const ADVANCED_CORE_KNOBS := {"bloom": ["Bloom (0 off)", 0.0, 2.0]}
const COLOUR_KNOBS := {"core_colour": "Core colour", "edge_colour": "Edge colour"}

## The recipe this preset sets (its folder under the presets).
@export var recipe := ""
## The effect's two colours: its core and its edge (a bolt's white core and
## blue halo; a tornado's light and dark sand).
@export var core_colour := Color(1.0, 1.0, 1.0)
@export var edge_colour := Color(0.5, 0.7, 1.0)
## How big the effect is drawn: 1 is the recipe's own size.
@export var size := 1.0
## Its phases (s): forming, holding, fading.
@export var form_s := 0.0
@export var hold_s := 0.0
@export var fade_s := 0.6
## How bright it is (glow and flash), before the player's effect intensity.
@export var intensity := 1.0
## When its impact plays against the move's hit marker (s; negative: before).
@export var trigger_offset_s := 0.0
## The optional bloom (grill Q11, ticket 08): the scene's own glow at half
## resolution while the effect plays (FxBloom), 0 (the default) off.
@export var bloom := 0.0
## Each block's own knobs (knob -> value), by the recipe.
@export var knobs := {}
## P-O's adjustments to its Low version (FxLow; knob -> value, a core knob
## by its name too): what the rule made from the max graphics knobs is
## overridden by these. Empty: the rule alone.
@export var low := {}


## The family its glow and flash follow on the player's effect intensity
## knob (EffectIntensity; ticket 08, grill Q12).
const INTENSITY_FAMILY := "fx.presets"


## How bright its glow and flash draw: its own intensity times the
## player's effect intensity knob at `at` (0 to 1; below 0: the level now).
func drawn_intensity(at: float = -1.0) -> float:
	return intensity * EffectIntensity.factor(INTENSITY_FAMILY, "brightness", at)


## Whether `knob` is one of the shared knobs (a preset's own property, not
## one of its `knobs`).
static func is_core(knob: String) -> bool:
	return CORE_KNOBS.has(knob) or ADVANCED_CORE_KNOBS.has(knob) or COLOUR_KNOBS.has(knob)


## How long the effect plays after its impact (s): form, hold and fade.
func life_s() -> float:
	return form_s + hold_s + fade_s


## When its impact plays for a hit marker `hit_s` seconds after the cast:
## the hit plus the trigger offset.
func impact_at(hit_s: float) -> float:
	return hit_s + trigger_offset_s


## Its phase `t` seconds after the cast for a hit at `hit_s` (grill Q7):
## {name ("before", "form", "hold", "fade", "over"), reach (how far it has
## formed, 0..1), fade (1 full, 0 gone)}. Formed at the impact, held for
## hold_s, faded over fade_s.
func phase(hit_s: float, t: float) -> Dictionary:
	var impact := impact_at(hit_s)
	var hold_end := impact + hold_s
	var fade_end := hold_end + fade_s
	if t < impact - form_s:
		return {"name": "before", "reach": 0.0, "fade": 0.0}
	if t < impact:
		return {"name": "form", "reach": 1.0 - (impact - t) / form_s, "fade": 1.0}
	if t <= hold_end:
		return {"name": "hold", "reach": 1.0, "fade": 1.0}
	if t < fade_end:
		return {"name": "fade", "reach": 1.0, "fade": 1.0 - (t - hold_end) / fade_s}
	return {"name": "over", "reach": 1.0, "fade": 0.0}
