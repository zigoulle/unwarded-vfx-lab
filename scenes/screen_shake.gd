## The camera shake (front-end ticket 03): a small, chunky jolt on heavy
## moments, your ground shake landing on enemies (your stagger-tier hit),
## being staggered yourself, and a heavy slam landing within the feel page's
## [shake] near_m of you (slam_near: a boss's, its split pieces', the golem's
## staggering slam). Its strength and length are the [shake] knobs (strength
## 0 removes it); the settings' screen-shake toggle (`enabled`, on by
## default) switches it off.
##
## Chunky: the offset jumps to a new random spot STEP_S apart instead of
## sliding, and shrinks to nothing over the length. Presentation only: its
## randomness is its own, never the simulation's, and main.gd adds the
## offset to the local camera only.
class_name ScreenShake
extends RefCounted

## How long the camera holds each jolt before jumping to the next.
const STEP_S := 1.0 / 30.0

## The settings' screen-shake toggle; off, the camera never moves.
var enabled := true

var _strength := 0.0
var _length := 0.0
var _left := 0.0
var _step_left := 0.0
var _jolt := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## Starts a shake from the feel page's [shake] values ({strength_m,
## length_s}); a stronger one running keeps going.
func kick(shake: Dictionary) -> void:
	var strength := float(shake.get("strength_m", 0.0))
	var length := float(shake.get("length_s", 0.0))
	if strength <= 0.0 or length <= 0.0 or (_left > 0.0 and _strength * _left / _length >= strength):
		return
	_strength = strength
	_length = length
	_left = length
	_step_left = 0.0


## Kicks it with every kick `body`'s moves' lab presets gave since the last
## take (CharacterModel.take_shake_kicks: a preset's shake knob, FxShake;
## null: none). Off with the settings' toggle like every other shake.
func take_from(body: CharacterModel) -> void:
	if body == null:
		return
	for shake: Dictionary in body.take_shake_kicks():
		kick(shake)


## The camera's offset this frame, `delta` seconds after the last; zero when
## off or still.
func offset(delta: float) -> Vector3:
	if not enabled:
		_left = 0.0
	if _left <= 0.0:
		return Vector3.ZERO
	_step_left -= delta
	if _step_left <= 0.0:
		_step_left = STEP_S
		var size := _strength * _left / _length
		_jolt = Vector3(_rng.randf_range(-size, size), _rng.randf_range(-size, size), _rng.randf_range(-size, size))
	_left -= delta
	if _left <= 0.0:
		return Vector3.ZERO
	return _jolt


## True if sound cue `cue` (GameAudio.cue_started) from `source` is a heavy
## moment for the window whose own avatar is named `local`: its own
## stagger-tier hit landing (the ground shake). Slams are judged by where
## they land (slam_near), never by their sound.
static func shakes_on(cue: String, source: String, local: String) -> bool:
	return cue == "hit_stagger" and source == local


## True if a heavy slam lands within `tuning["shake"]["near_m"]` of `at` (the
## local player's ground point; measured along `ground`: Ground.distance)
## between two world views' enemy lists
## (GameAudio.world_seen: {type, phase, attack, hp, hitstop, stun, pos}, same
## index and type). Heavy: any slam or sweep by a boss (ProgressMeter.BOSSES,
## each with its `[boss.<type>]` section) or a piece it splits into, or any other slam that staggers (the
## golem's); the core mother's leg's stab shakes less (stab_near). Landed: a
## slam's wind-up ending unbroken (no hitstop, no stun), a sweep's lunge
## reaching the floor (HEAD_LOW).
static func slam_near(before: Array, now: Array, tuning: Dictionary, ground: Ground, at: Vector3) -> bool:
	var near := float(tuning.get("shake", {}).get("near_m", 0.0))
	var bosses := boss_types(tuning)
	for i in mini(before.size(), now.size()):
		var was: Dictionary = before[i]
		var is_now: Dictionary = now[i]
		if was["type"] != is_now["type"] or int(is_now["hp"]) <= 0:
			continue
		var attack: String = was["attack"]
		var landed := false
		if attack == "slam":
			landed = (int(was["phase"]) == CombatSim.ENEMY_WINDUP and is_now["attack"] == ""
				and int(is_now["hitstop"]) == 0 and int(is_now["stun"]) == 0)
		elif attack == "sweep":
			landed = int(was["phase"]) == CombatSim.HEAD_WINDUP and int(is_now["phase"]) == CombatSim.HEAD_LOW
		if not landed:
			continue
		var type: String = is_now["type"]
		var row: Dictionary = tuning.get(Enemies.section_of(type) if Enemies.is_kind(type) else type, {})
		if not (type in bosses or row.get("%s_hit_tier" % attack, "") == "stagger"):
			continue
		if ground.distance(is_now["pos"], at) <= near:
			return true
	return false


