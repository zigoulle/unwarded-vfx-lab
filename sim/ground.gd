## The ground seam (lava-ball spec "The ground seam"; GLOSSARY: Surface): the
## one module the simulation asks about the ground a run is played on. No
## sim file outside the ground modules does position arithmetic or names a
## zone's layout (test_ground_seam_guard.gd keeps it so); CombatSim holds
## the run's Ground (`sim.ground`, the zone's: `of`).
##
## The questions, in terms of ground points and a character's heading (and
## `reframe`, a 2D direction in one thing's frame as another's):
## - Shape: curved, curved_at (the views bend what they draw on it), in_sight
##   (what its curve hides from a camera).
## - Frame and moving: up_at, heading_at, carry; walk (a 2D step in a character's frame,
##   carried over the surface, the heading carried along) and offset (a
##   spot that far off a point, no heading carried).
## - Measuring: local (where `to` lies seen from `from` in its frame,
##   measured along the surface), distance, distance_squared (for orderings
##   and thresholds only), within, cell_of (a coarse grid's cell),
##   maybe_within (its quick first test).
## - Bounds: clamp_walker, clamp_flier, clamp_to_floor, push_out (pillars),
##   on_floor, walkable.
## - Hazards: lava_tier_at, harmful_at, the vents (vent_spots, vent_left),
##   the lavafall (in_lavafall), the climb's lava flows (flow_channels) and
##   the dripping sky (drips_fall, drip_spot), and a content zone's own
##   (fresh_hazards, step_hazards, hazard_marks).
## - Places: spawning_section, areas, area_of, surface_areas, on_surface_of, roams_at, tab_map, portals, start_spot / start_facing / start_heading,
##   spawn_spot, and racks (rack_fits, rack_spot, rack_facing,
##   pedestal_row).
## - Pillars and sight: fresh_pillars, pillar_count, pillar_respawn_frames,
##   pillar_hits_to_break, pillar_feet, pillar_standing, pillar_rising,
##   line_blocked, pillars_across, reach_along, pillars_in_reach, steer.
## - Routes: flow_field, flow_route (the flow field, FlowField: where a
##   chasing enemy walks round what stands in its way).
##
## The 2D frame: a step or a `local` answer is CombatSim's ground plane, x
## right and y back (its -y is the heading), as SurfaceGravity.on_surface.
## A ground point is a surface point (Vector3, ADR 0006); every character
## and moving thing carries a heading (a unit tangent there), and its down
## is -up_at where it stands, never stored. On the level ground every
## heading is the world's -Z, `local` is plain subtraction and `walk` plain
## addition in the x/z plane: bit for bit the arithmetic of the 2D
## simulation it replaced.
## Node-free and deterministic: pure functions of the tuning and their
## arguments, so rollback replays agree.
@abstract
class_name Ground
extends RefCounted

## The lava under a point (lava_tier_at), deepest last: none (rock),
## shallow (wades, burns), deep (wades slowly, burns more), sea (a wall).
const TIER_NONE := ""
const TIER_SHALLOW := "shallow"
const TIER_DEEP := "deep"
const TIER_SEA := "sea"


## The zone a run plays in (`[run] zone`, set by `playing`): the volcano,
## its level ground and the lava ball on top of it (ZoneGround). One zone
## today; a run started on the lava ball plays it too (start_areas).
const VOLCANO := "volcano"


## The run's ground: the zone's. The volcano's is ZoneGround (the level
## volcano and the lava ball on top of it, each answering for its own surface
## points); the water zone's comes from the water content, only through its
## registry (WaterRegistry.ground; docs/design/content-switch.md), and a
## water run with no water there (a demo, or no water page) plays the
## volcano's. `tuning` is the world tuning (VolcanoGround.scaled applied).
static func of(tuning: Dictionary) -> Ground:
	if zone_of(tuning) == WaterRegistry.ZONE:
		var water := WaterRegistry.ground(tuning)
		if water:
			return water
		push_warning("a water run with no water content or no water page: playing the volcano")
	return ZoneGround.new(tuning)


