## The tornado (GLOSSARY: Recipe; VFX lab ticket 07, grill Q17): the mage's
## tornado round his feet, its first preset "tornado - sand", the sensible
## default from target_sand-tornado_v1 (docs/vfx/targets/), built for max
## graphics (Low: ticket 08). Built from blocks:
##   - the spiral: the ribbon block (FxRibbon) in its cel look, its bands
##     fanned round the axis off it (the caster stands clear in the eye),
##     flaring from his feet to its radius, wound round as they rise and
##     turning; a second, flat one is the swirl on the floor;
##   - rocks riding the spiral: the debris block (FxDebris, the game's rock
##     meshes);
##   - sand grains swirling up it: the particles block (FxParticles), flat.
## Sand is flat cel tones with hard edges and NO glow (P-O's ruling, spec
## story 34): no glow pass, no flash, no light, nothing additive.
##
## Phases (grill Q7): it FORMS over form_s, rising from his feet, up to the
## IMPACT (the move's hit marker plus the trigger offset); it HOLDS for
## hold_s, then FADES over fade_s, its bands thinning and its rocks
## shrinking. Drawn only from (preset, seed, time) and its base (grill Q8,
## Q9): any frame in any order, the same on every peer and replay. Its
## preset is re-read every frame it draws. Looks only: the simulation never
## reads it.
## Its sizes are ratios of the channel's real reach, [mage.move.tornado]
## radius_m (ticket 15, FxReach): its foot on the floor is the reach times
## foot_x, its top the foot times flare_x (free: above the ground), its
## floor swirl the reach times floor_swirl_x; the fairness check holds its
## foot or swirl, the outermost, to the reach.
## In the game (VFX all-spells ticket 04) the mage's tornado plays it once
## his page names a preset ([mage.look] tornado_fx; TornadoLook otherwise),
## and his channel steers it (set_channel), as TornadoLook was steered: its
## reach is the channel's radius_m (the push wall, Greatsword's wider one
## too); it is never taller
## than [look] tornado_height_m (its top band's width included, its rocks
## and grains too); it forms from the cast as the preset says, holds for as
## long as he channels, and fades over fade_s once the channel ends (its
## last frame, Q or a hit). Drawn under the enemies' telegraphs
## (GroundDrawOrder).
## It stands along the up of its ground at its foot (set_ground; ADR 0006),
## read every frame it draws: on the lava ball it leans with the planet
## wherever he channels (playtest 2026-10-25 #12), straight up on level
## ground and in the lab.
class_name FxTornado
extends Node3D

## The recipe its presets are saved under (FxPresets), and its first one.
const RECIPE := "tornado"
const DEFAULT_NAME := "tornado - sand"
## Its own knobs the lab shows: knob -> [label, min, max, step]. With the
## core set and the colours, 14 in all (spec story 25); the rest sit under
## the panel's Advanced (ADVANCED_KNOBS).
const KNOBS := {
	"bands": ["Bands", 1, 9, 1],
	"height_m": ["Height (m)", 1.0, 12.0, 0.1],
	"foot_x": ["Foot (x reach)", 0.05, 2.0, 0.01],
	"flare_x": ["Top (x foot)", 0.5, 8.0, 0.05],
	"spin": ["Spin (turns/s)", 0.0, 3.0, 0.05],
	"rocks": ["Rocks", 0, FxDebris.MAX, 1],
	"grains": ["Sand grains", 0, FxParticles.MAX, 1],
}
## Its own knobs under Advanced, the same way.
const ADVANCED_KNOBS := {
	"twist": ["Twist (turns up its height)", 0.0, 4.0, 0.05],
	"band_m": ["Band width (m)", 0.05, 1.5, 0.01],
	"streaks": ["Dark streaks per band", 0, 16, 1],
	"opacity": ["Opacity", 0.0, 1.0, 0.01],
	"wobble_m": ["Wobble (m)", 0.0, 1.0, 0.01],
	"floor_swirl_x": ["Floor swirl (x reach, 0 off)", 0.0, 2.0, 0.01],
	"rock_size_m": ["Rock size (m)", 0.05, 1.0, 0.01],
	"rock_rise_m_s": ["Rock climb (m/s)", 0.0, 5.0, 0.05],
	"grain_speed": ["Grain speed (m/s)", 0.0, 10.0, 0.1],
	"grain_size_m": ["Grain size (m)", 0.01, 0.3, 0.005],
}
## The innermost band's share of the radius: the eye he stands in.
const EYE := 0.45
## How far the bands flare (the reach's curve up the height: over 1 it
## opens late, a funnel).
const FLARE := 1.5
## The bands' width at the top (times their width at the foot).
const WIDTH_TOP := 1.6
## The light tone's share of a band's width, and how fast its streaks slide.
const CEL_SPLIT := 0.45
const STREAK_SPEED := 1.5
## The lowest it is drawn in the game, however low the height cap (m).
const MIN_HEIGHT_M := 0.1
## The floor swirl: how high over the floor (m), how many bands, how far it
## winds (turns) and turns (times the spin).
const SWIRL_LIFT_M := 0.04
const SWIRL_BANDS := 3
const SWIRL_TWIST := 1.2
const SWIRL_SPIN := 0.6
## The grains: how long each lives (s), how wide they spray (the cone),
## how hard they fall (m/s2 at size 1) and how much faster than the bands
## they swirl.
const GRAIN_LIFE_S := 0.9
const GRAIN_CONE := 0.85
const GRAIN_GRAVITY := 1.5
const GRAIN_SWIRL := 1.5

