## The drawn area matches the hit area (VFX all-spells ticket 15; P-O,
## 2026-10-23: "the area of the spell [should] reflect the area in game... if
## not that will seem unfair"). A preset's ground footprint is ratios of its
## move's real reach from the tuning page, never metres of its own: a knob
## ending "_x" is "times the reach" (TIES), and drawn() turns it into the
## metres the recipe draws (ratio x reach), so tuning the reach scales the
## look in the game and the VFX lab alike. Above the ground the look is free
## (the tornado's top, its height, a slash's height, the grains...).
## The fairness check (check): the drawn edge on the ground (edge_m: the
## outermost of the recipe's EDGES) within `tolerance` of the hit's edge, a
## share either way; the lab warns like the budget (FxBudget).
## The hit (hit_of) comes from the move's data as the simulation holds it
## (MoveKit.move_data: the page's values, boons included in a run): its
## reach_m (REACH_KEYS: a swing's reach_m, a channel's or slam's radius_m,
## the dash's half_width_m, the blink's distance_m) and its arc_deg. A hop's
## (the log roll, all-spells ticket 12) has two lobes, one ahead and one
## behind: its front lobe's reach is its reach_m, its back lobe's
## reach_back_m, each lobe arc_deg wide; both are checked (BACK_EDGES).
## Node-free, pure static. Looks only: the simulation never reads it.
class_name FxReach
extends RefCounted

## _default_knobs_of's: recipe -> its default preset's knobs (or null).
static var _default_knobs := {}

## The fairness check's default tolerance: the drawn ground edge may be this
## share longer or shorter than the hit's (spec: 10%).
const TOLERANCE := 0.1
## The tolerance knob (the lab's check reads it): TOLERANCE unless changed.
## Read through tolerance_now(): a script run before the class's statics are
## set (godot -s) sees 0 here, and gets TOLERANCE.
static var tolerance := TOLERANCE

## Per recipe, each ratio knob: [the metres knob the recipe draws, what it
## is a ratio of]: "reach" (the hit's reach_m), "arc" (its arc_deg), or
## another metres knob (the tornado's top: its foot times its flare).
const TIES := {
	"tornado": {"foot_x": ["base_m", "reach"], "flare_x": ["radius_m", "base_m"],
		"floor_swirl_x": ["floor_swirl_m", "reach"]},
	"ground_shake": {"burst_x": ["burst_m", "reach"], "cracks_x": ["cracks_m", "reach"],
		"dust_x": ["dust_m", "reach"], "dust_ring_x": ["dust_ring_m", "reach"]},
	"whirlwind": {"radius_x": ["radius_m", "reach"], "burst_x": ["burst_m", "reach"],
		"dust_x": ["dust_m", "reach"]},
	"sand_slash": {"radius_x": ["radius_m", "reach"], "arc_x": ["arc_deg", "arc"]},
	"blink": {"burst_x": ["burst_m", "reach"], "puff_x": ["puff_m", "reach"]},
}
## Per recipe with a hit area, the metres knobs drawn on (or over) the
## ground round the hit: its drawn edge is the outermost (edge_m). The
## blink (no hit: it only carries him) and the time slow (the whole map) have
## none, so nothing to check.
const EDGES := {
	"tornado": ["base_m", "floor_swirl_m"],
	"ground_shake": ["burst_m", "cracks_m", "dust_m"],
	"whirlwind": ["radius_m", "burst_m", "dust_m"],
	"sand_slash": ["radius_m"],
}
## Per two-lobe recipe (the log roll's), the metres knobs drawn round its
## back lobe: checked against the hit's reach_back_m as EDGES are against
## its reach_m.
const BACK_EDGES := {
}
## The recipes whose edge is an angle, not a ground edge (all-spells ticket
## 11: the parry's forks fan across his front cone, which has no reach: any
## blow from the front counts): their EDGES are degrees, checked against the
## hit's arc_deg.
const ANGLE_EDGES: Array[String] = ["parry"]
## The reach a recipe is drawn at before its holder gives its move's (the
## frozen tuning copy's, 2026-10-23): a node shown alone still draws its size.
const REFERENCE := {
	"tornado": {"reach_m": 3.0, "arc_deg": 360.0},
	"ground_shake": {"reach_m": 4.4, "arc_deg": 360.0},
	"whirlwind": {"reach_m": 2.8, "arc_deg": 360.0},
	"sand_slash": {"reach_m": 2.4, "arc_deg": 150.0},
	"blink": {"reach_m": 7.0, "arc_deg": 360.0},
}
## The move data's key holding its reach, first found first (the throw's:
## the blades' hit body round them, the key a reach boon scales).
## A shot's: its body (its range is carried beside it, hit_of); a lob's its burst,
## radius_m; a tidal wave's the circle it turns in.
## A ring of orbiting bubbles' its ring.
const REACH_KEYS: Array[String] = ["reach_m", "radius_m", "half_width_m", "distance_m", "blade_radius_m", "shot_radius_m",
	"wave_reach_m", "ring_radius_m"]
