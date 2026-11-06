## The lab's Commit presets (grill Q6): commits the presets folder
## (res://fx/presets, FxPresets) and nothing else in the working tree to the
## current branch, saved, duplicated, renamed (the old file's removal
## included) and removed presets alike, with a message naming each. Prior
## art: the tuning screen's Commit tuning (TuningCommit). Node-free.
##
## Git runs through `runner` (Callable(args: PackedStringArray) -> {code,
## output}; TuningCommit.git_runner in the lab, a fake in the tests). A
## commit git cannot make comes back as the reason and the command line to
## run by hand.
extends RefCounted

## How plan's error starts when its folder has no change.
const NOTHING := "Nothing to commit"


## What a commit of every folder in `folders` would hold (FxPresets.folders: the
## shared one and a character's): plan's, with each folder's presets and `paths`,
## the folders that changed. A folder with no change stays out: `git commit
## --only` fails on a path with nothing tracked under it. The first error stands.
static func plan_all(folders: Array, runner: Callable) -> Dictionary:
	var out := {}
	var paths: Array = []
	var every: Array = []
	for folder: String in folders:
		var one := plan(folder, runner)
		if out.is_empty():
			out = one
		if str(one["error"]).begins_with(NOTHING):
			continue
		if one["error"] != "":
			return one
		paths.append(one["path"])
		every.append_array(one["presets"])
	if not paths.is_empty():
		out["error"] = ""
		out["paths"] = paths
		out["path"] = paths[0]
		out["presets"] = every
		out["command"] = command_line(out["root"], paths, "")
	return out


## What a commit would hold: {root, path (the folder from the repo root),
## presets: [{change: added|changed|removed, recipe, name}], error, command}.
static func plan(folder: String, runner: Callable) -> Dictionary:
	var out := {"root": folder.get_base_dir(), "path": folder.get_file(), "presets": [], "error": "", "command": ""}
	out["command"] = command_line(out["root"], out["path"], "")
	var top: Dictionary = runner.call(PackedStringArray(["-C", folder, "rev-parse", "--show-toplevel"]))
	if top["code"] != 0:
		out["error"] = "Not committed: git was not found, or %s is not in a git repository." % folder
		return out
	var root: String = str(top["output"]).strip_edges()
	out["root"] = root
	out["path"] = folder.trim_prefix(root).trim_prefix("/")
	out["command"] = command_line(root, out["path"], "")
	if _git(runner, root, ["rev-parse", "-q", "--verify", "MERGE_HEAD"])["code"] == 0:
		out["error"] = "Not committed: a merge is in progress. Finish it (git merge --continue) or abort it, then commit."
		return out
	var status := _git(runner, root, ["status", "--porcelain", "--untracked-files=all", "--", out["path"]])
	if status["code"] != 0:
		out["error"] = "Not committed: git status failed:\n" + str(status["output"]).strip_edges()
		return out
	out["presets"] = presets(str(status["output"]), out["path"])
	if out["presets"].is_empty():
		out["error"] = NOTHING + ": the presets match the last commit."
	return out


## The presets `status` (`git status --porcelain` under `path`) shows:
## [{change, recipe, name}], in its order. A rename's two sides are a
## removal and an addition; any other file is listed by its path (_add).
static func presets(status: String, path: String) -> Array:
	var out: Array = []
	for line: String in status.split("\n", false):
		line = line.trim_suffix("\r")
		if line.length() < 4:
			continue
		var code := line.left(2)
		var file := line.substr(3)
		if code.contains("R") or code.contains("C"):
			var sides := file.split(" -> ")
			if code.contains("R"):
				_add(out, "removed", unquoted(sides[0]), path)
			_add(out, "added", unquoted(sides[sides.size() - 1]), path)
		elif code.contains("D"):
			_add(out, "removed", unquoted(file), path)
		elif code == "??" or code.contains("A"):
			_add(out, "added", unquoted(file), path)
		else:
			_add(out, "changed", unquoted(file), path)
	return out


