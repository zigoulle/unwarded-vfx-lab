## The whirlwind (GLOSSARY: Recipe; VFX all-spells ticket 03): the mage's
## two spins (heavy, heavy: whirlwind, then whirlwind_2 turning back) as one
## family, its first preset "whirlwind - default" made from today's look:
## the staff's sand trail swept round him as he spins (MageModel's trail on
## a heavy swing: a 0.75 m band down the staff from its tip, sand gold,
## fading over the feel page's heavy_fade_s), the grains it sheds, and the
## dust and thin shockwave ImpactLooks throws up at his feet when an
## all-round swing hits. Built from the blocks, never copies of them:
##   - the swirl: the ribbon block (FxRibbon) in its cel look, bent into a
##     ring round him at the staff tip's height, swept round from the hit
##     the way that spin turns (MageClips' spin: the first one way, the
##     second back);
##   - sand grains shed round the swirl as it sweeps, carried round with it
##     (the particles block, flat);
##   - a dust burst: sand-dust puffs thrown out low round his feet (the
##     particles block, flat) and the shockwave ring (the burst block),
##     laid on the floor through the ground seam (FxBurst.show_laid);
##   - a kick of the game's screen shake (FxShake), off by default: today's
##     spins never shook the camera.
## Sand is flat cel tones with hard edges and NO glow (P-O's ruling, VFX lab
## spec story 34): no glow pass, no flash, no light, nothing additive.
## Built for max graphics; its Low version (FxLow) halves the bands, the
## grains and the dust.
##
## Phases (VFX lab grill Q7): its IMPACT is the move's hit marker plus the
## trigger offset (the spin's first active tick: the dust, the shockwave,
## the shake). From there the swirl SWEEPS round over form_s (his spin
## turns over its active frames), HOLDS for hold_s, then FADES over fade_s,
## its bands thinning. Drawn only from (preset, seed, time), its move and
## its base (grill Q8, Q9): any frame in any order, the same on every peer
## and replay. Its preset is re-read every frame it draws. Looks only: the
## simulation never reads it (the spins' real reach is their rows' reach_m;
## the preset's sizes are only drawn).
class_name FxWhirlwind
extends Node3D

## The recipe its presets are saved under (FxPresets), and its first one.
const RECIPE := "whirlwind"
const DEFAULT_NAME := "whirlwind - default"
## Its own knobs the lab shows: knob -> [label, min, max, step]. With the
## core set and the colours, 14 in all (VFX lab spec story 25); the rest sit
## under the panel's Advanced (ADVANCED_KNOBS).
const KNOBS := {
	"radius_x": ["Swirl radius (x reach)", 0.1, 2.0, 0.01],
	"band_m": ["Band width (m)", 0.05, 2.0, 0.01],
	"grains": ["Sand grains", 0, FxParticles.MAX, 1],
	"dust": ["Dust puffs", 0, FxParticles.MAX, 1],
	"burst_x": ["Shockwave (x reach, 0 off)", 0.0, 2.0, 0.01],
	"shake_m": ["Shake (m, 0 off)", 0.0, 0.3, 0.005],
}
## Its own knobs under Advanced, the same way.
const ADVANCED_KNOBS := {
	"height_m": ["Swirl height (m)", 0.0, 3.0, 0.05],
	"arc_deg": ["Sweep (deg)", 30.0, 360.0, 5.0],
	"start_deg": ["Sweep starts at (deg, 0 ahead)", -180.0, 180.0, 5.0],
	"bands": ["Bands", 1, 4, 1],
	"band_gap_m": ["Gap between bands (m)", 0.0, 0.6, 0.01],
	"streaks": ["Dark streaks per band", 0, 16, 1],
	"opacity": ["Opacity", 0.0, 1.0, 0.01],
	"wobble_m": ["Wobble (m)", 0.0, 0.5, 0.01],
	"grain_speed": ["Grain speed (m/s)", 0.0, 6.0, 0.1],
	"grain_size_m": ["Grain size (m)", 0.01, 0.3, 0.005],
	"grain_life_s": ["Grain life (s)", 0.05, 2.0, 0.05],
	"dust_x": ["Dust reach (x reach)", 0.05, 2.0, 0.01],
	"dust_life_s": ["Dust life (s)", 0.1, 3.0, 0.01],
	"dust_size_m": ["Dust puff size (m)", 0.02, 1.5, 0.01],
	"burst_s": ["Shockwave length (s)", 0.05, 2.0, 0.01],
	"shake_s": ["Shake length (s)", 0.05, 1.0, 0.01],
}
## The first spin (the lab opens on it; a move MageClips gives no spin
## sweeps its way).
const FIRST := "whirlwind"
## The light tone's share of a band's width, how fast its streaks slide,
## and how much of the band's length tapers to each point.
const CEL_SPLIT := 0.45
const STREAK_SPEED := 2.0
const END_TAPER := 0.2
## The grains: how wide they spray (the cone), how hard they fall (m/s2 at
## size 1) and how fast they are carried round with the swirl (turns a
## second at its sweep's own pace, times this).
const GRAIN_CONE := 0.7
const GRAIN_GRAVITY := 3.0
const GRAIN_CARRY := 0.5
## The dust: how hard it falls back (m/s2 at size 1), how much its speed
## and life vary, how wide round straight out it flies, how far it carries
## (times dust_m) and where round his feet it starts (m at size 1).
const DUST_GRAVITY := 2.0
const DUST_SPEED_JITTER := 0.5
const DUST_LIFE_JITTER := 0.4
const DUST_CONE := 0.35
const DUST_CARRY := 1.2
const DUST_RING_M := 0.4
## The dust's tone: the core colour toward the dark dirt (today's dust and
## dirt pair), this share of the way.
const DIRT := Color(0.42, 0.33, 0.26)
const DIRT_SHARE := 0.3
## The shockwave: its opacity at intensity 1 (today's ring: 0.7) and its
## tone (the core colour this share of the way to white).
const BURST_ALPHA := 0.7
const BURST_WHITE := 0.4
## The most its shockwave's opacity grows with intensity.
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
## The spin it plays (whirlwind or whirlwind_2: which way it sweeps).
var move := FIRST