## When the move's hit marker falls: seconds after the cast (the clip's
## start), before the preset's trigger offset.
var impact_s := 0.0
## The knobs it is drawn with, read each frame.
var preset: FxPreset = default_preset()
## The move's hit area its ground footprint is ratios of (FxReach.hit_of:
## {reach_m}): the lab's from the page; in the game the channel's radius_m
## (set_channel, boons included). {} draws at FxReach.REFERENCE's.
var hit := {}

var _base := Vector3.ZERO
## The ground it stands on (set_ground; null: level, world up) and the up
## at its foot as last drawn.
var _ground: Ground
var _up := Vector3.UP
var _ribbon := FxRibbon.new(true)
var _swirl := FxRibbon.new(true)
var _debris := FxDebris.new()
var _grains := FxParticles.new()
var _drawn: Array = []
## The CPU twin of the frame last drawn (drawn()), worked out only when
## asked: the shaders shape what is seen, and the twin, a knot at a time,
## cost the game milliseconds a frame for nothing (perf pass 15).
var _twin := Callable()
var _fade := 0.0
## The game's channel (set_channel): whether it steers this one, whether he
## channels, its radius (m), its length (s after the cast), the height cap
## (m), the cast drawn (its seed) and when its channel ended (s after the
## cast; INF while it runs), and the preset fitted to it (cached per key).
var _in_game := false
var _channel_on := false
var _channel_radius := 0.0
var _channel_length_s := 0.0
var _height_cap := 0.0
var _seed := -1
var _end_s := INF
var _fitted: FxPreset
var _fitted_key: Array = []
var _sized := FxReach.Sized.new()


## Builds its blocks (the spiral, the floor swirl, the debris, the grains),
## its see-through ones drawn under the enemies' telegraphs.
func _init() -> void:
	name = "Tornado"
	_swirl.name = "FloorSwirl"
	_grains.name = "Grains"
	_grains.set_flat(true)
	for block: Node in [_swirl, _ribbon, _debris, _grains]:
		add_child(block)
	for drawn: MeshInstance3D in _ribbon.passes() + _swirl.passes():
		drawn.material_override.render_priority = GroundDrawOrder.PLAYER_EFFECTS
	_grains.material_override.render_priority = GroundDrawOrder.PLAYER_EFFECTS


## The sensible default (target_sand-tornado_v1): saved as DEFAULT_NAME.
static func default_preset() -> FxPreset:
	var out := FxPreset.new()
	out.recipe = RECIPE
	out.core_colour = Color(0.98, 0.84, 0.55)
	out.edge_colour = Color(0.78, 0.55, 0.28)
	out.size = 1.0
	out.form_s = 0.3
	out.hold_s = 1.9
	out.fade_s = 0.4
	out.intensity = 1.0
	# The mage's tornado hits on its first frame: formed 0.3 s after it.
	out.trigger_offset_s = 0.3
	out.knobs = {"bands": 6, "height_m": 6.0, "foot_x": 1.0, "flare_x": 1.3, "spin": 0.8, "rocks": 14,
		"grains": 96, "twist": 1.4, "band_m": 0.35, "streaks": 5, "opacity": 0.95, "wobble_m": 0.1,
		"floor_swirl_x": 1.0, "rock_size_m": 0.3, "rock_rise_m_s": 1.2, "grain_speed": 2.5, "grain_size_m": 0.05}
	return out