## The zone a run on `tuning` plays in: its `[run] zone` (no page holds it:
## the run's start sets it, `playing`), the volcano by default.
static func zone_of(tuning: Dictionary) -> String:
	return str(tuning.get("run", {}).get("zone", VOLCANO))


## The name of `zone`'s own copy of the shared section `base` (`[fatigue]`,
## `[arrival]`, `[danger]`, `[spawning]`): `base` itself in the volcano,
## `[<base>.<zone>]` (on the zone's own page) in another, as its super
## spawner pool's (SuperSpawner.pool_section).
static func zone_section_name(base: String, zone: String) -> String:
	return base if zone == VOLCANO else "%s.%s" % [base, zone]


## The section of `base` a run on `tuning` reads: its zone's own copy
## (zone_section_name) when `tuning` has it, else `base` (the volcano's, and
## a hand-built test tuning's). A loaded copy is whole: the keys its page
## gives over the shared section's (with_zone_copies).
static func zone_section(tuning: Dictionary, base: String) -> String:
	var own := zone_section_name(base, zone_of(tuning))
	return own if tuning.has(own) else base


## The shared sections (on the zones page, Tuning.ZONES_PAGE) a zone's page
## overrides key by key in its copy (zone_section_name): `[spawning.<zone>]
## ramp_cap` alone, the rest from `[spawning]` (P-O 2026-11-05). The super
## spawner's pool is no such section: each zone's has its own kinds.
const ZONE_SHARED: Array[String] = ["spawning", "fatigue", "arrival", "danger", "progress"]


## The shared section (ZONE_SHARED) `section` is a zone's copy of, or "" for
## any other (the lava ball's own `[spawning.ball]` included: an area's whole
## clock, not a zone's copy).
static func shared_of(section: String) -> String:
	# The zones beside the volcano: the water's (through its registry).
	for base: String in ZONE_SHARED:
		if section == zone_section_name(base, WaterRegistry.ZONE):
			return base
	return ""


## `values` (a load's, edited in place) with each zone copy among `sections`
## (shared_of) whole: its shared section's keys, its own page's over them. A
## copy its page leaves out is the shared section's.
static func with_zone_copies(values: Dictionary, sections: Array) -> Dictionary:
	for section: String in sections:
		var shared := shared_of(section)
		if shared != "" and values.has(shared):
			values[section] = (values[shared] as Dictionary).merged(values.get(section, {}), true)
	return values


## `tuning` (not edited) for a run played in `zone` (VOLCANO).
static func playing(tuning: Dictionary, zone: String) -> Dictionary:
	var out := tuning.duplicate()
	out["run"] = {"zone": zone}
	return out


## Where a volcano run may start (start_areas_of; `--start-at=` names one, the
## default first): the zone's areas, the lava ball last (VolcanoZone.AREAS).
## The host rolls each run's from its seed (rolled_start), which reaches every
## peer with the run's players (Lobby.run_players). "Lava ball" is a
## volcano run whose players start in the ball area.
static func start_areas() -> Array[String]:
	return VolcanoZone.AREAS.duplicate()


## The zones a run may be played in (the start choice, the solo pick's and the
## host's lobby's): the volcano, then the water zone while its switch is on
## (WaterRegistry; the volcano alone in a demo).
static func start_zones() -> Array[String]:
	var zones: Array[String] = [VOLCANO]
	if not WaterRegistry.start_areas().is_empty():
		zones.append(WaterRegistry.ZONE)
	return zones


## The areas a run played in `zone` may start in (GLOSSARY: Start area): the
## water zone's through its registry, the volcano's (start_areas, the lava
## ball too) for any other.
static func start_areas_of(zone: String) -> Array[String]:
	if zone == WaterRegistry.ZONE:
		var water := WaterRegistry.start_areas()
		if not water.is_empty():
			return water
	return start_areas()


