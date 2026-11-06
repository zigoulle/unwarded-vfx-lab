## Which move each recipe plays with (P-O, 2026-10-22: "animation should
## match the hit we do"): the one table the game and the VFX lab both read,
## so they cannot disagree. A character behind the content switch adds his rows
## through his pack (CharacterPack.fx_recipes; table). Per recipe: the character, his move, and the
## move's preset knob on his tuning page ([section, key]: the word value the
## game resolves, FxPresets.resolve; its rule ["preset", recipe]). An empty
## knob: the game still draws that move's own effect (spec Q3: a move
## switches once P-O approves a preset for it), and the lab casts the recipe
## from that move all the same.
## A family (one recipe on several moves: the mage's three light slashes)
## lists them all in `moves`, its first the move the lab opens it on.
## A `reaction` (the Duelist's parry, all-spells ticket 11) is no move of
## his kit: it plays when the world says a blow was parried, with no clip
## (Q22: nothing on his body), and its data is his kit's [parry] section
## (data_of).
## The Duelist's fusion (all-spells ticket 13) is his ultimate (only while
## his [duelist.ultimate] effect is "fusion"): its data carries the hit its
## look is drawn for, the greatsword's (FUSION_SWING: his fused light's
## reach and arc, data_of), and it strikes on its clip's "swap" (hit_s).
## Its hit (hit_s): where the game shows the move clip's hit marker, the
## effect's impact before its trigger offset (spec: impact = the hit marker).
## Node-free, pure static. Looks only: the simulation never reads it.
class_name FxMoves
extends RefCounted

