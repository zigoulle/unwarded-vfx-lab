## Reads the tuning pages: plain-text pages in the tuning/ folder, each read
## with Godot's ConfigFile (`[section]` headers, `key = value` lines, `;`
## comments), merged into one set of values by section, e.g.
## values["move.light_1"]["startup_frames"]. The plain-words meaning of each
## key is in the comment above it on its page.
##
## The pages are the game's own (Unwarded), cut down to what the lab draws:
## the Mage's kit and looks (mage.cfg), what every character shares
## (character.cfg), the feel of his hits (feel.cfg), the camera and the
## shared looks (camera-and-arena.cfg), the effect intensity knob
## (global.cfg) and the volcano's ring arena (volcano.cfg). The lab reads
## them and never writes them.
##
## Node-free, pure static.
class_name Tuning
extends RefCounted

## Every page, by file name without ".cfg". All must exist.
const PAGES: Array[String] = ["character", "mage", "camera-and-arena", "feel", "global", "volcano"]
## The Light group's move name: [mage.move.light] holds every light-swing
## value; [mage.move.light_<n>] holds a swing's chaining values and its
## overrides (_resolve_light_groups).
const LIGHT_GROUP := "light"
## A swing row's keys that are its edges in the move graph: per swing, never
## in a Light group.
const CHAINING_KEYS: Array[String] = ["next_light", "next_heavy", "next_auto", "combo_window_start_frame",
	"combo_window_end_frame"]
## Keys of every swing row that live on the feel page; the row's other keys
## are on the Mage's page.
const FEEL_ROW_KEYS: Array[String] = ["hitstop_frames", "knockback_m"]
## The page each section lives on, for messages (page_of).
const PAGE_OF_SECTION := {
	"player": "character", "dodge": "character", "blink": "character", "drink": "character",
	"combo": "mage", "ultimate": "mage",
	"camera": "camera-and-arena", "look": "camera-and-arena",
	"shake": "feel", "trail": "feel",
	"global": "global",
}
## The Mage's move presets: each names the saved preset a move of his plays
## ("" for the move's own look). They live on his page headed [mage.look]
## and read into the common [look] section.
const MAGE_LOOK := {
	"look.ground_shake_fx": ["preset", "ground_shake"],
	"look.sand_slash_fx": ["preset", "sand_slash"],
	"look.whirlwind_fx": ["preset", "whirlwind"],
	"look.tornado_fx": ["preset", "tornado"],
	"look.blink_fx": ["preset", "blink"],
	"look.ultimate_fx": ["preset", "time_slow"],
}

static var _folder := ""


## The page `section`'s `key` lives on (the Mage's rows on his page, their
## feel keys on the feel page; the ring arena's sections on the volcano's).
static func page_of(section: String, key: String) -> String:
	section = Kit.from_header(section)
	if Moves.is_row(section):
		return "feel" if key in FEEL_ROW_KEYS else Kit.MAGE_PAGE
	if MAGE_LOOK.has("%s.%s" % [section, key]):
		return Kit.MAGE_PAGE
	return PAGE_OF_SECTION.get(section, "volcano")


## The rule of `section`'s `key` where the lab knows one (a move row's, from
## Moves.KINDS; a Mage move preset's ["preset", recipe]), else [].
static func rule_of(section: String, key: String) -> Array:
	section = Kit.from_header(section)
	if Moves.is_row(section):
		return Moves.row_rule(key)
	return MAGE_LOOK.get("%s.%s" % [section, key], [])


## The folder the lab reads its pages from: res://tuning unless use_folder
## pointed it elsewhere.
static func default_path() -> String:
	return _folder if _folder != "" else "res://tuning"


## Points default_path at `folder` for the rest of the run ("" for res://tuning).
static func use_folder(folder: String) -> void:
	_folder = folder


## Reads every page from `folder` and merges them.
static func load_folder(folder: String) -> Result:
	var result := parse(read_pages(folder))
	if result.error != "":
		result.error = "In the tuning folder %s:\n%s" % [folder, result.error]
	return result