## The area a run played in `zone` with `run_seed` starts in: one of
## start_areas_of(zone), the same for the same seed on every peer (its own
## generator, so the run's rolls are left alone).
static func rolled_start(zone: String, run_seed: int) -> String:
	var areas := start_areas_of(zone)
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	return areas[rng.randi_range(0, areas.size() - 1)]


## The zone a run started in `area` plays: the water zone for one of its
## areas (WaterRegistry: none in a demo), the volcano for every other.
static func zone_for(area: String) -> String:
	return WaterRegistry.ZONE if WaterRegistry.has_area(area) else VOLCANO


## True for a travel area (GLOSSARY: Travel area): a connector cavern or
## tunnel between main areas (VolcanoZone.TRAVEL_AREAS), which never tires
## (AreaFatigue).
static func is_travel_area(area: String) -> bool:
	return area in VolcanoZone.TRAVEL_AREAS


# --- Frame and moving ----------------------------------------------------------------

## True when any of the ground curves (the zone: the lava ball does).
## A view drawing at a point asks curved_at.
func curved() -> bool:
	return false

## True when the ground curves at `point` (the lava ball): the views stand
## things along its up and lay ground looks along it (SurfaceDraw,
## SurfaceMesh); on the level ground they keep their flat code.
func curved_at(_point: Vector3) -> bool:
	return curved()

## True when the ground stands nowhere across the straight line from `eye`
## (off the surface: a camera) to `point` (on the surface or over it): a
## curved surface hides what lies under its horizon. The level ground hides
## nothing (its cliffs and caves are the views' own fades).
func in_sight(_eye: Vector3, _point: Vector3) -> bool:
	return true

## The unit "up" at `point` (down is its negative).
@abstract func up_at(point: Vector3) -> Vector3

## The heading a thing appearing at `point` carries, and the frame a spot
## laid off `point` is measured in when no one's own heading stands there
## (world -Z on the level ground).
@abstract func heading_at(point: Vector3) -> Vector3

## `heading` (a tangent at `from`) carried along the surface to `to`: what a
## thing moved other than by `walk` (a steer, a push, a clamp) heads then.
@abstract func carry(from: Vector3, heading: Vector3, to: Vector3) -> Vector3

## `dir`, a 2D direction in the frame at `from` heading `from_heading`, as
## the same way on the surface in the frame at `to` heading `to_heading`
## (carried along the surface): a push in the pusher's frame, given to the
## pushed. The identity on the level ground.
@abstract func reframe(from: Vector3, from_heading: Vector3, dir: Vector2, to: Vector3, to_heading: Vector3) -> Vector2

## A walk of `step` (the character's frame: x right, y back) from `point`
## heading `heading`: {position, heading (carried along the step)}.
@abstract func walk(point: Vector3, heading: Vector3, step: Vector2) -> Dictionary

## The spot `step` (the frame at `point` heading `heading`) off `point`: a
## walk's position, for spots laid off a point (a hit point, a summon spot).
@abstract func offset(point: Vector3, heading: Vector3, step: Vector2) -> Vector3


# --- Measuring --------------------------------------------------------------------

## Where `to` lies seen from `from` heading `heading` (the frame's x right,
## y back), measured along the surface: its length is the distance, its
## angle the bearing.
@abstract func local(from: Vector3, heading: Vector3, to: Vector3) -> Vector2

## The distance from `a` to `b` along the surface.
@abstract func distance(a: Vector3, b: Vector3) -> float

## A measure that orders as `distance` does (its square on the level
## ground): for nearest-first and within-reach checks only.
@abstract func distance_squared(a: Vector3, b: Vector3) -> float

## True when `b` lies within `reach` of `a` (distance(a, b) <= reach).
func within(a: Vector3, b: Vector3, reach: float) -> bool:
	return distance(a, b) <= reach