const MOVES := {
	"lightning_line": {"character": "duelist", "move": "dash", "knob": ["duelist.look", "dash_fx"]},
	"lightning_ring": {"character": "duelist", "move": "slam", "knob": ["duelist.look", "slam_fx"]},
	"light_strike": {"character": "duelist", "move": "light_1", "moves": ["light_1", "light_2", "light_3"],
		"knob": ["duelist.look", "light_fx"]},
	"heavy_spin": {"character": "duelist", "move": "throw_spin", "knob": ["duelist.look", "heavy_spin_fx"]},
	"blade_throw": {"character": "duelist", "move": "throw", "knob": ["duelist.look", "throw_fx"]},
	"parry": {"character": "duelist", "move": "parry", "knob": ["duelist.look", "parry_fx"], "reaction": true},
	"roll": {"character": "duelist", "move": "heavy", "moves": ["heavy", "heavy_2"], "knob": ["duelist.look", "roll_fx"]},
	"fusion": {"character": "duelist", "move": "ultimate", "knob": ["duelist.look", "fusion_fx"]},
	"tornado": {"character": "mage", "move": "tornado", "knob": ["look", "tornado_fx"]},
	"ground_shake": {"character": "mage", "move": "ground_shake", "knob": ["look", "ground_shake_fx"]},
	"sand_slash": {"character": "mage", "move": "light_1", "moves": ["light_1", "light_2", "light_3"],
		"knob": ["look", "sand_slash_fx"]},
	"whirlwind": {"character": "mage", "move": "whirlwind", "moves": ["whirlwind", "whirlwind_2"],
		"knob": ["look", "whirlwind_fx"]},
	"blink": {"character": "mage", "move": "blink", "knob": ["look", "blink_fx"]},
	"time_slow": {"character": "mage", "move": "ultimate", "knob": ["look", "ultimate_fx"]},
}
## World effects (on no move; spawn-pressure ticket 05): each recipe's
## preset knob on a zone page ([section, key]). The VFX lab lists them under
## either caster (its WORLD_EFFECTS).
const WORLD := {
	"spawner_swirl": {"knob": ["spawner_look", "swirl_fx"]},
	# The core mother's spinning X, each beam a flame jet (the polish pass,
	# P-O 2026-10-29): on no move, so a world effect; its knob on the
	# enemies page. The lab draws it at the shipped beam's half width.
	"flame_jet": {"knob": ["core_mother_look", "x_fx"]},
}
## Enemy attacks (enemy-vfx ticket 01): each recipe's casters (enemy types),
## the attack it draws (the projectile they throw, the ground circle they
## drop), its preset knob on the enemies page ([section, key]) and the key
## of the caster's row its hit's reach is (FxReach: its drawn ground edge is
## ratios of it). One preset for every caster of a recipe: the skeleton mage
## throws the fire elemental's projectile. The VFX lab casts them on each
## caster (its ENEMY_CASTERS).
const ENEMY := {
	"fireball": {"casters": ["elemental", "skeleton_mage"], "attack": "projectile",
		"knob": ["caster_look", "fireball_fx"], "reach_key": "projectile_radius_m"},
	"flame_strike": {"casters": ["elemental"], "attack": "circle", "knob": ["caster_look", "flame_strike_fx"],
		"reach_key": "circle_radius_m"},
}
## The boss boons' looks (gear-boons tickets 26 and 28): each look's recipe
## and its preset knob on the boons page ([section, key]); the game draws
## them on the boss boon's own shape (ScatterLooks, ShockwaveLooks), the lab
## tunes them under their recipe's caster.
const BOSS_BOON := {
	"scatter_splash": {"recipe": "flame_strike", "knob": ["boss_boon_look", "scatter_splash_fx"]},
	"lava_shockwave": {"recipe": "ground_shake", "knob": ["boss_boon_look", "shockwave_fx"]},
	# The core mother's (core-mother ticket 07; CoreMotherBoonLooks).
	"leg_stab": {"recipe": "ground_shake", "knob": ["boss_boon_look", "leg_stab_fx"]},
	"mother_volcano": {"recipe": "flame_strike", "knob": ["boss_boon_look", "mother_volcano_fx"]},
}
## The gear sets' looks (gear-boons ticket 33): each look's recipe and its
## preset knob on the gear page ([section, key]); the game draws them on the
## set's own shape (VolcanoSetLooks), the lab tunes them under their
## recipe's caster.
## A look with a `reach` ([section, key] on the gear page: its hit's reach;
## polish steps 9 and 10, P-O 2026-10-29) is drawn as ratios of it
## (FxReach), the lab listing it under either caster as a world effect
## (gear_of); a `life` ([section, key]) is how long its hit lasts (s).
const GEAR := {
	"volcano_aura": {"recipe": "flame_strike", "knob": ["volcano_set", "aura_fx"]},
	# The boots' fire trail: each patch a fire puddle, as wide as it burns.
	"volcano_trail": {"recipe": "fire_puddle", "knob": ["volcano_boots", "trail_fx"],
		"reach": ["volcano_boots", "trail_radius_m"], "life": ["volcano_boots", "trail_life_s"]},
	# The full set's aura: a heat shimmer and embers round its wearer, as
	# wide as it burns (no circle on the floor).
	"volcano_heat": {"recipe": "heat_aura", "knob": ["volcano_set", "heat_fx"],
		"reach": ["volcano_set", "aura_radius_m"]},
}
## Boon effects (playtest 2026-10-25 #3): each recipe's boon, its preset
## knob on the boons page ([section, key]; another piece may name the same
## preset with a knob of its own: the volcano helmet) and the boon's key
## its hit's reach is (FxReach: its drawn ground edge is ratios of it). The
## VFX lab lists them under either caster (its WORLD_EFFECTS), cast on a
## dummy dying.
const BOON := {
	"fire_bomb": {"boon": "fire_bomb", "knob": ["boon_look", "fire_bomb_fx"], "reach_key": "explosion_radius_m"},
	# The Throwing knives boon's knife (the light vs heavy pass, 2026-10-28):
	# cast in the lab from his hit, flying the boon's range at its speed.
	"throwing_knife": {"boon": "throwing_knives", "knob": ["boon_look", "throwing_knife_fx"],
		"reach_key": "knife_radius_m"},
}
## Looks an enemy wears on its body (new-enemies ticket 04): each recipe's
## wearers (enemy types) and its preset knob on the enemies page ([section,
## key]); always on while the wearer lives, it hits nothing (no reach). The
## VFX lab shows them on the wearer's model (its CREATURES).
const WORN := {
	"tiger_flames": {"wearers": ["fire_tiger"], "knob": ["fire_tiger_look", "flames_fx"]},
}
## The clips' frame rate (DuelistClips and MageClips: 60 frames a second).
const CLIP_FPS := 60.0
## A reaction's hit in the VFX lab (s after Space; it has no clip of its
## own): a beat after the cast, so it reads as a blow landing on him, and
## how long the lab plays it.
const REACTION_HIT_S := 0.3
const REACTION_LENGTH_S := 0.6
## The fused swing whose reach and arc the fusion's look is drawn for: his
## first light strike, the fan the fusion widens (arc_mult) and reaches
## further with (reach_mult).
const FUSION_SWING := "light_1"
## A reaction's kit section when its row names none (data_section): the parry's.
const PARRY_SECTION := "parry"

## table's: MOVES with the packs' rows, and the packs' rows it was merged from.
static var _merged := {}
static var _merged_from: Variant = null