## The rest of a hit's shape a recipe draws from, handed on as the page has it: a
## tidal wave's and its mines', a bubble ring's. A pack's tie may name one as what
## its ratio knob is "times" of (ties_of).
const CARRIED_KEYS: Array[String] = ["wave_cast_s", "wave_turn_s", "wave_width_m", "wave_count", "wave_length_m",
	"wave_offset_m", "wave_spread_deg", "mine_count", "mine_lifetime_s", "mine_cap", "ring_turn_deg_per_s",
	"bubble_radius_m", "bubbles", "recharge_s"]
## A tidal wave's inner end, its length and where its tip comes out: its hit's
## TIP_KEY, the wave's own edge beside the circle it turns in.
const WAVE_OFFSET_KEY := "wave_offset_m"
const WAVE_LENGTH_KEY := "wave_length_m"
const TIP_KEY := "wave_tip_m"
## What a ratio knob may be "times" of the hit's (else a key the hit carries, or
## another drawn knob).
const HIT_BASES: Array[String] = ["reach", "back", "arc"]
## A full circle, the arc of a hit with none of its own (a channel, a slam).
const FULL_ARC := 360.0
## A hop's data keys holding its two lobes (the log roll: Moves.HOP rows),
## and each lobe's width.
const FRONT_KEY := "reach_front_m"
const BACK_KEY := "reach_back_m"
const LOBE_ARC_KEY := "lobe_arc_deg"
## The parry's data key holding its cone ([duelist.parry]: how far either
## side of his facing a blow counts as from the front), the key its reach
## slider edits.
const CONE_KEY := "front_half_angle_deg"


## The hit area of a move from its data (MoveKit.move_data): {reach_m,
## arc_deg}; {} for a move with no reach (the time slow; the fusion carries the greatsword's: FxMoves.data_of). A throw's also
## carries where its blades fly (all-spells ticket 10): range_m, and
## flight_s (its lock: out and back, Moves.LOCK_FRAMES in seconds). The
## parry's (its kit's [parry] data, MoveKit.parry_data; ticket 11): its
## front cone, arc_deg twice CONE_KEY, with no reach. A hop's (the log
## roll; ticket 12): its front lobe's reach as reach_m, its back lobe's as
## reach_back_m, each lobe's width as arc_deg.
static func hit_of(data: Dictionary) -> Dictionary:
	if data.has(CONE_KEY):
		return {"reach_m": 0.0, "arc_deg": 2.0 * float(data[CONE_KEY])}
	if data.has(FRONT_KEY):
		return {"reach_m": float(data[FRONT_KEY]), "reach_back_m": float(data.get(BACK_KEY, data[FRONT_KEY])),
			"arc_deg": float(data.get(LOBE_ARC_KEY, FULL_ARC))}
	for key: String in REACH_KEYS:
		if data.has(key):
			var out := {"reach_m": float(data[key]), "arc_deg": float(data.get("arc_deg", FULL_ARC))}
			if Moves.is_throw(data):
				out["range_m"] = float(data["range_m"])
				out["flight_s"] = float(Moves.phase_frames(data, Moves.LOCK_FRAMES)) / MoveKit.TICK_HZ
			elif data.has("range_m") and Moves.fires_shots(data):
				out["range_m"] = float(data["range_m"])
			for carried: String in CARRIED_KEYS:
				if data.has(carried):
					out[carried] = data[carried]
			if data.has(WAVE_LENGTH_KEY):
				out[TIP_KEY] = float(data.get(WAVE_OFFSET_KEY, 0.0)) + float(data[WAVE_LENGTH_KEY])
			return out
	return {}


## Whether `recipe`'s move has a hit area its ground edge is checked against.
static func has_hit(recipe: String) -> bool:
	return EDGES.has(recipe)


## `recipe`'s ratio knobs (TIES' row, or its pack's: CharacterPack.fx_recipes);
## {} with none.
static func ties_of(recipe: String) -> Dictionary:
	return TIES.get(recipe, {})


## `recipe`'s ground-edge knobs (EDGES' row, or its pack's); [] with none.
static func edges_of(recipe: String) -> Array:
	return EDGES.get(recipe, [])


## The reach `recipe` is drawn at alone (REFERENCE's row, or its pack's).
static func reference_of(recipe: String) -> Dictionary:
	return REFERENCE.get(recipe, {})


