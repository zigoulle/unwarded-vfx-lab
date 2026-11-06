## The ground shake (GLOSSARY: Recipe; VFX all-spells ticket 02): the
## mage's finisher (light, light, heavy) slamming the floor round him. Its
## default, "ground shake - default", is today's look (ImpactLooks before
## the switch: dust and a thin shockwave at his feet, the floor cracked
## under him, glowing orange as it cools). Built from the blocks, never
## copies of them:
##   - cracks split in the floor under him: the ground marks block
##     (FxGroundMarks as cracks, through the ground seam: they wrap curved
##     ground), their scorch glowing in the edge colour as it cools;
##   - a dust burst: sand-dust puffs thrown out low round his feet (the
##     particles block, flat: the sand look, nothing additive) and the
##     shockwave ring (the burst block) in the core colour, laid on the
##     floor through the ground seam (FxBurst.show_laid);
##   - a kick of the game's screen shake (FxShake), off by default: the
##     game already shakes your camera when your ground shake lands (the
##     feel page's [shake], on the stagger-tier hit), so a preset's shake
##     adds to that.
## Built for max graphics; its Low version (FxLow) halves the dust puffs
## and cracks.
##
## Phases (grill Q7): it plays at the IMPACT, the move's hit marker plus
## the trigger offset. The dust is thrown up over form_s after it; the
## cracks last hold_s, then fade over fade_s. Drawn only from (preset, seed,
## time) and its centre (grill Q8, Q9): any frame in any order, the same on
## every peer and replay. Its preset is re-read every frame it draws.
## Looks only: the simulation never reads it (the stun's real reach is
## [mage.move.ground_shake] reach_m; the preset's sizes are only drawn).
class_name FxGroundShake
extends Node3D

## The recipe its presets are saved under (FxPresets), and its first one.
const RECIPE := "ground_shake"
const DEFAULT_NAME := "ground shake - default"
## Its own knobs the lab shows: knob -> [label, min, max, step]. With the
## core set and the colours, 15 in all (spec story 25); the rest sit under
## the panel's Advanced (ADVANCED_KNOBS).
const KNOBS := {
	"cracks_x": ["Cracks (x reach, 0 off)", 0.0, 1.5, 0.01],
	"cracks": ["Crack count", 0, 16, 1],
	"dust": ["Dust puffs", 0, FxParticles.MAX, 1],
	"dust_x": ["Dust reach (x reach)", 0.05, 2.0, 0.01],
	"burst_x": ["Shockwave (x reach, 0 off)", 0.0, 2.0, 0.01],
	"shake_m": ["Shake (m, 0 off)", 0.0, 0.3, 0.005],
	"crack_tint": ["Crack colour (0 dark, 1 edge colour)", 0.0, 1.0, 0.01],
}
## Its own knobs under Advanced, the same way.
const ADVANCED_KNOBS := {
	"jag": ["Crack jag (x size)", 0.0, 0.6, 0.01],
	"dust_life_s": ["Dust life (s)", 0.1, 3.0, 0.01],
	"dust_size_m": ["Dust puff size (m)", 0.02, 1.5, 0.01],
	"dust_ring_x": ["Dust starts from (x reach)", 0.0, 1.0, 0.01],
	"burst_s": ["Shockwave length (s)", 0.05, 2.0, 0.01],
	"shake_s": ["Shake length (s)", 0.05, 1.0, 0.01],
}
## How hard the dust falls back (m/s2 at size 1), how much its speed and
## life vary.
const DUST_GRAVITY := 2.0
const DUST_SPEED_JITTER := 0.5
const DUST_LIFE_JITTER := 0.4
## The dust's tone: the core colour toward the dark dirt (today's dust and
## dirt pair), this share of the way.
const DIRT := Color(0.42, 0.33, 0.26)
const DIRT_SHARE := 0.3
## The shockwave's opacity at intensity 1 (today's ring: 0.7), and its
## tone: the core colour this share of the way to white.
const BURST_ALPHA := 0.7
const BURST_WHITE := 0.4
## The dust's speed: enough to carry it about dust_m over its life (times
## this, as it slows under its fall), and how wide round straight out from
## his feet it flies (FxParticles' cone).
const DUST_CARRY := 1.2
const DUST_CONE := 0.35
## The most its blocks' opacity grows with intensity.
const MOST_ALPHA := 2.0

