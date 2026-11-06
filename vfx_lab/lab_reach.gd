## The lab's reach slider's page work (VFX all-spells ticket 16; spec: "a
## reach slider at the top of the preset panel edits the real reach (the same
## value the tuning screen writes, on the live page)"). Where a move's reach
## lives on the pages (spot_of) and writing it there the way the tuning
## screen's Apply does (write: TuningChanges.apply, the one line and the
## change log), so the tuning screen's Commit tuning commits it with the rest.
## Node-free, pure static. Developer only, never exported (the lab's folder).
extends RefCounted

## The fusion's slot key its look's reach follows (Moves.fused: every hit
## size times it).
const FUSION_KEY := "reach_mult"


## Where `character`'s `move` keeps the reach its hit area is drawn from
## (FxReach.hit_of of its `data`: the first of FxReach.REACH_KEYS it holds)
## on `pages` (page -> text, Tuning.read_pages): {page, section (the page's
## header), key, value (m), rule (Tuning.rule_of)}. A light swing with no
## line of its own plays its Light group's ([mage.move.light]): that one.
## The parry's is its cone, [<character>.parry] front_half_angle_deg (deg).
## A hop's (the log roll's two lobes, ticket 12) its front lobe's,
## reach_front_m (back_spot_of: its back lobe's). The fusion's (ticket 13:
## drawn for the greatsword's reach, FxMoves.data_of) its own reach_mult on
## [<character>.ultimate] (times, not m).
## {} for a move whose reach is on no page of his.
static func spot_of(pages: Dictionary, character: String, move: String, data: Dictionary) -> Dictionary:
	var key := ""
	for reach_key: String in FxReach.REACH_KEYS:
		if data.has(reach_key):
			key = reach_key
			break
	if data.has(FxReach.CONE_KEY):
		key = FxReach.CONE_KEY
	if data.has(FxReach.FRONT_KEY):
		key = FxReach.FRONT_KEY
	if data.has(FUSION_KEY):
		key = FUSION_KEY
	return _spot(pages, character, move, key)


## Where a two-lobe move (a hop: the log roll) keeps its back lobe's reach,
## reach_back_m, as spot_of; {} for a move with one.
static func back_spot_of(pages: Dictionary, character: String, move: String, data: Dictionary) -> Dictionary:
	return _spot(pages, character, move, FxReach.BACK_KEY if data.has(FxReach.BACK_KEY) else "")


## Where enemy `type` keeps the reach `key` of its attack's hit (FxMoves.ENEMY
## reach_key: the fire casters' projectile_radius_m, circle_radius_m) on
## the enemies page, as spot_of gives a move's; {} with none.
static func enemy_spot_of(pages: Dictionary, type: String, key: String) -> Dictionary:
	if key == "" or not Enemies.TYPES.has(type) or not pages.has("enemies"):
		return {}
	var section: String = Enemies.section_of(type)
	var value := TuningText.value_of(pages["enemies"], section, key)
	if value == "":
		return {}
	return {"page": "enemies", "section": section, "key": key, "value": float(value),
		"rule": Tuning.rule_of(section, key)}


## Where boon effect `recipe` (FxMoves.BOON) keeps its hit's reach (its
## reach_key on [boon.<id>]: the Fire bomb's explosion_radius_m) on the
## boons page, as spot_of gives a move's; {} with none.
static func boon_spot_of(pages: Dictionary, recipe: String) -> Dictionary:
	if not FxMoves.BOON.has(recipe) or not pages.has("boons"):
		return {}
	var section := Boons.section_of(FxMoves.BOON[recipe]["boon"])
	var key: String = FxMoves.BOON[recipe]["reach_key"]
	var value := TuningText.value_of(pages["boons"], section, key)
	if value == "":
		return {}
	return {"page": "boons", "section": section, "key": key, "value": float(value),
		"rule": Tuning.rule_of(section, key)}


## Where gear look `recipe` (FxMoves.gear_of) keeps its hit's reach on the
## gear page (the boots' fire puddle: [volcano_boots] trail_radius_m), as
## spot_of gives a move's; {} with none.
static func gear_spot_of(pages: Dictionary, recipe: String) -> Dictionary:
	var slot := FxMoves.gear_of(recipe)
	if slot.is_empty() or not pages.has("gear"):
		return {}
	var reach: Array = slot["reach"]
	var value := TuningText.value_of(pages["gear"], reach[0], reach[1])
	if value == "":
		return {}
	return {"page": "gear", "section": reach[0], "key": reach[1], "value": float(value),
		"rule": Tuning.rule_of(reach[0], reach[1])}


## `character`'s `move`'s line `key` on `pages`, as spot_of gives it.
static func _spot(pages: Dictionary, character: String, move: String, key: String) -> Dictionary:
	var page: String = Kit.MAGE_PAGE if character == Kit.MAGE else Kit.PAGES.get(character, "")
	if page == "" or not pages.has(page):
		return {}
	if key == "":
		return {}
	var section := "%s.move.%s" % [character, move]
	if key == FxReach.CONE_KEY:
		section = "%s.parry" % character
	elif key == FUSION_KEY or move == Moves.ULTIMATE_MOVE:
		section = "%s.%s" % [character, Moves.ULTIMATE_MOVE]
	elif FxMoves.is_reaction(move):
		section = "%s.%s" % [character, FxMoves.reaction_section(move)]
	if TuningText.value_of(pages[page], section, key) == "":
		section = Tuning.light_group_of(section)
		if section == "" or TuningText.value_of(pages[page], section, key) == "":
			return {}
	return {"page": page, "section": section, "key": key,
		"value": float(TuningText.value_of(pages[page], section, key)),
		"rule": Tuning.rule_of(Kit.from_header(section), key)}


## `spot`'s line set to `value` (m) on `pages`, as the page would read: the
## raw text (TuningValue.accept: clamped to its rule) and the pages' text.
## {raw, pages, error}.
static func edited(pages: Dictionary, spot: Dictionary, value: float) -> Dictionary:
	var accepted := TuningValue.accept(spot["rule"], String.num(snappedf(value, 0.01)), spot["section"], spot["key"])
	if accepted["error"] != "":
		return {"raw": "", "pages": pages, "error": accepted["error"]}
	var out := pages.duplicate()
	out[spot["page"]] = TuningText.with_value(pages[spot["page"]], spot["section"], spot["key"], accepted["value"])
	return {"raw": accepted["value"], "pages": out, "error": ""}


## Writes `spot`'s reach as `value` (m) into the pages in `folder` the way
## the tuning screen's Apply does (TuningChanges.apply; the change log at
## log_of(folder)). {changes, error}; on an error nothing is written.
static func write(folder: String, spot: Dictionary, value: float) -> Dictionary:
	var shown := edited(Tuning.read_pages(folder), spot, value)
	if shown["error"] != "":
		return {"changes": [], "error": shown["error"]}
	return TuningChanges.apply(folder, [{"page": spot["page"], "section": spot["section"], "key": spot["key"],
		"value": shown["raw"]}], log_of(folder), Time.get_datetime_string_from_system(false, true))


## The tuning screen's change log for `folder`: logs/tuning-changes.txt
## beside it (the game's TUNING_LOG for the live folder).
static func log_of(folder: String) -> String:
	return folder.path_join("../logs/tuning-changes.txt").simplify_path()