## The cell of a coarse grid of `cell_m` cubes holding `point` (CrowdGrid,
## the crowd's neighbour queries): the straight line between two ground
## points is never longer than the way along the surface, so every point
## within `reach` of `point` lies in the cells up to ceil(reach / cell_m)
## round its own, on every surface.
func cell_of(point: Vector3, cell_m: float) -> Vector3i:
	return Vector3i((point / cell_m).floor())


## False when `b` surely lies farther than `reach` from `a` along the
## ground (the straight line between them is longer): a quick first test
## before measuring (CrowdGrid). True says only that it may lie within.
func maybe_within(a: Vector3, b: Vector3, reach: float) -> bool:
	return a.distance_squared_to(b) <= reach * reach


## Where `point` lies from the way leaving `from` toward `dir` (the frame at
## `from` heading `heading`), along the surface: x how far along it
## (negative behind `from`), y how far off it (right of the way positive).
## Plain projection of `local` here; the ball measures it on its great
## circle (the core mother's beams).
func along_across(from: Vector3, heading: Vector3, dir: Vector2, point: Vector3) -> Vector2:
	var d := dir.normalized() if dir.length_squared() > 0.000001 else Vector2(0, -1)
	var v := local(from, heading, point)
	return Vector2(v.dot(d), v.dot(Vector2(-d.y, d.x)))


# --- Round a curve (the lava ball; the core mother) -------------------------------

## The angle (degrees) between `a` and `b` round the centre of the surface
## they lie on: 0 on a ground that does not curve round one.
func round_deg(_a: Vector3, _b: Vector3) -> float:
	return 0.0


## The distance along the surface at `point` spanning `deg` round its
## centre: INF on a ground that does not curve round one (nothing caps it).
func round_arc_m(_point: Vector3, _deg: float) -> float:
	return INF


## The point straight across the surface's centre from `point` (the ball's
## far side): `point` itself on a ground that does not curve round one.
func far_side(point: Vector3) -> Vector3:
	return point


# --- Bounds -----------------------------------------------------------------------

## `point` moved where a walker (a player, a walking enemy) may be.
@abstract func clamp_walker(point: Vector3) -> Vector3

## `point` kept where a flier (a bat, a fire tornado, a storm) may be.
@abstract func clamp_flier(point: Vector3) -> Vector3

## `point` moved onto floor with no lava (where a potion drops).
@abstract func clamp_to_floor(point: Vector3) -> Vector3

## `point` pushed out of every standing pillar of `pillars` (CombatSim
## `pillars`) to a body's width off its side, and out of the ash forest's
## trunks and fallen logs.
@abstract func push_out(pillars: Array, point: Vector3) -> Vector3


## As push_out, for a flier: it passes over the fallen logs (the trunks and
## pillars still stop it).
func push_out_flier(pillars: Array, point: Vector3) -> Vector3:
	return push_out(pillars, point)


## True when a trunk of the ash forest stands across the line from `a` to
## `b`: a shot stops there (a player's as well as an enemy's; line_blocked
## answers for the enemies' shots and sight). None by default.
func trunk_between(_a: Vector3, _b: Vector3) -> bool:
	return false


## The ash forest's slots whose tree is gone (AshTreant: a treant stood up
## there), as the state being stepped holds them (CombatSim sets them at
## the start of each half of its step): every trunk question (push_out,
## line_blocked, trunk_between, reach_along, steer) skips them. None by
## default (no forest). A ground with no forest may keep its own solids
## that go for the run on the same list (the state's, synced, predicted).
func set_uprooted(_slots: Array) -> void:
	pass


## The slots set_uprooted last set (none by default).
func uprooted() -> Array:
	return []


## The area of the ash forest ("" when none stands).
func forest_area() -> String:
	return ""


