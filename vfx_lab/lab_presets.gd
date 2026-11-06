## The lab's preset panel (ticket 02; grill Q5, Q6), on the right of the
## screen: the preset being tuned (FxPreset) with a slider per shared core
## knob, then one per knob of the recipe's own (ticket 04: its blocks'
## knobs, in FxPreset.knobs), and a picker per colour, then the recipe's
## advanced knobs under an Advanced button (ticket 05: hidden until opened,
## so a spell shows 5-15 knobs), the saved presets by name, and Save,
## Duplicate, Rename and Copy. The effect reads `preset` every frame
## it draws, so a slider moved shows at once, paused too.
## Ticket 08: the shared advanced knobs (the bloom) sit under Advanced too;
## "Editing: Max" (pressed: "Editing: Low") switches the effect to the
## preset's Low version (FxLow) and the sliders then show and adjust the
## Low version only (kept in the preset's `low`, saved with it);
## "Low: reset" drops them.
##
## Ticket 16: at the top, the move's reach (the spec's "drawn area matches
## the hit area"): a slider on the move's real reach from the tuning page
## (show_reach; none for a spell with no hit area). Moving it says so
## (reach_moved); the lab draws the effect at that reach (lab_reach.gd) and
## the look's ratios under it follow the reach. The page itself is never
## written: the label names the line to change by hand. A move with two lobes
## (none of the Mage's) has a second slider under it, its back lobe's (row
## 1: show_reach(spot, 1); back_reach_moved).
##
## Mouse only: its buttons, sliders and pickers never take the keyboard, so
## the lab's keys keep working; the name field gives the keys back on Enter.
##   Save            writes the preset under the name in the field (a new
##                   name saves a new preset and switches to it)
##   Duplicate       saves a copy under the field's name (or "<name> copy")
##                   and switches to it
##   Rename          renames the saved preset to the field's name
##   Copy            puts the preset's .tres file text on the clipboard (to
##                   paste into a file of your own, or share)
extends PanelContainer

## The edited preset changed (a knob, or another preset picked).
signal edited
## The reach slider moved to `value` (m): `done` once it is let go (or moved
## by a click or the wheel), else mid-drag.
signal reach_moved(value: float, done: bool)
## The second reach slider (a two-lobe move's back lobe) moved, the same way.
signal back_reach_moved(value: float, done: bool)

var recipe := ""
## The recipe's own knobs, shown and under Advanced: knob -> [label, min,
## max, step] (none for the placeholder).
var own_knobs := {}
## Those under Advanced (hidden until it is opened): knob -> its spec.
var advanced_knobs := {}
## The preset tuned now; its file is `preset_name` once saved.
var preset: FxPreset
var preset_name := ""

var _sliders := {}
var _values := {}
var _pickers := {}
var _list: OptionButton
var _name: LineEdit
var _status: Label
var _syncing := false
var _advanced: Button
var _advanced_open := false
var _editing_low := false
var _low_button: Button
## The reach rows (0 the move's reach, 1 a two-lobe move's back lobe): each
## its box, line, slider, page line shown ({} hidden) and whether dragged.
const REACH_ROWS := 2
var _reach_boxes: Array[VBoxContainer] = []
var _reach_labels: Array[Label] = []
var _reach_sliders: Array[HSlider] = []
var _reach_spots: Array[Dictionary] = [{}, {}]
var _reach_dragging: Array[bool] = [false, false]


## `recipe`'s panel, on its first saved preset, else `fresh` named
## `fresh_name` (not saved yet), with a slider per knob in `own` (the
## recipe's KNOBS) after the core set, then one per knob in `advanced` (its
## ADVANCED_KNOBS) under an Advanced button, hidden until it is pressed.
func _init(recipe_id: String, fresh: FxPreset, fresh_name: String, own: Dictionary = {},
		advanced: Dictionary = {}) -> void:
	name = "Presets"
	recipe = recipe_id
	own_knobs = own.merged(advanced)
	advanced_knobs = FxPreset.ADVANCED_CORE_KNOBS.merged(advanced)
	_build()
	var saved := FxPresets.names(recipe)
	if saved.is_empty():
		_use(fresh, fresh_name)
		say("%s: not saved yet (Save keeps it)" % fresh_name)
	else:
		_use(FxPresets.load_preset(recipe, saved[0]), saved[0])


# --- What the lab and the tests drive -----------------------------------------

## The knobs' sliders, the core set then the recipe's own: knob -> HSlider.
func sliders() -> Dictionary:
	return _sliders


