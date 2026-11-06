## The blink (GLOSSARY: Recipe; VFX all-spells ticket 05): the mage's leap
## that light, light, light flows into, its distance in a few frames. Its
## first preset, "blink - default", is made from today's look: the pale
## blue see-through he turns for the whole blink (PlayerAvatar's
## IFRAME_COLOR), with nothing else drawn. Built from the blocks, never
## copies of them:
##   - the streak: the ribbon block (FxRibbon) in its cel look, a band from
##     him back to where he left, at hip height, thinning to its tail;
##   - the arrival burst where he lands: puffs thrown out low round his
##     feet (the particles block, flat) and a ring (the burst block);
##   - a kick of the game's screen shake (FxShake), off by default: today's
##     blink never shook the camera.
## Flat cel tones like his sand (no glow pass, no flash, no light).
## Built for max graphics; its Low version (FxLow) halves the bands, the
## streaks and the puffs.
##
## Phases (VFX lab grill Q7): its IMPACT is the move's hit marker plus the
## trigger offset; the blink hits nothing, so its marker is its end, his
## arrival (FxMoves.hit_s, MageClips.move_cast). The streak FORMS form_s
## before it (he is on his way: it runs from where he left to him), HOLDS
## for hold_s past it, then FADES over fade_s, drawn back into where he
## landed. The puffs are thrown out over the first BURST_SPAWN_S past the
## impact. Drawn only from (preset, seed, time) and its two ends (grill Q8,
## Q9): any frame in any order, the same on every peer and replay. Its
## preset is re-read every frame it draws. Looks only: the simulation never
## reads it (the blink's real distance is [blink] distance_m; the preset's
## sizes are only drawn).
class_name FxBlink
extends Node3D

## The recipe its presets are saved under (FxPresets), and its first one.
const RECIPE := "blink"
const DEFAULT_NAME := "blink - default"
## Its own knobs the lab shows: knob -> [label, min, max, step]. With the
## core set and the colours, 14 in all (VFX lab spec story 25); the rest sit
## under the panel's Advanced (ADVANCED_KNOBS).
const KNOBS := {
	"width_m": ["Streak width (m)", 0.05, 2.0, 0.01],
	"opacity": ["Streak opacity", 0.0, 1.0, 0.01],
	"puffs": ["Arrival puffs", 0, FxParticles.MAX, 1],
	"burst_x": ["Arrival ring (x distance, 0 off)", 0.0, 1.0, 0.01],
	"shake_m": ["Shake (m, 0 off)", 0.0, 0.3, 0.005],
}
## Its own knobs under Advanced, the same way.
const ADVANCED_KNOBS := {
	"height_m": ["Streak height (m)", 0.0, 3.0, 0.05],
	"tail": ["Tail width (x width)", 0.0, 1.0, 0.01],
	"bands": ["Bands", 1, 4, 1],
	"band_gap_m": ["Gap between bands (m)", 0.0, 0.6, 0.01],
	"streaks": ["Dark streaks per band", 0, 16, 1],
	"wobble_m": ["Wobble (m)", 0.0, 0.5, 0.01],
	"puff_x": ["Puff reach (x distance)", 0.02, 1.0, 0.01],
	"puff_life_s": ["Puff life (s)", 0.1, 2.0, 0.01],
	"puff_size_m": ["Puff size (m)", 0.02, 1.0, 0.01],
	"burst_s": ["Ring length (s)", 0.05, 2.0, 0.01],
	"shake_s": ["Shake length (s)", 0.05, 1.0, 0.01],
}
## The light tone's share of a band's width, how fast its streaks slide,
## and how much of its length tapers to each point.
const CEL_SPLIT := 0.45
const STREAK_SPEED := 3.0
const END_TAPER := 0.1
## The puffs: thrown out over this long past the impact, from a ring this
## wide round his feet (m at size 1), how much their speed and life vary,
## how wide round straight out they fly, how far they carry (times puff_m)
## and how hard they fall back (m/s2 at size 1).
const BURST_SPAWN_S := 0.05
const PUFF_RING_M := 0.3
const PUFF_SPEED_JITTER := 0.5
const PUFF_LIFE_JITTER := 0.4
const PUFF_CONE := 0.4
const PUFF_CARRY := 1.2
const PUFF_GRAVITY := 1.5
## The ring: how high round him it sits (m at size 1), its opacity at
## intensity 1 and its tone (the core colour this share of the way to white).
const BURST_UP_M := 0.1
const BURST_ALPHA := 0.7
const BURST_WHITE := 0.4
## The most its ring's opacity grows with intensity.
const MOST_ALPHA := 2.0

## When the move's hit marker falls (his arrival): seconds after the cast
## (the clip's start), before the preset's trigger offset.
var impact_s := 0.0
## The knobs it is drawn with, read each frame (its default first).
var preset: FxPreset = default_preset()
## The move's hit area its ground footprint is ratios of (FxReach.hit_of:
## {reach_m, arc_deg}), set by its holder from the move's data, the game's
## or the lab's; {} draws at its recipe's FxReach.REFERENCE reach.
var hit := {}

