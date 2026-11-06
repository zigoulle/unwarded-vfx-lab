## One move's lab effect in the game (VFX all-spells; the Duelist's dash
## was the first, inline in DuelistModel): the preset a character's tuning
## page names for the move (its knob, FxMoves), the recipe node drawing it,
## and the cast it plays.
## - The name resolves through FxPresets.resolve. A name with no saved
##   preset fails clearly: the error (the page, the key, the name and the
##   saved ones) is printed once per name read and kept, and the move keeps
##   its old effect (playing() false), so a typo never leaves it bare. A
##   developer build re-reads the preset when its file changes on disk.
## - A cast ({seed, since_s, hit_s, hit}: the seed from the move's event,
##   the seconds into the move the pose shows, its hit marker after its
##   start, its hit area) starts it on its FxCastClock (holds behind the
##   pause menu), its ground footprint drawn as ratios of that hit's reach
##   (FxReach); it plays on after the move ends until a new cast.
## - At Low graphics (or low quality) its Low version (FxLow), made once per
##   change.
## - Its impact's shake (the preset's shake knob, FxShake) is kept for the
##   holder to hand the local camera's ScreenShake (take_shake_kick).
## Its holder places the node (centre, ground) before each show. Looks
## only: the simulation never reads it.
class_name FxMoveEffect
extends RefCounted

## How often a developer build looks whether the preset's file changed (ms).
static var preset_check_ms := 500

## The recipe drawing it (a child of its holder, the model).
var node: Node3D

var _recipe := ""
var _knob: Array = []
var _who := ""
var _name := ""
var _preset: FxPreset
var _error := ""
var _logged := 0
var _version := ""
var _looked_ms := -1
var _clock := FxCastClock.new()
var _seed := -1
var _time := -1000.0
var _drawn: FxPreset
var _drawn_for := ""
var _kicks := FxShakeKicks.new()
## Nothing left to draw (perf pass 15): the last show_at hid it all, before
## any cast or past its cast's end (rested); show skips the node until a new
## cast, a new preset or another graphics level.
var _rested := false


## The effect of the move whose preset knob is `knob` ([section, key]),
## drawn by `drawing` (recipe `recipe`'s node); `who` opens its log lines
## ("[mage] his ground shake").
func _init(recipe: String, knob: Array, drawing: Node3D, who: String) -> void:
	_recipe = recipe
	_knob = knob
	node = drawing
	_who = who
	node.visible = false


## The preset named `name` ("" none: the move's old effect).
func set_preset_name(name: String) -> void:
	if name == _name and not _resaved():
		return
	_name = name
	_version = FxPresets.version_of(_recipe, name) if name != "" else ""
	var found := FxPresets.resolve({_knob[0]: {_knob[1]: name}}, _knob[0], _knob[1])
	_preset = found["preset"]
	_error = found["error"]
	_drawn = null
	_drawn_for = ""
	_rested = false
	if _error != "":
		_logged += 1
		printerr("%s plays its old effect instead: %s" % [_who, _error])


## In a developer build, whether the preset's file changed on disk since it
## was read (looked at every preset_check_ms at most).
func _resaved() -> bool:
	if not OS.is_debug_build() or _name == "":
		return false
	var now := Time.get_ticks_msec()
	if _looked_ms >= 0 and now - _looked_ms < preset_check_ms:
		return false
	_looked_ms = now
	return FxPresets.version_of(_recipe, _name) != _version


## Whether it plays (its name resolved to a saved preset): the move's old
## effect is off.
func playing() -> bool:
	return _preset != null


## Why its name did not resolve, or "" (none named, or found).
func error() -> String:
	return _error


## The recipe drawing it (FxMoves).
func recipe() -> String:
	return _recipe


## How many times an unresolved name was logged.
func errors_logged() -> int:
	return _logged


## The seconds into its cast it was last drawn at (-1000: none yet).
func time() -> float:
	return _time


## Draws it for `cast` ({} while the move is not on: the last cast plays
## on), its Low version when `low` or at Low graphics; hidden with no preset.
## Once nothing of it is left to show (before any cast, or past its recipe's
## end_time with nothing shown) it rests: the node is left as drawn, hidden,
## until a new cast (perf pass 15: a recipe works its particles out one by
## one each draw, ~0.2 ms a move a frame for nothing). A channel (the
## tornado's set_channel) is its own cast's, so it rests too once over; a
## recipe that follows a slow (set_slow, the time slow's, set from outside
## its cast) never rests.
func show(cast: Dictionary, low: bool) -> void:
	node.visible = _preset != null
	if not cast.is_empty() and int(cast["seed"]) != _seed:
		_seed = int(cast["seed"])
		_clock.cast(float(cast["since_s"]))
		node.set("impact_s", float(cast["hit_s"]))
		if "hit" in node:
			node.set("hit", cast.get("hit", {}))
		_rested = false
	if _preset == null or _seed < 0:
		_time = -1000.0
		if not _rested:
			node.call("show_at", 0, _time)
			_rested = true
		return
	var graphics := GraphicsSettings.LOW if low else FxLow.game_graphics
	if _drawn == null or graphics != _drawn_for:
		_drawn = FxLow.for_graphics(_preset, graphics)
		_drawn_for = graphics
		_rested = false
	_time = _clock.time()
	if _rested:
		return
	node.set("preset", _drawn)
	node.call("show_at", _seed, _time)
	_kicks.see(_seed, _time, node)
	_rested = _can_rest() and _time > float(node.call("end_time")) and not node.call("shown")


## Whether its recipe tells when it is over and whether it shows, and draws
## from its cast alone (not a slow its holder keeps setting).
func _can_rest() -> bool:
	return node.has_method("end_time") and node.has_method("shown") and not node.has_method("set_slow")


## The kick its impact gave the screen shake since the last take
## ({strength_m, length_s}; {} none: FxShakeKicks).
func take_shake_kick() -> Dictionary:
	return _kicks.take()
