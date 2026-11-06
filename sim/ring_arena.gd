## The volcano's ring arena as the simulation sees it (zone SOP step 6a;
## docs/zones/volcano.md): a flat ring of rock between the central lava pit
## (`[ring] pit_radius_m`) and the outer lava (`outer_radius_m`), two bridge
## strips across the outer lava (the entrance at +Z, 4 lavafall lanes wide;
## the exit, entrance 2, toward the ash forest: VolcanoZone.ring_exit_deg,
## -Z without one), rock pillars standing on the ring, lava vents, the
## lavafall's two burning outer lanes, and the spots enemies climb out of
## the lava from. Ground points are Vector2(x, z), as in the game's simulation. Pure
## static functions of the tuning (the whole set of values by section) and
## the pillars' state, so rollback replays agree.
##
## Angles (deg) run from the entrance (+Z) toward +X: a point at angle a,
## r metres out, is Vector2(sin a, cos a) * r.
##
## Pillars' state (the game's simulation `pillars`): one {hits, down} per pillar spot:
## hits = golem slams taken since it last stood up; down = ticks until it
## stands again (0 = standing). While down it is a stump anyone walks over;
## over its last rise_frames ticks the rising telegraph shows. A missing
## entry counts as standing.
class_name RingArena
extends RefCounted

## Where the exit bridge (entrance 2) leaves the ring (deg from +Z toward
## +X): straight back, as the game draws it with no zone round the ring.
const EXIT_DEG := 180.0

## How far a body's centre is kept from a standing pillar's side (m): about
## a character's radius.
const BODY_M := 0.4
## How far each bridge reaches back into the ring (m), so the strip and the
## ring join without a seam.
const BRIDGE_OVERLAP_M := 1.0
## push_out's margin past a pillar's reach (m) beyond which it skips them.
const PUSH_CLEAR_M := 0.05
## Fliers stay this far inside the cave wall (m).
const WALL_MARGIN_M := 0.5
## A walker steers round a pillar this far ahead of it (m).
const LOOK_AHEAD_M := 3.0
## Rerolls for a lava spawn spot clear of the bridges and the players.
const SPOT_TRIES := 16

## The volcano page's keys by section, as [kind, min, max] (Tuning.SCHEMA).
const KEYS := {
	"ring": {
		"outer_radius_m": ["number", 5.0, 200.0],
		"pit_radius_m": ["number", 0.0, 100.0],
		"outer_lava_width_m": ["number", 0.5, 100.0],
		"exit_bridge_width_m": ["number", 0.5, 50.0],
	},
	"pillar": {
		"count": ["whole number", 0, 12],
		"width_m": ["number", 0.2, 20.0],
		"height_m": ["number", 0.5, 30.0],
		"first_angle_deg": ["number", 0.0, 360.0],
		"hits_to_break": ["whole number", 1, 100],
		"respawn_s": ["number", 0.0, 3600.0],
		"rise_telegraph_s": ["number", 0.0, 60.0],
	},
	"vent": {
		"count": ["whole number", 0, 24],
		"radius_m": ["number", 0.1, 10.0],
		"first_angle_deg": ["number", 0.0, 360.0],
		"inset_m": ["number", 0.0, 50.0],
		"cycle_frames": ["whole number", 1, 36000],
		"telegraph_frames": ["whole number", 0, 36000],
		"damage": ["whole number", 0, 100000],
		"hit_tier": ["choice", Moves.HIT_TIERS],
	},
	"lavafall": {
		"lane_width_m": ["number", 0.2, 10.0],
		"burn_damage": ["whole number", 0, 100000],
		"burn_interval_frames": ["whole number", 1, 3600],
		"hit_tier": ["choice", Moves.HIT_TIERS],
	},
	"lava_spawn": {
		"swell_s": ["number", 0.0, 120.0],
		"no_spawn_radius_m": ["number", 0.0, 100.0],
		"edge_inset_m": ["number", 0.0, 10.0],
		"pit_share": ["number", 0.0, 1.0],
	},
}