## When the move's hit marker falls: seconds after the cast (the clip's
## start), before the preset's trigger offset.
var impact_s := 0.0
## The knobs it is drawn with, read each frame (its default first).
var preset: FxPreset = default_preset()
## The move's hit area its ground footprint is ratios of (FxReach.hit_of:
## {reach_m, arc_deg}), set by its holder from the move's data, the game's
## or the lab's; {} draws at its recipe's FxReach.REFERENCE reach.
var hit := {}

var _sized := FxReach.Sized.new()

var _centre := Vector3.ZERO
var _ground: Ground
var _level_y := 0.0
var _marks := FxGroundMarks.new()
var _dust := FxParticles.new()
var _burst := FxBurst.new()


## Builds its blocks (the cracks, the dust, the shockwave), hidden until a cast.
func _init() -> void:
	name = "GroundShake"
	_dust.name = "Dust"
	_dust.set_flat(true)
	_burst.name = "Shockwave"
	for block: Node in [_marks, _dust, _burst]:
		add_child(block)


## The sensible default from today's look (ImpactLooks and the feel page's
## [impact]: dust 2 m, a 4.5 m shockwave over 0.35 s, cracks 2.5 m fading
## over 1.5 s): saved as DEFAULT_NAME.
static func default_preset() -> FxPreset:
	var out := FxPreset.new()
	out.recipe = RECIPE
	# Today's dust, and its cracks' glow in the same sand (P-O, 2026-11-04).
	out.core_colour = Color(0.78, 0.66, 0.5)
	out.edge_colour = Color(0.78, 0.66, 0.5)
	out.size = 1.0
	out.form_s = 0.1
	out.hold_s = 0.9
	out.fade_s = 0.6
	out.intensity = 1.0
	out.trigger_offset_s = 0.0
	out.knobs = {"cracks_x": 0.57, "cracks": 10, "dust": 48, "dust_x": 0.45, "burst_x": 1.0, "shake_m": 0.0,
		"jag": 0.25, "dust_life_s": 0.9, "dust_size_m": 0.35, "dust_ring_x": 0.09,
		"burst_s": 0.35, "shake_s": 0.3, "crack_tint": 1.0}
	return out


## The preset's own knobs, any it lacks (saved before a knob was added) at
## the default's, its ratios of the reach in metres (FxReach.knobs_of: a
## look drawn for its hit keeps its own).
static func own_knobs(look: FxPreset) -> Dictionary:
	return FxReach.knobs_of(look)


## The cracks under him (FxGroundMarks' knobs, as cracks): none at 0. They
## last hold_s and fade_s (the marks hold most of their life, then fade).
static func crack_knobs(look: FxPreset) -> Dictionary:
	var own := own_knobs(look)
	return {"radius_m": float(own["cracks_m"]) * look.size, "streaks": int(own["cracks"]),
		"life_s": look.hold_s + look.fade_s, "cracks": 1, "jag": float(own["jag"]),
		"crack_tint": float(own["crack_tint"])}


## The dust (FxParticles' knobs): born on a ring round his feet over
## form_s, thrown up and out from it to about dust_m, settling back.
static func dust_knobs(look: FxPreset, up: Vector3) -> Dictionary:
	var own := own_knobs(look)
	var life := maxf(float(own["dust_life_s"]), 0.01)
	var out := FxParticles.default_knobs()
	out["count"] = int(own["dust"])
	out["spawn_s"] = maxf(look.form_s, 0.0)
	# Out to about dust_m over its life, slowing under its fall.
	out["speed_m_s"] = float(own["dust_m"]) * look.size / life * DUST_CARRY
	out["speed_jitter"] = DUST_SPEED_JITTER
	out["life_s"] = life
	out["life_jitter"] = DUST_LIFE_JITTER
	out["cone"] = DUST_CONE
	out["gravity_m_s2"] = DUST_GRAVITY * look.size
	out["size_m"] = float(own["dust_size_m"]) * look.size
	# Up and out from the ring round him (FxParticles' ring_m).
	out["dir"] = up
	out["up"] = up
	out["ring_m"] = maxf(float(own["dust_ring_m"]) * look.size, 0.001)
	return out