## Every recipe's row: MOVES, then the character packs' (MOVES itself with none).
static func table() -> Dictionary:
	var packs := CharacterPacks.fx_recipes()
	if packs.is_empty():
		return MOVES
	if not is_same(packs, _merged_from):
		_merged_from = packs
		_merged = MOVES.merged(packs)
	return _merged


## Whether `move` is a reaction (no move of the kit: the parry).
static func is_reaction(move: String) -> bool:
	return not _reaction_row(move).is_empty()


## The row of the reaction `move`, or {} when it is none.
static func _reaction_row(move: String) -> Dictionary:
	var rows := table()
	for recipe: String in rows:
		var slot: Dictionary = rows[recipe]
		if slot.get("reaction", false) and move in moves_of(recipe):
			return slot
	return {}


## The kit section reaction `move` reads on `sim` (its row's data_section, the
## parry's by default); {} for a kit with none.
static func _reaction_data(sim: CombatSim, move: String) -> Dictionary:
	return sim.kit_section(reaction_section(move))


## The kit section reaction `move` reads (its row's data_section, the parry's by
## default).
static func reaction_section(move: String) -> String:
	return str(_reaction_row(move).get("data_section", PARRY_SECTION))


## `move`'s data on `sim` (its CombatSim.move_data; a reaction's, its kit's
## section: the parry's [parry], or the one its row names).
## The fusion's (is_fusion): its ultimate slot's with the greatsword's hit
## added, reach_m and arc_deg of his fused FUSION_SWING (the page's reach
## times reach_mult, its arc times arc_mult: CombatSim.fused_kit).
static func data_of(sim: CombatSim, move: String) -> Dictionary:
	if is_reaction(move):
		return _reaction_data(sim, move)
	if is_fusion(sim, move):
		var out := sim.move_data(move).duplicate()
		var swing := sim.fused_kit().move_data(FUSION_SWING)
		out["reach_m"] = float(swing["reach_m"])
		out["arc_deg"] = float(swing["arc_deg"])
		return out
	return sim.move_data(move)


## Whether `move` on `sim` is the Duelist's fusion: his ultimate, its
## effect the fusion (Moves.EFFECT_FUSION).
static func is_fusion(sim: CombatSim, move: String) -> bool:
	return move == Moves.ULTIMATE_MOVE and sim.has_move(move) and sim.ultimate_effect() == Moves.EFFECT_FUSION


## Whether `sim`'s kit has `move` (a reaction: its section).
static func has_move(sim: CombatSim, move: String) -> bool:
	return not _reaction_data(sim, move).is_empty() if is_reaction(move) else sim.has_move(move)


## A reaction's clip markers in the lab (s: start, hit, end), as a move's.
static func reaction_marks() -> Dictionary:
	return {"start": 0.0, "hit": REACTION_HIT_S, "end": REACTION_LENGTH_S}


## `recipe`'s move: {character, move, knob} (and a family's `moves`), or {}
## for a recipe on none (the lab's placeholder).
static func of_recipe(recipe: String) -> Dictionary:
	return table().get(recipe, {})


## Every move `recipe` plays on: a family's `moves`, else its one move ([]
## for a recipe on none).
static func moves_of(recipe: String) -> Array:
	var slot: Dictionary = table().get(recipe, {})
	if slot.is_empty():
		return []
	return slot.get("moves", [slot["move"]])


## The recipe whose knob is `section`'s `key` on the tuning pages, or "";
## the mage's page's header or the merged values' section alike
## ([mage.look] or [look], Kit.from_header).
static func recipe_of_knob(section: String, key: String) -> String:
	for table: Dictionary in [WORLD, ENEMY, BOON, WORN]:
		for recipe: String in table:
			if table[recipe]["knob"] == [section, key]:
				return recipe
	var rows := table()
	for recipe: String in rows:
		var knob: Array = rows[recipe]["knob"]
		if not knob.is_empty() and Kit.from_header(knob[0]) == Kit.from_header(section) and knob[1] == key:
			return recipe
	for look: String in BOSS_BOON:
		if BOSS_BOON[look]["knob"] == [section, key]:
			return BOSS_BOON[look]["recipe"]
	for look: String in GEAR:
		if GEAR[look]["knob"] == [section, key]:
			return GEAR[look]["recipe"]
	# The sand mage's character boons' looks (on [mage.look]; MageBoonLooks).
	for look: String in MageBoonLooks.LOOKS:
		if Kit.from_header(section) == "look" and MageBoonLooks.LOOKS[look][0] == key:
			return MageBoonLooks.LOOKS[look][1]
	if Kit.from_header(section) == "look" and key == MageBoonLooks.TWIN_KNOB[1]:
		return "tornado"
	# A pack's knob whose recipe has no row yet: its rule names it.
	if Kit.character_of(section) != "":
		var rule := Tuning.rule_of(section, key)
		if rule.size() == 2 and rule[0] == "preset":
			return str(rule[1])
	return ""