## The ash forest's trunk slots, in AshForest.trunks' order: each
## {position (a ground point), radius (its trunk's, m), kind (AshForest.TREE
## or TREANT)}. Callers must not edit them. None by default.
func forest_slots() -> Array:
	return []

## True when `point` is floor (rock, never lava).
@abstract func on_floor(point: Vector3) -> bool

## True when a walker may be at `point` (floor or wadeable lava).
@abstract func walkable(point: Vector3) -> bool


# --- Hazards ----------------------------------------------------------------------

## The lava under `point` (TIER_*), with `world`'s lava (CombatSim state:
## its lava patches, its surge).
@abstract func lava_tier_at(point: Vector3, world: Dictionary = {}) -> String

## True when the ground at `point` burns (any lava tier, a lava patch):
## where a travel move that stops before danger stops.
func harmful_at(point: Vector3, world: Dictionary) -> bool:
	return lava_tier_at(point, world) != TIER_NONE

## How far a travel move that stops before danger (the Duelist's hop, his
## dash) may go from `from` (heading `heading`) along `dir` (a unit 2D
## direction in that frame), at most `length` m, with `world`'s lava (its
## patches, its surge) and standing pillars. The way is sampled every
## SAFE_STEP_M along the surface. Safe floor is walkable and not harmful.
## Begun on safe floor: up to the last safe sample before the first unsafe
## one (short of lava, an edge or a wall) and short of a pillar's side.
## Begun on harmful ground: the distance to the first safe sample, through
## walkable lava only, if one lies within `length`; else 0 (no move).
## `safe_start`: the caller knows `from` is safe floor (not asked again).
func safe_reach(world: Dictionary, from: Vector3, heading: Vector3, dir: Vector2, length: float,
		safe_start: bool = false) -> float:
	var limit := minf(length, reach_along(world.get("pillars", []), from, heading, dir, length))
	var started_safe := safe_start or (walkable(from) and not harmful_at(from, world))
	var gone := 0.0
	while gone < limit:
		var next := minf(limit, gone + SAFE_STEP_M)
		var at := offset(from, heading, dir * next)
		var safe := walkable(at) and not harmful_at(at, world)
		if started_safe and not safe:
			return gone
		if not started_safe and safe:
			return next
		if not started_safe and not walkable(at):
			return 0.0
		gone = next
	return gone if started_safe else 0.0


## The sampling step of safe_reach (m).
const SAFE_STEP_M := 0.05


## Where each vent opens (none on a ground without vents).
@abstract func vent_spots() -> PackedVector3Array

## Ticks until vent `i` erupts with the vent clock at `clock` (0: now).
@abstract func vent_left(i: int, clock: int) -> int

## True when `point` is in the lavafall's burning lanes.
@abstract func in_lavafall(point: Vector3) -> bool

## The climb's lava flow channels (ConeGround.flow_channels; LavaFlows):
## none on a ground without a climb.
func flow_channels() -> Array:
	return []

## True when `point` is under live lava of `world`'s flows (CombatSim
## `flows`; shallow lava, its rock bridges spared).
func in_live_flow(_point: Vector3, _world: Dictionary) -> bool:
	return false

## True when some place of this ground has a current (flowing water that
## drifts whoever stands in it); CombatSim skips the drift otherwise. None
## by default.
func has_current() -> bool:
	return false

## The current at `point`: the drift it carries a walker or a flier there
## by, in m per s in the frame of `heading` (x right, y back). CombatSim
## drifts players (never mid-dodge) and enemies by it each tick.
func current(_point: Vector3, _heading: Vector3) -> Vector2:
	return Vector2.ZERO

## The sim's tick (CombatSim sets it at the start of each half of a step,
## from the state it steps, so a replayed tick sets it again): a ground
## whose solids move with time (moving cover) places them for it before
## push_out, line_blocked and the rest answer. Others ignore it.
func set_clock(_tick: int) -> void:
	pass

