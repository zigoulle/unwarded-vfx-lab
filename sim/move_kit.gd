## The Mage's moves as frames (the lab's stand-in for the game's combat
## simulation, which it does not carry): built from the merged tuning
## (Tuning.parse), each move's phases in frames at 60 a second (Moves.KINDS),
## how far it carries him, and the rows his looks read. The lab plays a move
## with no simulation running: these answers are what the game's own
## simulation gives for the same pages, on open floor.
##
## Node-free. Looks only: nothing here moves anyone.
class_name MoveKit
extends RefCounted

## The game's simulation rate (ticks a second).
const TICK_HZ := Moves.TICK_HZ

## The tuning this kit plays (its tempo and heavy area applied).
var _tuning: Dictionary = {}
## Move name -> {kind, data, length, travel_frames, phases: [[name, last frame]],
## distance_m, channel, dash}.
var _moves: Dictionary = {}


func _init(tuning: Dictionary) -> void:
	tuning = Kit.tuning_of(tuning, Kit.MAGE)
	# The move tempo and the heavy area, as the game builds its move table.
	tuning = Moves.at_tempo(tuning)
	tuning = Moves.at_heavy_area(tuning)
	_tuning = tuning
	for name: String in Moves.names(tuning):
		var section := Moves.section_of(name)
		if not tuning.has(section):
			continue
		var data: Dictionary = tuning[section]
		var kind := Moves.kind_of_section(section, data)
		var phases: Array = []
		var last_frame := 0
		var travel_frames := 0
		for phase: Array in kind["phases"]:
			last_frame += Moves.phase_frames(data, phase[1])
			phases.append([phase[0], last_frame])
			if phase[0] == kind["travels_until"]:
				travel_frames = last_frame
		_moves[name] = {"kind": kind, "data": data, "length": last_frame, "travel_frames": travel_frames,
			"phases": phases, "distance_m": Moves.travel_m(kind, data),
			"channel": Moves.is_row(section) and Moves.is_channel(data),
			"dash": Moves.is_row(section) and Moves.is_dash(data)}


## The kit character `id` plays: the lab has one, the Mage's.
func for_character(_id: String) -> MoveKit:
	return self


## This kit's fused variant: the Mage has none, so this kit.
func fused_kit() -> MoveKit:
	return self


## The light swings' move names (Moves.light_rows).
func light_moves() -> Array:
	return Moves.light_rows(_tuning).map(func(section: String) -> String: return section.trim_prefix(Moves.ROW_PREFIX))


## What this kit's ultimate does (the slot's `effect`; absent: the slow).
func ultimate_effect() -> String:
	return str(_tuning.get(Moves.ULTIMATE_MOVE, {}).get(Moves.EFFECT_KEY, Moves.EFFECT_SLOW))


## True while `player` ({move, move_frame}) is in a channel's channel phase
## (the tornado).
func is_channelling(player: Dictionary) -> bool:
	var move: String = player.get("move", "")
	if move == "" or not _moves.has(move) or not _moves[move]["channel"]:
		return false
	return move_phase(move, int(player.get("move_frame", 0))) == "channel"


## Which phase of `move` frame `frame` (1 = its first) falls in ("" for no move).
func move_phase(move: String, frame: int) -> String:
	if move == "":
		return ""
	var phases: Array = _moves[move]["phases"]
	for phase: Array in phases:
		if frame <= int(phase[1]):
			return phase[0]
	return phases[-1][0]


## `move`'s tuning section.
func move_data(move: String) -> Dictionary:
	return _moves[move]["data"]


## Frames of `move` before its first active frame (where its hit lands), or
## its length when it has no active phase.
func frames_before_active(move: String) -> int:
	var before := 0
	for phase: Array in _moves[move]["phases"]:
		if phase[0] == "active":
			return before
		before = int(phase[1])
	return int(_moves[move]["length"])


## The frame `move`'s channel ends on (0 for a move with none).
func channel_end_frame(move: String) -> int:
	for phase: Array in _moves[move]["phases"]:
		if phase[0] == "channel":
			return int(phase[1])
	return 0


## How many frames `move` lasts.
func move_length(move: String) -> int:
	return int(_moves[move]["length"])


## True when this kit has `move`.
func has_move(move: String) -> bool:
	return _moves.has(move)


## How far (m) `move` has carried him `frames` frames into it, on open floor:
## a dash over its active phase, any other move evenly over its travel frames.
func travelled_m(move: String, frames: float) -> float:
	var entry: Dictionary = _moves[move]
	if entry["dash"]:
		var launch := float(entry["phases"][0][1])
		var landed := float(entry["phases"][1][1])
		return float(entry["data"]["distance_m"]) * clampf((frames - launch) / maxf(landed - launch, 1.0), 0.0, 1.0)
	var travel := float(entry["travel_frames"])
	if travel <= 0.0:
		return 0.0
	return float(entry["distance_m"]) * clampf(frames / travel, 0.0, 1.0)


## The [player] section (flinch and stagger frames, for his clips).
func player_data() -> Dictionary:
	return _tuning.get("player", {})


## Tuning section `section` of this kit ({} with none).
func kit_section(section: String) -> Dictionary:
	return _tuning.get(section, {})


## The [look] values he is drawn with.
func look_data() -> Dictionary:
	return _tuning.get("look", {})


## True when `move` hits (it has an active phase).
func hits_enemies(move: String) -> bool:
	if move == "":
		return false
	for phase: Array in _moves[move]["phases"]:
		if phase[0] == "active":
			return true
	return false
