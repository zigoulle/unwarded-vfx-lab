## The VFX lab (developer only, never exported: addons/dev_only_export; spec
## .scratch/vfx-lab/spec.md, ticket 01): a place to watch a spell effect at
## the game camera, on the caster's real move, on any zone's floor, with
## slow motion, frame steps and replays of the same cast.
##
## Open it with vfx-lab.cmd at the repo root (the developer build; it reads
## the live tuning pages for the caster's size and the camera).
##
## Keys:
##   Space   cast (a new seed)          R       replay the same cast
##   P       pause / resume             S       slow motion 0.1x
##   Right/. one frame on (pauses)      Left/,  one frame back (pauses)
##   L       loop the cast              M / N   next / previous move
##   Tab     the other caster           F, 1-6  next floor / pick a floor
##   Right mouse drag  orbit            Wheel   closer / further
##   G       back to the game camera    C       measure the effect's GPU cost
##                                              (loops the cast)
##   H       hide / show the help        V       his next effect (by move)
##   Tab     with an effect on its own move: the other caster's first effect
## Dummies (ticket 03): game enemies posed in their idle on a ring of their
## hurt area (lab_dummies.gd):
##   T       next enemy from the roster  E       add one
##   X       take the last one away      K       flinch on impacts on / off
##   Left mouse drag  move a dummy
## The picker (P-O, 2026-10-23), top right above the preset panel, mouse
## only: the character, then his spells (V's list, named by their moves).
## Tab is caught before the GUI so the panel's buttons can't take it.
## Presets (ticket 02; lab_presets.gd), the panel on the right, mouse only:
## the saved presets by name, a slider per shared core knob (size, form,
## hold, fade, intensity, trigger offset) and a picker per colour, re-read
## every frame so an edit shows at once, paused too; Save, Duplicate,
## Rename, and Commit presets (asks, then commits game/fx/presets only).
## Recipes (ticket 04): V switches the effect cast, the lightning line or
## ticket 01's placeholder burst; the panel follows it, with a slider per
## knob of the recipe's own. A cast's seed comes from its frame and caster
## (FxSeed); R replays it.
## Each effect plays with the move it belongs to in the game, and matches
## its hit (P-O, 2026-10-22; FxMoves, the table the game reads too): the
## line on the Duelist's dash, the ring on his jump-slam, the tornado on the
## mage's tornado. That move plays as the game draws it (its clip retimed
## on his kit's frame data, DuelistClips / MageClips, its hit where the game
## shows it, FxMoves.hit_s) and carries him as the simulation does (the
## dash runs him its distance: CombatSim.travelled_m); the line runs from
## his hip where he launched to his hip now, its impact kept where he was at
## the hit, as the game's dash draws it (DuelistModel.dash_fx_point). M, N
## and Tab pass while an effect plays its own move; the placeholder takes
## any move.
## The sand tornado (ticket 07): V reaches it too, round the mage's feet.
## The ground shake (all-spells ticket 02): on the mage's finisher, cracks,
## dust and a shockwave round his feet.
## The sand slash (all-spells ticket 01): one recipe on the mage's three
## light slashes (FxMoves' family); V reaches it after the Duelist's, and M
## and N pass through his three light slashes, each cast on its own hit and
## swept its own way.
## The whirlwind (all-spells ticket 03): one recipe on the mage's two spins
## (FxMoves' family), a sand swirl swept round him each spin's own way;
## M and N pass between the two spins.
## The blink (all-spells ticket 05): on the leap his light slashes flow
## into, a streak from where he stood to him as he goes, and a burst where
## he lands (its hit marker: his arrival, FxMoves.hit_s).
## The light strike (all-spells ticket 07): one lightning recipe on the
## Duelist's three light strikes (FxMoves' family), a bolt swept round him
## each strike's own way and a burst where its hit lands; V reaches it first
## of his, and M and N pass through his three light strikes.
## The heavy spin (all-spells ticket 08): on the Duelist's heavy spin
## (light, light, heavy: throw_spin), a lightning ring swept all round him
## the way his blades swing and a shockwave laid round his feet out to the
## spin's reach; listed under him after his jump-slam.
## The blade throw (all-spells ticket 10): on the Duelist's throw (light,
## light, heavy's ender), his blades fly out along his facing to the throw's
## range and home again as the simulation flies them (_thrown_points),
## lightning tethers from his hands to them, a streak behind each, a whirl
## round them as wide as their hit; the blades' path outlined on the floor;
## listed under him after his heavy spin.
## The parry (all-spells ticket 11): on the Duelist's parry (a reaction, no
## move of his kit and no clip: FxMoves.reaction_marks; he stands idle, Q22),
## a heavy blow parried a beat after Space at the contact in front of him at
## chest height (DuelistModel.parry_point), its forks fanned across his real
## front cone ([duelist.parry]: outlined on the floor, its slider the cone);
## listed under him after his throw.
## The log roll (all-spells ticket 12): on both the Duelist's log rolls
## (heavy, and heavy, heavy's second: M goes on to it), a lightning wheel
## round him turning front to back over the top, bolts racing out along the
## floor across the lobe in front of him and the one behind and a burst in
## each, to their real reach ([duelist.move.heavy] reach_front_m and
## reach_back_m: both outlined on the floor, a slider each); listed under
## him after his dash.
## The fusion (all-spells ticket 13): on the Duelist's ultimate (the
## fusion's cast), a bolt from the sky striking him on the clip's swap, the
## greatsword's arcs racing out along the floor across his fused front to
## the greatsword's reach (his fused light's: outlined on the floor, its
## slider the fusion's reach_mult), a burst round his feet, and its
## full-screen flash on the lab's screen as the game's HUD draws it on his
## own (screen_flash; none with Reduce flashing); listed under him last.
## The effects are grouped by character, then move (all-spells spec story
## 10; effects_of): V steps through the caster's own effects in his moves'
## order, then the placeholder; Tab, with an effect on its own move, goes
## to the other caster's first effect (with the placeholder, the other
## caster on the same placeholder).
## The impact (ticket 05): sparks, a burst, and a scorch and streaks laid on
## the floor through the ground seam (they wrap the curved patch); a local
## flash and a kick of the game's screen shake (this camera's) when a preset
## turns them on. The panel shows the line's main knobs; Advanced opens the
## rest.
## The cast's clock runs on the game's (GameClock): it holds while the game
## is paused.
## The lightning ring (ticket 06): V's third effect, on the Duelist's
## jump-slam: the ribbon bent into a ring round his feet, bolts out to it,
## cracks in the floor under him, sparks off the ring; the dummies inside it
## flinch at its impact.
## The reach (all-spells ticket 15; FxReach): each effect's ground
## footprint is ratios of its move's real reach on the lab's tuning (as the
## game's), the move's hit area drawn as a thin outline on the floor
## (lab_hit_outline.gd), and the readout says whether the drawn ground edge
## is fair: within FxReach.tolerance of the hit's (UNFAIR warned like the
## budget, under the counter too with the help hidden).
## The reach slider (ticket 16; lab_reach.gd): at the top of the preset
## panel, the move's real reach on the tuning page the lab reads (the live
## one), written there as the tuning screen's Apply writes it (its change
## log; Commit tuning commits it), on release while dragging; the effect and
## the outline follow at once, paused too. None for a spell with no hit area.
## A move with two lobes (the log roll's) has a second slider under it, its
## back lobe's reach (Reach.back_spot_of).
## Budgets, Low versions, bloom (ticket 08): the readout warns when the
## preset drawn goes over its budget (FxBudget: max graphics', or Low's
## while the panel edits the Low version); the panel's "Editing: Max/Low"
## draws the preset's Low version (FxLow) and its sliders adjust it; the
## preset's bloom (under Advanced, off by default) turns on the scene's glow
## (FxBloom). Glow, flash and bloom follow the effect intensity knob at the
## live tuning's level, as in the game.
## The super spawner's swirl (spawn-pressure ticket 05): a world effect, on
## no move of a caster's; V reaches it under either caster, after his own
## effects. It opens in the hole of the spawner's rock ring, SPAWNER_AT
## ahead of him, holds, then closes (its fade: the spawner's death).
## The Fire bomb's explosion (playtest 2026-10-25 #3; FxMoves.BOON): a
## world effect too, V reaching it under either caster. His move's hit kills
## a dummy BOMB_AT ahead of him (the first dummy; one is stood there when
## there is none), which explodes where it stood: hidden from the kill on,
## standing again before it (a replay, a step back) and off the bomb. Drawn
## for the boon's explosion_radius_m (the lab's tuning), outlined round the
## dummy, the reach slider that line on the boons page.
## The Throwing knives' knife (2026-10-28; FxMoves.BOON): a world effect
## too. At his move's hit the knife flies straight ahead from where he
## stood, the boon's knife_range_m at its knife_speed_m_per_s (the lab's
## tuning), stopping on the nearest dummy within its width of the line (one
## stood KNIFE_AT ahead when there is none), its ring and sparks there; the
## knife's width outlined round where it stops, the reach slider the boon's
## knife_radius_m on the boons page.
## The gear looks with a reach of their own (polish steps 9 and 10, P-O
## 2026-10-29; FxMoves.gear_of): world effects too, V reaching them under
## either caster. At his move's hit the look plays where he stands, drawn
## for its reach on the lab's tuning (the boots' fire puddle: one patch,
## [volcano_boots] trail_radius_m wide, living their trail_life_s; the full
## set's heat aura: its shimmer and embers round him out to [volcano_set]
## aura_radius_m, held hold_s then faded), that reach outlined round him, the reach slider that line on the gear page.
## The fire casters (enemy-vfx ticket 01): the fire elemental and the lava
## skeleton mage are casters too, in the picker after the characters
## (ENEMY_CASTERS; Tab passes between them). Each casts its attacks' effects
## (FxMoves.ENEMY: the fireball on both, the flame strike on the
## elemental's ground circle) on its real model, cast and timing from the
## lab's tuning: its wind-up, then the fireball flying at its
## projectile_speed_m_per_s to the target ENEMY_TARGET_AT ahead of it, or
## the circle landing there, its red ground warning shown (Telegraphs, as
## the game draws it) until it bursts circle_delay_frames later. The hit is
## outlined round the target, the reach slider is its row's radius
## (projectile_radius_m, circle_radius_m).
## The fire tiger (new-enemies ticket 04): a wearer, last in the picker
## (CREATURES), its flames (FxMoves.WORN: the tiger flames) on its real
## rigged model at its look's model_scale. Idle it stands burning on its
## mane and tail tip sockets; Space plays its combo from the lab's tuning
## (tiger_cast: swipe 1's tell, swipe 2's, the stumble, the recover), holds
## hold_s, then it dies: the flames shrink in the stumble (stumble_x) and die
## out over fade_s after its death. It hits nothing: no reach slider.
## Looks only: nothing here runs the simulation.
extends Node3D