## `recipe`'s sensible default preset (its script's default_preset).
static func default_of(recipe: String) -> FxPreset:
	var script := script_of(recipe)
	return script.default_preset() if script != null else null


## `recipe`'s default preset's knobs (null: none), made once per recipe and
## never changed (perf pass 17: knobs_of runs several times a recipe a
## frame, and a default preset made each time cost ~40 us). Read only.
static func _default_knobs_of(recipe: String) -> Variant:
	if not _default_knobs.has(recipe):
		var fresh := default_of(recipe)
		_default_knobs[recipe] = fresh.knobs if fresh != null else null
	return _default_knobs[recipe]


## The script drawing `recipe` (null: none; the lab's placeholder is its own).
static func script_of(recipe: String) -> GDScript:
	match recipe:
		FxTornado.RECIPE:
			return FxTornado
		FxGroundShake.RECIPE:
			return FxGroundShake
		FxSandSlash.RECIPE:
			return FxSandSlash
		FxWhirlwind.RECIPE:
			return FxWhirlwind
		FxBlink.RECIPE:
			return FxBlink
		FxTimeSlow.RECIPE:
			return FxTimeSlow
	return null


## `look`'s knobs in metres: any it lacks at its recipe's default's, each
## ratio knob's metres (TIES) worked out for `hit` ({reach_m, arc_deg};
## hit_of). With no hit, metres it already holds (a look drawn()) are kept
## and any missing are worked out for its recipe's REFERENCE reach.
static func knobs_of(look: FxPreset, hit: Dictionary = {}) -> Dictionary:
	var fresh: Variant = _default_knobs_of(look.recipe)
	var out: Dictionary = fresh.merged(look.knobs, true) if fresh != null else look.knobs.duplicate()
	var ties := ties_of(look.recipe)
	if ties.is_empty():
		return out
	var at: Dictionary = hit if not hit.is_empty() else reference_of(look.recipe)
	# Ratios of the hit first, then those of another drawn knob (the top).
	for of_hit: bool in [true, false]:
		for knob: String in ties:
			var tie: Array = ties[knob]
			if (tie[1] in HIT_BASES or at.has(tie[1])) != of_hit:
				continue
			if hit.is_empty() and look.knobs.has(tie[0]):
				continue
			out[tie[0]] = float(out[knob]) * _base(tie[1], at, out)
	return out


## What a ratio knob tied to `of` multiplies: the hit's reach, its back
## lobe's (a hop's; its reach without one) or its arc, or the knob `of` in
## `knobs`.
static func _base(of: String, hit: Dictionary, knobs: Dictionary) -> float:
	match of:
		"reach":
			return float(hit["reach_m"])
		"back":
			return float(hit.get("reach_back_m", hit["reach_m"]))
		"arc":
			return float(hit.get("arc_deg", FULL_ARC))
	return float(hit[of]) if hit.has(of) else float(knobs[of])


## `look` as drawn for `hit` ({reach_m, arc_deg}; hit_of): a copy whose
## metres knobs are its ratios times the reach (TIES). A recipe with no ties,
## or no hit, comes back as it is.
static func drawn(look: FxPreset, hit: Dictionary) -> FxPreset:
	if look == null or ties_of(look.recipe).is_empty() or hit.is_empty():
		return look
	var out := look.duplicate(true) as FxPreset
	out.knobs = knobs_of(look, hit)
	return out


## A recipe node's look as drawn (drawn()), made again only when its preset,
## a knob of it or the hit changed: the lab edits a preset in place.
class Sized:
	var _look: FxPreset
	var _key: Array = []

	## `look` drawn for `hit` (its REFERENCE reach with none).
	func of(look: FxPreset, hit: Dictionary) -> FxPreset:
		if look == null or FxReach.ties_of(look.recipe).is_empty():
			return look
		var at: Dictionary = hit if not hit.is_empty() else FxReach.reference_of(look.recipe)
		var key := [look, look.knobs.hash(), look.size, look.form_s, look.hold_s, look.fade_s, look.intensity,
			look.trigger_offset_s, look.core_colour, look.edge_colour, look.bloom, at]
		if _look == null or key != _key:
			_look = FxReach.drawn(look, at)
			_key = key
		return _look


