## Reads and rewrites the text of one tuning page line by line, for the
## tuning screen (TuningScreen). Node-free, pure static.
##
## A rewrite changes only the value after the `=` on one `key = value` line
## inside the named [section]: every comment, blank line, the order, the
## spacing and the line endings (\n or \r\n) stay as they were, so the page
## still reads as written and git shows a one-line change. The value text is
## written as given (a number like 7.0, a word in quotes like "chip").
class_name TuningText
extends RefCounted


## `text` with `section`'s `key` set to `value` (the raw text after the `=`),
## or `text` unchanged when the page has no such key in that section.
static func with_value(text: String, section: String, key: String, value: String) -> String:
	var lines := text.split("\n")
	var at := _line_of(lines, section, key)
	if at < 0:
		return text
	var line := lines[at]
	var cr := "\r" if line.ends_with("\r") else ""
	var body := line.trim_suffix("\r")
	var eq := body.find("=")
	var after := body.substr(eq + 1)
	var gap := after.substr(0, after.length() - after.lstrip(" \t").length())
	lines[at] = body.substr(0, eq + 1) + gap + value + cr
	return "\n".join(lines)


## `text` without `section`'s `key` line (a light swing's override going back
## to its Light group), or `text` unchanged when the page has no such key
## there. The comment lines right above it go with it when they are its own:
## no value line under it shares them.
static func without_key(text: String, section: String, key: String) -> String:
	var lines := text.split("
")
	var at := _line_of(lines, section, key)
	if at < 0:
		return text
	var first := at
	var shared := at + 1 < lines.size() and _is_value_line(lines[at + 1].strip_edges())
	while not shared and first > 0 and lines[first - 1].strip_edges().begins_with(";"):
		first -= 1
	var kept: PackedStringArray = lines.slice(0, first)
	kept.append_array(lines.slice(at + 1))
	return "
".join(kept)


## The raw value text of `section`'s `key` (what follows the `=`, trimmed),
## or "" when the page has no such key there.
static func value_of(text: String, section: String, key: String) -> String:
	var lines := text.split("\n")
	var at := _line_of(lines, section, key)
	return "" if at < 0 else _value(lines[at])


## The `;` comment lines right above `section`'s `key` (no blank line
## between), without the `;`, one per line: the key's help on the page. A
## key in a group of value lines under one comment (no blank line between)
## shares that comment.
static func help_of(text: String, section: String, key: String) -> String:
	var lines := text.split("\n")
	var at := _line_of(lines, section, key)
	var help: PackedStringArray = []
	var i := at - 1
	while at >= 0 and i >= 0 and _is_value_line(lines[i].strip_edges()):
		i -= 1
	while at >= 0 and i >= 0 and lines[i].strip_edges().begins_with(";"):
		help.insert(0, lines[i].strip_edges().trim_prefix(";").strip_edges())
		i -= 1
	return "\n".join(help)


## Every value on the page in order: [{section, key, value}] (value = raw text).
static func entries(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var section := ""
	for line: String in text.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("["):
			section = _section_of(stripped)
		elif section != "" and _is_value_line(stripped):
			out.append({"section": section, "key": stripped.get_slice("=", 0).strip_edges(), "value": _value(line)})
	return out


static func _line_of(lines: PackedStringArray, section: String, key: String) -> int:
	var current := ""
	for i in lines.size():
		var stripped := lines[i].strip_edges()
		if stripped.begins_with("["):
			current = _section_of(stripped)
		elif current == section and _is_value_line(stripped) and stripped.get_slice("=", 0).strip_edges() == key:
			return i
	return -1


static func _section_of(stripped: String) -> String:
	return stripped.get_slice(";", 0).strip_edges().trim_prefix("[").trim_suffix("]").strip_edges()


static func _is_value_line(stripped: String) -> bool:
	return stripped != "" and not stripped.begins_with(";") and stripped.contains("=")


static func _value(line: String) -> String:
	return line.substr(line.find("=") + 1).strip_edges()