const Clock := preload("res://vfx_lab/lab_clock.gd")
const Cost := preload("res://vfx_lab/lab_cost.gd")
const Floors := preload("res://vfx_lab/lab_floors.gd")
const Effect := preload("res://vfx_lab/placeholder_effect.gd")
const Dummies := preload("res://vfx_lab/lab_dummies.gd")
const Presets := preload("res://vfx_lab/lab_presets.gd")
const HitOutline := preload("res://vfx_lab/lab_hit_outline.gd")
const Reach := preload("res://vfx_lab/lab_reach.gd")
## The name the placeholder's first preset gets until it is saved.
const FRESH_PRESET := "placeholder - sparks"
## The recipes the lab has, the first opened (_script_of: their scripts). V
## steps through a caster's own in his moves' order (effects_of), whatever
## their order here.
const RECIPES := ["lightning_line", "placeholder", "lightning_ring", "sand_slash", "tornado", "ground_shake",
	"whirlwind",
	"blink",
	"light_strike",
	"heavy_spin",
	"blade_throw",
	"parry",
	"roll",
	"time_slow",
	"spawner_swirl",
	"fusion",
	"fireball",
	"flame_strike",
	"fire_bomb",
	"throwing_knife",
	"tiger_flames",
	"fire_puddle",
	"heat_aura",
	"flame_jet",
]
## World effects (on no move of a caster's; spawn-pressure ticket 05): V
## reaches them under either caster, after his own and before the
## placeholder. The super spawner's swirl is drawn in the hole of its rock
## ring, SPAWNER_AT ahead of the caster.
const WORLD_EFFECTS := ["spawner_swirl", "fire_bomb", "throwing_knife", "fire_puddle", "heat_aura", "flame_jet"]
const SPAWNER_AT := Vector3(0.0, 0.0, -5.0)
## Where the dummy his hit kills for the Fire bomb stands (ahead of him).
const BOMB_AT := Vector3(0.0, 0.0, -4.0)
## Where the dummy the Throwing knives' knife flies at stands (ahead of
## him, inside the knife's range).
const KNIFE_AT := Vector3(0.0, 0.0, -3.0)

const CHARACTERS := ["duelist", "mage"]
## The enemy casters (enemy-vfx ticket 01), after the characters in the
## picker: each casts its attacks' effects (FxMoves.ENEMY).
const ENEMY_CASTERS := ["elemental", "skeleton_mage"]
## The wearers (new-enemies ticket 04), last in the picker: each shows the
## looks it wears on its body (FxMoves.WORN) on its real model.
const CREATURES := ["fire_tiger"]
## Where an enemy caster's target stands (the player it casts at): ahead of
## it (-Z), the shot flying to it, the circle landing on it.
const ENEMY_TARGET_AT := Vector3(0.0, 0.0, -4.5)
## Each caster's moves offered, in order (keys of his model's markers, or a
## reaction: FxMoves.is_reaction).
const MOVES := {
	"duelist": ["light_1", "light_2", "light_3", "dash", "heavy", "heavy_2", "slam", "throw_spin", "throw", "parry",
		"ultimate", "split"],
	"mage": ["light_1", "light_2", "light_3", "blink", "ground_shake", "whirlwind", "whirlwind_2", "tornado", "ultimate"],
}
## The effect plays on this long past the move's clip (s).
const TAIL_S := 0.8
## Where the placeholder bursts: ahead of the caster at chest height (m;
## the models face -Z).
const EFFECT_AT := Vector3(0.0, 1.0, -1.4)
## The caster's outline: the first player's colour (CharacterModelView).
const OUTLINE := Color(0.2, 0.72, 0.82)
## Orbit: degrees per pixel dragged, the camera's height range and the zoom
## step and range (shares of the game camera's distance).
const ORBIT_DEG_PER_PX := 0.3
const ZOOM_STEP := 0.1
const ZOOM_MIN := 0.2
const ZOOM_MAX := 4.0
## Where E puts the first dummy (ahead of the caster, past the effect) and
## how far apart the next ones stand (m).
const DUMMY_AT := Vector3(0.0, 0.0, -3.0)
const DUMMY_SPREAD_M := 2.5
## The fps counter refreshes this often (s).
const READOUT_EVERY_S := 0.25
## The help box's text size (px): half the theme's 16, so the box takes a
## quarter of the room the help took (P-O, 2026-10-22).
const HELP_FONT_SIZE := 8
## The help box's key help.
const HELP := [
	"Space cast   R replay   P pause   S 0.1x   Left/Right frame step   L loop",
	"M/N move (an effect keeps its own move, or its family's)   Tab next caster (his first effect)",
	"F or 1-6 floor   right drag orbit   wheel zoom   G game camera",
	"C measure GPU cost (effect on vs off)   H hide this box",
	"T next enemy   E add a dummy   X take the last away   K flinch on/off   left drag move a dummy",
	"V his next effect, by move (then the placeholder, which takes any move)",
	"A bubble ring: B pops the next bubble   J jumps to just before the next one comes back",
	"Top right: pick the character, then his spell; the preset panel under it",
	"Presets: the panel on the right (sliders, Advanced, Save, Duplicate, Rename, Commit presets)",
]

var clock := Clock.new()
var character := "duelist"
var move := "dash"
## The recipe cast (RECIPES).
var recipe: String = RECIPES[0]
var floor_kind := "ring"
## The enemy E adds (T: the next one).
var dummy_kind := "golem"

var _tuning: Dictionary = {}
## The tuning folder the lab reads and its reach slider writes (the live one;
## use_folder), and its pages' text as last read.
var _folder := ""
var _pages: Dictionary = {}
## The reach slider's line now (Reach.spot_of; {} with none) and what it was
## worked out for.
var _reach: Dictionary = {}
var _reach_back: Dictionary = {}
var _reach_for: Array = []
var _world: Dictionary = {}
var _floor: Node3D
var _caster: CharacterModel
var _effect: Node3D
var _camera: Camera3D
var _environment: WorldEnvironment
var _lights: Node3D
var _hud: CanvasLayer
## The picker at the top right (P-O, 2026-10-23): the character, then his
## spells; the preset panel sits under it.
var _picker: PanelContainer
var _who: OptionButton
var _spell: OptionButton
## The fps counter (top left), the help box (bottom left; H) and the
## explanations in it (the cast, the cost, the budget, the dummies).
var _readout: Label
## The full-screen flash an effect gives its caster's own screen (the
## fusion's, FxFusion.screen_alpha: the game's HUD draws it there).
var _screen_flash: ColorRect
var _help: PanelContainer
var _info: Label
var _meter := Cost.new()
var _vp: RID
var _pose: Dictionary = {}
var _cast := false
var _yaw_deg := 0.0
var _rise_deg := 0.0
var _zoom := 1.0
var _orbiting := false
var _fps := 0.0
var _frames := 0
var _frames_s := 0.0
var _census := {}
var _dummies: Node3D
var _outline: Node3D
## The dummy the left mouse holds (-1 none), and the clock's time last shown
## (the impact flinches the dummies as the clock passes it).
var _held := -1
var _shown_t := INF
var _presets: Presets
## The super spawner's rock ring round its swirl (_show_spawner_ring).
var _spawner_ring: MeshInstance3D
## The caster's kit (his moves' frame data: a cast of an effect's own move
## plays as the game draws it), and where he stands before a cast.
var _sim: CombatSim
var _stand_at := Vector3.ZERO
## The floor's ground behind the ground seam (the effect lays its marks on
## it): the lava ball's on the curved patch, else the level volcano's.
var _ground: Ground
## The game's own screen shake on the lab's camera: kicked as an impact
## passes (forward only), its offset this frame.
var _shake := ScreenShake.new()
var _shake_offset := Vector3.ZERO
## The game clock's seconds last frame (the lab's time runs on it).
var _game_s := 0.0
## The enemy caster shown (null until one is picked; hidden with a
## character on) and its circle's ground warning.
var _enemy: EnemyModel
var _telegraphs: Telegraphs
var _telegraph_on := false
## The fire tiger shown (null until picked; hidden with another caster on),
## and its idle flames' clock (s; they burn on while no cast plays).
var _tiger: FireTigerModel
var _idle_s := 10.0


