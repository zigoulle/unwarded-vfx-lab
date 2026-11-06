## Kits (GLOSSARY "Kit"; Duelist spec "The kit seam"): what one character
## brings to a run that another does not share, as tuning. Node-free, pure
## static.
##
## The mage's kit is his own page, mage.cfg (MAGE_PAGE): [mage.combo],
## [mage.ultimate], every [mage.move.<name>] row. Tuning reads them as the
## unprefixed sections his kit has always played ([combo], [ultimate],
## [move.<name>], header_of / from_header), so the merged values, and all
## that reads them, are as before his page moved; his rows' hit-stop and
## knockback stay on the shared feel page. Another character's kit lives on
## its own page (PAGES), every section prefixed with its id and kept so in
## the merged values: [duelist.combo], [duelist.move.light_1], [duelist.ultimate],
## [duelist.parry]... Each validates as the section without its prefix would
## (Tuning), so his rows run through the same Moves and CombatSim code as the
## mage's. Everything else (walking, HP, the dodge and its meter, the blink,
## potions, the drink, lives, the enemies, the zone) is common to every kit.
##
## tuning_of turns merged tuning (Tuning.parse's values) into the tuning one
## kit plays: the common sections plus its own, prefix stripped. CombatSim
## builds one per character a player plays (CombatSim.for_character).
class_name Kit
extends RefCounted

## The character whose kit is the unprefixed sections, and who plays when a
## player's character is absent or has no kit in the tuning.
const MAGE := "mage"
## The mage's own page (Tuning.PAGES), every section named [mage.<section>].
const MAGE_PAGE := "mage"
## Every other character with a kit: id -> its tuning page (Tuning.PAGES).
## The pistol shrimp's page is behind the content switch (Tuning.WATER_SHRIMP_PAGE;
## his keys beside every kit's come from his pack, CharacterPacks.kit_keys): with
## no page, or a page holding none of his kit, has_kit stays false.
const PAGES := {"duelist": "duelist", "pistol_shrimp": "zones/water-shrimp"}
## The mage's own fixed sections (the rows, [move.<name>], are his too); a
## character's kit has its own instead.
const OWN_SECTIONS: Array[String] = ["combo", "ultimate"]


## The character id `player` (a CombatSim player) plays: its `character`,
## the mage when it has none.
static func id_of(player: Dictionary) -> String:
	return str(player.get("character", MAGE))


## The character whose kit `section` is a section of on its own page
## ("duelist" for [duelist.move.light_1]), or "" for any other section (the
## mage's own and the common ones).
static func character_of(section: String) -> String:
	for id: String in PAGES:
		if section.begins_with(id + ".") and section.length() > id.length() + 1:
			return id
	return ""


## `section` without its character's prefix ([duelist.move.light_1] ->
## [move.light_1], [mage.move.light_1] -> [move.light_1]); any other section
## as it is.
static func strip(section: String) -> String:
	var id := character_of(section)
	return section.substr(id.length() + 1) if id != "" else from_header(section)


## True for a section header as the mage's page writes it ([mage.combo]).
static func is_mage_header(section: String) -> bool:
	return section.begins_with(MAGE_PAGE + ".") and section.length() > MAGE_PAGE.length() + 1


## The section a header of the mage's page stands for ([mage.move.light_1]
## -> [move.light_1]); any other section as it is.
static func from_header(section: String) -> String:
	return section.substr(MAGE_PAGE.length() + 1) if is_mage_header(section) else section


## How section `section` is headed on `page`: every section on his page
## with his name ([mage.combo], and [mage.look] for the [look] keys his
## page holds, Tuning.MAGE_LOOK); every other as it is.
static func header_of(page: String, section: String) -> String:
	return "%s.%s" % [MAGE_PAGE, section] if page == MAGE_PAGE and not is_mage_header(section) else section


## True when `values` (merged tuning) holds a kit for character `id`: the
## mage always; another character when its page gives it a [<id>.combo].
static func has_kit(values: Dictionary, id: String) -> bool:
	return id == MAGE or (PAGES.has(id) and values.has(id + ".combo"))


## True for a section of the mage's own kit (OWN_SECTIONS, his rows).
static func is_mages_own(section: String) -> bool:
	return section in OWN_SECTIONS or Moves.is_row(section)


## The tuning character `id` plays, out of `values` (merged tuning): the
## common sections, then its own sections with their prefix stripped (a
## stripped section that is also a common one, [duelist.look] over [look],
## adds its keys to it). The mage's is `values` without any other kit's
## sections: `values` itself when there are none. A character with no kit
## in `values` (has_kit) plays the mage's.
static func tuning_of(values: Dictionary, id: String) -> Dictionary:
	if not has_kit(values, id):
		id = MAGE
	var foreign := false
	for section: String in values:
		if character_of(section) != "":
			foreign = true
			break
	if id == MAGE and not foreign:
		return values
	var out := {}
	for section: String in values:
		if character_of(section) == "" and not (id != MAGE and is_mages_own(section)):
			out[section] = values[section]
	if id == MAGE:
		return out
	for section: String in values:
		if character_of(section) != id:
			continue
		var own := strip(section)
		if out.has(own):
			var merged: Dictionary = out[own].duplicate()
			merged.merge(values[section], true)
			out[own] = merged
		else:
			out[own] = values[section]
	return out


## Every character with a kit in `values`, the mage first, then PAGES' order.
static func characters(values: Dictionary) -> Array[String]:
	var out: Array[String] = [MAGE]
	for id: String in PAGES:
		if has_kit(values, id):
			out.append(id)
	return out