## A count that changes whenever this ground's solids moved (set_clock):
## CombatSim's memo of where an enemy may stand starts again when it
## changes. 0 for solids that never move.
func solids_clock() -> int:
	return 0

## True when the sky drips over `area` (Drips; the lava ball's); "" asks
## whether it drips over any of this ground.
func drips_fall(_area: String = "") -> bool:
	return false

## Where a drip marked now lands (Drips), rolled from `rng`: within
## `near_m` of one of `near` (the living players), outside `clear_m` of
## every one of them. A ground with pillars keeps it off them.
func drip_spot(rng: RandomNumberGenerator, near: Array, near_m: float, clear_m: float) -> Vector3:
	var anchor: Vector3 = near[rng.randi_range(0, near.size() - 1)]
	var d := rng.randf_range(minf(clear_m, near_m), near_m)
	return offset(anchor, heading_at(anchor), Vector2.from_angle(rng.randf() * TAU) * d)

## The ground's own hazards, once a tick in the enemy half, after the shared
## ones (CombatSim._step_enemies, after its vents and lavafalls): a ground
## whose areas carry hazards of their own acts on `next` (the state the
## step is making) through `sim`, and lists its events in `events`.
## Deterministic: the same `next` gives the same result on every peer and
## replay. Hazards with state of their own keep it in `next`'s
## `ground_hazards` (fresh_hazards), replaced, never edited (EnemyWorld's
## history keeps the old one); they hurt through `sim`'s hazard hits
## (CombatSim._hazard_hits). None by default.
func step_hazards(_sim: CombatSim, _next: Dictionary, _events: Array) -> void:
	pass


## The ground's own hazards' state at a run's start (a content zone's: the
## shared sim names none of them), seeded from `rng_seed`, kept as CombatSim
## `ground_hazards` and stepped by step_hazards. {} for a ground with none
## (the volcano's): no `ground_hazards` key at all.
func fresh_hazards(_rng_seed: int) -> Dictionary:
	return {}


## The ground marks the ground's own hazards lay now in `hazards` (CombatSim
## `ground_hazards`), for the wire and the shared telegraph look
## (HazardMarkLooks): [{kind (the hazard's name, for its own look),
## position (a ground point), radius_m, lands_tick, lead (ticks from the
## mark's opening to its landing)}]. None by default.
func hazard_marks(_hazards: Dictionary) -> Array:
	return []


# --- Places -----------------------------------------------------------------------

## The tuning section holding `area`'s spawning clock (SpawnGrid: the time
## scalar and the player factor; "" the zone's): the volcano's `[spawning]`.
func spawning_section(_area: String = "") -> String:
	return "spawning"

## The ground's areas, in order (kill counts, spawn grids).
@abstract func areas() -> Array[String]

## The area `point` lies in ("" none).
@abstract func area_of(point: Vector3) -> String

## The areas on the same surface as `area` (all of them on a ground of one
## surface; the level volcano's for "" or an area outside every surface).
func surface_areas(_area: String) -> Array[String]:
	return areas()

## True when `point` lies on the surface holding `area` (always, on a ground
## of one surface): who counts toward an area's player factor (SpawnGrid).
func on_surface_of(_point: Vector3, _area: String) -> bool:
	return true

## True when an enemy at `point` roams (enemy-tactics ruling 7; Leash): it
## notices players by its aggro range, chases them anywhere it walks to on
## this ground and walks home past the leash; a player at `point` can be
## chased there. True by default; the lava ball keeps its area rule (its
## enemies go for whoever stands on it, and nothing follows onto it).
func roams_at(_point: Vector3) -> bool:
	return true


## What the Tab map draws of this ground (GroundMap; SOP step 6a), asked once
## per ground: every area needs a shape on it (test_water_tab_map fails on one
## with none). `tuning` is the view's. None by default.
func tab_map(_tuning: Dictionary) -> GroundMap:
	return GroundMap.new()