## Builds the lab (developer builds only): the live tuning, the light, the
## camera, the first effect and its panel, the dummies, the floor and the caster.
func _ready() -> void:
	_add_hud()
	if not OS.is_debug_build():
		_readout.text = "The VFX lab runs in developer builds only."
		return
	_folder = Tuning.default_path()
	_pages = Tuning.read_pages(_folder)
	var loaded := Tuning.load_folder(_folder)
	if loaded.error != "":
		_readout.text = "Tuning page error\n\n" + loaded.error
		return
	_tuning = loaded.values
	# The effect intensity knob at the game's level: glow and flash as played.
	EffectIntensity.set_from(_tuning)
	_world = VolcanoZone.scaled(_tuning)
	_game_s = GameClock.seconds()
	_add_light()
	_camera = Camera3D.new()
	_camera.name = "Camera"
	add_child(_camera)
	_camera.current = true
	use_recipe(recipe)
	_dummies = Dummies.new(_tuning)
	add_child(_dummies)
	_outline = HitOutline.new()
	add_child(_outline)
	_vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	_show_floor(floor_kind)
	_show_caster(character)
	_show()


# --- What the tests and the keys drive ---------------------------------------

## The floor shown.
func floor_node() -> Node3D:
	return _floor


## The caster's model.
func caster() -> CharacterModel:
	return _caster


## The lab's camera (the game camera unless orbited).
func camera() -> Camera3D:
	return _camera


## The effect cast (the recipe's node).
func effect() -> Node3D:
	return _effect


## The dummies (lab_dummies.gd).
func dummies() -> Node3D:
	return _dummies


## The world tuning the floors are built with.
func world() -> Dictionary:
	return _world


## The tuning the lab reads (Tuning.parse's merged values).
func tuning() -> Dictionary:
	return _tuning


## The floor's ground (the effect's marks are laid on it).
func ground() -> Ground:
	return _ground


## The camera's shake this frame (zero when still).
func shake_offset() -> Vector3:
	return _shake_offset


## The left mouse pressed at `screen`: holds the dummy there; false if none.
func press_at(screen: Vector2) -> bool:
	var at: Variant = _ground_at(screen)
	_held = -1 if at == null else _dummies.pick(at)
	return _held >= 0


## The left mouse moved to `screen`: the held dummy follows over the floor.
func drag_to(screen: Vector2) -> void:
	var at: Variant = _ground_at(screen)
	if _held >= 0 and at != null:
		_dummies.move_to(_held, at)


## The left mouse released: no dummy held.
func release() -> void:
	_held = -1


## The pose the caster was last shown in.
func pose() -> Dictionary:
	return _pose


## The move's hit area drawn on the floor (lab_hit_outline.gd).
func hit_outline() -> Node3D:
	return _outline


## The move's hit area its effect is drawn for (FxReach.hit_of of the
## move's data on the lab's tuning, as the game's cast carries it); {} off
## the effect's own move.
func hit() -> Dictionary:
	if _enemy_on():
		return FxMoves.enemy_hit(recipe, _enemy_row()) if FxMoves.ENEMY.has(recipe) else {}
	if FxMoves.BOON.has(recipe):
		return FxMoves.boon_hit(recipe, _tuning)
	if not FxMoves.gear_of(recipe).is_empty():
		return FxMoves.gear_hit(recipe, _tuning)
	return FxReach.hit_of(FxMoves.data_of(_sim, move)) if _plays_own_move() else {}


## Reads `values` (tuning, as Tuning.parse merges the pages) in place of the
## pages read at the start: the caster's kit, so the effect and the outline
## follow the move's reach (ticket 16's reach slider writes the page).
func use_tuning(values: Dictionary) -> void:
	_tuning = values
	if _caster != null and not _enemy_on():
		_sim = CombatSim.new(_tuning).for_character(character)
		_caster.read_kit(_sim, _tuning["look"])
	_reach_for = []
	_show()


## Reads and writes the tuning pages in `folder` from now on (the live
## folder at the start; the tests' a temp copy).
func use_folder(folder: String) -> void:
	_folder = folder
	_pages = Tuning.read_pages(folder)
	var loaded := Tuning.load_folder(folder)
	if loaded.error != "":
		_readout.text = "Tuning page error

" + loaded.error
		return
	use_tuning(loaded.values)


## The reach slider's line (Reach.spot_of): the move's reach on the page;
## {} for a spell with no hit area, or off its own move.
func reach() -> Dictionary:
	return _reach


## The second reach slider's line (Reach.back_spot_of): a two-lobe move's
## back lobe's reach on the page (the log roll's reach_back_m); {} for any
## other.
func reach_back() -> Dictionary:
	return _reach_back


## The reach slider moved to `value` (m): mid-drag (`done` false) the effect
## and outline are drawn at it without writing; else it is written on the
## page as the tuning screen's Apply writes it (Reach.write) and read back.
func set_reach(value: float, done: bool = true) -> String:
	return _set_spot(_reach, value, done)


## The second reach slider (the back lobe's) moved to `value` (m), as
## set_reach.
func set_reach_back(value: float, done: bool = true) -> String:
	return _set_spot(_reach_back, value, done)


## `spot` (a reach slider's line) moved to `value`, as set_reach.
func _set_spot(spot: Dictionary, value: float, done: bool) -> String:
	if spot.is_empty():
		return "no reach to set"
	if not done:
		var shown := Reach.edited(_pages, spot, value)
		var parsed := Tuning.parse(shown["pages"]) if shown["error"] == "" else null
		if parsed == null or parsed.error != "":
			return shown["error"] if shown["error"] != "" else parsed.error
		use_tuning(parsed.values)
		return ""
	var result := Reach.write(_folder, spot, value)
	if result["error"] != "":
		_presets.say("Reach not written: " + result["error"])
		return result["error"]
	for change: Dictionary in result["changes"]:
		print("[vfx lab] reach written: %s" % TuningChanges.log_line("", change).strip_edges())
	use_folder(_folder)
	return ""


## The reach slider on the move shown (Reach.spot_of), worked out again
## only when the recipe, the caster, the move or the tuning changed.
func _sync_reach() -> void:
	var key := [recipe, character, move, _presets.get_instance_id()]
	if key == _reach_for:
		return
	_reach_for = key
	if _enemy_on():
		var reach_key: String = FxMoves.ENEMY[recipe]["reach_key"] if FxMoves.ENEMY.has(recipe) else ""
		_reach = Reach.enemy_spot_of(_pages, character, reach_key)
		_reach_back = {}
		_presets.show_reach(_reach)
		_presets.show_reach(_reach_back, 1)
		return
	if not FxMoves.gear_of(recipe).is_empty():
		_reach = Reach.gear_spot_of(_pages, recipe)
		_reach_back = {}
		_presets.show_reach(_reach)
		_presets.show_reach(_reach_back, 1)
		return
	if FxMoves.BOON.has(recipe):
		_reach = Reach.boon_spot_of(_pages, recipe)
		_reach_back = {}
		_presets.show_reach(_reach)
		_presets.show_reach(_reach_back, 1)
		return
	var own := _plays_own_move() and FxReach.has_hit(recipe)
	_reach = Reach.spot_of(_pages, character, move, FxMoves.data_of(_sim, move)) if own else {}
	_reach_back = Reach.back_spot_of(_pages, character, move, FxMoves.data_of(_sim, move)) if own else {}
	_presets.show_reach(_reach)
	_presets.show_reach(_reach_back, 1)


## The readout's text: the fps counter's, then the help box's explanations
## (the cast, the cost, the budget, the dummies).
func readout() -> String:
	return _readout.text + "\n" + _info.text


## A key pressed (`keycode`), as _unhandled_input passes it.
func handle_key(keycode: int) -> void:
	match keycode:
		KEY_SPACE:
			_start_cast(_new_seed())
		KEY_R:
			if _cast:
				clock.replay()
			else:
				_start_cast(_new_seed())
		KEY_P:
			clock.toggle_pause()
		KEY_S:
			clock.toggle_slow()
		KEY_RIGHT, KEY_PERIOD:
			clock.step(1)
		KEY_LEFT, KEY_COMMA:
			clock.step(-1)
		KEY_L:
			clock.toggle_loop()
		KEY_M:
			_next_move(1)
		KEY_N:
			_next_move(-1)
		KEY_TAB:
			_next_caster()
		KEY_F:
			_show_floor(Floors.KINDS[(Floors.KINDS.find(floor_kind) + 1) % Floors.KINDS.size()])
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			_show_floor(Floors.KINDS[mini(keycode - KEY_1, Floors.KINDS.size() - 1)])
		KEY_G:
			_yaw_deg = 0.0
			_rise_deg = 0.0
			_zoom = 1.0
		KEY_C:
			# Measured over a looping cast, so the effect draws all through.
			if not clock.looping:
				clock.toggle_loop()
			if not _cast:
				_start_cast(_new_seed())
			_meter.start()
		KEY_H:
			_help.visible = not _help.visible
		KEY_T:
			var kinds: Array = Dummies.kinds()
			dummy_kind = kinds[(kinds.find(dummy_kind) + 1) % kinds.size()]
		KEY_E:
			_add_dummy()
		KEY_X:
			if _dummies.count() > 0:
				_dummies.remove(_dummies.count() - 1)
				_held = -1
		KEY_K:
			_dummies.flinch_on = not _dummies.flinch_on
		KEY_V:
			var own := effects_of(character)
			use_recipe(own[(own.find(recipe) + 1) % own.size()])
		KEY_B:
			# An effect with pieces that break and come back (a bubble ring).
			if _effect.has_method("pop_next"):
				if not _cast:
					_start_cast(_new_seed())
				_effect.pop_next(clock.seed, clock.time)
		KEY_J:
			if _effect.has_method("next_return_s") and _cast:
				clock.time = minf(maxf(clock.time, _effect.next_return_s(clock.time)), clock.length)
	_show(0.0)