var _feet := Vector3.ZERO
var _frame := Basis.IDENTITY
var _ground: Ground
var _level_y := 0.0
var _ribbon := FxRibbon.new(true)
var _grains := FxParticles.new()
var _dust := FxParticles.new()
var _burst := FxBurst.new()
var _drawn: Array = []
## The CPU twin of the frame last drawn (drawn()), worked out only when
## asked: the shaders shape what is seen, and the twin, a knot at a time,
## cost the game milliseconds a frame for nothing (perf pass 15).
var _twin := Callable()


## Builds its blocks (the swirl, the grains, the dust, the shockwave),
## hidden until a cast.
func _init() -> void:
	name = "Whirlwind"
	_ribbon.name = "Swirl"
	_grains.name = "Grains"
	_grains.set_flat(true)
	_dust.name = "Dust"
	_dust.set_flat(true)
	_burst.name = "Shockwave"
	for block: Node in [_ribbon, _grains, _dust, _burst]:
		add_child(block)
	_ribbon.visible = false
	_grains.visible = false
	_dust.visible = false
	_burst.visible = false


## The sensible default from today's look (the feel page's [trail] on a
## heavy swing: a 0.75 m band, 0.85 opacity, a 0.4 s fade, 32 grains 0.1 m
## across living 0.5 s; [impact]: dust 2 m, a 4.5 m shockwave over 0.35 s;
## his spin turning once over its 10 active frames): saved as DEFAULT_NAME.
static func default_preset() -> FxPreset:
	var out := FxPreset.new()
	out.recipe = RECIPE
	# Today's trail's sand gold, and its deeper gold edge.
	out.core_colour = Color(1.0, 0.85, 0.55)
	out.edge_colour = Color(1.0, 0.72, 0.28)
	out.size = 1.0
	out.form_s = 0.17
	out.hold_s = 0.05
	out.fade_s = 0.4
	out.intensity = 1.0
	out.trigger_offset_s = 0.0
	out.knobs = {"radius_x": 0.5, "band_m": 0.75, "grains": 32, "dust": 32, "burst_x": 1.0, "shake_m": 0.0,
		"height_m": 0.9, "arc_deg": 360.0, "start_deg": 0.0, "bands": 2, "band_gap_m": 0.15, "streaks": 5,
		"opacity": 0.85, "wobble_m": 0.04, "grain_speed": 1.5, "grain_size_m": 0.1, "grain_life_s": 0.5,
		"dust_x": 0.7, "dust_life_s": 0.9, "dust_size_m": 0.35, "burst_s": 0.35, "shake_s": 0.25}
	return out