## `look` (in metres, as saved before ticket 15) as ratios of `hit`: the copy
## that draws the same size for that hit (drawn), its metres knobs dropped.
static func to_ratios(look: FxPreset, hit: Dictionary) -> FxPreset:
	var out := look.duplicate(true) as FxPreset
	var ties := ties_of(look.recipe)
	if ties.is_empty() or hit.is_empty():
		return out
	var own := default_of(look.recipe).knobs.merged(look.knobs, true)
	for knob: String in ties:
		var tie: Array = ties[knob]
		var base := _base(tie[1], hit, own)
		out.knobs[knob] = float(own.get(tie[0], 0.0)) / base if base != 0.0 else 0.0
	for knob: String in ties:
		out.knobs.erase(ties[knob][0])
	return out


## The drawn ground edge (m) of `drawn_look` (a look drawn(): in metres):
## the outermost of its recipe's EDGES, times its size; 0 with none. An
## angle edge (ANGLE_EDGES) in degrees, whatever its size.
static func edge_m(drawn_look: FxPreset) -> float:
	return _outermost(drawn_look, edges_of(drawn_look.recipe))


## The drawn ground edge (m) round the back lobe of `drawn_look` (a
## two-lobe recipe's, BACK_EDGES; times its size); 0 with none.
static func back_edge_m(drawn_look: FxPreset) -> float:
	return _outermost(drawn_look, BACK_EDGES.get(drawn_look.recipe, []))


static func _outermost(drawn_look: FxPreset, knobs: Array) -> float:
	var out := 0.0
	for knob: String in knobs:
		out = maxf(out, float(drawn_look.knobs.get(knob, 0.0)))
	return out if drawn_look.recipe in ANGLE_EDGES else out * drawn_look.size


## The fairness check of `look` (as saved: ratios) for `hit`: {ok, drawn_m
## (its ground edge), hit_m (the hit's reach), off (drawn / hit - 1), unit
## ("m"; "deg" for an angle edge: drawn_m its fan, hit_m the hit's arc)}. A
## recipe with no hit area, or no hit, is always fair (nothing to check).
## A two-lobe recipe (BACK_EDGES: the log roll) checks both lobes, each
## against its own reach, and gives the worse, its `lobe` ("front" or
## "back") named.
static func check(look: FxPreset, hit: Dictionary) -> Dictionary:
	if look == null or not has_hit(look.recipe) or hit.is_empty():
		return {"ok": true}
	var angle := look.recipe in ANGLE_EDGES
	var sized := drawn(look, hit)
	var out := _checked(edge_m(sized), float(hit["arc_deg"] if angle else hit["reach_m"]), angle)
	if BACK_EDGES.has(look.recipe):
		out["lobe"] = "front"
		var back := _checked(back_edge_m(sized), float(hit.get("reach_back_m", hit["reach_m"])), false)
		back["lobe"] = "back"
		if absf(float(back["off"])) > absf(float(out["off"])):
			out = back
		out["ok"] = absf(float(out["off"])) <= tolerance_now() + 0.000001
	return _spans_checked(out, sized, hit)


## A pack recipe's `spans` row (metres knob -> the hit's key it must match: a wave's
## tip and the gap at its inner end) checked beside its edge: the worst of them, the
## knob named as `lobe`. Times its size, as an edge is.
static func _spans_checked(out: Dictionary, sized: FxPreset, hit: Dictionary) -> Dictionary:
	var spans: Dictionary = {}
	var worst := out
	for knob: String in spans:
		var span := _checked(float(sized.knobs.get(knob, 0.0)) * sized.size, float(hit.get(spans[knob], 0.0)), false)
		span["lobe"] = knob
		if absf(float(span["off"])) > absf(float(worst["off"])):
			worst = span
	return worst


## One edge's check: `drawn_m` against `hit_m`.
static func _checked(drawn_m: float, hit_m: float, angle: bool) -> Dictionary:
	var off := drawn_m / hit_m - 1.0 if hit_m > 0.0 else 0.0
	return {"ok": absf(off) <= tolerance_now() + 0.000001, "drawn_m": drawn_m, "hit_m": hit_m, "off": off,
		"unit": "deg" if angle else "m"}


## The tolerance the check uses: the knob, TOLERANCE while it is unset (0).
static func tolerance_now() -> float:
	return tolerance if tolerance > 0.0 else TOLERANCE


## The lab's line for check(): "fair" or the warning, with both edges.
static func describe(result: Dictionary) -> String:
	if not result.has("drawn_m"):
		return "reach: no hit area to match"
	var unit: String = result.get("unit", "m")
	var line := "drawn edge %.2f %s, hit %.2f %s (%+.0f%%, tolerance %.0f%%)" % [result["drawn_m"], unit,
		result["hit_m"], unit, float(result["off"]) * 100.0, tolerance_now() * 100.0]
	if result.has("lobe"):
		line = "%s lobe %s" % [result["lobe"], line]
	return ("fair: " if result["ok"] else "UNFAIR: ") + line
