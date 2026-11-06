## The saved presets (FxPreset; spec Q5, Q6): one resource file per recipe and
## name, res://fx/presets/<recipe>/<name>.tres (a recipe of a character pack's: in
## his own folder, CharacterPack.presets_folder, so it follows his switch). The game loads a preset by
## name; a move names its preset with a word value on its character's tuning
## page (rule ["preset", recipe], resolve). The VFX lab saves, duplicates and
## renames them; its Commit presets commits only this folder. Node-free, pure
## static.
class_name FxPresets
extends RefCounted

## The presets' folder in the game.
const FOLDER := "res://fx/presets"
## Characters a preset's name may not hold (it is a file name).
const FORBIDDEN := ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]

static var _folder := ""
## version_of's hashes: path -> [modified time, hash].
static var _versions := {}
## How long (s) after its modified time a file is still hashed every ask.
const FRESH_S := 2


## The folder presets are read from and saved to: FOLDER unless use_folder
## pointed it elsewhere (the tests' scratch folders).
static func folder() -> String:
	return _folder if _folder != "" else FOLDER


## Points folder() at `path` for the rest of the run ("" for FOLDER again).
static func use_folder(path: String) -> void:
	_folder = path


## The folder `recipe`'s presets are in: its pack's for a pack's recipe, unless
## use_folder pointed everything elsewhere.
static func folder_of(recipe: String) -> String:
	if _folder != "":
		return _folder
	var own := CharacterPacks.presets_folder_of(recipe)
	return own if own != "" else FOLDER


## Every folder presets are saved in (the lab's Commit presets commits them all):
## folder(), then each pack's, unless use_folder pointed everything elsewhere.
static func folders() -> Array[String]:
	var out: Array[String] = [folder()]
	if _folder == "":
		out.append_array(CharacterPacks.presets_folders())
	return out


## The file of `recipe`'s preset `name`.
static func path_of(recipe: String, name: String) -> String:
	return folder_of(recipe).path_join(recipe).path_join(name + ".tres")


## `recipe`'s saved presets' names, sorted.
static func names(recipe: String) -> Array[String]:
	var out: Array[String] = []
	var dir := folder_of(recipe).path_join(recipe)
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f: String in DirAccess.get_files_at(dir):
		# An export may keep a converted resource's original name as a remap.
		var file := f.trim_suffix(".remap")
		if file.get_extension() == "tres" and not file.get_basename() in out:
			out.append(file.get_basename())
	out.sort()
	return out


## Every recipe with a presets folder, sorted.
static func recipes() -> Array[String]:
	var out: Array[String] = []
	for each: String in folders():
		if DirAccess.dir_exists_absolute(each):
			for d: String in DirAccess.get_directories_at(each):
				if not d in out:
					out.append(d)
	out.sort()
	return out


## `recipe`'s preset `name` read from its file (never a cached copy), or null
## when none is saved by that name.
static func load_preset(recipe: String, name: String) -> FxPreset:
	if not name in names(recipe):
		return null
	return ResourceLoader.load(path_of(recipe, name), "", ResourceLoader.CACHE_MODE_IGNORE) as FxPreset


## A fingerprint of `recipe`'s preset `name` as saved now (its file's MD5;
## "" when none is saved): it changes whenever the lab saves over it, so a
## developer build can re-read a preset the game already holds.
## The hash is kept per file while its modified time stands (perf pass 18:
## a hash reads the whole file, ~0.5 ms, and every drawn preset asks every
## half second); a file modified within FRESH_S is hashed again each time,
## as the modified time counts whole seconds.
static func version_of(recipe: String, name: String) -> String:
	var path := path_of(recipe, name)
	var modified := FileAccess.get_modified_time(path)
	if modified == 0:
		# None saved, or no modified time (a packed build's file): hashed
		# each time.
		_versions.erase(path)
		return FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
	var kept: Array = _versions.get(path, [])
	var settled := int(Time.get_unix_time_from_system()) - modified > FRESH_S
	if not kept.is_empty() and int(kept[0]) == modified and settled:
		return kept[1]
	var version := FileAccess.get_md5(path)
	_versions[path] = [modified, version]
	return version


## Why `name` cannot name a preset, or "" when it can.
static func name_error(name: String) -> String:
	if name.strip_edges() == "":
		return "A preset needs a name."
	if name != name.strip_edges():
		return "A preset's name may not start or end with a space: \"%s\"." % name
	if name.begins_with("."):
		return "A preset's name may not start with a dot: \"%s\"." % name
	for c: String in FORBIDDEN:
		if name.contains(c):
			return "A preset's name may not hold %s: \"%s\"." % [c, name]
	return ""


## Writes `preset` as its recipe's preset `name` (over one saved by that
## name). Returns "" or why it was not saved.
static func save(preset: FxPreset, name: String) -> String:
	var bad := name_error(name)
	if bad != "":
		return bad
	if preset.recipe == "" or name_error(preset.recipe) != "":
		return "A preset needs its recipe's name to be saved: \"%s\"." % preset.recipe
	var path := path_of(preset.recipe, name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	# Saved from a copy, so the file is never tied to the edited resource's path.
	var copy := preset.duplicate(true) as FxPreset
	var error := ResourceSaver.save(copy, path)
	return "" if error == OK else "Not saved: %s could not be written (%s)." % [path, error_string(error)]


## Saves a copy of `recipe`'s preset `name` as `new_name`. Returns "" or why not.
static func duplicate_preset(recipe: String, name: String, new_name: String) -> String:
	var preset := load_preset(recipe, name)
	if preset == null:
		return "No preset \"%s\" of %s to duplicate." % [name, recipe]
	if new_name in names(recipe):
		return "%s already has a preset \"%s\"." % [recipe, new_name]
	return save(preset, new_name)


## Renames `recipe`'s preset `name` to `new_name`. Returns "" or why not.
static func rename(recipe: String, name: String, new_name: String) -> String:
	if load_preset(recipe, name) == null:
		return "No preset \"%s\" of %s to rename." % [name, recipe]
	var error := duplicate_preset(recipe, name, new_name)
	if error != "":
		return error
	var removed := DirAccess.remove_absolute(path_of(recipe, name))
	return "" if removed == OK else "Saved as \"%s\" but \"%s\" could not be removed (%s)." % [new_name, name,
		error_string(removed)]


## The preset `section`'s `key` names on the tuning pages (`values`, as
## Tuning.parse merged them; its rule ["preset", recipe]): {preset, name,
## error}. A name with no saved preset is an error naming the page, the key,
## the name and the saved ones, never a silent default; "" names none
## (preset null, no error: the move keeps its own effect).
static func resolve(values: Dictionary, section: String, key: String) -> Dictionary:
	var rule := Tuning.rule_of(section, key)
	var out := {"preset": null, "name": "", "error": ""}
	var page := Tuning.page_of(section, key)
	var where := "%s.cfg [%s] %s" % [page, Kit.header_of(page, section), key]
	if rule.is_empty() or rule[0] != "preset":
		out["error"] = "%s is not a preset's name on the tuning pages." % where
		return out
	var recipe: String = rule[1]
	var name: String = str(values.get(section, {}).get(key, ""))
	out["name"] = name
	if name == "":
		return out
	var preset := load_preset(recipe, name)
	if preset == null:
		var saved := names(recipe).map(func(n: String) -> String: return "\"%s\"" % n)
		out["error"] = "%s names no saved preset of the %s recipe: \"%s\" (saved in %s: %s)" % [where, recipe, name,
			folder_of(recipe).path_join(recipe), ", ".join(saved) if not saved.is_empty() else "none yet"]
		return out
	out["preset"] = preset
	return out