## The zone's portals (GLOSSARY: Portal; volcano-climb spec "Portals"):
## [{area (where it stands), to (the area it leads to), spot (its middle),
## heading (the heading at it), door (the way its doorway faces: a world
## direction at it, for the looks), arrival (where a player stepping into
## it lands), arrival_heading, arrival_facing (in the arrival's frame)}].
## None by default.
func portals() -> Array:
	return []


## The portal (one of portals) a player standing at `point` steps into: by
## default the first whose spot lies within `radius_m` of him (`[portal]
## radius_m`); {} for none. A ground whose doorway is wider than a spot (the
## whirlpool's mouth, a band round its wall) answers its own way.
func portal_into(point: Vector3, radius_m: float) -> Dictionary:
	for portal: Dictionary in portals():
		if within(point, portal["spot"], radius_m):
			return portal
	return {}


## Where player `i` of `count` starts a run begun in `area`, `spacing_m`
## apart (side by side across the way they face on the level ground; round
## the pole on the ball).
@abstract func start_spot(i: int, count: int, spacing_m: float, area: String) -> Vector3

## The way the players face (their frame's 2D facing) as a run begun in
## `area` starts.
@abstract func start_facing(area: String) -> Vector2

## The heading player `i` of `count` (start_spot's) carries as a run begun
## in `area` starts.
@abstract func start_heading(i: int, count: int, spacing_m: float, area: String) -> Vector3

## A spot an enemy may appear at in `area`, rolled from `rng`, clear of
## every point of `away_from` (the players up); `near` (the players up in
## `area`) where the area spawns near the party.
@abstract func spawn_spot(area: String, rng: RandomNumberGenerator, away_from: Array, near: Array = []) -> Vector3

## How far apart an arrival batch's enemies form (arrival_spots), while the
## band has room.
const ARRIVAL_SPACING_M := 2.0

## The spots an arrival batch's `count` enemies (ArrivalBatch) form at in
## `area`, rolled from `rng`: `band.x` to `band.y` m from `from` (the player
## walking in), where the area's own spawns stand (spawn_spot's floor, off
## the lava), off the pillars as the area's own spawns keep off them (the
## flat zones: every standing pillar of `pillars`; the lava ball: every
## pillar's foot, standing or not, as its spawn and drip spots), outside the no-spawn
## radius of every point of `away_from` (the players up), and
## ARRIVAL_SPACING_M from one another and every point of `taken` (falling
## big drips) while the band has room. When nothing of the area lies in
## the band, the clear spot nearest it (apart from the others where one is).
@abstract func arrival_spots(area: String, rng: RandomNumberGenerator, from: Vector3, band: Vector2, count: int,
		away_from: Array, taken: Array, pillars: Array) -> Array

## True when a rack's pedestal may stand at `point` (safe floor).
@abstract func rack_fits(point: Vector3) -> bool

## True when a pedestal may stand at `point` with `world` (CombatSim state)
## as it is now: on the flat zones always (their racks keep only to
## rack_fits); the ball keeps them off its drip pools and blob trails.
func rack_clear(_point: Vector3, _world: Dictionary) -> bool:
	return true

## True when the super spawner's body may stand at `point` once the trees
## and pillars there are cleared (SuperSpawner; P-O, 2026-10-24): rack_fits
## with the ash forest's trunks and every pillar left out (the forest's logs,
## the vents, the lava and the edges still count). rack_fits by default.
func spawner_fits(point: Vector3) -> bool:
	return rack_fits(point)

## True when a super spawner here pours only the kinds its area's spawn grid
## row has a rate above 0 for (SuperSpawner.pour): a zone whose areas keep
## their own rosters. False by default: the volcano's spawner draws from its
## whole pool in any area (grill Q8).
func spawner_keeps_to_area_rows() -> bool:
	return false