## The preset's own knobs, any it lacks (saved before a knob was added) at
## the default's, its ratios of the reach in metres (FxReach.knobs_of: a
## look drawn for its hit keeps its own).
static func own_knobs(look: FxPreset) -> Dictionary:
	return FxReach.knobs_of(look)


## Which way `move_name`'s swirl sweeps round his up: its spin's
## (MageClips.MOVES' spin, 1 one way, -1 back), the first spin's for a move
## with none.
static func sweep_of(move_name: String) -> float:
	var spin := float(MageClips.MOVES.get(move_name, {}).get("spin", 0.0))
	if spin == 0.0:
		spin = float(MageClips.MOVES[FIRST]["spin"])
	return signf(spin)


## Its swirl's phase `t` s after the cast for a hit at `hit_s`
## (FxPreset.phase): it sweeps round over form_s FROM the impact, so its
## "formed" moment is form_s after it.
static func swirl_phase(look: FxPreset, hit_s: float, t: float) -> Dictionary:
	return look.phase(hit_s + look.form_s, t)


## The swirl's arc round a caster turned `frame` (his basis: -Z ahead, +Y
## up), for `move_name`: {up (world), start and span (radians round that
## up, FxRibbon.ring_frame's)}.
static func arc_of(look: FxPreset, move_name: String, frame: Basis) -> Dictionary:
	var own := own_knobs(look)
	var frame_n := frame.orthonormalized()
	var up := frame_n.y.normalized()
	var ahead := frame_n * Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(float(own["start_deg"])))
	var arc := FxRibbon.ring_frame(up)
	return {"up": up, "start": atan2(ahead.dot(arc[1]), ahead.dot(arc[0])),
		"span": deg_to_rad(float(own["arc_deg"])) * sweep_of(move_name)}


## The swirl's centre (world): height_m up his frame from his feet.
static func centre_of(look: FxPreset, feet: Vector3, frame: Basis) -> Vector3:
	return feet + frame.orthonormalized().y.normalized() * float(own_knobs(look)["height_m"]) * look.size


## The swirl's ribbon shape for `move_name` from the preset `look` in `now`
## (swirl_phase), by a caster turned `frame`.
static func shape(look: FxPreset, now: Dictionary, move_name: String, frame: Basis) -> Dictionary:
	var own := own_knobs(look)
	var arc := arc_of(look, move_name, frame)
	var out := FxRibbon.default_shape()
	out["restrike"] = 0.0
	out["sag"] = 0.0
	out["converge"] = 0.0
	out["strand_flash"] = 0.0
	out["flicker"] = 0.0
	out["tip_glow"] = 0.0
	out["branch_dim"] = 0.8
	out["core_width"] = 1.0
	out["glow"] = 1.0
	out["opacity"] = clampf(float(own["opacity"]) * look.intensity, 0.0, 1.0)
	out["colour_core"] = look.core_colour
	out["colour_inner"] = look.core_colour.lerp(look.edge_colour, 0.5)
	out["colour_outer"] = look.edge_colour
	out["colour_halo"] = look.edge_colour.darkened(0.4)
	out["cel_split"] = CEL_SPLIT
	out["streaks"] = float(own["streaks"])
	out["streak_speed"] = STREAK_SPEED
	out["end_taper"] = END_TAPER
	out["progress"] = float(now["reach"])
	out["fade"] = float(now["fade"])
	out["strands"] = clampi(int(own["bands"]), 1, 4)
	out["radial_min"] = 0.0
	out["spread"] = float(own["band_gap_m"]) * look.size
	out["spread_near"] = float(own["band_gap_m"]) * look.size
	out["spread_curve"] = 1.0
	out["twist"] = 0.0
	out["twist_speed"] = 0.0
	out["jitter"] = float(own["wobble_m"]) * look.size
	out["jitter_scale"] = 0.4
	out["octaves"] = 1
	out["crawl"] = 0.5
	out["pinch"] = 0.1
	# band_m is the band's whole width (today's trail: down the staff from
	# its tip); the ribbon's width is half of it each side.
	out["width"] = float(own["band_m"]) * 0.5 * look.size
	# An even band, its two ends tapered (END_TAPER).
	out["width_tip"] = 1.0
	out["width_curve"] = 1.0
	out["ring_radius"] = float(own["radius_m"]) * look.size
	out["ring_start"] = arc["start"]
	out["ring_span"] = arc["span"]
	out["ring_up"] = arc["up"]
	return out