## On by `delta` real seconds: the clock, then the frame drawn.
func advance(delta: float) -> void:
	if _caster == null:
		return
	var before := clock.time
	clock.advance(delta)
	_count_fps(delta)
	if _meter.measuring():
		_meter.sample(RenderingServer.viewport_get_measured_render_time_gpu(_vp))
	_show(clock.time - before if _cast else (0.0 if clock.paused else delta))


## The lab's own light is kept out of the tree while a floor lights itself:
## freed with the lab.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _environment != null and _environment.get_parent() == null:
		_environment.free()


## On by the game clock's seconds since the last frame (none while the
## game is paused), not the engine's.
func _process(_delta: float) -> void:
	var now := GameClock.seconds()
	var delta := maxf(now - _game_s, 0.0)
	_game_s = now
	advance(delta)


## The keys (handle_key), the left mouse on the dummies, the right mouse
## orbiting and the wheel zooming.
## Tab before the GUI, which takes it to move the focus between the panel's
## buttons (the lab's caster switch never got it); typing a preset's name
## keeps it.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_TAB:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	handle_key(KEY_TAB)
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		handle_key((event as InputEventKey).keycode)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				# A click in the scene gives the keys back from the preset's name field.
				get_viewport().gui_release_focus()
				press_at(button.position)
			else:
				release()
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		_place_camera()
	elif event is InputEventMouseMotion and _held >= 0:
		drag_to((event as InputEventMouseMotion).position)
	elif event is InputEventMouseMotion and _orbiting:
		var motion := event as InputEventMouseMotion
		_yaw_deg -= motion.relative.x * ORBIT_DEG_PER_PX
		_rise_deg = clampf(_rise_deg - motion.relative.y * ORBIT_DEG_PER_PX, -40.0, 60.0)
		_place_camera()


# --- Presets (lab_presets.gd) --------------------------------------------------

## The preset panel: the preset the effect is drawn with, its sliders, Save,
## Duplicate, Rename and Commit presets.
func presets() -> Presets:
	return _presets


## Casts `id`'s effect (RECIPES) from now on, the panel on its presets (its
## first saved one, else its default not saved yet).
func use_recipe(id: String) -> void:
	if _effect != null:
		remove_child(_effect)
		_effect.free()
	if _presets != null:
		_hud.remove_child(_presets)
		_presets.free()
	recipe = id
	var script := _script_of(id)
	_effect = script.new()
	add_child(_effect)
	if id == Effect.RECIPE:
		_presets = Presets.new(id, Effect.default_preset(), FRESH_PRESET)
	else:
		_presets = Presets.new(id, script.default_preset(), script.DEFAULT_NAME, script.KNOBS, script.ADVANCED_KNOBS)
	_presets.edited.connect(func() -> void: _show(0.0))
	_presets.reach_moved.connect(func(value: float, done: bool) -> void: set_reach(value, done))
	_presets.back_reach_moved.connect(func(value: float, done: bool) -> void: set_reach_back(value, done))
	_hud.add_child(_presets)
	_presets.offset_top = _picker.get_combined_minimum_size().y
	var own := FxMoves.of_recipe(id)
	if not own.is_empty():
		_cast_by(own["character"], own["move"])
	elif FxMoves.ENEMY.has(id):
		_cast_by_enemy(id)
	elif FxMoves.WORN.has(id):
		_show_tiger()
	elif (_enemy_on() or _tiger_on()) and _caster != null:
		# A world effect or the placeholder: on a character.
		_show_caster(CHARACTERS[0])
	if _cast:
		_effect.impact_s = hit_s()
	_fill_picker()


## The script drawing recipe `id`.
static func _script_of(id: String) -> GDScript:
	var script := FxReach.script_of(id)
	return script if script != null else Effect


## The recipes the lab has: RECIPES, then the character packs' (CharacterPacks).
static func recipes() -> Array:
	return RECIPES + CharacterPacks.fx_recipes().keys()


## The characters the lab casts: CHARACTERS, then the packs' with moves to offer,
## locked or not.
static func characters() -> Array:
	return CHARACTERS + CharacterPacks.lab_characters()


## The moves caster `who` offers, in order (MOVES, or his pack's).
static func moves_of(who: String) -> Array:
	if MOVES.has(who):
		return MOVES[who]
	var pack := CharacterPacks.of(who)
	return pack.lab_moves() if pack else []


## The effects the lab lists under caster `who`, in V's order: his recipes
## (FxMoves) by his moves' order (moves_of; a family by its first move), then
## the placeholder (it takes any move).
static func effects_of(who: String) -> Array:
	if who in CREATURES:
		return FxMoves.WORN.keys().filter(func(id: String) -> bool: return who in FxMoves.WORN[id]["wearers"])
	if who in ENEMY_CASTERS:
		return FxMoves.ENEMY.keys().filter(func(id: String) -> bool: return who in FxMoves.ENEMY[id]["casters"])
	var own := recipes().filter(func(id: String) -> bool:
		return FxMoves.of_recipe(id).get("character", "") == who)
	own.sort_custom(func(a: String, b: String) -> bool: return _move_rank(who, a) < _move_rank(who, b))
	own.append_array(WORLD_EFFECTS)
	own.append(Effect.RECIPE)
	return own


## Where recipe `id`'s (first) move comes in `who`'s moves (MOVES).
static func _move_rank(who: String, id: String) -> int:
	return moves_of(who).find(FxMoves.of_recipe(id)["move"])


## Tab: the next caster (CHARACTERS). With an effect of his own on, the
## next caster's first effect (effects_of); with the placeholder, the
## placeholder on him.
func _next_caster() -> void:
	if _tiger_on():
		return  # One wearer: it stays.
	if _enemy_on():
		var other: String = ENEMY_CASTERS[(ENEMY_CASTERS.find(character) + 1) % ENEMY_CASTERS.size()]
		_show_enemy_caster(other)
		use_recipe(recipe if recipe in effects_of(other) else effects_of(other)[0])
		return
	var all := characters()
	var next: String = all[(all.find(character) + 1) % all.size()]
	if recipe == Effect.RECIPE:
		_show_caster(next)
	else:
		use_recipe(effects_of(next)[0])


## Caster `character_id` shown, on `cast_move` when he has it (before the
## lab is built: the ones it opens on).
func _cast_by(character_id: String, cast_move: String) -> void:
	if _caster == null:
		character = character_id
		move = cast_move
		return
	if character_id != character:
		move = cast_move
		_show_caster(character_id)
	move = cast_move if _offers(cast_move) else _moves()[0]
	_cast = false


# --- The cast ------------------------------------------------------------------

## The move's clip markers (s) on the caster's model (a reaction's: the
## lab's, FxMoves.reaction_marks).
func _marks() -> Dictionary:
	return FxMoves.reaction_marks() if FxMoves.is_reaction(move) else _caster.markers[move]


## Seconds from the cast to the move's hit marker: on an effect's own move
## where the game shows it (FxMoves.hit_s), else the clip's own.
func hit_s() -> float:
	if _tiger_on():
		return 0.0
	if _enemy_on():
		return float(enemy_cast()["windup_s"])
	var marks := _marks()
	if _plays_own_move():
		return FxMoves.hit_s(_sim, move, marks)
	return float(marks["hit"]) - float(marks["start"])


## True while the effect cast is the one its move plays in the game
## (FxMoves; P-O, 2026-10-22: the effect matches the hit, so the move stays
## its own): the cast plays that move as the game draws it, and M, N and
## Tab pass (V reaches the placeholder, which takes any move).
func _plays_own_move() -> bool:
	var own := FxMoves.of_recipe(recipe)
	return not own.is_empty() and own["character"] == character and move in FxMoves.moves_of(recipe) \
		and _sim != null and FxMoves.has_move(_sim, move)


## The pose the game draws `t` s into the move (DuelistClips or MageClips
## reading his kit, as the avatar does: the clip retimed on the move's frame
## data), idle once the move is over. Today's dash streak stays off: the
## effect in the lab is the one drawn.
func _game_pose(t: float) -> Dictionary:
	if FxMoves.is_reaction(move):
		# A reaction whose recipe says what state it draws plays that on his model.
		if _effect.has_method("reaction_state"):
			var held: Dictionary = _caster.clip_pose(_sim, _effect.reaction_state(t))
			held["streak"] = false
			return held
		# Nothing on his body (the parry, Q22): he stands idle.
		return {"clip": "idle", "time": -1.0, "rate": 1.0, "spin": 0.0, "lean": 0.0, "yaw_deg": 0.0, "streak": false}
	var elapsed := t * FxMoves.CLIP_FPS
	var state := {"move": "", "move_frame": 0, "hitstop": 0, "tick_factor": 0.0, "speed_m_per_s": 0.0}
	if elapsed <= float(_sim.move_length(move)):
		var whole := floorf(elapsed)
		state = {"move": move, "move_frame": int(whole) + 2, "hitstop": 0, "tick_factor": elapsed - whole}
	# An effect that goes on past its cast (a tidal wave) says what the simulation's
	# state would hold then, and how far he has turned with it: the lab runs no sim.
	if _effect != null and _effect.has_method("pose_state"):
		state.merge(_effect.pose_state(t), true)
	var shown: Dictionary = (DuelistClips.pose(_sim, state, _caster.markers) if _caster is DuelistModel
		else _caster.clip_pose(_sim, state))
	if _effect != null and _effect.has_method("pose_yaw_deg"):
		shown["yaw_deg"] = float(shown.get("yaw_deg", 0.0)) + float(_effect.pose_yaw_deg(t))
	shown["streak"] = false
	return shown