## The preset's own knobs, any it lacks (saved before a knob was added) at
## the default's, its ratios of the reach in metres (FxReach.knobs_of: a
## look drawn for its hit keeps its own).
static func own_knobs(look: FxPreset) -> Dictionary:
	return FxReach.knobs_of(look)


## Its top's centre over a base at `base`, standing along `up`.
static func top_of(look: FxPreset, base: Vector3, up: Vector3 = Vector3.UP) -> Vector3:
	return base + up * float(own_knobs(look)["height_m"]) * look.size


## The flat tones, the opacity and the phase every cel ribbon of it shares.
static func _cel(look: FxPreset, now: Dictionary) -> Dictionary:
	var own := own_knobs(look)
	var out := FxRibbon.default_shape()
	out["restrike"] = 0.0
	out["sag"] = 0.0
	out["converge"] = 0.0
	out["strand_flash"] = 0.0
	out["flicker"] = 0.0
	out["tip_glow"] = 0.0
	out["branch_dim"] = 1.0
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
	out["progress"] = float(now["reach"])
	out["fade"] = float(now["fade"])
	return out


## The spiral's ribbon shape from the preset `look` in `now` (a phase).
static func shape(look: FxPreset, now: Dictionary) -> Dictionary:
	var own := own_knobs(look)
	var wobble := float(own["wobble_m"]) * look.size
	var out := _cel(look, now)
	out["strands"] = clampi(int(own["bands"]), 1, 9)
	out["radial_min"] = EYE
	# Its outer band's wobble stays inside the drawn radius.
	out["spread"] = maxf(float(own["radius_m"]) * look.size - wobble, 0.0)
	out["spread_near"] = float(own["base_m"]) * look.size
	out["spread_curve"] = FLARE
	out["twist"] = float(own["twist"])
	out["twist_speed"] = float(own["spin"])
	out["jitter"] = wobble
	out["jitter_scale"] = 0.3
	out["octaves"] = 1
	out["crawl"] = 0.5
	out["width"] = float(own["band_m"]) * look.size
	out["width_tip"] = WIDTH_TOP
	return out


## The floor swirl's ribbon shape (flat, round his feet) in `now`.
static func swirl_shape(look: FxPreset, now: Dictionary) -> Dictionary:
	var own := own_knobs(look)
	var out := _cel(look, now)
	out["strands"] = SWIRL_BANDS
	out["radial_min"] = 0.5
	out["spread"] = float(own["floor_swirl_m"]) * look.size
	out["spread_near"] = float(own["base_m"]) * look.size
	out["spread_curve"] = 0.8
	out["twist"] = SWIRL_TWIST
	out["twist_speed"] = float(own["spin"]) * SWIRL_SPIN
	out["jitter"] = 0.0
	out["width"] = float(own["band_m"]) * 0.8 * look.size
	out["width_tip"] = WIDTH_TOP
	return out


## Each band's knots as drawn `t` seconds after the cast with `seed`, for a
## hit at `hit_s`, round `base`: only as high as it has formed, none before
## its form or once faded; standing along `up`.
static func bands_drawn(look: FxPreset, seed: int, t: float, hit_s: float, base: Vector3,
		up: Vector3 = Vector3.UP) -> Array:
	return _bands_at(look, look.phase(hit_s, t), seed, t, base, up)


## `look` (drawn for the channel's reach: FxReach) fitted to the game's
## channel (set_channel): its top band's edge, its rocks and its grains no
## higher than `height_cap_m`; its grains born all through a channel of
## `length_s` (s after the cast, for a hit at `hit_s`).
static func fitted(look: FxPreset, height_cap_m: float, length_s: float, hit_s: float) -> FxPreset:
	var out := look.duplicate(true) as FxPreset
	var size := maxf(look.size, 0.001)
	var own := own_knobs(look)
	out.knobs = own.duplicate()
	var top_half_width := float(own["band_m"]) * size * WIDTH_TOP
	out.knobs["height_m"] = maxf(minf(float(own["height_m"]), (height_cap_m - top_half_width) / size), MIN_HEIGHT_M)
	# A grain rises at most its speed for its life.
	out.knobs["grain_speed"] = minf(float(own["grain_speed"]), height_cap_m / (size * GRAIN_LIFE_S))
	out.hold_s = maxf(look.hold_s, length_s - look.impact_at(hit_s))
	return out


