## The time slow (GLOSSARY: Recipe; VFX all-spells ticket 06): the mage's
## ultimate. Its default, "time slow - default", is today's look
## (HourglassLook before the switch, with [look] hourglass_size,
## hourglass_shatter_s and the two markers' values): a see-through
## sand-gold hourglass standing round him whose sand pours as the cast
## charges; as the slow begins the pour finishes and the glass shatters;
## then a faint one stays over him for the rest of his slow ("I'm in ult").
## Built from:
##   - the hourglass: HourglassLook's glass, bulbs, sand and shards (the
##     game's own piece, drawn here from the recipe's phases; its own
##     sparkles off), tinted in the preset's colours;
##   - sparkles climbing the glass while it pours: the particles block
##     (FxParticles, its soft additive dots);
##   - a pulse thrown out as it shatters: the burst block (FxBurst), off by
##     default (today's has none).
## No screen tint of its own: the slow's sand-gold tint over the screen is
## the HUD's (UltimateHud, from the world's slow, the same on every peer),
## so the recipe adds no screen-covering layer (perf rule 5).
##
## Phases (grill Q7): the IMPACT is the move's hit marker (the cast's
## completing tick) plus the trigger offset. The sand pours over form_s up
## to it (POUR_AT_CAST_END of it run through), then over shatter_s the
## pour finishes and the glass breaks; the marker fades in over
## marker_in_s, holds, and fades over fade_s. In the lab it holds for
## hold_s; in the game (set_slow) for as long as his slow runs, and none
## of it shows once a hit broke the cast. Drawn only from (preset, seed,
## time) and its centre, and in the game the slow's synced state: any frame
## in any order, the same on every peer and replay. Its preset is re-read
## every frame it draws. Looks only: the simulation never reads it.
class_name FxTimeSlow
extends Node3D

## The recipe its presets are saved under (FxPresets), and its first one.
const RECIPE := "time_slow"
const DEFAULT_NAME := "time slow - default"
## Its own knobs the lab shows: knob -> [label, min, max, step]. With the
## core set and the colours, 14 in all (spec story 25); the rest sit under
## the panel's Advanced (ADVANCED_KNOBS).
const KNOBS := {
	"height_m": ["Hourglass height (m)", 0.5, 8.0, 0.05],
	"shatter_s": ["Shatter (s)", 0.05, 3.0, 0.01],
	"marker": ["Marker over your mage (0 off)", 0.0, 1.0, 0.01],
	"marker_other": ["Marker over the others' (0 off)", 0.0, 1.0, 0.01],
	"sparkles": ["Sparkles", 0, FxParticles.MAX, 1],
	"shards": ["Shards", 0, HourglassLook.SHARDS, 1],
}
## Its own knobs under Advanced, the same way.
const ADVANCED_KNOBS := {
	"marker_in_s": ["Marker fade-in (s)", 0.0, 2.0, 0.01],
	"sparkle_life_s": ["Sparkle life (s)", 0.1, 2.0, 0.01],
	"sparkle_size_m": ["Sparkle size (m)", 0.01, 0.3, 0.005],
	"pulse_m": ["Pulse at the shatter (m, 0 off)", 0.0, 10.0, 0.05],
	"pulse_s": ["Pulse length (s)", 0.05, 2.0, 0.01],
}
## Of the sand, the share poured by the impact; the rest pours in the first
## POUR_FINISH_SHARE of the shatter, then the glass breaks (HourglassLook's).
const POUR_AT_CAST_END := HourglassLook.POUR_AT_CAST_END
const POUR_FINISH_SHARE := HourglassLook.POUR_FINISH_SHARE
## The sparkles: born round the glass's foot, this share of its height out,
## climbing about this share of its height over their life, in a narrow cone.
const SPARKLE_RING := 0.3
const SPARKLE_CLIMB := 0.9
const SPARKLE_CONE := 0.12
## The pulse: how high up the glass (share of its height).
const PULSE_UP := 0.5
## The most the sparkles' and pulse's brightness grows with intensity.
const MOST_ALPHA := 2.0

## When the move's hit marker falls: seconds after the cast (the clip's
## start), before the preset's trigger offset.
var impact_s := 0.0
## The knobs it is drawn with, read each frame (its default first).
var preset: FxPreset = default_preset()

var _centre := Vector3.ZERO
## The ground under him (set_ground; null: level): the hourglass, its
## sparkles and pulse stand along its up at his feet, read each frame.
var _ground: Ground
var _glass := HourglassLook.new()
var _sparkles := FxParticles.new()
var _pulse := FxBurst.new()
var _state := {"phase": "", "pour": 0.0, "shatter": 0.0, "opacity": 0.0}
## The game's slow (set_slow; {} in the lab), the cast it was seen for (its
## seed) and when his slow was first seen over (s after the cast; INF while
## it runs).
var _slow := {}
var _seed := -1
var _end_s := INF


