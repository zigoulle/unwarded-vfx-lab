## Which move each recipe plays with ("animation should match the hit we
## do"): the one table the game and the VFX lab both read, so they cannot
## disagree. Per recipe: the character, his move, and the move's preset knob
## on his tuning page ([section, key]: the word value naming the preset the
## move plays, FxPresets.resolve; its rule ["preset", recipe]).
## A family (one recipe on several moves: the Mage's three light slashes)
## lists them all in `moves`, its first the move the lab opens it on.
## Its hit (hit_s): where the game shows the move clip's hit marker, the
## effect's impact before its trigger offset.
## Node-free, pure static. Looks only.
class_name FxMoves
extends RefCounted

const MOVES := {
	"tornado": {"character": "mage", "move": "tornado", "knob": ["look", "tornado_fx"]},
	"ground_shake": {"character": "mage", "move": "ground_shake", "knob": ["look", "ground_shake_fx"]},
	"sand_slash": {"character": "mage", "move": "light_1", "moves": ["light_1", "light_2", "light_3"],
		"knob": ["look", "sand_slash_fx"]},
	"whirlwind": {"character": "mage", "move": "whirlwind", "moves": ["whirlwind", "whirlwind_2"],
		"knob": ["look", "whirlwind_fx"]},
	"blink": {"character": "mage", "move": "blink", "knob": ["look", "blink_fx"]},
	"time_slow": {"character": "mage", "move": "ultimate", "knob": ["look", "ultimate_fx"]},
}
## The clips' frame rate (MageClips: 60 frames a second).
const CLIP_FPS := 60.0


## Every recipe's row (MOVES).
static func table() -> Dictionary:
	return MOVES


## `move`'s data on `sim` (its tuning section).
static func data_of(sim: MoveKit, move: String) -> Dictionary:
	return sim.move_data(move)


## Whether `sim`'s kit has `move`.
static func has_move(sim: MoveKit, move: String) -> bool:
	return sim.has_move(move)


## `recipe`'s move: {character, move, knob} (and a family's `moves`), or {}
## for a recipe on none (the lab's placeholder).
static func of_recipe(recipe: String) -> Dictionary:
	return MOVES.get(recipe, {})


## Every move `recipe` plays on: a family's `moves`, else its one move ([]
## for a recipe on none).
static func moves_of(recipe: String) -> Array:
	var slot: Dictionary = MOVES.get(recipe, {})
	if slot.is_empty():
		return []
	return slot.get("moves", [slot["move"]])


## The recipe whose knob is `section`'s `key` on the tuning pages, or "";
## the Mage's page's header or the merged values' section alike
## ([mage.look] or [look], Kit.from_header).
static func recipe_of_knob(section: String, key: String) -> String:
	for recipe: String in MOVES:
		var knob: Array = MOVES[recipe]["knob"]
		if not knob.is_empty() and Kit.from_header(knob[0]) == Kit.from_header(section) and knob[1] == key:
			return recipe
	return ""


## The knob ([section, key]) naming the preset `character`'s `move` plays,
## or [] when it has none.
static func knob_of(character: String, move: String) -> Array:
	for recipe: String in MOVES:
		var slot: Dictionary = MOVES[recipe]
		if slot["character"] == character and move in moves_of(recipe):
			return slot["knob"]
	return []


## Seconds from `move`'s start to where the game shows its clip's hit marker
## (`sim` the Mage's, as MageClips retimes it): a strike's first active
## tick, a move with no startup at its end; a channel (the tornado) loops its
## clip from the start at the clip's own rate, so its marker shows `marks`'
## hit after the start (marks in seconds).
static func hit_s(sim: MoveKit, move: String, marks: Dictionary) -> float:
	var data := sim.move_data(move)
	if Moves.is_channel(data):
		return float(marks["hit"]) - float(marks["start"])
	if data.has("startup_frames"):
		return float(sim.frames_before_active(move)) / CLIP_FPS
	return float(sim.move_length(move)) / CLIP_FPS