## A random spot in `area` a rack may try, rolled from `rng`.
@abstract func rack_spot(area: String, rng: RandomNumberGenerator) -> Vector3

## The way a rack centred at `centre` must face where its area says so
## (the ring's rows face the pit); Vector2.ZERO where any way will do.
@abstract func rack_facing(centre: Vector3) -> Vector2

## The `count` pedestals of a rack centred on `centre` facing `facing`: a
## row across `facing`, `spacing_m` apart, laid along the surface.
@abstract func pedestal_row(centre: Vector3, facing: Vector2, count: int, spacing_m: float) -> PackedVector3Array


# --- Pillars and sight ------------------------------------------------------------

## Every pillar standing, as a run starts (CombatSim `pillars`).
@abstract func fresh_pillars() -> Array

@abstract func pillar_count() -> int

## Ticks broken pillar `i` lies before it stands again.
@abstract func pillar_respawn_frames(i: int = 0) -> int

## Golem slams that break pillar `i`.
@abstract func pillar_hits_to_break(i: int = 0) -> int

## Where each pillar stands (its foot on the surface), by index.
@abstract func pillar_feet() -> PackedVector3Array

## True when pillar `i` of `pillars` stands (not broken; past the list: standing).
func pillar_standing(pillars: Array, i: int) -> bool:
	return RingArena.is_standing(pillars, i)

## True while pillar `i` of `pillars` lies broken with its rising warning
## showing (the last stretch before it stands again).
@abstract func pillar_rising(pillars: Array, i: int) -> bool

## Ticks pillar `i`'s rising warning lasts (pillar_rising's stretch). None
## by default.
func pillar_rise_frames(_i: int = 0) -> int:
	return 0

## True when something stands across the line from `a` to `b` (a standing
## pillar, a wall between areas).
@abstract func line_blocked(pillars: Array, a: Vector3, b: Vector3) -> bool

## The indices of the standing pillars across the line from `a` to `b`.
@abstract func pillars_across(pillars: Array, a: Vector3, b: Vector3) -> Array

## How far (up to `length`) one gets from `from` along `dir` (the frame
## there heading `heading`) before a standing pillar's side.
@abstract func reach_along(pillars: Array, from: Vector3, heading: Vector3, dir: Vector2, length: float) -> float

## The standing pillars whose side is within `range_m` of `at`.
@abstract func pillars_in_reach(pillars: Array, at: Vector3, range_m: float) -> Array

## One step of `step_m` from `from` toward `to` round what stands in the
## way (the pillars; a walker, `around_pit`, round the pit). Not clamped.
@abstract func steer(pillars: Array, from: Vector3, to: Vector3, step_m: float, around_pit: bool) -> Vector3


# --- Routes -----------------------------------------------------------------------

## The flow field toward `root` (a ground point: where a chased player
## stood), `reach_m` out, with the shallow and deep lava costing `shallow`
## and `deep` times rock and the standing pillars of `pillars` (CombatSim
## `pillars`) and trunks laid on it (FlowField; enemy-tactics ruling 6):
## the same one for the same arguments while the ground keeps it, unfinished
## until worked (FlowField.work, finish). null where the ground has none
## (by default; the level volcano has them).
func flow_field(_root: Vector3, _pillars: Array, _reach_m: float, _shallow: float, _deep: float) -> FlowField:
	return null


## How many cells of a flow field lie within `reach_m` of its root each
## way (the square they span): what working it out that far costs.
func flow_cells_within(reach_m: float) -> float:
	var across := 2.0 * reach_m / FlowField.CELL_M + 1.0
	return across * across


## Where an enemy at `from` walks on `field` (flow_field's, finished)
## instead of straight at its goal: a ground point to steer toward, or null
## to walk straight (its way is free, or the field does not reach it).
## `before` is what it answered last tick for that enemy (null: none).
func flow_route(_field: FlowField, _from: Vector3, _before: Variant) -> Variant:
	return null