## The text of every page found in `folder` (page name -> text).
static func read_pages(folder: String) -> Dictionary:
	var pages := {}
	for page in PAGES:
		var path := folder.path_join(page + ".cfg")
		if FileAccess.file_exists(path):
			pages[page] = FileAccess.get_file_as_string(path)
	return pages


## Merges `pages` (page name -> page text) into one set of values by
## section. The Mage's page's [mage.<section>] headers read as the sections
## his kit plays ([mage.move.light_1] -> [move.light_1]); his Light group's
## values fill each light swing. A move row's whole-number keys read as
## whole numbers, its other numbers as decimals (Moves.row_rule).
static func parse(pages: Dictionary) -> Result:
	var result := Result.new()
	var files := {}
	for page in PAGES:
		if not pages.has(page):
			result.error = "%s.cfg is missing (every tuning page must exist)" % page
			return result
		var file := ConfigFile.new()
		if file.parse(pages[page]) != OK:
			result.error = "%s.cfg could not be read (check each line is key = value, [section] or a ; comment)" % page
			return result
		if page == Kit.MAGE_PAGE:
			var own := ConfigFile.new()
			for header: String in file.get_sections():
				for key: String in file.get_section_keys(header):
					own.set_value(Kit.from_header(header), key, file.get_value(header, key))
			file = own
		files[page] = file
	var light := _resolve_light_groups(files)
	if light != "":
		result.error = light
		return result
	for page in PAGES:
		var file: ConfigFile = files[page]
		for section: String in file.get_sections():
			if not result.values.has(section):
				result.values[section] = {}
			for key: String in file.get_section_keys(section):
				result.values[section][key] = _typed(section, key, file.get_value(section, key))
	return result


## `value` as the game reads it: a move row's whole number as an int, its
## number as a float; any other value as the page wrote it.
static func _typed(section: String, key: String, value: Variant) -> Variant:
	if not (value is int or value is float) or not Moves.is_row(section):
		return value
	var rule := Moves.row_rule(key)
	if rule.is_empty():
		return value
	if rule[0] == "whole number":
		return int(value)
	if rule[0] == "number":
		return float(value)
	return value


## Fills each light swing ([move.light_<n>], on any page) with every key of
## its page's Light group ([move.light]) its own section lacks, then drops
## the group. Returns "" or what is wrong.
static func _resolve_light_groups(files: Dictionary) -> String:
	var swings: Array[String] = []
	for page: String in files:
		for section: String in (files[page] as ConfigFile).get_sections():
			if light_group_of(section) != "" and not section in swings:
				swings.append(section)
	for page: String in files:
		var file: ConfigFile = files[page]
		for group: String in file.get_sections():
			if not is_light_group(group):
				continue
			for key: String in file.get_section_keys(group):
				if key in CHAINING_KEYS:
					return "%s.cfg: [%s] %s is a chaining value: it goes on each light swing's own section" % [
						page, Kit.header_of(page, group), key]
			for swing: String in swings:
				for key: String in file.get_section_keys(group):
					if not file.has_section_key(swing, key):
						file.set_value(swing, key, file.get_value(group, key))
			file.erase_section(group)
	return ""


## True for the Light group's section, [move.light].
static func is_light_group(section: String) -> bool:
	return Kit.from_header(section) == Moves.ROW_PREFIX + LIGHT_GROUP


## The Light group section a light swing's section plays ([mage.move.light_3]
## -> [mage.move.light]), or "" for any other section.
static func light_group_of(section: String) -> String:
	var own := Kit.from_header(section)
	var swing := Moves.ROW_PREFIX + LIGHT_GROUP + "_"
	if not (own.begins_with(swing) and own.trim_prefix(swing).is_valid_int()):
		return ""
	return section.substr(0, section.length() - own.length()) + Moves.ROW_PREFIX + LIGHT_GROUP


## A parse: the merged values, or the error that stopped it ("" for none).
class Result:
	var values: Dictionary = {}
	var error := ""