## The colours' pickers: knob -> ColorPickerButton.
func colour_pickers() -> Dictionary:
	return _pickers


## The saved presets' names.
func names() -> Array:
	return Array(FxPresets.names(recipe))


## The panel's last word (saved, refused, copied).
func status() -> String:
	return _status.text


## Shows `text` as the panel's last word.
func say(text: String) -> void:
	_status.text = text


## Sets `knob` (a core knob, a colour, or one of the recipe's own) on the
## preset (on its Low version while editing Low); a whole-step own knob
## (strands) is kept whole.
func set_knob(knob: String, value: Variant) -> void:
	var kept: Variant = value
	if own_knobs.has(knob):
		var whole := is_equal_approx(float(own_knobs[knob][3]), 1.0)
		kept = int(round(float(value))) if whole else float(value)
	if _editing_low:
		preset.low[knob] = kept
	elif own_knobs.has(knob):
		preset.knobs[knob] = kept
	else:
		preset.set(knob, kept)
	_show_values()
	edited.emit()


## The reach slider of `row` (0 the move's reach, 1 a two-lobe move's back
## lobe; hidden with no reach shown).
func reach_slider(row: int = 0) -> HSlider:
	return _reach_sliders[row]


## The reach line over `row`'s slider: the key, its value, where it is written.
func reach_label(row: int = 0) -> String:
	return _reach_labels[row].text


## Shows `row`'s reach slider on `spot` (lab_reach.gd spot_of: {page,
## section, key, value, rule}), or hides it ({}: a spell with no hit area,
## or row 1 on a move with one lobe). Its range is kept while the same line
## is shown, so a drag is not rescaled.
func show_reach(spot: Dictionary, row: int = 0) -> void:
	_syncing = true
	var was: Dictionary = _reach_spots[row]
	var same: bool = not spot.is_empty() and not was.is_empty() and spot["page"] == was["page"] \
		and spot["section"] == was["section"] and spot["key"] == was["key"]
	_reach_spots[row] = spot
	_reach_boxes[row].visible = not spot.is_empty()
	var slider := _reach_sliders[row]
	if not spot.is_empty():
		var value := float(spot["value"])
		var rule: Array = spot["rule"]
		if not same:
			slider.min_value = float(rule[1]) if rule.size() > 2 else 0.1
			slider.max_value = minf(float(rule[2]) if rule.size() > 2 else 20.0, maxf(ceilf(value * 2.5), 2.0))
		if not (same and _reach_dragging[row]):  # mid-drag the slider leads
			slider.max_value = maxf(slider.max_value, value)
			slider.value = value
			_show_reach_label(value, row)
	_syncing = false


## The preset the effect draws: the preset, or its Low version while
## editing Low.
func drawn_preset() -> FxPreset:
	return FxLow.low_version(preset) if _editing_low else preset


## Whether the sliders edit the Low version.
func editing_low() -> bool:
	return _editing_low


## Switches the effect and the sliders to the Low version (`on`) or back.
func edit_low(on: bool) -> void:
	_editing_low = on
	_low_button.text = "Editing: Low" if on else "Editing: Max"
	_show_values()
	edited.emit()


## Drops P-O's Low adjustments: the Low version is the rule's again.
func reset_low() -> void:
	preset.low = {}
	_show_values()
	edited.emit()


## Opens or closes Advanced (the recipe's advanced knobs' sliders).
func toggle_advanced() -> void:
	_advanced_open = not _advanced_open
	_show_advanced()


## Saves the preset as `as_name` ("" for its own name). Returns "" or why not.
func save_preset(as_name: String = "") -> String:
	var target := as_name if as_name != "" else preset_name
	var error := FxPresets.save(preset, target)
	if error != "":
		return _refused(error)
	preset_name = target
	_refresh_list()
	say("Saved %s" % target)
	return ""


## Saves a copy of the preset as `new_name` and switches to it.
func duplicate_preset(new_name: String) -> String:
	if new_name in names():
		return _refused("%s already has a preset \"%s\"." % [recipe, new_name])
	var error := FxPresets.save(preset, new_name)
	if error != "":
		return _refused(error)
	_use(FxPresets.load_preset(recipe, new_name), new_name)
	say("Duplicated as %s" % new_name)
	return ""