## Its knots in phase `now` (FxPreset.phase's), standing along `up`.
static func _bands_at(look: FxPreset, now: Dictionary, seed: int, t: float, base: Vector3,
		up: Vector3 = Vector3.UP) -> Array:
	if now["name"] == "before" or now["name"] == "over":
		return []
	var drawn_shape := shape(look, now)
	var top := top_of(look, base, up)
	var out := []
	for band in int(drawn_shape["strands"]):
		var knots := PackedVector3Array()
		for i in FxRibbon.SEGMENTS + 1:
			var along := float(i) / FxRibbon.SEGMENTS
			if along > float(now["reach"]) + 0.0001:
				break
			knots.append(FxRibbon.point(drawn_shape, base, top, along, band, seed, t))
		out.append(knots)
	return out


## The rocks (FxDebris' knobs): riding inside the bands, turning with them.
static func debris_knobs(look: FxPreset) -> Dictionary:
	var own := own_knobs(look)
	var out := FxDebris.default_knobs()
	out["count"] = int(own["rocks"])
	out["size_m"] = float(own["rock_size_m"]) * look.size
	out["radius_near_m"] = float(own["base_m"]) * look.size
	out["radius_far_m"] = float(own["radius_m"]) * 0.85 * look.size
	out["height_m"] = float(own["height_m"]) * 0.9 * look.size
	out["turns_per_s"] = float(own["spin"])
	out["rise_m_s"] = float(own["rock_rise_m_s"]) * look.size
	out["colour_dark"] = look.edge_colour.darkened(0.7)
	out["colour_light"] = look.edge_colour.darkened(0.35)
	return out


## The sand grains (FxParticles' knobs): kicked up from his feet all
## through its form and hold, swirling up (`up`) and out.
static func grain_knobs(look: FxPreset, up: Vector3 = Vector3.UP) -> Dictionary:
	var own := own_knobs(look)
	var out := FxParticles.default_knobs()
	out["count"] = int(own["grains"])
	out["spawn_s"] = look.form_s + look.hold_s
	out["speed_m_s"] = float(own["grain_speed"]) * look.size
	out["speed_jitter"] = 0.6
	out["life_s"] = GRAIN_LIFE_S
	out["life_jitter"] = 0.5
	out["cone"] = GRAIN_CONE
	out["gravity_m_s2"] = GRAIN_GRAVITY * look.size
	out["size_m"] = float(own["grain_size_m"]) * look.size
	out["dir"] = up
	out["up"] = up
	out["swirl"] = float(own["spin"]) * GRAIN_SWIRL
	return out


## Its foot (world): the caster's feet. It turns with the world, not with
## his facing (`_facing` is MageModel's, for recipes turned with him).
func set_base(at: Vector3, _facing: Basis = Basis.IDENTITY) -> void:
	_base = at


## The ground under it (MageModel's, the lab's floor; null: level): it
## stands along the up there at its foot, read each frame it draws.
## `_level_y` is the recipes' shared signature (unused: the up is enough).
func set_ground(ground: Ground, _level_y: float = 0.0) -> void:
	_ground = ground


## The up it stands along now: its ground's at its foot (world up with none).
func up() -> Vector3:
	return _up


## The game's channel this frame (MageModel; the lab never calls it):
## `channel` the cast's ({on (he channels), radius_m, length_s}; {} once
## the move is over), under a height cap of `height_cap_m` (m, [look]
## tornado_height_m).
func set_channel(channel: Dictionary, height_cap_m: float) -> void:
	_in_game = true
	_height_cap = height_cap_m
	_channel_on = bool(channel.get("on", false))
	if channel.has("radius_m"):
		_channel_radius = float(channel["radius_m"])
		_channel_length_s = float(channel.get("length_s", 0.0))
		hit = {"reach_m": _channel_radius, "arc_deg": FxReach.FULL_ARC}


## The preset drawn: its ratios times the hit's reach (FxReach.drawn), in
## the game fitted to his channel too (fitted).
func drawn_preset() -> FxPreset:
	var sized := _sized.of(preset, hit)
	if not _in_game:
		return sized
	var key := [sized, _height_cap, _channel_length_s, impact_s]
	if _fitted == null or key != _fitted_key:
		_fitted = fitted(sized, _height_cap, _channel_length_s, impact_s)
		_fitted_key = key
	return _fitted