## Where the move has carried him `t` s into it (CombatSim.travelled_m: the
## dash's run, a hop's), from where he stood, along the floor ahead of him
## (-Z; on the curved patch through the ground seam).
func _carried(t: float) -> Vector3:
	if FxMoves.is_reaction(move):
		return _stand_at
	var gone := _sim.travelled_m(move, minf(t * FxMoves.CLIP_FPS, float(_sim.move_length(move))))
	if gone <= 0.0:
		return _stand_at
	if floor_kind == "curved":
		return _ground.offset(_stand_at, _ground.heading_at(_stand_at), Vector2(0.0, -gone))
	return _stand_at + Vector3(0.0, 0.0, -gone)


## A new cast's seed: the lab has no ticks, so the wall clock's microseconds
## stand in for one, with its caster; a game cast's comes from its real tick
## and actor (FxSeed). R replays the seed kept.
func _new_seed() -> int:
	return FxSeed.of(Time.get_ticks_usec(), casters().find(character))


## A cast with `seed` from the move's start: the clock as long as the move
## (on an effect's own move, its frames; else its clip) plus TAIL_S, the
## effect's impact on the move's hit.
func _start_cast(seed: int) -> void:
	if _tiger_on():
		clock.length = float(tiger_cast()["end_s"]) + TAIL_S
		clock.cast(seed)
		_cast = true
		return
	if _enemy_on():
		var cast := enemy_cast()
		clock.length = float(cast["impact_s"]) + TAIL_S
		_effect.impact_s = float(cast["impact_s"])
		if "launch_s" in _effect:
			_effect.launch_s = float(cast["windup_s"])
		clock.cast(seed)
		_cast = true
		return
	var marks := _marks()
	var length := float(marks["end"]) - float(marks["start"])
	if _plays_own_move() and not FxMoves.is_reaction(move):
		length = float(_sim.move_length(move)) / FxMoves.CLIP_FPS
	clock.length = length + TAIL_S
	_effect.impact_s = hit_s()
	if "move" in _effect:
		_effect.move = move
	clock.cast(seed)
	_cast = true


## The caster's move `step` on (or back) among those the lab offers: while
## an effect plays its own move, among its family's (FxMoves.moves_of; one
## move: it stays).
func _next_move(step: int) -> void:
	if _enemy_on() or _tiger_on():
		return  # An enemy caster's attack is its effect's own; the tiger has its combo.
	var moves := FxMoves.moves_of(recipe) if _plays_own_move() else _moves()
	move = moves[posmod(moves.find(move) + step, moves.size())]
	_cast = false


## The caster's moves the lab offers (those his model has, and his reactions
## his kit has: the parry).
func _moves() -> Array:
	return moves_of(character).filter(func(m: String) -> bool: return _offers(m))


## Whether the caster shown offers `m`: his model's clip, or a reaction of
## his kit's.
func _offers(m: String) -> bool:
	if FxMoves.is_reaction(m):
		return _sim != null and FxMoves.has_move(_sim, m)
	return _caster.markers.has(m)


## Draws the frame: the caster's pose `delta` after the last, the effect at
## the clock's time, the camera, the readout.
func _show(delta: float = 0.0) -> void:
	if _caster == null:
		return
	if _tiger_on():
		_show_tiger_cast(delta)
		return
	if _enemy_on():
		_show_enemy_cast(delta)
		return
	_caster.position = _stand_at
	if _cast and _plays_own_move():
		_pose = _game_pose(clock.time)
		_caster.position = _carried(clock.time)
	elif _cast:
		var marks := _marks()
		var start := float(marks["start"])
		# A reaction has no clip (the parry: he stands idle).
		_pose = {"clip": "idle" if FxMoves.is_reaction(move) else move,
			"time": -1.0 if FxMoves.is_reaction(move) else minf(start + clock.time, float(marks["end"])), "rate": 1.0,
			"spin": 0.0, "lean": float(marks.get("lean", 0.0)), "yaw_deg": 0.0}
	else:
		_pose = {"clip": "idle", "time": -1.0, "rate": 1.0, "spin": 0.0, "lean": 0.0, "yaw_deg": 0.0}
	_caster.show_pose(_pose, maxf(delta, 0.0))
	var thrown := _thrown_points()
	if _caster is DuelistModel:
		(_caster as DuelistModel).show_thrown(thrown, maxf(delta, 0.0))
	_dummies.advance(maxf(delta, 0.0))
	_effect.visible = _meter.effect_on()
	# Re-read every frame: an edit in the preset panel shows at once, paused too.
	var drawn := _presets.drawn_preset()
	_effect.preset = drawn
	# Its ground footprint is ratios of the move's reach (FxReach), the
	# move's real hit area outlined on the floor round him (the dash's
	# from where he launched).
	if "hit" in _effect:
		_effect.hit = hit()
	_sync_reach()
	if _outline != null and not _effect is FxFireBomb and not _effect is FxThrowingKnife \
			and not _effect.has_method("hit_outline"):
		var own := FxMoves.data_of(_sim, move) if _plays_own_move() and FxReach.has_hit(recipe) else {}
		if not FxMoves.gear_of(recipe).is_empty():
			own = {"radius_m": float(hit().get("reach_m", 0.0))}
		if own.has(FxReach.WAVE_LENGTH_KEY) and _effect.has_method("turned_rad"):
			own = own.duplicate()
			own[HitOutline.TURNED_KEY] = _effect.turned_rad(clock.time if _cast else 0.0)
		_outline.show_for(own, _stand_at if own.has("half_width_m") else _caster.position)
	FxBloom.apply(get_world_3d().environment, drawn.bloom, drawn.drawn_intensity())
	_effect.position = _caster.position + EFFECT_AT
	# A recipe that reads its kit's rows (a pack's: its rows are its own) or its caster's
	# sockets and clip markers.
	if _effect.has_method("set_kit"):
		_effect.set_kit(_sim)
	if _effect.has_method("set_caster"):
		_effect.set_caster(_caster)
	if _effect.has_method("set_ends"):
		_dash_line()
	if _effect.has_method("set_centre"):
		_effect.set_centre(_caster.position)
	if _effect.has_method("set_ground"):
		_effect.set_ground(_ground, _caster.position.y)
	# A hit that lands away from him (a lob): outlined where the recipe says it lands.
	if _outline != null and _effect.has_method("hit_outline"):
		var away: Dictionary = _effect.hit_outline()
		_outline.show_for(away["data"], away["at"])
	if _effect.has_method("set_base"):
		_effect.set_base(_caster.position)
	if _effect.has_method("set_blades") and _caster is DuelistModel:
		_effect.set_blades((_caster as DuelistModel).hands_at(), thrown)
	if _effect.has_method("set_path"):
		_effect.set_path(_stand_at, _caster.position, Basis.IDENTITY)
	_show_spawner_ring()
	_show_bomb_victim()
	_show_knife_flight()
	if _effect.has_method("set_contact"):
		# Where the game's parry meets the blow (the lab's caster faces -Z).
		_effect.set_contact(DuelistModel.parry_point(_caster.position, Basis.IDENTITY, _caster.height_m))
	_play_cast(delta)


## The effect at the clock's time (its cast placed), the dummies' flinch
## and the camera's shake as its impact passes, the camera, the readout.
func _play_cast(delta: float) -> void:
	if _cast:
		# Long enough for the effect to play out past the move.
		var end: float = (_effect.end_time() if _effect.has_method("end_time") else _effect.impact_time()
			+ _presets.preset.hold_s + _presets.preset.fade_s)
		clock.length = maxf(clock.length, end + 0.1)
		_effect.show_at(clock.seed, clock.time)
		# The clock passed the impact (on, not stepping back): the dummies
		# near it flinch and the camera shakes (forward only).
		var impact: float = _effect.impact_time()
		if _shown_t < impact and clock.time >= impact:
			_dummies.impact(_effect.impact_point(),
				_effect.impact_reach() if _effect.has_method("impact_reach") else 0.0)
			if _effect.has_method("shake_kick"):
				_shake.kick(_effect.shake_kick())
		_shown_t = clock.time
	else:
		# The tiger's flames burn on while it stands (on their idle clock).
		_effect.show_at(0, _idle_s if _tiger_on() else -1.0)
		_shown_t = INF
	_show_screen_flash()
	_shake_offset = _shake.offset(maxf(delta, 0.0))
	_place_camera()
	_write_readout()


## The full-screen flash the effect gives its caster's own screen now (the
## fusion's; 0 with none, or with Reduce flashing), as the game's HUD draws it.
func screen_flash() -> float:
	return _screen_flash.color.a if _screen_flash.visible else 0.0


func _show_screen_flash() -> void:
	var alpha: float = _effect.screen_alpha() if _cast and _effect.has_method("screen_alpha") else 0.0
	_screen_flash.visible = alpha > 0.0
	_screen_flash.color = Color(_presets.drawn_preset().core_colour, alpha)


# --- Scene ---------------------------------------------------------------------