static func pit_radius(tuning: Dictionary) -> float:
	return minf(float(tuning["ring"]["pit_radius_m"]), outer_radius(tuning) - 0.5)


static func outer_radius(tuning: Dictionary) -> float:
	return float(tuning["ring"]["outer_radius_m"])


## Where the outer lava meets the cave wall, from the centre.
static func wall_radius(tuning: Dictionary) -> float:
	return outer_radius(tuning) + float(tuning["ring"]["outer_lava_width_m"])


## A ground point `r` metres out at `angle_deg` (see the header's angles).
static func at_angle(angle_deg: float, r: float) -> Vector2:
	var a := deg_to_rad(angle_deg)
	return Vector2(sin(a), cos(a)) * r


# --- Floor ---------------------------------------------------------------------

## The two bridge strips: [{name, dir (outward unit), from_m, to_m (along
## dir, from the centre), half_width_m}]: the entrance (+Z) four lavafall
## lanes wide, the exit (entrance 2: at VolcanoZone.ring_exit_deg, the
## ring's point nearest the ash forest; -Z without one)
## `exit_bridge_width_m` wide. Both reach the cave wall, where the zone's
## tunnels go on.
##
static func bridges(tuning: Dictionary) -> Array:
	return _bridges(tuning)


static func _bridges(tuning: Dictionary) -> Array:
	var from := outer_radius(tuning) - BRIDGE_OVERLAP_M
	var to := wall_radius(tuning)
	return [
		{"name": "entrance", "dir": Vector2(0, 1), "from_m": from, "to_m": to,
			"half_width_m": 2.0 * float(tuning["lavafall"]["lane_width_m"])},
		{"name": "exit", "dir": at_angle(EXIT_DEG, 1.0), "from_m": from, "to_m": to,
			"half_width_m": float(tuning["ring"]["exit_bridge_width_m"]) / 2.0},
	]


## True when `point` stands on the ring or a bridge.
static func on_floor(tuning: Dictionary, point: Vector2) -> bool:
	var r := point.length()
	if r >= pit_radius(tuning) - 0.0001 and r <= outer_radius(tuning) + 0.0001:
		return true
	return on_bridge(tuning, point)


## True when `point` stands on one of the ring arena's bridges.
static func on_bridge(tuning: Dictionary, point: Vector2) -> bool:
	for bridge: Dictionary in bridges(tuning):
		if _in_strip(bridge, point, 0.0001):
			return true
	return false


## `point` moved onto the ring or a bridge (players and walking enemies):
## unchanged on it, else the nearest point of it. Nothing ever ends up over
## the lava: every slide stops here.
static func clamp_walker(tuning: Dictionary, point: Vector2) -> Vector2:
	if on_floor(tuning, point):
		return point
	var r := point.length()
	var dir := point / r if r > 0.000001 else Vector2(0, 1)
	var best := dir * clampf(r, pit_radius(tuning), outer_radius(tuning))
	for bridge: Dictionary in bridges(tuning):
		var d: Vector2 = bridge["dir"]
		var across := Vector2(-d.y, d.x)
		var along := clampf(point.dot(d), float(bridge["from_m"]), float(bridge["to_m"]))
		var side := clampf(point.dot(across), -float(bridge["half_width_m"]), float(bridge["half_width_m"]))
		var on_bridge := d * along + across * side
		if point.distance_squared_to(on_bridge) < point.distance_squared_to(best):
			best = on_bridge
	return best


## `point` kept inside the cave (fliers: the bats fly over the pit and the
## outer lava, never through the wall).
static func clamp_flier(tuning: Dictionary, point: Vector2) -> Vector2:
	var reach := wall_radius(tuning) - WALL_MARGIN_M
	return point.limit_length(reach)


static func _in_strip(bridge: Dictionary, point: Vector2, slack: float) -> bool:
	var d: Vector2 = bridge["dir"]
	var along := point.dot(d)
	var side := absf(point.dot(Vector2(-d.y, d.x)))
	return along >= float(bridge["from_m"]) - slack and along <= float(bridge["to_m"]) + slack \
		and side <= float(bridge["half_width_m"]) + slack


