## The sand slash (GLOSSARY: Recipe; VFX all-spells ticket 01): the mage's
## three light slashes as one family, its first preset "sand slash -
## default" made from today's look (the staff's sand trail, MageModel, and
## the grains it sheds: its colours, its 0.3 m band, its 0.22 s fade, its 32
## grains), built for max graphics (FxLow makes its Low version). Built from
## blocks:
##   - the crescent: the ribbon block (FxRibbon) in its cel look, bent into
##     an arc round his chest the way that slash's staff swings (SWINGS,
##     read off the clips' staff tip): the first from his right round to his
##     left, the second back from his left to his right, the ender down
##     across him from over his right shoulder to low at his left;
##   - sand grains shed by its sweeping front: the particles block
##     (FxParticles), flat.
## Sand is flat cel tones with hard edges and NO glow (P-O's ruling, VFX lab
## spec story 34): no glow pass, no flash, no light, nothing additive.
##
## Phases (VFX lab grill Q7): it SWEEPS round over form_s up to its IMPACT
## (the move's hit marker, plus its swing's own lag, after_hit_s: the staff
## crosses the hit part way through its sweep, plus the trigger offset);
## it HOLDS for hold_s, then FADES over fade_s, its band thinning. Drawn
## only from (preset, seed, time), its move and its base (grill Q8, Q9):
## any frame in any order, the same on every peer and replay. Its preset is
## re-read every frame it draws. Looks only: the simulation never reads it
## (the slashes' real reach is their rows' reach_m and arc_deg).
class_name FxSandSlash
extends Node3D

## The recipe its presets are saved under (FxPresets), and its first one.
const RECIPE := "sand_slash"
const DEFAULT_NAME := "sand slash - default"
## Its own knobs the lab shows: knob -> [label, min, max, step]. With the
## core set and the colours, 14 in all; the rest sit under Advanced.
const KNOBS := {
	"radius_x": ["Radius (x reach)", 0.1, 2.0, 0.01],
	"arc_x": ["Sweep (x hit angle)", 0.1, 3.0, 0.01],
	"height_m": ["Height (m)", 0.0, 3.0, 0.05],
	"band_m": ["Band width (m)", 0.02, 1.0, 0.01],
	"bands": ["Bands", 1, 4, 1],
	"grains": ["Sand grains", 0, FxParticles.MAX, 1],
}
## Its own knobs under Advanced, the same way.
const ADVANCED_KNOBS := {
	"ender_tilt_deg": ["Ender's tilt (deg)", -90.0, 90.0, 1.0],
	"band_gap_m": ["Gap between bands (m)", 0.0, 0.6, 0.01],
	"streaks": ["Dark streaks per band", 0, 16, 1],
	"opacity": ["Opacity", 0.0, 1.0, 0.01],
	"wobble_m": ["Wobble (m)", 0.0, 0.5, 0.01],
	"grain_speed": ["Grain speed (m/s)", 0.0, 6.0, 0.1],
	"grain_size_m": ["Grain size (m)", 0.01, 0.3, 0.005],
	"grain_life_s": ["Grain life (s)", 0.05, 2.0, 0.05],
}
## Each slash's swing (read off the clips' staff tip, at the hit): where
## its sweep is centred (degrees round his up, 0 ahead, positive to his
## left), which way it sweeps (1 right to left, -1 left to right), whether
## its plane is the ender's tilt (else level), and how long after the hit
## marker the staff finishes it (s). A move the table lacks sweeps as the
## first slash.
const SWINGS := {
	"light_1": {"centre_deg": 45.0, "sweep": 1.0, "tilted": false, "after_hit_s": 0.04},
	"light_2": {"centre_deg": -40.0, "sweep": -1.0, "tilted": false, "after_hit_s": 0.035},
	"light_3": {"centre_deg": -30.0, "sweep": 1.0, "tilted": true, "after_hit_s": 0.0},
}
const FIRST := "light_1"
## The light tone's share of a band's width, how fast its streaks slide,
## and how much of the band's length tapers to each point.
const CEL_SPLIT := 0.45
const STREAK_SPEED := 2.0
const END_TAPER := 0.3
## The grains: how wide they spray (the cone) and how hard they fall (m/s2).
const GRAIN_CONE := 0.6
const GRAIN_GRAVITY := 3.0