## The super spawner's rock ring (the game's, SuperSpawnerLooks) round the
## swirl, SPAWNER_AT ahead of where the caster stands, at the size the
## swirl is drawn against (FxReach.REFERENCE: the shipped model_size_m);
## shown only with the swirl.
func _show_spawner_ring() -> void:
	var on := _effect is FxSpawnerSwirl
	if not on:
		if _spawner_ring != null:
			_spawner_ring.visible = false
		return
	if _spawner_ring == null:
		_spawner_ring = MeshInstance3D.new()
		_spawner_ring.name = "SpawnerRing"
		_spawner_ring.mesh = SuperSpawnerLooks.ring_mesh()
		_spawner_ring.material_override = SuperSpawnerLooks.rock_material(SuperSpawnerLooks.DEFAULT_ROCK, 2.0)
		add_child(_spawner_ring)
	var at := _stand_at + SPAWNER_AT
	var across := float(FxReach.REFERENCE[FxSpawnerSwirl.RECIPE]["reach_m"]) * 2.0
	_spawner_ring.transform = Transform3D(Basis.from_scale(Vector3.ONE * across), at)
	(_spawner_ring.material_override as ShaderMaterial).set_shader_parameter("glow_color",
		_presets.drawn_preset().core_colour)
	_spawner_ring.visible = true
	_effect.set_centre(at)


## The Fire bomb's dummy: the first (stood BOMB_AT ahead of him when there
## is none), dead from his hit on while the bomb is cast, the explosion and
## the boon's radius outlined where it stands. Off the bomb every dummy
## stands.
func _show_bomb_victim() -> void:
	if not _effect is FxFireBomb:
		for i in _dummies.count():
			_dummies.set_dead(i, false)
		return
	if _dummies.count() == 0:
		_dummies.add(dummy_kind, _stand_at + BOMB_AT)
	var at: Vector3 = _dummies.position_of(0)
	var bomb := _effect as FxFireBomb
	bomb.set_centre(at)
	bomb.set_ground(_ground, at.y)
	_dummies.set_dead(0, _cast and clock.time >= bomb.impact_time())
	if _outline != null:
		_outline.show_for({"radius_m": float(hit().get("reach_m", 0.0))}, at)


## The Throwing knives' knife: thrown from where he stands at his hit,
## straight ahead (-Z) for the boon's knife_range_m at its
## knife_speed_m_per_s (the lab's tuning), stopping on the nearest dummy
## within its width of that line and its range (one is stood KNIFE_AT
## ahead when there is none), as the game's does; the knife's width
## outlined round where it stops.
func _show_knife_flight() -> void:
	if not _effect is FxThrowingKnife:
		return
	var knife := _effect as FxThrowingKnife
	var row: Dictionary = _tuning.get(Boons.section_of(FxMoves.BOON[FxThrowingKnife.RECIPE]["boon"]), {})
	var range_m := float(row.get("knife_range_m", FxThrowingKnife.RANGE_M))
	var radius := float(hit().get("reach_m", 0.0))
	var from := _stand_at
	knife.set_flight(from, from + Vector3(0.0, 0.0, -range_m),
		float(row.get("knife_speed_m_per_s", FxThrowingKnife.SPEED_M_S)))
	knife.set_ground(_ground, from.y)
	if _dummies.count() == 0:
		_dummies.add(dummy_kind, _stand_at + KNIFE_AT)
	var best := -1
	var best_ahead := INF
	for i in _dummies.count():
		var at: Vector3 = _dummies.position_of(i)
		var ahead := from.z - at.z
		if ahead >= 0.0 and ahead <= range_m + radius and absf(at.x - from.x) <= radius and ahead < best_ahead:
			best = i
			best_ahead = ahead
	if best >= 0:
		var on: Vector3 = _dummies.position_of(best)
		knife.set_stop(Vector3(on.x, from.y, on.z), true)
	if _outline != null:
		_outline.show_for({"radius_m": radius}, knife.impact_point())


## The spawner's rock ring shown with its swirl (null until first shown).
func spawner_ring() -> MeshInstance3D:
	return _spawner_ring


## The lightning line on his dash, as the game draws it (DuelistModel's
## dash fx): from his hip where he launched to his hip now, its impact kept
## where he was at the hit (DuelistModel.dash_fx_point: up through the
## ground seam).
func _dash_line() -> void:
	var height := _caster.height_m
	_effect.set_ends(DuelistModel.dash_fx_point(_ground, _stand_at, height),
		DuelistModel.dash_fx_point(_ground, _caster.position, height))
	_effect.set_impact_point(DuelistModel.dash_fx_point(_ground, _carried(_effect.impact_time()), height))


## Where the thrown blades fly now, on the blade throw's own move (as the
## simulation flies them, CombatSim._fly_blades: from the release out along
## his facing, -Z, to the throw's range over half its lock, home over the
## other half; drawn a little apart and at the height the avatar draws them,
## PlayerAvatar._thrown_points); none before the release, once home, or off
## the throw.
func _thrown_points() -> Array:
	if not _cast or not _plays_own_move() or not _effect.has_method("set_blades"):
		return []
	var own := hit()
	var flight := float(own.get("flight_s", 0.0))
	var age := clock.time - hit_s()
	if age <= 0.0 or age >= flight:
		return []
	var half := flight / 2.0
	var out_m := float(own["range_m"]) * (age / half if age <= half else 2.0 - age / half)
	var centre := _stand_at + Vector3(0.0, PlayerAvatar.THROWN_UP_M, -out_m)
	var across := Vector3(PlayerAvatar.thrown_spread(out_m), 0.0, 0.0)
	return [centre - across, centre + across]


## A dummy of the picked enemy: the next free spot along a row ahead of the
## caster, on his floor.
func _add_dummy() -> void:
	var n: int = _dummies.count()
	var side := floorf((n + 1) / 2.0) * DUMMY_SPREAD_M * (1.0 if n % 2 == 1 else -1.0)
	_dummies.add(dummy_kind, _caster.position + DUMMY_AT + Vector3(side, 0.0, 0.0))


## The floor point under `screen` (the plane the caster stands on); null off it.
func _ground_at(screen: Vector2) -> Variant:
	if _camera == null or _caster == null:
		return null
	var plane := Plane(Vector3.UP, _caster.position.y)
	return plane.intersects_ray(_camera.project_ray_origin(screen), _camera.project_ray_normal(screen))


## Floor `kind` (Floors.KINDS) in place of the last, its ground behind the
## ground seam, the lab's light unless it lights itself; he stands on it.
func _show_floor(kind: String) -> void:
	if _floor != null:
		remove_child(_floor)
		_floor.free()
	floor_kind = kind
	_floor = Floors.build(kind, _world)
	add_child(_floor)
	_ground = _ground_of(kind)
	# A floor that lights itself (the ring arena) replaces the lab's light.
	var lit := Floors.brings_light(_floor)
	_lights.visible = not lit
	if lit:
		remove_child(_environment)
	elif _environment.get_parent() == null:
		add_child(_environment)
	_stand()


## Caster `id` (his real model, size and kit) in place of the last, on a
## move of his; no cast.
func _show_caster(id: String) -> void:
	if _caster != null:
		remove_child(_caster)
		_caster.free()
	character = id
	if _enemy != null:
		_enemy.visible = false
	if _tiger != null:
		_tiger.visible = false
	_show_telegraph(-1.0)
	_caster = Roster.load_from().build_model(id)
	_caster.name = "Caster"
	var look: Dictionary = _tuning["look"]
	_caster.set_look(float(look.get("mage_height_m", MageLook.BASE_HEIGHT_M)), OUTLINE,
		float(look.get("mage_outline", 0.5)), float(look.get("mage_lift", 0.0)))
	add_child(_caster)
	_sim = CombatSim.new(_tuning).for_character(id)
	_caster.read_kit(_sim, look)
	if not _offers(move):
		move = _moves()[0]
	_cast = false
	_stand()


## The ground under floor `kind`: the lava ball's (its core below the
## origin, as the curved patch is built) or the level volcano's.
func _ground_of(kind: String) -> Ground:
	if kind == "curved":
		return BallGround.new(_world, Vector3(0.0, -Floors.curved_radius(_world), 0.0))
	return VolcanoGround.new(_world)


## The caster stands at the floor's stand spot (Floors.stand_spot: halfway
## across the ring), on its level round it (Floors.level_round: on the
## slabs, not down in a seam between them), where the effects lay their
## marks (set_ground).
func _stand() -> void:
	if _caster == null or _floor == null:
		return
	var spot := Floors.stand_spot(floor_kind, _world)
	var top := Floors.level_round(_floor, spot)
	_stand_at = Vector3(spot.x, top if is_finite(top) else 0.0, spot.y)
	_caster.position = _stand_at


## The game camera (SurfaceCamera.place with the tuning's distance and
## height), turned by the orbit and zoomed.
func _place_camera() -> void:
	if _camera == null or _caster == null:
		return
	var cam: Dictionary = _tuning["camera"]
	var distance := float(cam["distance_m"]) * _zoom
	var height := float(cam["height_m"]) * _zoom
	if _rise_deg != 0.0:
		# The orbit's rise: the same reach, tilted up or down round him.
		var reach := Vector2(distance, height).length()
		var angle := atan2(height, distance) + deg_to_rad(_rise_deg)
		angle = clampf(angle, deg_to_rad(2.0), deg_to_rad(88.0))
		distance = reach * cos(angle)
		height = reach * sin(angle)
	_camera.global_transform = SurfaceCamera.place(_caster.position, Vector3.UP, Vector3.FORWARD, _yaw_deg,
		distance, height, _shake_offset)


## The lab's own light: a dark background, ambient, a key and a fill.
func _add_light() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.03, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = RingArenaView.AMBIENT
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment = WorldEnvironment.new()
	_environment.name = "LabEnvironment"
	_environment.environment = env
	add_child(_environment)
	_lights = Node3D.new()
	_lights.name = "LabLights"
	add_child(_lights)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, 35, 0)
	key.light_color = Color(1.0, 0.8, 0.65)
	key.light_energy = 1.2
	_lights.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-60, 30 + 180, 0)
	fill.light_color = RingArenaView.FILL
	fill.light_energy = 0.35
	_lights.add_child(fill)