## Renames the saved preset to `new_name` (its file only: unsaved edits stay
## unsaved).
func rename_preset(new_name: String) -> String:
	if not preset_name in names():
		return _refused("Save \"%s\" before renaming it." % preset_name)
	var error := FxPresets.rename(recipe, preset_name, new_name)
	if error != "":
		return _refused(error)
	var old := preset_name
	preset_name = new_name
	_refresh_list()
	say("Renamed %s to %s (a tuning page naming the old name needs the new one)" % [old, new_name])
	return ""


## Switches to the saved preset `pick_name` (unsaved edits are dropped).
func pick_preset(pick_name: String) -> String:
	var picked := FxPresets.load_preset(recipe, pick_name)
	if picked == null:
		return _refused("No preset \"%s\" of %s." % [pick_name, recipe])
	_use(picked, pick_name)
	say("Picked %s" % pick_name)
	return ""


## The preset as its .tres file's text (as Save writes it).
func preset_text() -> String:
	var path := "user://copied_preset.tres"
	if ResourceSaver.save(preset.duplicate(true) as FxPreset, path) != OK:
		return ""
	var text := FileAccess.get_file_as_string(path)
	DirAccess.remove_absolute(path)
	return text


## Puts the preset's .tres text on the clipboard.
func copy_preset() -> void:
	var text := preset_text()
	if text == "":
		_refused("the preset could not be written out.")
		return
	DisplayServer.clipboard_set(text)
	say("Copied %s as .tres text: paste it into fx/presets/%s/<name>.tres" % [preset_name, recipe])


# --- Inside --------------------------------------------------------------------

## Edits `next` as the preset `next_name` from now on: the list, the
## sliders and the drawn effect follow it.
func _use(next: FxPreset, next_name: String) -> void:
	preset = next
	preset_name = next_name
	_refresh_list()
	_show_values()
	edited.emit()


## Shows why an action was not done; returns `error`.
func _refused(error: String) -> String:
	say("Not done: " + error)
	return error


## The drop-down of saved names and the name field, on the preset edited.
func _refresh_list() -> void:
	_syncing = true
	_list.clear()
	var saved := names()
	for n: String in saved:
		_list.add_item(n)
	_list.select(saved.find(preset_name))
	_name.text = preset_name
	_syncing = false


## Every slider, value label and colour picker on the preset drawn (its Low version while editing Low).
func _show_values() -> void:
	_syncing = true
	var shown := drawn_preset()
	var core := FxPreset.CORE_KNOBS.merged(FxPreset.ADVANCED_CORE_KNOBS)
	for knob: String in _sliders:
		var own := own_knobs.has(knob)
		var value := float(shown.knobs.get(knob, own_knobs[knob][1]) if own else shown.get(knob))
		(_sliders[knob] as HSlider).value = value
		var label: String = own_knobs[knob][0] if own else core[knob][0]
		(_values[knob] as Label).text = "%s  %.2f" % [label, value]
	for knob: String in _pickers:
		(_pickers[knob] as ColorPickerButton).color = shown.get(knob)
	_syncing = false


## The name typed in the field, trimmed.
func _typed_name() -> String:
	return _name.text.strip_edges()