var _sized := FxReach.Sized.new()

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _frame := Basis.IDENTITY
var _ribbon := FxRibbon.new(true)
var _puffs := FxParticles.new()
var _burst := FxBurst.new()
var _drawn: Array = []
## The CPU twin of the frame last drawn (drawn()), worked out only when
## asked: the shaders shape what is seen, and the twin, a knot at a time,
## cost the game milliseconds a frame for nothing (perf pass 15).
var _twin := Callable()


## Builds its blocks (the streak, the puffs, the ring), hidden until a cast.
func _init() -> void:
	name = "Blink"
	_ribbon.name = "Streak"
	_puffs.name = "Puffs"
	_puffs.set_flat(true)
	_burst.name = "Ring"
	for block: Node in [_ribbon, _puffs, _burst]:
		add_child(block)
	_ribbon.visible = false
	_puffs.visible = false
	_burst.visible = false


## The sensible default from today's look (the pale blue see-through over
## him for the whole blink, PlayerAvatar's IFRAME_COLOR at 0.55 opacity;
## the blink's 7 m in 8 frames): saved as DEFAULT_NAME.
static func default_preset() -> FxPreset:
	var out := FxPreset.new()
	out.recipe = RECIPE
	# Today's pale blue, and a deeper blue edge.
	out.core_colour = Color(0.55, 0.85, 1.0)
	out.edge_colour = Color(0.3, 0.6, 0.95)
	out.size = 1.0
	out.form_s = 0.2
	out.hold_s = 0.05
	out.fade_s = 0.25
	out.intensity = 1.0
	out.trigger_offset_s = 0.0
	out.knobs = {"width_m": 0.5, "opacity": 0.55, "puffs": 24, "burst_x": 0.29, "shake_m": 0.0,
		"height_m": 0.9, "tail": 0.15, "bands": 2, "band_gap_m": 0.12, "streaks": 4, "wobble_m": 0.04,
		"puff_x": 0.17, "puff_life_s": 0.45, "puff_size_m": 0.22, "burst_s": 0.3, "shake_s": 0.2}
	return out


## The preset's own knobs, any it lacks (saved before a knob was added) at
## the default's, its ratios of the reach in metres (FxReach.knobs_of: a
## look drawn for its hit keeps its own).
static func own_knobs(look: FxPreset) -> Dictionary:
	return FxReach.knobs_of(look)


## The streak's ribbon shape from the preset `look` in `now` (look.phase).
static func shape(look: FxPreset, now: Dictionary) -> Dictionary:
	var own := own_knobs(look)
	var out := FxRibbon.default_shape()
	out["restrike"] = 0.0
	out["sag"] = 0.0
	out["converge"] = 1.0
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
	# Fading, it is drawn back into where he landed.
	out["progress"] = float(now["fade"]) if now["name"] == "fade" else 1.0
	out["fade"] = float(now["fade"])
	out["strands"] = clampi(int(own["bands"]), 1, 4)
	out["radial_min"] = 0.0
	out["spread"] = float(own["band_gap_m"]) * look.size
	out["spread_near"] = 0.0
	out["spread_curve"] = 1.0
	out["twist"] = 0.0
	out["twist_speed"] = 0.0
	out["jitter"] = float(own["wobble_m"]) * look.size
	out["jitter_scale"] = 0.4
	out["octaves"] = 1
	out["crawl"] = 0.5
	out["pinch"] = 0.1
	# width_m is the band's whole width at him; the ribbon's is half each side.
	out["width"] = float(own["width_m"]) * 0.5 * look.size
	out["width_tip"] = clampf(float(own["tail"]), 0.0, 1.0)
	out["width_curve"] = 1.0
	return out


## The streak's two ends (world): at him (`to`) and where he left (`from`),
## height_m up `frame`'s up.
static func ends_of(look: FxPreset, from: Vector3, to: Vector3, frame: Basis) -> Array:
	var up := frame.orthonormalized().y.normalized() * float(own_knobs(look)["height_m"]) * look.size
	return [to + up, from + up]


## Each band's knots as drawn `t` s after the cast with `seed`, arriving at
## `hit_s`, from `from` to `to` by a caster turned `frame`: from him back
## to where he left (only as far as drawn while it fades), none before it
## forms or once faded.
static func streak_drawn(look: FxPreset, seed: int, t: float, hit_s: float, from: Vector3, to: Vector3,
		frame: Basis) -> Array:
	var now := look.phase(hit_s, t)
	if now["name"] == "before" or now["name"] == "over":
		return []
	var drawn_shape := shape(look, now)
	var ends := ends_of(look, from, to, frame)
	var out := []
	for band in int(drawn_shape["strands"]):
		var knots := PackedVector3Array()
		for i in FxRibbon.SEGMENTS + 1:
			var along := float(i) / FxRibbon.SEGMENTS
			if along > float(drawn_shape["progress"]) + 0.0001:
				break
			knots.append(FxRibbon.point(drawn_shape, ends[0], ends[1], along, band, seed, t))
		out.append(knots)
	return out