## Builds its blocks (the hourglass, the sparkles, the pulse), drawn under
## the enemies' telegraphs, hidden until a cast.
func _init() -> void:
	name = "TimeSlow"
	_glass.top_level = true
	_glass.drop_sparkles()
	_sparkles.name = "Sparkles"
	_pulse.name = "Pulse"
	for block: Node in [_glass, _sparkles, _pulse]:
		add_child(block)
	_sparkles.material_override.render_priority = GroundDrawOrder.PLAYER_EFFECTS + 1
	_pulse.material_override.render_priority = GroundDrawOrder.PLAYER_EFFECTS + 1


## The sensible default from today's look (HourglassLook, the [look]
## hourglass values: 1.6 times his 1.9 m, shattering over 0.5 s, markers
## 0.2 over yours and 0.1 over the others', fading in over 15 ticks; its
## 20 sparkles over the cast, its 24 shards): saved as DEFAULT_NAME.
static func default_preset() -> FxPreset:
	var out := FxPreset.new()
	out.recipe = RECIPE
	# HourglassLook's sand and frame.
	out.core_colour = Color(1.0, 0.8, 0.42)
	out.edge_colour = Color(1.0, 0.8, 0.38)
	out.size = 1.0
	# The pour over the whole cast (mage.cfg's cast_frames: 0.4 s).
	out.form_s = 0.4
	# The lab's stand-in for his slow (the game holds it while the slow runs).
	out.hold_s = 1.0
	out.fade_s = 0.2
	out.intensity = 1.0
	out.trigger_offset_s = 0.0
	out.knobs = {"height_m": 3.04, "shatter_s": 0.5, "marker": 0.2, "marker_other": 0.1, "sparkles": 20,
		"shards": HourglassLook.SHARDS, "marker_in_s": 0.25, "sparkle_life_s": 0.6, "sparkle_size_m": 0.18,
		"pulse_m": 0.0, "pulse_s": 0.4}
	return out


## The preset's own knobs, any it lacks (saved before a knob was added) at
## the default's.
static func own_knobs(look: FxPreset) -> Dictionary:
	return default_preset().knobs.merged(look.knobs, true)


## The hourglass's height (m).
static func height_of(look: FxPreset) -> float:
	return maxf(0.1, float(own_knobs(look)["height_m"]) * look.size)


## What the hourglass shows `t` s after the cast with its hit at `hit_s`
## (HourglassLook.show_state's): {phase "" | "cast" | "shatter" | "marker",
## pour, shatter, opacity}. `slow`: the game's ({} in the lab: the marker
## held for hold_s; see set_slow), `end_s` when his slow was seen over.
static func glass_at(look: FxPreset, hit_s: float, t: float, slow: Dictionary = {}, end_s: float = INF) -> Dictionary:
	var none := {"phase": "", "pour": 0.0, "shatter": 0.0, "opacity": 0.0}
	var own := own_knobs(look)
	var impact := look.impact_at(hit_s)
	if t < 0.0:
		return none
	if not slow.is_empty() and not slow.get("cast", false) and not slow.get("fired", false):
		# A hit broke the cast (or it is long over): nothing.
		return none
	if t < impact:
		var reach := 1.0 if look.form_s <= 0.0 else clampf(1.0 - (impact - t) / look.form_s, 0.0, 1.0)
		return {"phase": "cast", "pour": POUR_AT_CAST_END * reach, "shatter": 0.0, "opacity": 1.0}
	var shatter_s := maxf(float(own["shatter_s"]), 0.001)
	if t < impact + shatter_s:
		var k := (t - impact) / shatter_s
		return {"phase": "shatter", "pour": lerpf(POUR_AT_CAST_END, 1.0, clampf(k / POUR_FINISH_SHARE, 0.0, 1.0)),
			"shatter": clampf((k - POUR_FINISH_SHARE) / (1.0 - POUR_FINISH_SHARE), 0.0, 1.0), "opacity": 1.0}
	var since := t - impact - shatter_s
	var held_until := look.hold_s if slow.is_empty() else (INF if is_inf(end_s) else maxf(end_s - impact - shatter_s, 0.0))
	var fade := 1.0
	if since > held_until:
		fade = 0.0 if look.fade_s <= 0.0 else 1.0 - (since - held_until) / look.fade_s
	if fade <= 0.0:
		return none
	var faint := float(own["marker" if slow.get("own", true) else "marker_other"])
	var fade_in := 1.0 if float(own["marker_in_s"]) <= 0.0 else clampf(since / float(own["marker_in_s"]), 0.0, 1.0)
	var opacity := faint * fade_in * fade
	if opacity <= 0.0:
		return none
	return {"phase": "marker", "pour": 1.0, "shatter": 0.0, "opacity": opacity}


