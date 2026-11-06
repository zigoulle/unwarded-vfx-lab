## Budgets (VFX lab ticket 08; grill Q10, spec story 21): what one effect
## may draw at once, so a tuned preset can't kill the frame rate on Iris Xe.
## Every preset is checked against its graphics level's budget (its max
## graphics knobs against HIGH, its Low version against LOW); the lab's
## cost readout warns when it goes over. Counted by the lab's census
## (its cost readout):
## - screen_layers: see-through layers each covering at least SCREEN_SHARE
##   of the screen (they overlap there: the overdraw that costs);
## - particles: particles and instanced pieces;
## - full_screen: full-screen passes (a full-screen flash): none allowed.
## Node-free, pure static.
class_name FxBudget
extends RefCounted

## The share of the screen a see-through layer covers to count as one of
## the overlapping layers over the screen.
const SCREEN_SHARE := 0.5
## The caps at max graphics and at Low (particles: one particles block's own
## cap, FxParticles.MAX, for a whole effect; half at Low).
const HIGH := {"screen_layers": 3, "particles": 128, "full_screen": 0}
const LOW := {"screen_layers": 2, "particles": 64, "full_screen": 0}


## The caps at Low (`low`) or max graphics.
static func of(low: bool) -> Dictionary:
	return LOW if low else HIGH


## What `census` passes of the budget (Low's when `low`): one line each,
## none within it.
static func over(census: Dictionary, low: bool) -> Array[String]:
	var cap := of(low)
	var out: Array[String] = []
	var layers := int(census.get("screen_layers", 0))
	if layers > int(cap["screen_layers"]):
		out.append("%d see-through layers over the screen (budget %d)" % [layers, cap["screen_layers"]])
	var particles := int(census.get("particles", 0))
	if particles > int(cap["particles"]):
		out.append("%d particles (budget %d)" % [particles, cap["particles"]])
	var full := int(census.get("full_screen", 0))
	if full > int(cap["full_screen"]):
		out.append("%d full-screen pass%s (budget none)" % [full, "" if full == 1 else "es"])
	return out