## The HUD: the fps counter top left, where it always was, and the help and
## the explanations (the cast, the cost, the budget, the dummies) in a small
## box at the bottom left (P-O, 2026-10-22: the text in the middle blocked
## the screen); H hides and shows the box.
func _add_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "Hud"
	add_child(_hud)
	_screen_flash = ColorRect.new()
	_screen_flash.name = "ScreenFlash"
	_screen_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_flash.visible = false
	_hud.add_child(_screen_flash)
	_readout = Label.new()
	_readout.name = "Readout"
	_readout.position = Vector2(12, 10)
	_readout.add_theme_color_override("font_outline_color", Color.BLACK)
	_readout.add_theme_constant_override("outline_size", 4)
	_hud.add_child(_readout)
	_help = PanelContainer.new()
	_help.name = "Help"
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	back.set_content_margin_all(4)
	_help.add_theme_stylebox_override("panel", back)
	_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud.add_child(_help)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	_help.add_child(lines)
	_info = _small_label("Info", Color.WHITE)
	lines.add_child(_info)
	var keys := _small_label("Keys", Color(0.8, 0.85, 0.9))
	keys.text = "\n".join(HELP)
	lines.add_child(keys)
	_add_picker()


## The picker at the top right, as wide as the preset panel under it: the
## character list, then his spells (effects_of, named by their moves). Mouse
## only, so the keys stay the lab's.
func _add_picker() -> void:
	_picker = PanelContainer.new()
	_picker.name = "Picker"
	_picker.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_picker.offset_left = -300
	_hud.add_child(_picker)
	var row := HBoxContainer.new()
	_picker.add_child(row)
	_who = OptionButton.new()
	_who.name = "Character"
	_who.focus_mode = Control.FOCUS_NONE
	for id: String in casters():
		_who.add_item(id.capitalize())
	_who.item_selected.connect(func(i: int) -> void:
		var who: String = casters()[i]
		if who != character:
			if who in ENEMY_CASTERS:
				_show_enemy_caster(who)
			use_recipe(effects_of(who)[0])
			_show(0.0))
	row.add_child(_who)
	_spell = OptionButton.new()
	_spell.name = "Spell"
	_spell.focus_mode = Control.FOCUS_NONE
	_spell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spell.clip_text = true
	_spell.item_selected.connect(func(i: int) -> void:
		var own := effects_of(character)
		if own[i] != recipe:
			use_recipe(own[i])
			_show(0.0))
	row.add_child(_spell)


## The picker on the caster and the effect on now.
func _fill_picker() -> void:
	_who.select(casters().find(character))
	_spell.clear()
	for id: String in effects_of(character):
		var moves := FxMoves.moves_of(id)
		var on := ", ".join(moves).replace("_", " ") if not moves.is_empty() else (
			"the super spawner" if id in WORLD_EFFECTS else "any move")
		if FxMoves.WORN.has(id):
			on = "its mane and tail tip"
		if FxMoves.ENEMY.has(id):
			on = "its ground circle" if FxMoves.ENEMY[id]["attack"] == "circle" else "its projectile"
		_spell.add_item("%s  (%s)" % [id.replace("_", " "), on])
	_spell.select(effects_of(character).find(recipe))