## Builds the panel: the list, the name field and its buttons, Max/Low,
## a slider per knob (Advanced folded), the colour pickers, the status line.
func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -300
	# Scrolls when Advanced makes it taller than the screen.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_NONE
	add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_add_reach(box)
	var title := Label.new()
	title.text = "Preset (%s)" % recipe
	box.add_child(title)
	_list = OptionButton.new()
	_list.focus_mode = Control.FOCUS_NONE
	_list.item_selected.connect(func(i: int) -> void:
		if not _syncing:
			pick_preset(_list.get_item_text(i)))
	box.add_child(_list)
	_name = LineEdit.new()
	_name.placeholder_text = "name, e.g. tornado - sand"
	_name.text_submitted.connect(func(_t: String) -> void: _name.release_focus())
	box.add_child(_name)
	var row := HBoxContainer.new()
	box.add_child(row)
	for pair: Array in [["Save", func() -> void: save_preset(_typed_name())],
			["Duplicate", func() -> void:
				var copy := _typed_name()
				duplicate_preset(copy if copy != preset_name and copy != "" else preset_name + " copy")],
			["Rename", func() -> void: rename_preset(_typed_name())],
			["Copy", copy_preset]]:
		var button := Button.new()
		button.text = pair[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(pair[1])
		row.add_child(button)
	var low_row := HBoxContainer.new()
	box.add_child(low_row)
	_low_button = Button.new()
	_low_button.text = "Editing: Max"
	_low_button.focus_mode = Control.FOCUS_NONE
	_low_button.tooltip_text = ("Switches to the Low version (Low graphics), made from the max graphics knobs:"
		+ " the sliders then adjust it")
	_low_button.pressed.connect(func() -> void: edit_low(not _editing_low))
	low_row.add_child(_low_button)
	var rule := Button.new()
	rule.text = "Low: reset"
	rule.focus_mode = Control.FOCUS_NONE
	rule.pressed.connect(reset_low)
	low_row.add_child(rule)
	var specs := FxPreset.CORE_KNOBS.merged(own_knobs)
	for knob: String in specs:
		if not advanced_knobs.has(knob):
			_add_slider(box, knob, specs[knob])
	for knob: String in FxPreset.COLOUR_KNOBS:
		var line := HBoxContainer.new()
		box.add_child(line)
		var label := Label.new()
		label.text = FxPreset.COLOUR_KNOBS[knob]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(label)
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(64, 0)
		picker.edit_alpha = false
		picker.focus_mode = Control.FOCUS_NONE
		picker.color_changed.connect(func(c: Color) -> void:
			if not _syncing:
				set_knob(knob, c))
		line.add_child(picker)
		_pickers[knob] = picker
	if not advanced_knobs.is_empty():
		_advanced = Button.new()
		_advanced.focus_mode = Control.FOCUS_NONE
		_advanced.pressed.connect(toggle_advanced)
		box.add_child(_advanced)
		for knob: String in advanced_knobs:
			_add_slider(box, knob, advanced_knobs[knob])
		_show_advanced()
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(280, 0)
	box.add_child(_status)


## The reach rows' lines and sliders at the top of `box`, hidden until
## show_reach.
func _add_reach(box: Control) -> void:
	for row in REACH_ROWS:
		_add_reach_row(box, row)


## Reach row `row`: its line, its slider (moving it says so: reach_moved,
## or back_reach_moved for row 1) and a separator under it.
func _add_reach_row(box: Control, row: int) -> void:
	var row_box := VBoxContainer.new()
	row_box.visible = false
	box.add_child(row_box)
	_reach_boxes.append(row_box)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(280, 0)
	row_box.add_child(label)
	_reach_labels.append(label)
	var slider := HSlider.new()
	slider.step = 0.05
	slider.focus_mode = Control.FOCUS_NONE
	slider.tooltip_text = "The move's real reach (its line on the tuning page): the effect is drawn for it"
	var moved: Signal = reach_moved if row == 0 else back_reach_moved
	slider.drag_started.connect(func() -> void: _reach_dragging[row] = true)
	slider.drag_ended.connect(func(_changed: bool) -> void:
		_reach_dragging[row] = false
		if not _reach_spots[row].is_empty():
			moved.emit(slider.value, true))
	slider.value_changed.connect(func(v: float) -> void:
		if _syncing or _reach_spots[row].is_empty():
			return
		_show_reach_label(v, row)
		moved.emit(v, not _reach_dragging[row]))
	row_box.add_child(slider)
	_reach_sliders.append(slider)
	row_box.add_child(HSeparator.new())


func _show_reach_label(value: float, row: int = 0) -> void:
	var spot: Dictionary = _reach_spots[row]
	var unit := "deg" if str(spot["key"]).ends_with("_deg") else ("x" if str(spot["key"]).ends_with("_mult") else "m")
	_reach_labels[row].text = "Reach  %s %.2f %s  (%s.cfg [%s]; not saved)" % [spot["key"], value, unit,
		spot["page"], spot["section"]]


## A labelled slider for `knob` ([label, min, max, step?]) in `box`.
func _add_slider(box: Control, knob: String, spec: Array) -> void:
	var label := Label.new()
	box.add_child(label)
	_values[knob] = label
	var slider := HSlider.new()
	slider.min_value = spec[1]
	slider.max_value = spec[2]
	slider.step = float(spec[3]) if spec.size() > 3 else 0.01
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(v: float) -> void:
		if not _syncing:
			set_knob(knob, v))
	box.add_child(slider)
	_sliders[knob] = slider


## The advanced knobs' sliders shown while Advanced is open.
func _show_advanced() -> void:
	if _advanced == null:
		return
	_advanced.text = ("Advanced (%d) - hide" if _advanced_open else "Advanced (%d) - show") % advanced_knobs.size()
	for knob: String in advanced_knobs:
		(_sliders[knob] as HSlider).visible = _advanced_open
		(_values[knob] as Label).visible = _advanced_open