## The puffs (FxParticles' knobs): born on a ring round his feet where he
## lands, thrown up and out to about puff_m, settling back.
## `up`: his up where he lands (world up on level ground).
static func puff_knobs(look: FxPreset, up: Vector3 = Vector3.UP) -> Dictionary:
	var own := own_knobs(look)
	var life := maxf(float(own["puff_life_s"]), 0.01)
	var out := FxParticles.default_knobs()
	out["count"] = int(own["puffs"])
	out["spawn_s"] = BURST_SPAWN_S
	out["speed_m_s"] = float(own["puff_m"]) * look.size / life * PUFF_CARRY
	out["speed_jitter"] = PUFF_SPEED_JITTER
	out["life_s"] = life
	out["life_jitter"] = PUFF_LIFE_JITTER
	out["cone"] = PUFF_CONE
	out["gravity_m_s2"] = PUFF_GRAVITY * look.size
	out["size_m"] = float(own["puff_size_m"]) * look.size
	out["dir"] = up
	out["up"] = up
	out["ring_m"] = PUFF_RING_M * look.size
	return out


## The ring (FxBurst's knobs): none at 0.
static func burst_knobs(look: FxPreset) -> Dictionary:
	var own := own_knobs(look)
	return {"radius_m": float(own["burst_m"]) * look.size, "length_s": float(own["burst_s"])}


## Where he left (`from_at`) and where he is (`at`), his feet (world), and
## how he is turned (`frame`: +Y up).
func set_path(from_at: Vector3, at: Vector3, frame: Basis) -> void:
	_from = from_at
	_to = at
	_frame = frame


## Draws the frame `t` seconds after a cast with `seed`, with the preset's
## knobs as they are now.
func show_at(seed: int, t: float) -> void:
	var look := drawn_preset()
	var age := t - impact_time()
	var now := look.phase(impact_s, t)
	var on: bool = now["name"] != "before" and now["name"] != "over"
	_twin = streak_drawn.bind(look, seed, t, impact_s, _from, _to, _frame)
	_ribbon.visible = on
	if on:
		var ends := ends_of(look, _from, _to, _frame)
		_ribbon.show_shape(shape(look, now), ends[0], ends[1], seed, t)
	if age < 0.0:
		_puffs.visible = false
	else:
		# Flat puffs: full colour while they live (they shrink as they die).
		# Along his up (his frame stands on the ground's: the lava ball's
		# curve too, playtest 2026-10-25 #12).
		_puffs.show_at(puff_knobs(look, _frame.orthonormalized().y.normalized()), seed, age, _to,
			Color(look.core_colour, 1.0))
	var alpha := clampf(look.drawn_intensity(), 0.0, MOST_ALPHA)
	var ring := look.core_colour.lerp(Color.WHITE, BURST_WHITE)
	_burst.show_at(burst_knobs(look), age, _to + _frame.orthonormalized().y.normalized() * BURST_UP_M * look.size,
		Color(ring, BURST_ALPHA * alpha))


## What its impact kicks the holder's ScreenShake with (FxShake): strength
## 0, off, by default.
func shake_kick() -> Dictionary:
	var own := own_knobs(drawn_preset())
	return FxShake.kick_of({"strength_m": float(own["shake_m"]), "length_s": float(own["shake_s"])})


## When it plays (s after the cast): his arrival plus the trigger offset.
func impact_time() -> float:
	return drawn_preset().impact_at(impact_s)


## When the whole effect is over (s after the cast): the streak held and
## faded, the puffs settled, the ring played out.
func end_time() -> float:
	var look := drawn_preset()
	var own := own_knobs(look)
	var puffs := BURST_SPAWN_S + float(own["puff_life_s"])
	return impact_time() + maxf(maxf(look.hold_s + look.fade_s, puffs), float(own["burst_s"]))


## Whether any of it shows now.
func shown() -> bool:
	return _ribbon.visible or _puffs.visible or _burst.visible


## Where he left (his feet, world).
func from_point() -> Vector3:
	return _from


## Where it lands: his feet where he arrives.
func impact_point() -> Vector3:
	return _to


## How far round its impact point it reaches (m): the ring's radius (the
## lab's dummies flinch inside it).
func impact_reach() -> float:
	var look := drawn_preset()
	return float(own_knobs(look)["burst_m"]) * look.size


## The streak's bands drawn now (their knots, world).
func drawn() -> Array:
	return _twin_drawn()


## The streak (the ribbon, cel).
func streak() -> FxRibbon:
	return _ribbon


## The arrival puffs.
func puffs() -> FxParticles:
	return _puffs


## The arrival ring.
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