## Its phase `t` seconds after the cast with `seed`: the preset's (grill
## Q7); in the game held while he channels and faded over fade_s from the
## channel's end.
func _now(look: FxPreset, seed: int, t: float) -> Dictionary:
	var now := look.phase(impact_s, t)
	if not _in_game:
		return now
	if seed != _seed:
		_seed = seed
		_end_s = INF
	if not _channel_on and _end_s == INF:
		_end_s = t
	if now["name"] == "before":
		return now
	if t < _end_s:
		return now if now["name"] == "form" else {"name": "hold", "reach": 1.0, "fade": 1.0}
	var left := 1.0 - (t - _end_s) / maxf(look.fade_s, 0.001)
	if left <= 0.0:
		return {"name": "over", "reach": 1.0, "fade": 0.0}
	return {"name": "fade", "reach": now["reach"], "fade": left}


## Draws the frame `t` seconds after a cast with `seed`, with the preset's
## knobs as they are now (in the game, fitted to his channel).
func show_at(seed: int, t: float) -> void:
	var look := drawn_preset()
	var now := _now(look, seed, t)
	var on: bool = now["name"] != "before" and now["name"] != "over"
	_fade = float(now["fade"]) if on else 0.0
	var own := own_knobs(look)
	_up = _ground.up_at(_base) if _ground != null else Vector3.UP
	var frame := FxDebris.frame_along(_up)
	_twin = _bands_at.bind(look, now, seed, t, _base, _up)
	_ribbon.visible = on
	_swirl.visible = on and float(own["floor_swirl_m"]) > 0.0
	var since := t - (look.impact_at(impact_s) - look.form_s)
	_debris.show_at(debris_knobs(look), seed, since, _base,
		float(now["reach"]) * float(now["fade"]) if on else 0.0, frame)
	if on:
		var grain := look.core_colour.lerp(look.edge_colour, 0.4)
		# Flat grains: full colour while it shows (they shrink as they die, and
		# none are born once it fades).
		_grains.show_at(grain_knobs(look, _up), seed, since, _base, Color(grain, 1.0))
	else:
		_grains.visible = false
	if not on:
		return
	var reach := maxf(float(own["radius_m"]), float(own["floor_swirl_m"])) * look.size + float(own["band_m"]) * 2.0 * look.size
	var bounds := AABB(_base - Vector3(reach, 0.5, reach),
		Vector3(reach * 2.0, float(own["height_m"]) * look.size + 1.5, reach * 2.0))
	if not _up.is_equal_approx(Vector3.UP):
		# Leaning with a curved ground: a box round it whatever its up.
		bounds = AABB(_base, Vector3.ZERO).grow(maxf(reach, float(own["height_m"]) * look.size + 1.5))
	_ribbon.show_shape(shape(look, now), _base, top_of(look, _base, _up), seed, t)
	_swirl.show_shape(swirl_shape(look, now), _base + _up * SWIRL_LIFT_M,
		_base + _up * (SWIRL_LIFT_M * 3.0), seed + 1, t)
	# Wider than a bolt's bounds: the shader spreads the bands out to its radius.
	for drawn: MeshInstance3D in _ribbon.passes() + _swirl.passes():
		drawn.custom_aabb = bounds


## When the whole effect is over (s after the cast): formed, held and faded.
func end_time() -> float:
	return impact_time() + preset.hold_s + preset.fade_s


## Whether it shows now (forming, held or fading).
func shown() -> bool:
	return _ribbon.visible


## How full it shows now: 1 formed or held, falling to 0 as it fades.
func fade() -> float:
	return _fade


## When it has formed (s after the cast): the hit plus the trigger offset.
func impact_time() -> float:
	return preset.impact_at(impact_s)


## Where it stands: round its caster's feet.
func impact_point() -> Vector3:
	return _base


## The bands drawn now (their knots, world).
func drawn() -> Array:
	return _twin_drawn()


## Its spiral (the ribbon, cel).
func ribbon() -> FxRibbon:
	return _ribbon


## The swirl on the floor round its foot (the ribbon, cel, flat).
func floor_swirl() -> FxRibbon:
	return _swirl


## The rocks riding the spiral.
func debris() -> FxDebris:
	return _debris


## The sand grains swirling up it.
func grains() -> FxParticles:
	return _grains


## drawn(): the twin worked out now if a frame was drawn since it last was.
func _twin_drawn() -> Array:
	if _twin.is_valid():
		_drawn = _twin.call()
		_twin = Callable()
	return _drawn
