## The lab's reach slider's page work: where a move's reach lives on the
## tuning pages (spot_of), and the pages with it changed (edited). The lab
## draws the effect and the hit outline at the slider's value at once; it
## never writes the pages. To keep a reach, write the value the slider shows
## on its line in tuning/mage.cfg (the slider's label names it).
## Node-free, pure static.
extends RefCounted


## Where `character`'s `move` keeps the reach its hit area is drawn from
## (FxReach.hit_of of its `data`: the first of FxReach.REACH_KEYS it holds)
## on `pages` (page -> text, Tuning.read_pages): {page, section (the page's
## header), key, value (m), rule (Tuning.rule_of)}. A light swing with no
## line of its own plays its Light group's ([mage.move.light]): that one.
## {} for a move whose reach is on no page of his.
static func spot_of(pages: Dictionary, character: String, move: String, data: Dictionary) -> Dictionary:
	var key := ""
	for reach_key: String in FxReach.REACH_KEYS:
		if data.has(reach_key):
			key = reach_key
			break
	return _spot(pages, character, move, key)


## `character`'s `move`'s line `key` on `pages`, as spot_of gives it.
static func _spot(pages: Dictionary, character: String, move: String, key: String) -> Dictionary:
	var page: String = Kit.MAGE_PAGE
	if character != Kit.MAGE or not pages.has(page) or key == "":
		return {}
	var section := "%s.move.%s" % [character, move]
	if move == Moves.ULTIMATE_MOVE:
		section = "%s.%s" % [character, Moves.ULTIMATE_MOVE]
	if TuningText.value_of(pages[page], section, key) == "":
		section = Tuning.light_group_of(section)
		if section == "" or TuningText.value_of(pages[page], section, key) == "":
			return {}
	return {"page": page, "section": section, "key": key,
		"value": float(TuningText.value_of(pages[page], section, key)),
		"rule": Tuning.rule_of(Kit.from_header(section), key)}


## `spot`'s line set to `value` (m) on `pages`, as the page would read: the
## raw text (kept within its rule's range) and the pages' text.
## {raw, pages, error}.
static func edited(pages: Dictionary, spot: Dictionary, value: float) -> Dictionary:
	var rule: Array = spot["rule"]
	if rule.size() == 3 and rule[0] == "number":
		value = clampf(value, float(rule[1]), float(rule[2]))
	var raw := String.num(snappedf(value, 0.01))
	if not raw.contains("."):
		raw += ".0"
	var out := pages.duplicate()
	out[spot["page"]] = TuningText.with_value(pages[spot["page"]], spot["section"], spot["key"], raw)
	return {"raw": raw, "pages": out, "error": ""}
