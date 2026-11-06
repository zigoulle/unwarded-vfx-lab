## The mage's animation choice: which clip shows for a player's state, and at
## what time in it. Node-free; MageModel plays what this picks. Animations
## never drive combat: this only reads the simulation's state.
##
## The hit-frame convention: each attack's clip carries a "hit" marker (the
## frame where the strike connects, picked by looking at the clip), and is
## time-scaled so that marker shows on the move's first active tick (the tick
## after its startup frames); the wind-up and the follow-through are scaled
## separately, so a longer startup slows only the wind-up. The frame data is
## read from the CombatSim in effect, so a hot-reloaded tuning retimes at once.
## See docs/dev-notes/art-pipeline.md.
class_name MageClips
extends RefCounted

## Slower than this (m/s) counts as standing.
const WALKING_M_PER_S := 0.2
## A turn per clip, for a clip that does not face the way the mesh does (+Z).
## The Rigify clips (tools/blender/key_mage.py) are all keyed facing +Z: none.
const CLIP_YAW_DEG := {}

## The shipped table: per move (and per hit state), the clip of mage.glb it
## plays and its markers, in frames of that 60 fps clip: "start" (shown on
## the move's first frame), "hit" (on its first active tick; a cast's on its
## last frame) and "end" (on its last frame). Optional: "spin" turns the body
## once over the active frames (1 one way, -1 the other), "lean" tips it
## (radians, forward is negative), "yaw_deg" turns the whole model on top of
## its clip's turn, to vary one clip between moves. MageModel copies each
## source clip per move and writes these as named markers on the copy.
##
## The clips are keyed on the Rigify rig (tools/blender/key_mage.py), one per
## swing, with the hit frame keyed where the staff connects; these markers
## are the ones game/assets/mage/mage-clips.json carries (a test checks).
const MOVES := {
	"light_1": {"clip": "slash_1", "start": 0, "hit": 10, "end": 32},
	"light_2": {"clip": "slash_2", "start": 0, "hit": 10, "end": 34},
	"light_3": {"clip": "slash_3", "start": 0, "hit": 14, "end": 46},
	"ground_shake": {"clip": "ground_shake", "start": 0, "hit": 28, "end": 72},
	"whirlwind": {"clip": "whirlwind", "start": 0, "hit": 20, "end": 52, "spin": 1.0},
	"whirlwind_2": {"clip": "whirlwind_2", "start": 0, "hit": 16, "end": 54, "spin": -1.0},
	# The tornado's channel: a loop (hit 0), played on its own clock over the
	# channel phase (_channel), the recovery settling through idle.
	"tornado": {"clip": "tornado", "start": 0, "hit": 0, "end": 120},
	"ultimate": {"clip": "cast", "start": 0, "hit": 40, "end": 40},
	"dodge": {"clip": "dash", "start": 0, "hit": 8, "end": 8},
	"blink": {"clip": "dash", "start": 0, "hit": 8, "end": 8, "lean": -0.35},
	# The core mother's Dive boss boon (MotherBoons): his blink's dash, as he sinks.
	"boss_dive": {"clip": "dash", "start": 0, "hit": 8, "end": 8, "lean": 0.35},
	"drink": {"clip": "idle", "start": 0, "hit": 0, "end": 0, "lean": 0.3},
	"down": {"clip": "defeat", "start": 0, "hit": 0, "end": 0},
	"flinch": {"clip": "hit", "start": 0, "hit": 0, "end": 30},
	"stagger": {"clip": "stagger", "start": 0, "hit": 0, "end": 60},
}
## The clip's own frame rate (tools/blender/bake_mage.py bakes at 60 fps).
const CLIP_FPS := 60.0


## `state`: the player's move, move_frame, hitstop, held_frame (optional,
## remember_hold), tick_factor (netfox's
## fraction of the way to the next tick), hit_state and hit_frames (only
## while a hit holds the player), speed_m_per_s (drawn ground speed) and
## stride_m_per_s (the run clip's stride at the drawn scale). `markers`: per
## move, the clip it plays and its "start", "hit" and "end" marker times in
## seconds (see MOVES). Returns the clip to show (a key of `markers`, or
## idle / run), its time (-1: loops on its own clock at `rate`), and the
## body's spin and lean on top of the clip. Also the staff's sand trail:
## "trail" is "light" or "heavy" while a swing's staff trails ("" not), from
## `state`'s trail_lead_frames (feel page; default 0) shown before its first
## active tick to the clip's end marker (the move's last frame shown), hit or
## miss; "frozen" while hitstop holds the pose (the trail holds with it).
static func pose(sim: CombatSim, state: Dictionary, markers: Dictionary) -> Dictionary:
	var out := _pose(sim, state, markers)
	out["frozen"] = int(state.get("hitstop", 0)) > 0
	out["trail"] = ""
	var move: String = state.get("move", "")
	if move == "" or out["clip"] in ["down", "flinch", "stagger"] or not sim.hits_enemies(move):
		return out
	var data := sim.move_data(move)
	if not data.has("active_frames"):
		return out
	var anchor := float(data["startup_frames"])
	var elapsed := elapsed_frames(state)
	if elapsed >= anchor - float(state.get("trail_lead_frames", 0)) and elapsed <= float(sim.move_length(move)):
		out["trail"] = "light" if move in sim.light_moves() else "heavy"
	return out


