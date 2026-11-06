## A move's preset as a character model holds it (VFX all-spells; the
## dash's way, VFX lab ticket 09 and review findings 5 and 7): the name its
## knob on the tuning pages gives (FxMoves), the preset it resolves to
## (FxPresets.resolve), why it did not, and the version drawn at a graphics
## level (FxLow). A name with no saved preset fails clearly: the error (the
## page, the key, the name and the saved ones) is printed once per name read
## and kept, and the move falls back to its old effect. A developer build
## re-reads the preset when its file changes on disk (re-saved in the VFX
## lab). Looks only: the simulation never reads it.
class_name FxMovePreset
extends RefCounted

## Developer builds look at the preset's file at most this often (ms).
static var check_ms := 500

## The knob naming it ([section, key]) and its recipe (the knob's rule's).
var knob: Array
var recipe := ""
## Printed before an unresolved name's error ("[mage] his light slashes
## keep the staff's trail instead: ").
var fallback := ""
## The name last read, its preset at max graphics (null: none or unknown),
## why it did not resolve ("" when it did), and how many times that was logged.
var name := ""
var preset: FxPreset
var error := ""
var logged := 0

var _version := ""
var _looked_ms := -1
var _drawn: FxPreset
var _drawn_for := ""


## The preset `knob` names, of `recipe`'s, falling back with `fallback` printed.
func _init(knob_of: Array, recipe_of: String, fallback_text: String) -> void:
	knob = knob_of
	recipe = recipe_of
	fallback = fallback_text


## Reads `new_name` (the knob's value): resolves it when it changed, or
## when its file was re-saved (developer builds).
func use(new_name: String) -> void:
	if new_name == name and not _resaved():
		return
	name = new_name
	_version = FxPresets.version_of(recipe, name) if name != "" else ""
	var found := FxPresets.resolve({knob[0]: {knob[1]: name}}, knob[0], knob[1])
	preset = found["preset"]
	error = found["error"]
	_drawn = null
	_drawn_for = ""
	if error != "":
		logged += 1
		printerr(fallback + error)


## The preset drawn at graphics preset `graphics` (FxLow.for_graphics: its
## Low version at LOW), or null when none resolved.
func drawn(graphics: String) -> FxPreset:
	if preset == null:
		return null
	if _drawn == null or graphics != _drawn_for:
		_drawn = FxLow.for_graphics(preset, graphics)
		_drawn_for = graphics
	return _drawn


## In a developer build, whether its file changed on disk since it was read.
func _resaved() -> bool:
	if not OS.is_debug_build() or name == "":
		return false
	var now := Time.get_ticks_msec()
	if _looked_ms >= 0 and now - _looked_ms < check_ms:
		return false
	_looked_ms = now
	return FxPresets.version_of(recipe, name) != _version