## One of the help box's labels, `label_name`d, at HELP_FONT_SIZE in `colour`.
func _small_label(label_name: String, colour: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.add_theme_font_size_override("font_size", HELP_FONT_SIZE)
	label.add_theme_color_override("font_color", colour)
	return label


# --- The enemy casters (enemy-vfx ticket 01) -----------------------------------

## Every caster the picker offers: the characters, the enemy casters, then
## the wearers.
static func casters() -> Array:
	return characters() + ENEMY_CASTERS + CREATURES


## Whether an enemy caster is on (ENEMY_CASTERS).
func _enemy_on() -> bool:
	return character in ENEMY_CASTERS


## The enemy caster's model (null until one was picked).
func enemy_caster() -> EnemyModel:
	return _enemy


## The enemy caster's row on the lab's tuning (the enemies page).
func _enemy_row() -> Dictionary:
	return Enemies.row_of(_tuning, character)


## Whether the circle's ground warning shows now.
func telegraph_shown() -> bool:
	return _telegraph_on


## The enemy caster's cast as the simulation makes it, from its row:
## {windup_s (its attack_windup_frames: the cast's hit marker), target (the
## ground point it casts at, ENEMY_TARGET_AT ahead), impact_s (the circle's
## burst: the wind-up and circle_delay_frames; the shot's hit: the wind-up
## and its flight)}; a shot's also {from, to (its drawn points, at
## EnemyLooks.SHOT_HEIGHT_M: from the caster, to the target), velocity
## (m/s, projectile_speed_m_per_s), flight_s (until it is within
## projectile_radius_m of the target)}.
func enemy_cast() -> Dictionary:
	var row := _enemy_row()
	var windup := float(row.get("attack_windup_frames", 0)) / CombatSim.TICK_HZ
	var target := _stand_at + ENEMY_TARGET_AT
	var out := {"windup_s": windup, "target": target}
	if move == "circle":
		out["impact_s"] = windup + float(row.get("circle_delay_frames", 0)) / CombatSim.TICK_HZ
		return out
	var up := Vector3.UP * EnemyLooks.SHOT_HEIGHT_M
	var from := _stand_at + up
	var to := target + up
	var speed := maxf(float(row.get("projectile_speed_m_per_s", 1.0)), 0.001)
	var flight := maxf(from.distance_to(to) - float(row.get("projectile_radius_m", 0.0)), 0.0) / speed
	out.merge({"from": from, "to": to, "velocity": (to - from).normalized() * speed, "flight_s": flight,
		"impact_s": windup + flight})
	return out


## Enemy caster `who` shown (its real model) in place of the character;
## before the lab is built, the one it opens on.
func _show_enemy_caster(who: String) -> void:
	character = who
	_cast = false
	if _caster == null:
		return
	if _enemy == null or _enemy.type != who:
		if _enemy != null:
			remove_child(_enemy)
			_enemy.free()
		_enemy = EnemyModel.new(who)
		_enemy.name = "EnemyCaster"
		add_child(_enemy)
		RingArenaView.light_as_character(_enemy)
	_enemy.visible = true
	_caster.visible = false
	if _tiger != null:
		_tiger.visible = false


## Recipe `id`'s enemy caster (this one if it casts it, else its first),
## on the attack it draws; no cast.
func _cast_by_enemy(id: String) -> void:
	var own: Array = FxMoves.ENEMY[id]["casters"]
	if not character in own or _enemy == null or not _enemy.visible:
		_show_enemy_caster(character if character in own else own[0])
	move = FxMoves.ENEMY[id]["attack"]
	_cast = false


## The enemy caster's synced state `t` s into its cast (as EnemyClips reads
## the game's): winding up, then recovering; standing before any cast.
func _enemy_state(t: float) -> Dictionary:
	var row := _enemy_row()
	var state := {"phase": CombatSim.ENEMY_CHASE, "timer": 0, "attack": "", "hitstop": 0, "stun": 0,
		"tick_factor": 0.0, "speed_m_per_s": 0.0, "stride_m_per_s": _enemy.stride_m_per_s, "reacting_s": -1.0,
		"dead_s": -1.0}
	if t < 0.0:
		return state
	var frames := t * CombatSim.TICK_HZ
	var windup := int(row.get("attack_windup_frames", 0))
	state["attack"] = move
	state["tick_factor"] = frames - floorf(frames)
	if frames < windup:
		state["phase"] = CombatSim.ENEMY_WINDUP
		state["timer"] = windup - int(floorf(frames))
	else:
		state["phase"] = CombatSim.ENEMY_RECOVER
		state["timer"] = maxi(int(row.get("attack_cooldown_frames", 0)) - int(floorf(frames - windup)), 0)
	return state


## The frame with an enemy caster on: its pose, its effect at the clock's
## time where its cast puts it, the hit outlined round the target, the
## circle's warning; then the cast played as a character's is (_play_cast).
func _show_enemy_cast(delta: float) -> void:
	_caster.position = _stand_at
	var row := _enemy_row()
	var t := clock.time if _cast else -1.0
	_pose = EnemyClips.pose(character, _enemy_state(t), row)
	_enemy.transform = SurfaceDraw.upright(_stand_at + Vector3.UP * float(row.get("float_height_m", 0.0)),
		Vector2(0.0, -1.0))
	_enemy.set_size(float(row.get("model_size_m", 2.0)))
	_enemy.show_pose(_pose, maxf(delta, 0.0))
	_dummies.advance(maxf(delta, 0.0))
	_effect.visible = _meter.effect_on()
	var drawn := _presets.drawn_preset()
	_effect.preset = drawn
	_effect.hit = hit()
	_sync_reach()
	var cast := enemy_cast()
	var target: Vector3 = cast["target"]
	_outline.show_for({"radius_m": float(hit().get("reach_m", 0.0))}, target)
	FxBloom.apply(get_world_3d().environment, drawn.bloom, drawn.drawn_intensity())
	if _effect.has_method("set_flight"):
		var flown := clampf(t - float(cast["windup_s"]), 0.0, float(cast["flight_s"]))
		_effect.set_flight(Vector3(cast["from"]) + Vector3(cast["velocity"]) * flown, cast["velocity"])
	if _effect.has_method("set_centre"):
		_effect.set_centre(target)
	if _effect.has_method("set_ground"):
		_effect.set_ground(_ground, target.y)
	_show_spawner_ring()
	var burst := float(cast["impact_s"])
	var warning := _cast and move == "circle" and t >= float(cast["windup_s"]) and t < burst
	_show_telegraph(burst - t if warning else -1.0)
	_play_cast(delta)


## The circle's red ground warning (Telegraphs, as the game draws it) round
## the target, `left_s` before its burst; hidden below 0.
func _show_telegraph(left_s: float) -> void:
	_telegraph_on = left_s >= 0.0
	if _telegraphs == null:
		if not _telegraph_on:
			return
		_telegraphs = Telegraphs.new(self)
	if not _telegraph_on:
		_telegraphs.show([], _tuning.get("look", {}), _ground)
		return
	var target: Vector3 = enemy_cast()["target"]
	var view := {"enemies": [], "circles": [{"type": character, "position": VolcanoGround.xz(target),
		"point": target, "timer": ceili(left_s * CombatSim.TICK_HZ)}], "tick_factor": 0.0}
	_telegraphs.show(Telegraphs.list(view, {character: _enemy_row()}), _tuning.get("look", {}), _ground)


# --- The fire tiger (new-enemies ticket 04) --------------------------------------

## Whether the tiger is on (CREATURES).
func _tiger_on() -> bool:
	return character in CREATURES


## The tiger's model (null until picked).
func tiger() -> FireTigerModel:
	return _tiger


## The tiger's cast from its row on the lab's tuning (s from Space): swipe
## 2's tell starts (swipe_2_s), swipe 2 lands and it stumbles (stumble_s),
## it recovers (recover_s), it stands (stand_s), it dies hold_s later
## (death_s: the preset's hold, the lab's only), its flames have died out
## (end_s: its fade_s on).
func tiger_cast() -> Dictionary:
	var row := Enemies.row_of(_tuning, FireTiger.TYPE)
	var look := _presets.drawn_preset()
	var tell_1 := float(FireTiger.tell_frames(FireTiger.SWIPE_1, row)) / CombatSim.TICK_HZ
	var tell_2 := float(FireTiger.tell_frames(FireTiger.SWIPE_2, row)) / CombatSim.TICK_HZ
	var stumble := float(FireTiger.stumble_frames(row)) / CombatSim.TICK_HZ
	var recover := float(FireTiger.recover_frames(row)) / CombatSim.TICK_HZ
	var stand := tell_1 + tell_2 + stumble + recover
	var death := stand + look.hold_s
	return {"swipe_2_s": tell_1, "stumble_s": tell_1 + tell_2, "recover_s": tell_1 + tell_2 + stumble,
		"stand_s": stand, "death_s": death, "end_s": death + look.fade_s}


## The tiger shown (its real model at its look's scale) in place of the
## caster; no cast.
func _show_tiger() -> void:
	character = CREATURES[0]
	_cast = false
	if _caster == null:
		return
	_caster.visible = false
	if _enemy != null:
		_enemy.visible = false
	_show_telegraph(-1.0)
	if _tiger == null:
		_tiger = FireTigerModel.new()
		_tiger.name = "FireTiger"
		add_child(_tiger)
		RingArenaView.light_as_character(_tiger)
	_tiger.visible = true
	move = "combo"


## The tiger's synced state `t` s into its cast (as the game's FireTiger
## makes it, FireTigerClips reads it): swipe 1's tell, swipe 2's, the
## recovery (the stumble, then the recover), standing, then dead; standing
## before any cast.
func _tiger_state(t: float, row: Dictionary) -> Dictionary:
	var state := {"phase": CombatSim.ENEMY_CHASE, "timer": 0, "attack": "", "hitstop": 0, "stun": 0,
		"tick_factor": 1.0, "speed_m_per_s": 0.0, "dead_s": -1.0}
	if t < 0.0:
		return state
	var cast := tiger_cast()
	var frames := t * CombatSim.TICK_HZ
	var done := int(floorf(frames))
	state["tick_factor"] = frames - floorf(frames)
	var tell_1 := FireTiger.tell_frames(FireTiger.SWIPE_1, row)
	var tell_2 := FireTiger.tell_frames(FireTiger.SWIPE_2, row)
	if t < float(cast["swipe_2_s"]):
		state.merge({"phase": CombatSim.ENEMY_WINDUP, "attack": FireTiger.SWIPE_1, "timer": tell_1 - done}, true)
	elif t < float(cast["stumble_s"]):
		state.merge({"phase": CombatSim.ENEMY_WINDUP, "attack": FireTiger.SWIPE_2, "timer": tell_1 + tell_2 - done}, true)
	elif t < float(cast["stand_s"]):
		var total := FireTiger.stumble_frames(row) + FireTiger.recover_frames(row)
		state.merge({"phase": CombatSim.ENEMY_RECOVER, "timer": total - (done - tell_1 - tell_2)}, true)
	elif t >= float(cast["death_s"]):
		state["dead_s"] = t - float(cast["death_s"])
	return state


## The frame with the tiger on: its pose at the clock's time (its idle with
## no cast), its flames on its sockets (shrunk as it stumbles, dying out
## after its death); then the cast played as a character's is (_play_cast).
func _show_tiger_cast(delta: float) -> void:
	_caster.position = _stand_at
	var row := Enemies.row_of(_tuning, FireTiger.TYPE)
	var scale := FireTigerLooks.scale_of(_tuning)
	var t := clock.time if _cast else -1.0
	var state := _tiger_state(t, row)
	_pose = FireTigerClips.pose(state, row, scale, FireTigerClips.info())
	# Its rig faces +Z; the lab's casters face -Z.
	_tiger.transform = Transform3D(Basis(Vector3.UP, PI), _stand_at)
	_tiger.set_scale_to(scale)
	_tiger.show_pose(_pose, maxf(delta, 0.0))
	_tiger.visible = not _pose["gone"]
	_dummies.advance(maxf(delta, 0.0))
	_effect.visible = _meter.effect_on()
	var drawn := _presets.drawn_preset()
	_effect.preset = drawn
	_sync_reach()
	_outline.show_for({}, _stand_at)
	FxBloom.apply(get_world_3d().environment, drawn.bloom, drawn.drawn_intensity())
	var flames := _effect as FxTigerFlames
	flames.set_tiger_scale(scale)
	flames.set_sockets(_tiger.socket_at("mane"), _tiger.socket_at("tail_tip"))
	flames.set_motion(Vector3.ZERO)
	flames.set_stumble(FireTigerLooks.stumble_of(state, row))
	flames.set_dead_at(float(tiger_cast()["death_s"]) if _cast else INF)
	if not _cast:
		_idle_s += maxf(delta, 0.0)
	_show_spawner_ring()
	_play_cast(delta)

# --- Readout -------------------------------------------------------------------

## Counts a frame of `delta` seconds; the fps refreshes every READOUT_EVERY_S.
func _count_fps(delta: float) -> void:
	_frames += 1
	_frames_s += delta
	if _frames_s >= READOUT_EVERY_S:
		_fps = _frames / _frames_s
		_frames = 0
		_frames_s = 0.0


## The fps counter and the help box's explanations: the cast, the effect's
## census and budget, the dummies, the GPU cost.
func _write_readout() -> void:
	# Counted each frame it shows; held while the meter hides it.
	if _effect.visible or _census.is_empty():
		_census = Cost.census(_effect, _camera)
	var state := "paused" if clock.paused else ("0.1x" if clock.slow else "1x")
	var fps := "%.0f fps   (%.1f ms GPU frame)" % [_fps, RenderingServer.viewport_get_measured_render_time_gpu(_vp)]
	var lines := [
		"%s  %s  on %s   recipe %s: %s   (V %d of %d)" % [character, move, floor_kind, recipe, _presets.preset_name,
			effects_of(character).find(recipe) + 1, effects_of(character).size()],
		"t %.3f s / %.2f   %s%s   seed %d" % [clock.time, clock.length, state, "  loop" if clock.looping else "",
			clock.seed] if _cast else "Space to cast",
		"effect: %d transparent layers   %d particles   %d triangles" % [_census["transparent_layers"],
			_census["particles"], _census["triangles"]],
	]
	var low := _presets.editing_low()
	var over := FxBudget.over(_census, low)
	var level := "Low" if low else "max graphics"
	lines.append("%d over the screen   %d full-screen   %s" % [_census["screen_layers"], _census["full_screen"],
		"OVER BUDGET (%s): %s" % [level, "; ".join(over)] if not over.is_empty() else "within budget (%s)" % level])
	var fair := FxReach.check(_presets.drawn_preset(), hit())
	lines.append(FxReach.describe(fair))
	lines.append("dummies: %d   E adds a %s   flinch %s" % [_dummies.count(), dummy_kind,
		"on" if _dummies.flinch_on else "off"])
	if _meter.measuring():
		lines.append("GPU cost: measuring...")
	elif _meter.done():
		var report: Dictionary = _meter.report()
		lines.append("GPU cost: %.2f ms on, %.2f ms off: effect %.2f ms" % [report["gpu_on_ms"],
			report["gpu_off_ms"], report["gpu_effect_ms"]])
	else:
		lines.append("GPU cost: C to measure")
	_info.text = "\n".join(lines)
	# The box hidden (H), a budget or fairness warning still shows under the counter.
	_readout.text = fps + ("\nOVER BUDGET (%s)" % level if not over.is_empty() and not _help.visible else "") \
		+ ("\nUNFAIR: drawn edge %.2f m, hit %.2f m" % [fair["drawn_m"], fair["hit_m"]]
			if not fair["ok"] and not _help.visible else "")