## The shockwave (FxBurst's knobs): none at 0.
static func burst_knobs(look: FxPreset) -> Dictionary:
	var own := own_knobs(look)
	return {"radius_m": float(own["burst_m"]) * look.size, "length_s": float(own["burst_s"])}


## The dust's colour: the core colour toward the dark dirt, opaque (flat).
static func dust_colour(look: FxPreset) -> Color:
	return Color(look.core_colour.lerp(DIRT, DIRT_SHARE), 1.0)


## Its centre (world): the caster's feet.
func set_centre(centre: Vector3) -> void:
	_centre = centre


## The ground its cracks are laid on (null: none), its level floor at
## `level_y` (where it is level, they drop straight down to it).
func set_ground(ground: Ground, level_y: float) -> void:
	_ground = ground
	_level_y = level_y


## Draws the frame `t` seconds after a cast with `seed`, with the preset's
## knobs as they are now: nothing before its impact.
func show_at(seed: int, t: float) -> void:
	var look := drawn_preset()
	var age := t - impact_time()
	var up := _up()
	var alpha := clampf(look.drawn_intensity(), 0.0, MOST_ALPHA)
	_marks.show_at(crack_knobs(look), seed, age, _ground, _centre, _level_y, Color(look.edge_colour, alpha))
	if age < 0.0:
		_dust.visible = false
	else:
		_dust.show_at(dust_knobs(look, up), seed, age, _centre, dust_colour(look))
	var ring := look.core_colour.lerp(Color.WHITE, BURST_WHITE)
	# Laid on the floor round him (a camera-facing disc sank half into it).
	_burst.show_laid(burst_knobs(look), age, _ground, _centre, _level_y, up, Color(ring, BURST_ALPHA * alpha))


## The ground's up under its centre (level with no ground).
func _up() -> Vector3:
	return _ground.up_at(_centre) if _ground != null else Vector3.UP


## What its impact kicks the holder's ScreenShake with (FxShake): strength
## 0, off, by default.
func shake_kick() -> Dictionary:
	var own := own_knobs(drawn_preset())
	return FxShake.kick_of({"strength_m": float(own["shake_m"]), "length_s": float(own["shake_s"])})


## When it plays (s after the cast): the hit plus the trigger offset.
func impact_time() -> float:
	return drawn_preset().impact_at(impact_s)


## When the whole effect is over (s after the cast): the cracks faded, the
## dust settled and the shockwave played out.
func end_time() -> float:
	var look := drawn_preset()
	var own := own_knobs(look)
	var dust := maxf(look.form_s, 0.0) + float(own["dust_life_s"])
	return impact_time() + maxf(maxf(look.hold_s + look.fade_s, dust), float(own["burst_s"]))


## Whether any of it shows now.
func shown() -> bool:
	return _marks.visible or _dust.visible or _burst.visible


## Where it lands: round his feet, its centre.
func impact_point() -> Vector3:
	return _centre


## How far round its impact point it reaches (m): the shockwave's radius
## (the lab's dummies flinch inside it).
func impact_reach() -> float:
	var look := drawn_preset()
	return float(own_knobs(look)["burst_m"]) * look.size


## The cracks in the floor.
func marks() -> FxGroundMarks:
	return _marks


## The dust puffs.
func dust() -> FxParticles:
	return _dust


## The shockwave.
func burst() -> FxBurst:
	return _burst


## The preset as drawn: its ratios times the hit's reach (FxReach.drawn).
func drawn_preset() -> FxPreset:
	return _sized.of(preset, hit)