## When the move's hit marker falls: seconds after the cast (the clip's
## start), before its swing's lag and the preset's trigger offset.
var impact_s := 0.0
## The knobs it is drawn with, read each frame.
var preset: FxPreset = default_preset()
## The move's hit area its ground footprint is ratios of (FxReach.hit_of:
## {reach_m, arc_deg}), set by its holder from the move's data, the game's
## or the lab's; {} draws at its recipe's FxReach.REFERENCE reach.
var hit := {}

var _sized := FxReach.Sized.new()
## The light slash it plays (SWINGS).
var move := FIRST

var _feet := Vector3.ZERO
var _frame := Basis.IDENTITY
var _ribbon := FxRibbon.new(true)
var _grains := FxParticles.new()
var _drawn: Array = []
## The CPU twin of the frame last drawn (drawn()), worked out only when
## asked: the shaders shape what is seen, and the twin, a knot at a time,
## cost the game milliseconds a frame for nothing (perf pass 15).
var _twin := Callable()


## Builds its blocks (the crescent, the grains).
func _init() -> void:
	name = "SandSlash"
	_grains.name = "Grains"
	_grains.set_flat(true)
	for block: Node in [_ribbon, _grains]:
		add_child(block)


## The sensible default from today's look: saved as DEFAULT_NAME.
static func default_preset() -> FxPreset:
	var out := FxPreset.new()
	out.recipe = RECIPE
	# Today's trail's sand gold, and its paler grains in the middle.
	out.core_colour = Color(1.0, 0.85, 0.55)
	out.edge_colour = Color(1.0, 0.72, 0.28)
	out.size = 1.0
	out.form_s = 0.1
	out.hold_s = 0.04
	out.fade_s = 0.22
	out.intensity = 1.0
	out.trigger_offset_s = 0.0
	out.knobs = {"radius_x": 1.0, "arc_x": 1.0, "height_m": 1.05, "band_m": 0.15, "bands": 2, "grains": 32,
		"ender_tilt_deg": 50.0, "band_gap_m": 0.12, "streaks": 4, "opacity": 0.9, "wobble_m": 0.03,
		"grain_speed": 1.2, "grain_size_m": 0.1, "grain_life_s": 0.5}
	return out


## The preset's own knobs, any it lacks (saved before a knob was added) at
## the default's, its ratios of the reach in metres (FxReach.knobs_of: a
## look drawn for its hit keeps its own).
static func own_knobs(look: FxPreset) -> Dictionary:
	return FxReach.knobs_of(look)


## `move`'s swing (SWINGS; the first slash's for a move it lacks).
static func swing_of(move_name: String) -> Dictionary:
	return SWINGS.get(move_name, SWINGS[FIRST])


## When `move`'s slash is formed (s after the cast) for a hit marker at
## `hit_s`: the hit, its swing's lag and the trigger offset.
static func impact_time_of(look: FxPreset, hit_s: float, move_name: String) -> float:
	return look.impact_at(hit_s + float(swing_of(move_name)["after_hit_s"]))


## Its phase `t` s after the cast (FxPreset.phase), for `move`'s hit at `hit_s`.
static func phase_of(look: FxPreset, hit_s: float, move_name: String, t: float) -> Dictionary:
	return look.phase(hit_s + float(swing_of(move_name)["after_hit_s"]), t)


## The arc's frame for `move` by a caster turned `frame` (his basis: -Z
## ahead, +Y up): {up (the arc's plane's, world), start and span (radians,
## FxRibbon.ring_frame's round that up)}.
static func arc_of(look: FxPreset, move_name: String, frame: Basis) -> Dictionary:
	var own := own_knobs(look)
	var swing := swing_of(move_name)
	var tilt := deg_to_rad(float(own["ender_tilt_deg"])) if swing["tilted"] else 0.0
	# Tilted round his forward axis: his right side rises.
	var up_here := Vector3(-sin(tilt), cos(tilt), 0.0)
	var centre_here := Vector3.FORWARD.rotated(up_here, deg_to_rad(float(swing["centre_deg"])))
	var frame_n := frame.orthonormalized()
	var up := (frame_n * up_here).normalized()
	var centre := frame_n * centre_here
	var arc := FxRibbon.ring_frame(up)
	var span := deg_to_rad(float(own["arc_deg"])) * float(swing["sweep"])
	var at := atan2(centre.dot(arc[1]), centre.dot(arc[0]))
	return {"up": up, "start": at - span / 2.0, "span": span}