## The recipe enemy `type`'s `attack` ("projectile", "circle") is drawn
## with (ENEMY), or "" when it keeps its own look.
static func enemy_recipe(type: String, attack: String) -> String:
	for recipe: String in ENEMY:
		if ENEMY[recipe]["attack"] == attack and type in ENEMY[recipe]["casters"]:
			return recipe
	return ""


## The hit `recipe`'s attack makes for a caster with enemy row `row`
## ({reach_m: its reach_key's value, arc_deg: all round}), the hit its
## ground edge is drawn for (FxReach.drawn).
static func enemy_hit(recipe: String, row: Dictionary) -> Dictionary:
	return {"reach_m": float(row.get(ENEMY[recipe]["reach_key"], 0.0)), "arc_deg": 360.0}


## The hit `recipe`'s boon effect makes on `values` (the merged tuning:
## its boon's reach_key on [boon.<id>]; {reach_m, arc_deg: all round}),
## the hit its ground edge is drawn for (FxReach.drawn).
static func boon_hit(recipe: String, values: Dictionary) -> Dictionary:
	var slot: Dictionary = BOON[recipe]
	var row: Dictionary = values.get(Boons.section_of(slot["boon"]), {})
	return {"reach_m": float(row.get(slot["reach_key"], 0.0)), "arc_deg": 360.0}


## The gear look (GEAR) recipe `recipe` draws with a reach of its own on the
## gear page ({recipe, knob, reach, life?}), or {} for none.
static func gear_of(recipe: String) -> Dictionary:
	for look: String in GEAR:
		if GEAR[look]["recipe"] == recipe and GEAR[look].has("reach"):
			return GEAR[look]
	return {}


## The hit gear look `recipe` (gear_of) makes on `values` (the merged
## tuning): {reach_m: its reach's value, arc_deg: all round, life_s: its
## life's (with one)}, the hit it is drawn for (FxReach.drawn).
static func gear_hit(recipe: String, values: Dictionary) -> Dictionary:
	var slot := gear_of(recipe)
	if slot.is_empty():
		return {}
	var reach: Array = slot["reach"]
	var out := {"reach_m": float(values.get(reach[0], {}).get(reach[1], 0.0)), "arc_deg": 360.0}
	if slot.has("life"):
		var life: Array = slot["life"]
		out["life_s"] = float(values.get(life[0], {}).get(life[1], 0.0))
	return out


## The knob ([section, key]) naming the preset `character`'s `move` plays,
## or [] when it has none.
static func knob_of(character: String, move: String) -> Array:
	var rows := table()
	for recipe: String in rows:
		var slot: Dictionary = rows[recipe]
		if slot["character"] == character and move in moves_of(recipe):
			return slot["knob"]
	return []


## Seconds from `move`'s start to where the game shows its clip's hit marker
## (`sim` the character's, as DuelistClips and MageClips retime it): a
## strike's first active tick, a move with no startup at its end; a channel
## (the tornado) loops its clip from the start at the clip's own rate, so
## its marker shows `marks`' hit after the start (marks in seconds); a
## throw (no active phase: its blades hit) at its release, the end of its
## wind-up, as the blades leave his hands; a reaction (the parry) at its
## marks' hit (in the game it plays on the parried tick); the fusion at its
## bolt's strike, the clip's "swap" over the cast retimed to the move's
## length (DuelistClips.strike_frames, the frame its flash starts on too); a
## shot or a volley on its first active tick, as a swing; a lob on its landing,
## its flight after its wind-up; a tidal wave as its cast ends (a cast has no
## startup: its length).
static func hit_s(sim: CombatSim, move: String, marks: Dictionary) -> float:
	if is_reaction(move):
		return float(marks["hit"]) - float(marks["start"])
	if is_fusion(sim, move):
		return DuelistClips.strike_frames(sim) / CLIP_FPS
	var data := sim.move_data(move)
	if Moves.is_throw(data):
		return float(Moves.phase_frames(data, "startup_frames")) / CLIP_FPS
	if Moves.is_channel(data):
		return float(marks["hit"]) - float(marks["start"])
	if Moves.is_lob(data):
		return float(sim.frames_before_active(move) + int(data["flight_frames"])) / CLIP_FPS
	if data.has("startup_frames"):
		return float(sim.frames_before_active(move)) / CLIP_FPS
	return float(sim.move_length(move)) / CLIP_FPS