## The ring's middle (the pillars stand on it).
static func mid_radius(tuning: Dictionary) -> float:
	return (pit_radius(tuning) + outer_radius(tuning)) / 2.0


## True when a rack's pedestal may stand at `point` (Racks.fits): on the
## ring `margin_m` clear of both lava edges (never on a bridge), and
## `clearance_m` beyond the side of
## every pillar spot (standing or a broken stump: it stands again; left
## out without `pillars`) and the edge of every vent.
static func rack_fits(tuning: Dictionary, point: Vector2, margin_m: float, clearance_m: float,
		pillars: bool = true) -> bool:
	var r := point.length()
	var lo := pit_radius(tuning) + margin_m
	if r < lo - 0.0001 or r > maxf(lo, outer_radius(tuning) - margin_m) + 0.0001:
		return false
	var pillar := pillar_radius(tuning) + clearance_m - 0.0001
	for spot in pillar_spots(tuning) if pillars else PackedVector2Array():
		if point.distance_squared_to(spot) < pillar * pillar:
			return false
	var vent := float(tuning["vent"]["radius_m"]) + clearance_m - 0.0001
	for spot in vent_spots(tuning):
		if point.distance_squared_to(spot) < vent * vent:
			return false
	return true


# --- Pillars --------------------------------------------------------------------

static func pillar_count(tuning: Dictionary) -> int:
	return int(tuning["pillar"]["count"])


static func pillar_radius(tuning: Dictionary) -> float:
	return float(tuning["pillar"]["width_m"]) / 2.0


## Where each pillar stands: evenly round the ring's middle from
## `first_angle_deg`.
## The spots are kept for the last count, first angle and middle radius
## asked (the page's three numbers, read each call, so an edited page moves
## them at once): every walk, sight line, push and dive lane round the
## pillars asks them, several times per enemy per tick, and laying them out
## (eight angles, each with its page reads) was most of each answer (perf
## pass 19: the ring's swarm).
static func pillar_spots(tuning: Dictionary) -> PackedVector2Array:
	var count := pillar_count(tuning)
	var first := float(tuning["pillar"]["first_angle_deg"])
	var mid := mid_radius(tuning)
	if count == _spots_count and first == _spots_first and mid == _spots_mid:
		# A copy: a packed array is shared, and a caller may change its own.
		return _spots.duplicate()
	var spots := PackedVector2Array()
	for i in count:
		spots.append(at_angle(first + 360.0 * i / count, mid))
	_spots_count = count
	_spots_first = first
	_spots_mid = mid
	_spots = spots.duplicate()
	return spots


## pillar_spots' last answer and the three numbers it was laid out from.
static var _spots := PackedVector2Array()
static var _spots_count := -1
static var _spots_first := NAN
static var _spots_mid := NAN


## Every pillar standing, as a run starts.
static func fresh_pillars(tuning: Dictionary) -> Array:
	var pillars: Array = []
	for i in pillar_count(tuning):
		pillars.append({"hits": 0, "down": 0})
	return pillars


## Ticks a broken pillar lies before it stands again (`respawn_s`), and the
## last ticks of that during which its rising telegraph shows.
static func respawn_frames(tuning: Dictionary) -> int:
	return maxi(1, roundi(float(tuning["pillar"]["respawn_s"]) * MoveKit.TICK_HZ))


static func rise_frames(tuning: Dictionary) -> int:
	return roundi(float(tuning["pillar"]["rise_telegraph_s"]) * MoveKit.TICK_HZ)


static func is_standing(pillars: Array, i: int) -> bool:
	return i >= pillars.size() or int(pillars[i].get("down", 0)) <= 0


## True while pillar `i` lies broken with its rising telegraph showing.
static func is_rising(tuning: Dictionary, pillars: Array, i: int) -> bool:
	return not is_standing(pillars, i) and int(pillars[i]["down"]) <= rise_frames(tuning)