## Each band's knots as drawn `t` s after the cast with `seed`, for
## `move_name`'s hit at `hit_s`, by a caster at `feet` turned `frame`: only
## as far round as it has swept, none before the hit or once faded.
static func swirl_drawn(look: FxPreset, seed: int, t: float, hit_s: float, move_name: String, feet: Vector3,
		frame: Basis) -> Array:
	var now := swirl_phase(look, hit_s, t)
	if now["name"] == "before" or now["name"] == "over":
		return []
	var drawn_shape := shape(look, now, move_name, frame)
	var centre := centre_of(look, feet, frame)
	var out := []
	for band in int(drawn_shape["strands"]):
		var knots := PackedVector3Array()
		for i in FxRibbon.SEGMENTS + 1:
			var along := float(i) / FxRibbon.SEGMENTS
			if along > float(now["reach"]) + 0.0001:
				break
			knots.append(FxRibbon.point(drawn_shape, centre, centre, along, band, seed, t))
		out.append(knots)
	return out


## The grains (FxParticles' knobs) for `move_name`: shed round the swirl's
## ring over its sweep, thrown out and up, carried round the way it turns,
## falling back.
## `up`: the ground's up at his feet (world up on level ground).
static func grain_knobs(look: FxPreset, move_name: String, up: Vector3 = Vector3.UP) -> Dictionary:
	var own := own_knobs(look)
	var out := FxParticles.default_knobs()
	out["count"] = int(own["grains"])
	out["spawn_s"] = maxf(look.form_s, 0.001)
	out["speed_m_s"] = float(own["grain_speed"]) * look.size
	out["speed_jitter"] = 0.6
	out["life_s"] = float(own["grain_life_s"])
	out["life_jitter"] = 0.5
	out["cone"] = GRAIN_CONE
	out["gravity_m_s2"] = GRAIN_GRAVITY * look.size
	out["size_m"] = float(own["grain_size_m"]) * look.size
	out["dir"] = up
	out["up"] = up
	out["ring_m"] = maxf(float(own["radius_m"]) * look.size, 0.001)
	# Carried round with the swirl: a share of its sweep's pace, its way.
	var turns := deg_to_rad(float(own["arc_deg"])) / TAU / maxf(look.form_s, 0.05)
	out["swirl"] = turns * GRAIN_CARRY * sweep_of(move_name)
	return out


## The dust (FxParticles' knobs): born on a ring round his feet at the hit,
## thrown up (`up`, the ground's) and out from it to about dust_m, settling back.
static func dust_knobs(look: FxPreset, up: Vector3 = Vector3.UP) -> Dictionary:
	var own := own_knobs(look)
	var life := maxf(float(own["dust_life_s"]), 0.01)
	var out := FxParticles.default_knobs()
	out["count"] = int(own["dust"])
	out["spawn_s"] = 0.05
	out["speed_m_s"] = float(own["dust_m"]) * look.size / life * DUST_CARRY
	out["speed_jitter"] = DUST_SPEED_JITTER
	out["life_s"] = life
	out["life_jitter"] = DUST_LIFE_JITTER
	out["cone"] = DUST_CONE
	out["gravity_m_s2"] = DUST_GRAVITY * look.size
	out["size_m"] = float(own["dust_size_m"]) * look.size
	out["dir"] = up
	out["up"] = up
	out["ring_m"] = DUST_RING_M * look.size
	return out


## The shockwave (FxBurst's knobs): none at 0.
static func burst_knobs(look: FxPreset) -> Dictionary:
	var own := own_knobs(look)
	return {"radius_m": float(own["burst_m"]) * look.size, "length_s": float(own["burst_s"])}


## Where its caster stands (`at`, his feet, world) and how he is turned
## (`frame`: -Z ahead, +Y up; the lab's caster faces -Z).
func set_base(at: Vector3, frame: Basis = Basis.IDENTITY) -> void:
	_feet = at
	_frame = frame