## The sparkles (FxParticles' knobs): born round the glass's foot over
## form_s up to the impact, climbing it.
## `up`: the ground's up at his feet (world up on level ground).
static func sparkle_knobs(look: FxPreset, up: Vector3 = Vector3.UP) -> Dictionary:
	var own := own_knobs(look)
	var height := height_of(look)
	var life := maxf(float(own["sparkle_life_s"]), 0.01)
	var out := FxParticles.default_knobs()
	out["count"] = int(own["sparkles"])
	out["spawn_s"] = maxf(look.form_s, 0.0)
	out["speed_m_s"] = height * SPARKLE_CLIMB / life
	out["speed_jitter"] = 0.5
	out["life_s"] = life
	out["life_jitter"] = 0.3
	out["cone"] = SPARKLE_CONE
	out["gravity_m_s2"] = 0.0
	out["size_m"] = float(own["sparkle_size_m"]) * look.size
	out["dir"] = up
	out["up"] = up
	out["ring_m"] = height * SPARKLE_RING
	return out


## The pulse (FxBurst's knobs): none at 0.
static func pulse_knobs(look: FxPreset) -> Dictionary:
	var own := own_knobs(look)
	return {"radius_m": float(own["pulse_m"]) * look.size, "length_s": float(own["pulse_s"])}


## Its centre (world): the caster's feet.
func set_centre(centre: Vector3) -> void:
	_centre = centre


## The ground under him (MageModel's; the lab's floor; null: level): it
## stands along the up there (the lava ball's, playtest 2026-10-25 #12).
## `_level_y` is the recipes' shared signature (unused).
func set_ground(ground: Ground, _level_y: float = 0.0) -> void:
	_ground = ground


## The game's slow for this player (PlayerAvatar; {} in the lab): {cast
## (he casts it now, unbroken), fired (his cast completed), on (his slow
## still runs: the world's slow and his share of it), own (this peer's own
## mage: the marker's own opacity, else the others')}.
func set_slow(slow: Dictionary) -> void:
	_slow = slow


## Draws the frame `t` seconds after a cast with `seed`, with the preset's
## knobs as they are now.
func show_at(seed: int, t: float) -> void:
	if seed != _seed:
		_seed = seed
		_end_s = INF
	if not _slow.is_empty() and not _slow.get("on", true) and is_inf(_end_s) and t >= impact_time():
		_end_s = t
	var own := own_knobs(preset)
	_state = glass_at(preset, impact_s, t, _slow, _end_s)
	var up := _ground.up_at(_centre) if _ground != null else Vector3.UP
	# Turned onto the up, keeping the size it is drawn at (HourglassLook sets
	# it only when it changes).
	_glass.transform = Transform3D(FxDebris.frame_along(up) * Basis.from_scale(_glass.scale), _centre)
	_glass.set_colours(preset.core_colour, preset.edge_colour)
	_glass.set_shards(int(own["shards"]))
	_glass.show_state(_state, height_of(preset), {"hourglass_size": 1.0})
	var alpha := clampf(preset.drawn_intensity(), 0.0, MOST_ALPHA)
	var start := impact_time() - maxf(preset.form_s, 0.0)
	if _state["phase"] == "cast" or (_state["phase"] == "shatter" and t - start >= 0.0):
		_sparkles.show_at(sparkle_knobs(preset, up), seed, t - start, _centre, Color(preset.core_colour.lerp(Color.WHITE, 0.3),
			0.8 * alpha))
	else:
		_sparkles.visible = false
	if _state["phase"] == "":
		_pulse.visible = false
	else:
		var ring := preset.core_colour.lerp(Color.WHITE, 0.4)
		_pulse.show_at(pulse_knobs(preset), t - impact_time(), _centre + up * height_of(preset) * PULSE_UP,
			Color(ring, alpha))


## When the slow begins (s after the cast): the hit plus the trigger offset.
func impact_time() -> float:
	return preset.impact_at(impact_s)


## When the whole effect is over in the lab (s after the cast): the glass
## broken, the marker held for hold_s and faded.
func end_time() -> float:
	var own := own_knobs(preset)
	return impact_time() + maxf(float(own["shatter_s"]), 0.0) + preset.hold_s + preset.fade_s


## Whether any of it shows now.
func shown() -> bool:
	return _glass.visible or _sparkles.visible or _pulse.visible


## What the hourglass shows now (glass_at).
func glass() -> Dictionary:
	return _state


## Where it plays: round his feet, its centre.
func impact_point() -> Vector3:
	return _centre


## The hourglass.
func hourglass() -> HourglassLook:
	return _glass


## The sparkles.
func sparkles() -> FxParticles:
	return _sparkles


## The pulse.
func pulse() -> FxBurst:
	return _pulse