## `point` pushed out of every standing pillar to `body_m` past its side
## (straight out from the pillar's centre; from the arena's centre out if it
## stands exactly on it).
## A point farther than `reach` + PUSH_CLEAR_M off the pillars' circle
## (the ring's middle) is clear of every pillar: it comes back as it is,
## the spots unasked (perf pass 16: the ash forest's crowd asks it per enemy
## per tick).
static func push_out(tuning: Dictionary, pillars: Array, point: Vector2, body_m: float = BODY_M) -> Vector2:
	var reach := pillar_radius(tuning) + body_m
	if absf(point.length() - mid_radius(tuning)) > reach + PUSH_CLEAR_M:
		return point
	var spots := pillar_spots(tuning)
	for i in spots.size():
		if not is_standing(pillars, i):
			continue
		var away := point - spots[i]
		if away.length_squared() >= reach * reach:
			continue
		var dir := away.normalized() if away.length_squared() > 0.000001 else spots[i].normalized()
		point = spots[i] + dir * reach
	return point


## True when a standing pillar stands across the line from `a` to `b`
## (line of sight).
static func line_blocked(tuning: Dictionary, pillars: Array, a: Vector2, b: Vector2) -> bool:
	return not pillars_across(tuning, pillars, a, b).is_empty()


## The indices of the standing pillars across the line from `a` to `b`.
## Every pillar stands on the ring's middle circle: a line wholly farther
## off it than a pillar's radius (+ PUSH_CLEAR_M), out past it or in
## within it, crosses none, unmeasured (since ticket 04 the crowd's sight
## lines out in the zone ask this every tick, ~30 us each).
static func pillars_across(tuning: Dictionary, pillars: Array, a: Vector2, b: Vector2) -> Array:
	var across: Array = []
	var radius := pillar_radius(tuning)
	var mid := mid_radius(tuning)
	if _segment_distance(a, b, Vector2.ZERO) > mid + radius + PUSH_CLEAR_M \
			or maxf(a.length(), b.length()) < mid - radius - PUSH_CLEAR_M:
		return across
	var spots := pillar_spots(tuning)
	for i in spots.size():
		if is_standing(pillars, i) and _segment_distance(a, b, spots[i]) < radius:
			across.append(i)
	return across


## How far (m, up to `length`) one can go from `from` along `dir` before
## reaching a standing pillar's side: a bat's dive lane stops there.
static func reach_along(tuning: Dictionary, pillars: Array, from: Vector2, dir: Vector2, length: float) -> float:
	var radius := pillar_radius(tuning)
	# Out of reach of the pillars' circle (they stand round the ring's
	# middle): none in the way, nothing measured (a push in the ash forest
	# asked every pillar; tactics speed pass, 2026-10-27).
	if from.length() > mid_radius(tuning) + radius + length + FAR_SLACK_M:
		return maxf(0.0, length)
	var spots := pillar_spots(tuning)
	var best := length
	var d := dir.normalized() if dir.length_squared() > 0.000001 else Vector2(0, -1)
	for i in spots.size():
		if not is_standing(pillars, i):
			continue
		var to_c := spots[i] - from
		if to_c.length_squared() <= radius * radius:
			return 0.0
		var t := to_c.dot(d)
		var miss2 := to_c.length_squared() - t * t
		if t <= 0.0 or miss2 >= radius * radius:
			continue
		best = minf(best, t - sqrt(radius * radius - miss2))
	return maxf(0.0, best)


## reach_along's margin past the pillars' circle (m).
const FAR_SLACK_M := 0.01


## The index of the standing pillar whose side is within `range_m` of
## `at` (a golem slam's reach overlapping it), all of them: [index].
static func pillars_in_reach(tuning: Dictionary, pillars: Array, at: Vector2, range_m: float) -> Array:
	var hit: Array = []
	var spots := pillar_spots(tuning)
	var radius := pillar_radius(tuning)
	for i in spots.size():
		if is_standing(pillars, i) and at.distance_to(spots[i]) <= range_m + radius:
			hit.append(i)
	return hit