## A path as git's status writes it, unquoted: git puts a path with a space
## or an unusual letter in quotes, with C escapes (a backslash before a
## quote, a backslash or a tab; a byte of a letter such as é in octal).
static func unquoted(text: String) -> String:
	if not (text.length() >= 2 and text.begins_with("\"") and text.ends_with("\"")):
		return text
	var inner := text.substr(1, text.length() - 2)
	var bytes := PackedByteArray()
	var i := 0
	while i < inner.length():
		var c := inner[i]
		if c != "\\" or i + 1 >= inner.length():
			bytes.append_array(c.to_utf8_buffer())
			i += 1
			continue
		if i + 3 < inner.length() and inner.substr(i + 1, 3).is_valid_int():
			bytes.append(_octal(inner.substr(i + 1, 3)))
			i += 4
			continue
		bytes.append_array({"t": "\t", "n": "\n", "\"": "\"", "\\": "\\"}.get(inner[i + 1], inner[i + 1]).to_utf8_buffer())
		i += 2
	return bytes.get_string_from_utf8()


## The number the octal `digits` write (git's quoted path escapes).
static func _octal(digits: String) -> int:
	var n := 0
	for d: String in digits:
		n = n * 8 + int(d)
	return n


## A preset's file as {change, recipe, name}; any other file in the folder
## (the commit takes it too) as {change, recipe: "", name: its path there}.
static func _add(out: Array, change: String, file: String, path: String) -> void:
	var inside := file.trim_prefix(path + "/")
	if inside.get_extension() == "tres" and inside.count("/") == 1:
		out.append({"change": change, "recipe": inside.get_slice("/", 0), "name": inside.get_file().get_basename()})
	else:
		out.append({"change": change, "recipe": "", "name": inside})


## One preset as the message and the lab list it ("added tornado: tornado -
## sand"; another file: "added file notes.txt").
static func line(preset: Dictionary) -> String:
	if preset["recipe"] == "":
		return "%s file %s" % [preset["change"], preset["name"]]
	return "%s %s: %s" % [preset["change"], preset["recipe"], preset["name"]]


## The commit message: a subject with the count, one line per preset, then
## the co-author.
static func message(presets: Array) -> String:
	var lines: PackedStringArray = ["P-O's presets: %d change%s from the VFX lab" % [presets.size(),
		"" if presets.size() == 1 else "s"], ""]
	for preset: Dictionary in presets:
		lines.append(line(preset))
	lines.append_array(["", "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>", ""])
	return "\n".join(lines)


## Commits `plan`'s folder (and only it: `commit --only`, whatever else is
## staged) with `message` of its presets, written to `message_path`.
## Returns {hash, error, command}.
static func commit(plan: Dictionary, message_path: String, runner: Callable) -> Dictionary:
	var root: String = plan["root"]
	var paths: Array = plan.get("paths", [plan["path"]])
	var out := {"hash": "", "error": "", "command": command_line(root, paths, message_path)}
	var file := FileAccess.open(message_path, FileAccess.WRITE)
	if file == null:
		out["error"] = "Not committed: the message file %s could not be written." % message_path
		out["command"] = command_line(root, paths, "")
		return out
	file.store_string(message(plan["presets"]))
	file.close()
	for step: Array in [["add", "-A", "--"], ["commit", "--only", "-F", message_path, "--"]]:
		var done := _git(runner, root, step + paths)
		if done["code"] != 0:
			out["error"] = "Not committed: git %s failed:\n%s" % [step[0], str(done["output"]).strip_edges()]
			return out
	out["hash"] = str(_git(runner, root, ["rev-parse", "--short", "HEAD"])["output"]).strip_edges()
	return out


## The command lines that add and commit `path` (one, or an Array of them) in
## `root`, as typed by hand.
static func command_line(root: String, path: Variant, message_path: String) -> String:
	var paths: Array = path if path is Array else [path]
	var add := PackedStringArray(["git", "-C", root, "add", "-A", "--"]) + PackedStringArray(paths)
	var commit := PackedStringArray(["git", "-C", root, "commit", "--only"])
	if message_path != "":
		commit.append_array(["-F", message_path])
	commit.append_array(["--"])
	commit.append_array(PackedStringArray(paths))
	return "%s && %s" % [_quoted(add), _quoted(commit)]


## Runs git `args` in the repo at `root` through `runner`: {code, output}.
static func _git(runner: Callable, root: String, args: Array) -> Dictionary:
	return runner.call(PackedStringArray(["-C", root]) + PackedStringArray(args))


## `args` as one command line, quoting those with a space or a quote (the log).
static func _quoted(args: PackedStringArray) -> String:
	var out: PackedStringArray = []
	for arg: String in args:
		out.append("\"%s\"" % arg if arg.contains(" ") or arg.contains("'") else arg)
	return " ".join(out)