static func _pose(sim: CombatSim, state: Dictionary, markers: Dictionary) -> Dictionary:
	if state.get("down", false):
		# Downed (0 HP): the defeat clip plays once and holds, over anything else.
		return {"clip": "down", "time": -1.0, "rate": 1.0, "spin": 0.0, "lean": 0.0, "once": true,
			"yaw_deg": _clip_yaw(markers["down"])}
	var held: String = state.get("hit_state", "")
	if held != "":
		return _held(sim, state, held, markers[held])
	var move: String = state["move"]
	if move == "":
		return _free(state)
	var data := sim.move_data(move)
	if Moves.is_channel(data):
		return _channel(sim, state, move, markers)
	var clip := _clip_for(move, data, markers)
	var marks: Dictionary = markers[clip]
	var elapsed := elapsed_frames(state)
	var total := float(sim.move_length(move))
	# The first active tick for a swing; the cast's hit marker shows as it completes.
	var anchor := float(data["startup_frames"]) if data.has("startup_frames") else total
	var time := retime(elapsed, anchor, total, marks["start"], marks["hit"], marks["end"])
	var spin := 0.0
	if data.has("active_frames"):
		spin = float(marks.get("spin", 0.0)) * TAU * clampf((elapsed - anchor) / float(data["active_frames"]), 0.0, 1.0)
	return {"clip": clip, "time": time, "rate": 1.0, "spin": spin, "lean": float(marks.get("lean", 0.0)),
		"yaw_deg": _clip_yaw(marks) + float(marks.get("yaw_deg", 0.0))}


## A channel (the tornado, Moves.CHANNEL): over its channel phase its clip
## loops from its start to its end marker at the clip's own rate, from the
## move's first frame (drawn a tick behind like a swing); the hit-frame
## retime has no hit to place, the pulses being evenly spread. Its recovery
## (a Q collapse lands there too) settles through idle, which MageModel
## crossfades into. No trail, no spin.
static func _channel(sim: CombatSim, state: Dictionary, move: String, markers: Dictionary) -> Dictionary:
	var frame := int(state["move_frame"])
	if sim.move_phase(move, frame) != "channel":
		return {"clip": "idle", "time": -1.0, "rate": 1.0, "spin": 0.0, "lean": 0.0, "yaw_deg": 0.0}
	var clip: String = move if markers.has(move) else "tornado"
	var marks: Dictionary = markers[clip]
	var cycle := float(marks["end"]) - float(marks["start"])
	var seconds := elapsed_frames(state) / CLIP_FPS
	var time := float(marks["start"]) + (fmod(seconds, cycle) if cycle > 0.0 else 0.0)
	return {"clip": clip, "time": time, "rate": 1.0, "spin": 0.0, "lean": 0.0, "yaw_deg": _clip_yaw(marks)}


## The marker row a move plays: its own, else one borrowed by its shape (a
## new swing row in the tuning needs no art to be playable): a stunning
## swing plays like the ground shake, an all-round one like the whirlwind,
## any other like the first slash.
static func _clip_for(move: String, data: Dictionary, markers: Dictionary) -> String:
	if markers.has(move):
		return move
	if data.get("stuns", "no") == "yes":
		return "ground_shake"
	if float(data.get("arc_deg", 0.0)) >= 360.0:
		return "whirlwind"
	return "light_1"


## The turn that makes marks's clip face the way the player faces.
static func _clip_yaw(marks: Dictionary) -> float:
	return float(CLIP_YAW_DEG.get(marks["clip"], 0.0))


## Held by a hit (flinch or stagger; the caller passes it only while it holds
## the player): its clip runs start to end over the hit's whole length
## (`player.flinch_frames` or `stagger_frames`), whatever the move was.
static func _held(sim: CombatSim, state: Dictionary, held: String, marks: Dictionary) -> Dictionary:
	var total := float(sim.player_data()["%s_frames" % held])
	var elapsed := maxf(0.0, total - float(state["hit_frames"]) - 1.0 + float(state["tick_factor"]))
	var time := retime(elapsed, total, total, marks["start"], marks["end"], marks["end"])
	return {"clip": held, "time": time, "rate": 1.0, "spin": 0.0, "lean": 0.0, "yaw_deg": _clip_yaw(marks)}


## No move: idle standing, run while walking. Both loop on their own clock
## (time -1); the run's rate matches its stride to the walking speed.
static func _free(state: Dictionary) -> Dictionary:
	var speed := float(state.get("speed_m_per_s", 0.0))
	if speed < WALKING_M_PER_S:
		return {"clip": "idle", "time": -1.0, "rate": 1.0, "spin": 0.0, "lean": 0.0, "yaw_deg": 0.0}
	return {"clip": "run", "time": -1.0, "rate": speed / float(state["stride_m_per_s"]), "spin": 0.0, "lean": 0.0,
		"yaw_deg": float(CLIP_YAW_DEG.get("run", 0.0))}