static func _segment_distance(a: Vector2, b: Vector2, c: Vector2) -> float:
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 0.000001 else clampf((c - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (a + ab * t).distance_to(c)


# --- Steering --------------------------------------------------------------------

## One step of `step_m` from `from` toward `to`, steering round what stands
## in the way: the pit (`around_pit`, walkers: along the pit's edge the
## shorter way round, when the straight line crosses it) and the standing
## pillars (sliding along the side facing the goal). The result is not
## clamped; the game's simulation clamps every enemy after it acts.
static func steer(tuning: Dictionary, pillars: Array, from: Vector2, to: Vector2, step_m: float,
		around_pit: bool) -> Vector2:
	var want := to - from
	if want.length_squared() < 0.000001 or step_m <= 0.0:
		return from
	var dir := want.normalized()
	if around_pit and pit_radius(tuning) > 0.0 and from.length() > 0.000001 \
			and _segment_distance(from, to, Vector2.ZERO) < pit_radius(tuning) + BODY_M:
		var cross := from.x * to.y - from.y * to.x
		var tangent := Vector2(-from.y, from.x).normalized()
		dir = tangent if cross >= 0.0 else -tangent
	var reach := pillar_radius(tuning) + BODY_M
	var ahead := from + dir * minf(LOOK_AHEAD_M, want.length())
	# Every pillar stands on the ring's middle circle: a look-ahead wholly
	# farther off it than `reach` (+ PUSH_CLEAR_M), out past it or in within
	# it, comes near none, unmeasured (perf pass 19: the swarm steers here
	# every tick).
	var mid := mid_radius(tuning)
	if _segment_distance(from, ahead, Vector2.ZERO) > mid + reach + PUSH_CLEAR_M \
			or maxf(from.length(), ahead.length()) < mid - reach - PUSH_CLEAR_M:
		return from + dir * minf(step_m, want.length())
	var spots := pillar_spots(tuning)
	var nearest := -1
	for i in spots.size():
		if not is_standing(pillars, i) or _segment_distance(from, ahead, spots[i]) >= reach:
			continue
		if nearest < 0 or from.distance_squared_to(spots[i]) < from.distance_squared_to(spots[nearest]):
			nearest = i
	if nearest >= 0:
		var away := from - spots[nearest]
		var v := away.normalized() if away.length_squared() > 0.000001 else spots[nearest].normalized()
		var side := Vector2(-v.y, v.x)
		dir = side if side.dot(dir) >= 0.0 else -side
	return from + dir * minf(step_m, want.length())


# --- Vents ------------------------------------------------------------------------

## Where each vent opens: evenly round the ring from `first_angle_deg`,
## alternately `inset_m` in from the pit's edge and from the outer edge.
static func vent_spots(tuning: Dictionary) -> PackedVector2Array:
	var spots := PackedVector2Array()
	var vent: Dictionary = tuning["vent"]
	var count := int(vent["count"])
	for i in count:
		var r := pit_radius(tuning) + float(vent["inset_m"]) if i % 2 == 0 \
			else outer_radius(tuning) - float(vent["inset_m"])
		spots.append(at_angle(float(vent["first_angle_deg"]) + 360.0 * i / count, r))
	return spots


## Ticks until vent `i` erupts when the vent clock (the game's simulation `vent_clock`:
## ticks the vents have run so far) reads `clock`; 0 = it erupts on this
## clock. The vents take turns: vent i is `i * cycle / count` ticks into the
## cycle, and each erupts first a whole cycle after its turn starts.
static func vent_left(tuning: Dictionary, i: int, clock: int) -> int:
	var vent: Dictionary = tuning["vent"]
	var cycle := int(vent["cycle_frames"])
	var since := clock - i * cycle / maxi(1, int(vent["count"]))
	if since <= 0:
		return cycle - since
	var m := since % cycle
	return 0 if m == 0 else cycle - m


# --- Lavafall --------------------------------------------------------------------

## The two burning outer lanes of the entrance bridge, where it crosses the
## outer lava: [{centre, size (across, along)}], as rectangles with sides
## along X and Z (the entrance runs along +Z).
static func lavafall_lanes(tuning: Dictionary) -> Array:
	var lane := float(tuning["lavafall"]["lane_width_m"])
	var from := outer_radius(tuning)
	var to := wall_radius(tuning)
	var lanes: Array = []
	for side: float in [-1.0, 1.0]:
		lanes.append({"centre": Vector2(side * 1.5 * lane, (from + to) / 2.0), "size": Vector2(lane, to - from)})
	return lanes


static func in_lavafall(tuning: Dictionary, point: Vector2) -> bool:
	for lane: Dictionary in lavafall_lanes(tuning):
		var half: Vector2 = Vector2(lane["size"]) / 2.0
		var d: Vector2 = point - Vector2(lane["centre"])
		if absf(d.x) <= half.x and absf(d.y) <= half.y:
			return true
	return false


# --- Lava spawns ---------------------------------------------------------------

## A spot an enemy climbs out of the lava onto the ring, rolled from `rng`:
## the pit's edge (`pit_share` of the time) or the outer edge, `edge_inset_m`
## onto the ring, never where a bridge meets the ring, and outside
## `no_spawn_radius_m` of every point in `away_from` (the players up). After
## SPOT_TRIES rolls with none clear, the last roll.
static func spawn_spot(tuning: Dictionary, rng: RandomNumberGenerator, away_from: Array) -> Vector2:
	var spawn: Dictionary = tuning["lava_spawn"]
	var clear := float(spawn["no_spawn_radius_m"])
	var inner := pit_radius(tuning) + float(spawn["edge_inset_m"])
	var outer := outer_radius(tuning) - float(spawn["edge_inset_m"])
	for attempt in SPOT_TRIES:
		var pit := rng.randf() < float(spawn["pit_share"])
		var spot := at_angle(rng.randf() * 360.0, inner if pit else outer)
		if not pit and _by_a_bridge(tuning, spot):
			continue
		if _clear_of(spot, away_from, clear):
			return spot
	# The rolls all missed: the farthest of the edges' spots, every degree.
	return farthest_from(edge_spots(tuning), away_from)


## Every spot an enemy may climb out of the lava onto the ring, a degree
## apart: the pit's edge and the outer edge (never by a bridge),
## `edge_inset_m` onto the ring, pit then outer at each degree.
static func edge_spots(tuning: Dictionary) -> Array:
	var inset := float(tuning["lava_spawn"]["edge_inset_m"])
	var inner := pit_radius(tuning) + inset
	var outer := outer_radius(tuning) - inset
	var spots: Array = []
	for degree in 360:
		spots.append(at_angle(degree, inner))
		var edge := at_angle(degree, outer)
		if not _by_a_bridge(tuning, edge):
			spots.append(edge)
	return spots


## Of `spots` (at least one), the one farthest from the nearest point of
## `away_from` (the first of equals; none to keep from: the first).
static func farthest_from(spots: Array, away_from: Array) -> Vector2:
	var best: Vector2 = spots[0]
	var best_d := -1.0
	for spot: Vector2 in spots:
		var d := INF
		for p: Vector2 in away_from:
			d = minf(d, spot.distance_to(p))
		if d > best_d:
			best = spot
			best_d = d
	return best


static func _clear_of(spot: Vector2, points: Array, radius: float) -> bool:
	for p: Vector2 in points:
		if spot.distance_to(p) < radius:
			return false
	return true


static func _by_a_bridge(tuning: Dictionary, spot: Vector2) -> bool:
	for bridge: Dictionary in bridges(tuning):
		var d: Vector2 = bridge["dir"]
		if spot.dot(d) > 0.0 and absf(spot.dot(Vector2(-d.y, d.x))) <= float(bridge["half_width_m"]) + 1.0:
			return true
	return false
