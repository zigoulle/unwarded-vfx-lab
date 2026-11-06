## The view clock (autoload GameClock; solo-pause story 24): the game's own
## seconds, which stop while a solo pause holds the scene tree. The world's
## shaders animate on it (the `game_time` global shader uniform, in place of
## the engine's TIME, which runs on through a pause) and so do the looks'
## own animations (a bob, a pulse) and the sound mix's cue gate, so nothing
## moves or goes stale behind the pause menu. The menu's own stone tablet
## keeps TIME: it runs while paused.
##
## It runs at the same pace as TIME and wraps as TIME does (the project's
## time rollover), so the looks are the same while the game runs. Views and
## sound only: the simulation runs on netfox's ticks.
extends Node

## The global shader uniform (project.godot, [shader_globals]).
const SHADER_PARAM := &"game_time"

var _seconds := 0.0
var _rollover: float = ProjectSettings.get_setting("rendering/limits/time/time_rollover_secs", 3600.0)


func _ready() -> void:
	# Pauses with the tree: a solo pause stops the clock.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Ahead of every view in the frame (autoloads come first anyway).
	process_priority = -1000


func _process(delta: float) -> void:
	_seconds += delta
	RenderingServer.global_shader_parameter_set(SHADER_PARAM, shader_time(_seconds))


## The game's seconds since it started, paused time left out.
func seconds() -> float:
	return _seconds


## The game's milliseconds (seconds() as Time.get_ticks_msec counts).
func msec() -> int:
	return int(_seconds * 1000.0)


## The game's microseconds (seconds() as Time.get_ticks_usec counts).
func usec() -> int:
	return int(_seconds * 1000000.0)


## `seconds` as the shaders see it: wrapped at the project's time rollover,
## as the engine wraps TIME.
func shader_time(seconds_now: float) -> float:
	return fmod(seconds_now, _rollover) if _rollover > 0.0 else seconds_now