## How many frames of the current move the screen shows as done. The drawn
## position runs one tick behind the simulation (TickInterpolator blends from
## the previous tick to this one by tick_factor), and so does this: move
## frame N is reached, N - 1 frames elapsed, when the factor reaches 1. In
## hitstop the move is frozen on its frame, and so is the clip (on the hit
## marker, for a hit on the first active tick). The tick after the freeze
## ends still shows that frame (`held_frame`, remember_hold: the blend runs
## from the frozen tick to the same frame), so the follow-through carries on
## forward from it, the frozen ticks added, instead of stepping back a tick
## and replaying the contact (playtest ruling 7's stutter).
static func elapsed_frames(state: Dictionary) -> float:
	var frame := float(state["move_frame"])
	if int(state["hitstop"]) > 0 or (int(state.get("held_frame", 0)) > 0 and int(state["held_frame"]) == int(state["move_frame"])):
		return frame - 1.0
	return maxf(0.0, frame - 2.0 + float(state["tick_factor"]))


## Keeps, in `memory` (one Dictionary per drawn player, kept by its caller),
## the move frame the last hitstop froze in the current move, and writes it
## into `state` as "held_frame" (0: none) for elapsed_frames. A new move, or
## a move frame before it (a rollback), forgets it.
static func remember_hold(memory: Dictionary, state: Dictionary) -> void:
	var move: String = state.get("move", "")
	var frame := int(state.get("move_frame", 0))
	if not memory.has("frame") or memory["move"] != move or frame < int(memory["frame"]):
		memory["move"] = move
		memory["frame"] = 0
	if move != "" and int(state.get("hitstop", 0)) > 0:
		memory["frame"] = frame
	state["held_frame"] = int(memory["frame"])


## Clip time for `elapsed` move frames: the start marker at 0, the hit marker
## at `anchor` frames (the first active tick), the end marker at `total`;
## straight lines between, so each side is time-scaled on its own.
static func retime(elapsed: float, anchor: float, total: float, start: float, hit: float, end: float) -> float:
	if elapsed <= anchor:
		return start + (hit - start) * clampf(elapsed / anchor, 0.0, 1.0)
	return hit + (end - hit) * clampf((elapsed - anchor) / maxf(total - anchor, 1.0), 0.0, 1.0)


## The cast of a swing for its lab preset (VFX all-spells; the dash's
## DuelistClips.dash_cast) in `state` (as pose's) playing `sim`, begun on
## `cast_tick` (the simulation's record, the player's move_tick) by the
## player in slot `actor`: {move, seed (FxSeed of the move's event, so every
## peer and every replay draws the same shapes; grill Q8), since_s (seconds
## into the move this state shows), hit_s (its hit marker: the clip is
## retimed to show it on the move's first active tick)}; {} outside a swing.
## A channel's (the tornado) too: its hit where its looping clip shows its
## hit marker (FxMoves.hit_s), and its `channel` {on (CombatSim
## is_channelling: not in its recovery), radius_m (his own kit's, his boons'
## wider one too), length_s (when it ends if nothing breaks it)}.
## The blink (ticket 05) casts too: it hits nothing, so its hit marker is
## its end, his arrival (CombatSim.frames_before_active).
## His ultimate's (the time slow) too: its hit the cast's completing tick.
## Each carries its `hit` area (FxReach.hit_of of the move's data, his boons'
## wider reach too): the preset's ground footprint is ratios of its reach.
## Looks only.
static func move_cast(sim: CombatSim, state: Dictionary, cast_tick: int, actor: int) -> Dictionary:
	var move: String = state.get("move", "")
	if move == "" or not sim.has_move(move):
		return {}
	var data := sim.move_data(move)
	if Moves.is_channel(data):
		var row: Dictionary = MOVES.get(move, MOVES["tornado"])
		var marks := {"start": float(row["start"]) / CLIP_FPS, "hit": float(row["hit"]) / CLIP_FPS}
		return {"move": move, "seed": FxSeed.of(cast_tick, actor), "since_s": elapsed_frames(state) / CLIP_FPS,
			"hit_s": FxMoves.hit_s(sim, move, marks), "hit": FxReach.hit_of(data),
			"channel": {"on": sim.is_channelling(state), "radius_m": float(data["radius_m"]),
				"length_s": float(sim.channel_end_frame(move)) / CLIP_FPS}}
	if move == Moves.ULTIMATE_MOVE and sim.ultimate_effect() == Moves.EFFECT_SLOW:
		# His time slow: its hit is the cast's completing tick (FxMoves.hit_s).
		return {"move": move, "seed": FxSeed.of(cast_tick, actor), "since_s": elapsed_frames(state) / CLIP_FPS,
			"hit_s": FxMoves.hit_s(sim, move, {}), "hit": FxReach.hit_of(data)}
	if not data.has("startup_frames") and move != Moves.BLINK_MOVE:
		return {}
	return {"move": move, "seed": FxSeed.of(cast_tick, actor), "since_s": elapsed_frames(state) / CLIP_FPS,
		"hit_s": float(sim.frames_before_active(move)) / CLIP_FPS, "hit": FxReach.hit_of(data)}