## The camera shake for the local player at `at` when a core mother's leg's
## stab lands within `[shake] near_m` of him between two world views' enemy
## lists (as slam_near's; its charge ending in LEG_STUCK): the usual shake at
## her leg row's `stab_shake_share` of its strength (P-O 2026-10-28: kept,
## really small); {} for none. The settings' switch holds for it.
static func stab_near(before: Array, now: Array, tuning: Dictionary, ground: Ground, at: Vector3) -> Dictionary:
	var shake: Dictionary = tuning.get("shake", {})
	var near := float(shake.get("near_m", 0.0))
	for i in mini(before.size(), now.size()):
		var was: Dictionary = before[i]
		var is_now: Dictionary = now[i]
		if not CoreMother.is_leg(str(is_now["type"])) or was["type"] != is_now["type"] or int(is_now["hp"]) <= 0:
			continue
		if was["attack"] != CoreMother.STAB or int(was["phase"]) != CombatSim.LEG_CHARGE \
				or int(is_now["phase"]) != CombatSim.LEG_STUCK:
			continue
		if ground.distance(is_now["pos"], at) <= near:
			return {"strength_m": float(shake.get("strength_m", 0.0))
				* float(tuning.get(CoreMother.LEG, {}).get("stab_shake_share", 0.0)),
				"length_s": float(shake.get("length_s", 0.0))}
	return {}


## How long the planet shakes for the local player at `at` between two world
## views' enemy lists (as slam_near's): the core mother's entrance
## (CoreMother: announced, then up inside the planet) with `at` on the lava
## ball, for her row's `entrance_shake_s`; 0 for none.
static func planet_shook(before: Array, now: Array, tuning: Dictionary, ground: Ground, at: Vector3) -> float:
	if ground == null or ground.area_of(at) != BallGround.BALL:
		return 0.0
	for i in mini(before.size(), now.size()):
		var was: Dictionary = before[i]
		var is_now: Dictionary = now[i]
		if CoreMother.is_mother(str(is_now["type"])) and was["type"] == is_now["type"] \
				and int(was["phase"]) == CombatSim.ENEMY_DORMANT and int(is_now["phase"]) == CombatSim.MOTHER_UNDER:
			return float(tuning.get(CoreMother.TYPE, {}).get("entrance_shake_s", 0.0))
	return 0.0


## The planet's shake for the local player at `at` when the core mother's
## synced steps (EnemyWorld.mother_steps) went from `before` to `now`
## (core-mother ticket 06, ruling 12): a new step, with `at` on the lava
## ball, kicks a shake weaker than the usual ([shake] strength_m x her row's
## `step_shake_share`) for her `step_shake_s`; {} for none. The settings'
## switch holds for it as for every kick.
static func planet_stepped(before: int, now: int, tuning: Dictionary, ground: Ground, at: Vector3) -> Dictionary:
	if now <= before or ground == null or ground.area_of(at) != BallGround.BALL:
		return {}
	var row: Dictionary = tuning.get(CoreMother.TYPE, {})
	return {"strength_m": float(tuning.get("shake", {}).get("strength_m", 0.0)) * float(row.get("step_shake_share", 0.0)),
		"length_s": float(row.get("step_shake_s", 0.0))}


## Every enemy type that is a boss (ProgressMeter.BOSSES with its
## `[boss.<type>]` section in `tuning`) or a piece one splits into
## (Enemies.splits_into, all the way down).
static func boss_types(tuning: Dictionary) -> Array[String]:
	var types: Array[String] = []
	for boss: String in ProgressMeter.BOSSES:
		if not tuning.has(ProgressMeter.boss_section(boss)):
			continue
		var type := boss
		while type != "" and Enemies.TYPES.has(type) and not type in types:
			types.append(type)
			type = Enemies.splits_into(type)
	return types


## True if the local player's synced hit (EnemyWorld player_hit_tick and
## player_hit_state) is a new stagger: `before_tick` last frame, `now_tick`
## and `state` now.
static func staggered(before_tick: int, now_tick: int, state: String) -> bool:
	return now_tick >= 0 and now_tick != before_tick and state == "stagger"