## Its centre (world): `height_m` up his frame from his feet.
static func centre_of(look: FxPreset, feet: Vector3, frame: Basis) -> Vector3:
	return feet + frame.orthonormalized().y * float(own_knobs(look)["height_m"]) * look.size


## The crescent's ribbon shape for `move` from the preset `look` in `now`
## (a phase), by a caster turned `frame`.
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
	out["branch_dim"] = 0.75
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
	out["pinch"] = 0.2
	out["width"] = float(own["band_m"]) * look.size
	out["width_tip"] = 1.0
	out["ring_radius"] = float(own["radius_m"]) * look.size
	out["ring_start"] = arc["start"]
	out["ring_span"] = arc["span"]
	out["ring_up"] = arc["up"]
	return out


## Each band's knots as drawn `t` s after the cast with `seed`, for `move`'s
## hit at `hit_s`, by a caster at `feet` turned `frame`: only as far round
## as it has swept, none before its sweep or once faded.
static func arc_drawn(look: FxPreset, seed: int, t: float, hit_s: float, move_name: String, feet: Vector3,
		frame: Basis) -> Array:
	var now := phase_of(look, hit_s, move_name, t)
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


## The grains (FxParticles' knobs) for `move` by a caster turned `frame`:
## born round the arc where its front is as it sweeps, thrown out and up,
## falling down his up.
static func grain_knobs(look: FxPreset, move_name: String, frame: Basis) -> Dictionary:
	var own := own_knobs(look)
	var arc := arc_of(look, move_name, frame)
	var up := frame.orthonormalized().y.normalized()
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
	out["ring_m"] = float(own["radius_m"]) * look.size
	out["ring_up"] = arc["up"]
	out["ring_start"] = arc["start"]
	out["ring_span"] = arc["span"]
	out["ring_follow"] = true
	return out


## Where its caster stands (`at`, his feet, world) and how he is turned
## (`frame`: -Z ahead, +Y up; the lab's caster faces -Z).
func set_base(at: Vector3, frame: Basis = Basis.IDENTITY) -> void:
	_feet = at
	_frame = frame


## Draws the frame `t` seconds after a cast with `seed`, with the preset's
## knobs as they are now.
func show_at(seed: int, t: float) -> void:
	var look := drawn_preset()
	var now := phase_of(look, impact_s, move, t)
	var on: bool = now["name"] != "before" and now["name"] != "over"
	_twin = arc_drawn.bind(look, seed, t, impact_s, move, _feet, _frame)
	_ribbon.visible = on
	if not on:
		_grains.visible = false
		return
	var centre := centre_of(look, _feet, _frame)
	var since := t - (impact_time() - look.form_s)
	# Flat grains: full colour while they live (they shrink as they die).
	_grains.show_at(grain_knobs(look, move, _frame), seed, since, centre, Color(look.core_colour, 1.0))
	_ribbon.show_shape(shape(look, now, move, _frame), centre, centre + _frame.orthonormalized() * Vector3.FORWARD,
		seed, t)


## When the whole slash is over (s after the cast): swept, held and faded.
func end_time() -> float:
	var look := drawn_preset()
	return impact_time() + look.hold_s + look.fade_s


## Whether it shows now (sweeping, held or fading).
func shown() -> bool:
	return _ribbon.visible


## When it has swept round (s after the cast): the hit, its swing's lag and
## the trigger offset.
func impact_time() -> float:
	return impact_time_of(drawn_preset(), impact_s, move)


## Where it strikes: round his chest.
func impact_point() -> Vector3:
	return centre_of(drawn_preset(), _feet, _frame)


## How far round its centre it reaches (m): the dummies there flinch.
func impact_reach() -> float:
	var look := drawn_preset()
	return float(own_knobs(look)["radius_m"]) * look.size


## The bands drawn now (their knots, world).
func drawn() -> Array:
	return _twin_drawn()


## Its crescent (the ribbon, cel).
func ribbon() -> FxRibbon:
	return _ribbon


## The sand grains its front sheds.
func grains() -> FxParticles:
	return _grains


## The preset as drawn: its ratios times the hit's reach (FxReach.drawn).
func drawn_preset() -> FxPreset:
	return _sized.of(preset, hit)


## drawn(): the twin worked out now if a frame was drawn since it last was.
func _twin_drawn() -> Array:
	if _twin.is_valid():
		_drawn = _twin.call()
		_twin = Callable()
	return _drawn