## The ground its shockwave is laid on (null: flat round his feet), its
## level floor at `level_y`.
func set_ground(ground: Ground, level_y: float) -> void:
	_ground = ground
	_level_y = level_y


## Draws the frame `t` seconds after a cast with `seed`, with the preset's
## knobs as they are now: nothing before its impact.
func show_at(seed: int, t: float) -> void:
	var look := drawn_preset()
	var age := t - impact_time()
	var now := swirl_phase(look, impact_s, t)
	var on: bool = now["name"] != "before" and now["name"] != "over"
	_twin = swirl_drawn.bind(look, seed, t, impact_s, move, _feet, _frame)
	_ribbon.visible = on
	if on:
		var centre := centre_of(look, _feet, _frame)
		_ribbon.show_shape(shape(look, now, move, _frame), centre,
			centre + _frame.orthonormalized() * Vector3.FORWARD, seed, t)
	if age < 0.0:
		_grains.visible = false
		_dust.visible = false
	else:
		# Flat grains and dust: full colour while they live (they shrink as they die).
		# Along the ground's up at his feet, read each frame (the lava ball's
		# from its centre: playtest 2026-10-25 #12), else his own up.
		var up := _ground.up_at(_feet) if _ground != null else _frame.orthonormalized().y.normalized()
		_grains.show_at(grain_knobs(look, move, up), seed, age, centre_of(look, _feet, _frame),
			Color(look.core_colour, 1.0))
		_dust.show_at(dust_knobs(look, up), seed + 1, age, _feet,
			Color(look.core_colour.lerp(DIRT, DIRT_SHARE), 1.0))
	var alpha := clampf(look.drawn_intensity(), 0.0, MOST_ALPHA)
	var ring := look.core_colour.lerp(Color.WHITE, BURST_WHITE)
	# Laid on the floor round his feet (a camera-facing disc sank half into it).
	_burst.show_laid(burst_knobs(look), age, _ground, _feet, _level_y, _frame.orthonormalized().y.normalized(),
		Color(ring, BURST_ALPHA * alpha))


## What its impact kicks the holder's ScreenShake with (FxShake): strength
## 0, off, by default.
func shake_kick() -> Dictionary:
	var own := own_knobs(drawn_preset())
	return FxShake.kick_of({"strength_m": float(own["shake_m"]), "length_s": float(own["shake_s"])})


## When it plays (s after the cast): the hit plus the trigger offset.
func impact_time() -> float:
	return drawn_preset().impact_at(impact_s)


## When the whole effect is over (s after the cast): the swirl swept, held
## and faded, the grains and the dust settled, the shockwave played out.
func end_time() -> float:
	var look := drawn_preset()
	var own := own_knobs(look)
	var swirl := look.form_s + look.hold_s + look.fade_s
	var grains := maxf(look.form_s, 0.001) + float(own["grain_life_s"])
	var dust := 0.05 + float(own["dust_life_s"])
	return impact_time() + maxf(maxf(swirl, grains), maxf(dust, float(own["burst_s"])))


## Whether any of it shows now.
func shown() -> bool:
	return _ribbon.visible or _grains.visible or _dust.visible or _burst.visible


## Where it lands: round his feet.
func impact_point() -> Vector3:
	return _feet


## How far round its impact point it reaches (m): the swirl's outer edge
## (the lab's dummies flinch inside it).
func impact_reach() -> float:
	var look := drawn_preset()
	var own := own_knobs(look)
	return (float(own["radius_m"]) + float(own["band_m"]) * 0.5) * look.size


## The swirl's bands drawn now (their knots, world).
func drawn() -> Array:
	return _twin_drawn()


## The swirl (the ribbon, cel).
func ribbon() -> FxRibbon:
	return _ribbon


## The sand grains it sheds.
func grains() -> FxParticles:
	return _grains


## The dust thrown up at his feet.
func dust() -> FxParticles:
	return _dust


## The shockwave.
func burst() -> FxBurst:
	return _burst


## The preset as drawn: its ratios times the hit's reach (FxReach.drawn).
func drawn_preset() -> FxPreset:
	return _sized.of(preset, hit)


## drawn(): the twin worked out now if a frame was drawn since it last was.
func _twin_drawn() -> Array:
	if _twin.is_valid():
		_drawn = _twin.call()
		_twin = Callable()
	return _drawn
