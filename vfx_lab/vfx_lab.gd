## The VFX lab: a place to watch a spell effect at the game camera, on the
## caster's real move, on the volcano's ring arena, with slow motion, frame
## steps and replays of the same cast, and to tune it live with the preset
## panel's knobs.
##
## Keys:
##   Space   cast (a new seed)          R       replay the same cast
##   P       pause / resume             S       slow motion 0.1x
##   Right/. one frame on (pauses)      Left/,  one frame back (pauses)
##   L       loop the cast              M / N   next / previous move
##   V       next effect                G       back to the game camera
##   C       measure the effect's GPU cost (loops the cast)
##   H       hide / show the help
##   Right mouse drag  orbit            Wheel   closer / further
## The picker (top right, mouse only): the caster, then his effects (V's
## list, named by their moves).
## Presets (lab_presets.gd), the panel on the right, mouse only: the saved
## presets by name, a slider per shared core knob (size, form, hold, fade,
## intensity, trigger offset), a slider per knob of the recipe's own and a
## picker per colour, re-read every frame so an edit shows at once, paused
## too; Save, Duplicate, Rename and Copy.
##
## Each effect plays with the move it belongs to (FxMoves, the table the game
## reads too), and matches its hit: that move plays as the game draws it
## (its clip retimed on the Mage's frame data, MageClips; its hit where the
## game shows it, FxMoves.hit_s) and carries him as the game does
## (MoveKit.travelled_m). M and N pass between the moves of an effect's own
## family (his three light slashes, his two spins); the placeholder takes
## any move.
## The reach (FxReach): each effect's ground footprint is ratios of its
## move's real reach on the tuning pages, the move's hit area drawn as a thin
## outline on the floor (lab_hit_outline.gd), and the readout says whether
## the drawn ground edge is fair: within FxReach.tolerance of the hit's
## (UNFAIR warned like the budget, under the counter too with the help
## hidden). The reach slider at the top of the preset panel (lab_reach.gd)
## moves the move's reach: the effect and the outline follow at once.
## Budgets, Low versions, bloom: the readout warns when the preset drawn
## goes over its budget (FxBudget: max graphics', or Low's while the panel
## edits the Low version); the panel's "Editing: Max/Low" draws the preset's
## Low version (FxLow) and its sliders adjust it; the preset's bloom (under
## Advanced, off by default) turns on the scene's glow (FxBloom).
## The impact: when a preset turns them on, a local flash and a kick of the
## camera's shake (ScreenShake) as the impact passes.
## Looks only: nothing here runs a game.
extends Node3D

const Clock := preload("res://vfx_lab/lab_clock.gd")
const Cost := preload("res://vfx_lab/lab_cost.gd")
const Floors := preload("res://vfx_lab/lab_floors.gd")
const Effect := preload("res://vfx_lab/placeholder_effect.gd")
const Presets := preload("res://vfx_lab/lab_presets.gd")
const HitOutline := preload("res://vfx_lab/lab_hit_outline.gd")
const Reach := preload("res://vfx_lab/lab_reach.gd")
## The name the placeholder's first preset gets until it is saved.
const FRESH_PRESET := "placeholder - sparks"
## The recipes the lab has, the first opened (_script_of: their scripts). V
## steps through a caster's own in his moves' order (effects_of), whatever
## their order here.
const RECIPES := ["sand_slash", "placeholder", "tornado", "ground_shake", "whirlwind", "blink", "time_slow"]
## The casters the picker offers.
const CHARACTERS := ["mage"]
## Each caster's moves offered, in order (keys of his model's clip markers).
const MOVES := {
	"mage": ["light_1", "light_2", "light_3", "blink", "ground_shake", "whirlwind", "whirlwind_2", "tornado", "ultimate"],
}
## The effect plays on this long past the move's clip (s).
const TAIL_S := 0.8
## Where the placeholder bursts: ahead of the caster at chest height (m;
## the models face -Z).
const EFFECT_AT := Vector3(0.0, 1.0, -1.4)
## The caster's outline: the game's first player's colour.
const OUTLINE := Color(0.2, 0.72, 0.82)
## Orbit: degrees per pixel dragged, and the zoom step and range (shares of
## the game camera's distance).
const ORBIT_DEG_PER_PX := 0.3
const ZOOM_STEP := 0.1
const ZOOM_MIN := 0.2
const ZOOM_MAX := 4.0
## The fps counter refreshes this often (s).
const READOUT_EVERY_S := 0.25
## The help box's text size (px).
const HELP_FONT_SIZE := 8
## The help box's key help.
const HELP := [
	"Space cast   R replay   P pause   S 0.1x   Left/Right frame step   L loop",
	"M/N move (an effect keeps its own move, or its family's)   V next effect",
	"right drag orbit   wheel zoom   G game camera   C measure GPU cost   H hide this box",
	"Top right: pick the caster, then his effect; the preset panel under it",
	"Presets: the panel on the right (sliders, Advanced, Save, Duplicate, Rename, Copy)",
]

var clock := Clock.new()
var character := "mage"
var move := "light_1"
## The recipe cast (RECIPES).
var recipe: String = RECIPES[0]
var floor_kind := "ring"

var _tuning: Dictionary = {}
## The tuning folder the lab reads, and its pages' text (the reach slider
## edits a copy of it, never the files).
var _folder := ""
var _pages: Dictionary = {}
## The reach slider's line now (Reach.spot_of; {} with none) and what it was
## worked out for.
var _reach: Dictionary = {}
var _reach_for: Array = []
var _floor: Node3D
var _caster: CharacterModel
var _effect: Node3D
var _camera: Camera3D
var _environment: WorldEnvironment
var _lights: Node3D
var _hud: CanvasLayer
## The picker at the top right: the caster, then his effects; the preset
## panel sits under it.
var _picker: PanelContainer
var _who: OptionButton
var _spell: OptionButton
## The fps counter (top left), the help box (bottom left; H) and the
## explanations in it (the cast, the cost, the budget, the reach).
var _readout: Label
## The full-screen flash an effect gives its caster's own screen (none of
## the Mage's today; screen_alpha).
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
var _outline: Node3D
## The clock's time last shown (the impact kicks the camera as the clock
## passes it).
var _shown_t := INF
var _presets: Presets
## The caster's kit (his moves' frame data: a cast of an effect's own move
## plays as the game draws it), and where he stands before a cast.
var _sim: MoveKit
var _stand_at := Vector3.ZERO
## The ground the effect lays its marks on (the floor is level).
var _ground := Ground.new()
## The screen shake on the lab's camera: kicked as an impact passes (forward
## only), its offset this frame.
var _shake := ScreenShake.new()
var _shake_offset := Vector3.ZERO
## The lab clock's seconds last frame (the lab's time runs on it).
var _game_s := 0.0


## Builds the lab: the tuning, the light, the camera, the first effect and
## its panel, the floor and the caster.
func _ready() -> void:
	_add_hud()
	_folder = Tuning.default_path()
	_pages = Tuning.read_pages(_folder)
	var loaded := Tuning.load_folder(_folder)
	if loaded.error != "":
		_readout.text = "Tuning page error\n\n" + loaded.error
		return
	_tuning = loaded.values
	# The effect intensity knob at the pages' level: glow and flash as played.
	EffectIntensity.set_from(_tuning)
	_game_s = GameClock.seconds()
	_add_light()
	_camera = Camera3D.new()
	_camera.name = "Camera"
	add_child(_camera)
	_camera.current = true
	use_recipe(recipe)
	_outline = HitOutline.new()
	add_child(_outline)
	_vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	_show_floor(floor_kind)
	_show_caster(character)
	_show()


# --- What the keys and the panel drive ------------------------------------------

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


## The tuning the lab reads (Tuning.parse's merged values).
func tuning() -> Dictionary:
	return _tuning


## The floor's ground (the effect's marks are laid on it).
func ground() -> Ground:
	return _ground


## The camera's shake this frame (zero when still).
func shake_offset() -> Vector3:
	return _shake_offset


## The pose the caster was last shown in.
func pose() -> Dictionary:
	return _pose


## The move's hit area drawn on the floor (lab_hit_outline.gd).
func hit_outline() -> Node3D:
	return _outline


## The move's hit area its effect is drawn for (FxReach.hit_of of the
## move's data); {} off the effect's own move.
func hit() -> Dictionary:
	return FxReach.hit_of(FxMoves.data_of(_sim, move)) if _plays_own_move() else {}


## Reads `values` (tuning, as Tuning.parse merges the pages) in place of the
## pages read at the start: the caster's kit, so the effect and the outline
## follow the move's reach.
func use_tuning(values: Dictionary) -> void:
	_tuning = values
	if _caster != null:
		_sim = MoveKit.new(_tuning)
		_caster.read_kit(_sim, _tuning["look"])
	_reach_for = []
	_show()


## The reach slider's line (Reach.spot_of): the move's reach on the page;
## {} for a spell with no hit area, or off its own move.
func reach() -> Dictionary:
	return _reach


## The reach slider moved to `value` (m): the effect and outline are drawn
## at it (the pages' text in memory changed, never the files).
func set_reach(value: float, _done: bool = true) -> String:
	if _reach.is_empty():
		return "no reach to set"
	var shown := Reach.edited(_pages, _reach, value)
	var parsed := Tuning.parse(shown["pages"])
	if parsed.error != "":
		return parsed.error
	_pages = shown["pages"]
	use_tuning(parsed.values)
	return ""


## The reach slider on the move shown (Reach.spot_of), worked out again
## only when the recipe, the move or the tuning changed.
func _sync_reach() -> void:
	var key := [recipe, character, move, _presets.get_instance_id(), _pages.hash()]
	if key == _reach_for:
		return
	_reach_for = key
	var own := _plays_own_move() and FxReach.has_hit(recipe)
	_reach = Reach.spot_of(_pages, character, move, FxMoves.data_of(_sim, move)) if own else {}
	_presets.show_reach(_reach)
	_presets.show_reach({}, 1)


## The readout's text: the fps counter's, then the help box's explanations.
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
		KEY_V:
			var own := effects_of(character)
			use_recipe(own[(own.find(recipe) + 1) % own.size()])
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


## On by the lab clock's seconds since the last frame, not the engine's.
func _process(_delta: float) -> void:
	var now := GameClock.seconds()
	var delta := maxf(now - _game_s, 0.0)
	_game_s = now
	advance(delta)


## The keys (handle_key), the right mouse orbiting and the wheel zooming.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		handle_key((event as InputEventKey).keycode)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			# A click in the scene gives the keys back from the preset's name field.
			get_viewport().gui_release_focus()
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		_place_camera()
	elif event is InputEventMouseMotion and _orbiting:
		var motion := event as InputEventMouseMotion
		_yaw_deg -= motion.relative.x * ORBIT_DEG_PER_PX
		_rise_deg = clampf(_rise_deg - motion.relative.y * ORBIT_DEG_PER_PX, -40.0, 60.0)
		_place_camera()


# --- Presets (lab_presets.gd) --------------------------------------------------

## The preset panel: the preset the effect is drawn with, its sliders, Save,
## Duplicate, Rename and Copy.
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
	_hud.add_child(_presets)
	_presets.offset_top = _picker.get_combined_minimum_size().y
	var own := FxMoves.of_recipe(id)
	if not own.is_empty():
		_cast_on(own["move"])
	if _cast:
		_effect.impact_s = hit_s()
	_fill_picker()


## The script drawing recipe `id`.
static func _script_of(id: String) -> GDScript:
	var script := FxReach.script_of(id)
	return script if script != null else Effect


## The moves caster `who` offers, in order (MOVES).
static func moves_of(who: String) -> Array:
	return MOVES.get(who, [])


## The effects the lab lists under caster `who`, in V's order: his recipes
## (FxMoves) by his moves' order (moves_of; a family by its first move), then
## the placeholder (it takes any move).
static func effects_of(who: String) -> Array:
	var own := RECIPES.filter(func(id: String) -> bool:
		return FxMoves.of_recipe(id).get("character", "") == who)
	own.sort_custom(func(a: String, b: String) -> bool: return _move_rank(who, a) < _move_rank(who, b))
	own.append(Effect.RECIPE)
	return own


## Where recipe `id`'s (first) move comes in `who`'s moves (MOVES).
static func _move_rank(who: String, id: String) -> int:
	return moves_of(who).find(FxMoves.of_recipe(id)["move"])


## The caster on `cast_move` when he has it (before the lab is built: the
## one it opens on); no cast.
func _cast_on(cast_move: String) -> void:
	if _caster == null:
		move = cast_move
		return
	move = cast_move if _offers(cast_move) else _moves()[0]
	_cast = false


# --- The cast ------------------------------------------------------------------

## The move's clip markers (s) on the caster's model.
func _marks() -> Dictionary:
	return _caster.markers[move]


## Seconds from the cast to the move's hit marker: on an effect's own move
## where the game shows it (FxMoves.hit_s), else the clip's own.
func hit_s() -> float:
	var marks := _marks()
	if _plays_own_move():
		return FxMoves.hit_s(_sim, move, marks)
	return float(marks["hit"]) - float(marks["start"])


## True while the effect cast is the one its move plays in the game
## (FxMoves: the effect matches the hit, so the move stays its own): the
## cast plays that move as the game draws it, and M and N pass among its
## family (V reaches the placeholder, which takes any move).
func _plays_own_move() -> bool:
	var own := FxMoves.of_recipe(recipe)
	return not own.is_empty() and own["character"] == character and move in FxMoves.moves_of(recipe) \
		and _sim != null and FxMoves.has_move(_sim, move)


## The pose the game draws `t` s into the move (MageClips reading his kit,
## as the game's avatar does: the clip retimed on the move's frame data),
## idle once the move is over.
func _game_pose(t: float) -> Dictionary:
	var elapsed := t * FxMoves.CLIP_FPS
	var state := {"move": "", "move_frame": 0, "hitstop": 0, "tick_factor": 0.0, "speed_m_per_s": 0.0}
	if elapsed <= float(_sim.move_length(move)):
		var whole := floorf(elapsed)
		state = {"move": move, "move_frame": int(whole) + 2, "hitstop": 0, "tick_factor": elapsed - whole}
	# An effect that goes on past its cast says what the game's state would
	# hold then, and how far he has turned with it: the lab runs no game.
	if _effect != null and _effect.has_method("pose_state"):
		state.merge(_effect.pose_state(t), true)
	var shown: Dictionary = _caster.clip_pose(_sim, state)
	if _effect != null and _effect.has_method("pose_yaw_deg"):
		shown["yaw_deg"] = float(shown.get("yaw_deg", 0.0)) + float(_effect.pose_yaw_deg(t))
	shown["streak"] = false
	return shown


## Where the move has carried him `t` s into it (MoveKit.travelled_m: a
## hop's, a lunge's), from where he stood, along the floor ahead of him (-Z).
func _carried(t: float) -> Vector3:
	var gone := _sim.travelled_m(move, minf(t * FxMoves.CLIP_FPS, float(_sim.move_length(move))))
	if gone <= 0.0:
		return _stand_at
	return _stand_at + Vector3(0.0, 0.0, -gone)


## A new cast's seed: the wall clock's microseconds stand in for the game's
## tick (FxSeed). R replays the seed kept.
func _new_seed() -> int:
	return FxSeed.of(Time.get_ticks_usec(), CHARACTERS.find(character))


## A cast with `seed` from the move's start: the clock as long as the move
## (on an effect's own move, its frames; else its clip) plus TAIL_S, the
## effect's impact on the move's hit.
func _start_cast(seed: int) -> void:
	var marks := _marks()
	var length := float(marks["end"]) - float(marks["start"])
	if _plays_own_move():
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
	var moves := FxMoves.moves_of(recipe) if _plays_own_move() else _moves()
	move = moves[posmod(moves.find(move) + step, moves.size())]
	_cast = false


## The caster's moves the lab offers (those his model has clips for).
func _moves() -> Array:
	return moves_of(character).filter(func(m: String) -> bool: return _offers(m))


## Whether the caster shown offers `m` (his model has its clip).
func _offers(m: String) -> bool:
	return _caster.markers.has(m)


## Draws the frame: the caster's pose `delta` after the last, the effect at
## the clock's time, the camera, the readout.
func _show(delta: float = 0.0) -> void:
	if _caster == null:
		return
	_caster.position = _stand_at
	if _cast and _plays_own_move():
		_pose = _game_pose(clock.time)
		_caster.position = _carried(clock.time)
	elif _cast:
		var marks := _marks()
		var start := float(marks["start"])
		_pose = {"clip": move, "time": minf(start + clock.time, float(marks["end"])), "rate": 1.0,
			"spin": 0.0, "lean": float(marks.get("lean", 0.0)), "yaw_deg": 0.0}
	else:
		_pose = {"clip": "idle", "time": -1.0, "rate": 1.0, "spin": 0.0, "lean": 0.0, "yaw_deg": 0.0}
	_caster.show_pose(_pose, maxf(delta, 0.0))
	_effect.visible = _meter.effect_on()
	# Re-read every frame: an edit in the preset panel shows at once, paused too.
	var drawn := _presets.drawn_preset()
	_effect.preset = drawn
	# Its ground footprint is ratios of the move's reach (FxReach), the
	# move's real hit area outlined on the floor round him.
	if "hit" in _effect:
		_effect.hit = hit()
	_sync_reach()
	if _outline != null and not _effect.has_method("hit_outline"):
		var own := FxMoves.data_of(_sim, move) if _plays_own_move() and FxReach.has_hit(recipe) else {}
		if own.has(FxReach.WAVE_LENGTH_KEY) and _effect.has_method("turned_rad"):
			own = own.duplicate()
			own[HitOutline.TURNED_KEY] = _effect.turned_rad(clock.time if _cast else 0.0)
		_outline.show_for(own, _stand_at if own.has("half_width_m") else _caster.position)
	FxBloom.apply(get_world_3d().environment, drawn.bloom, drawn.drawn_intensity())
	_effect.position = _caster.position + EFFECT_AT
	# A recipe that reads its kit's rows or its caster's sockets and clip markers.
	if _effect.has_method("set_kit"):
		_effect.set_kit(_sim)
	if _effect.has_method("set_caster"):
		_effect.set_caster(_caster)
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
	if _effect.has_method("set_path"):
		_effect.set_path(_stand_at, _caster.position, Basis.IDENTITY)
	_play_cast(delta)


## The effect at the clock's time (its cast placed), the camera's shake as
## its impact passes, the camera, the readout.
func _play_cast(delta: float) -> void:
	if _cast:
		# Long enough for the effect to play out past the move.
		var end: float = (_effect.end_time() if _effect.has_method("end_time") else _effect.impact_time()
			+ _presets.preset.hold_s + _presets.preset.fade_s)
		clock.length = maxf(clock.length, end + 0.1)
		_effect.show_at(clock.seed, clock.time)
		# The clock passed the impact (on, not stepping back): the camera
		# shakes (forward only).
		var impact: float = _effect.impact_time()
		if _shown_t < impact and clock.time >= impact and _effect.has_method("shake_kick"):
			_shake.kick(_effect.shake_kick())
		_shown_t = clock.time
	else:
		_effect.show_at(0, -1.0)
		_shown_t = INF
	_show_screen_flash()
	_shake_offset = _shake.offset(maxf(delta, 0.0))
	_place_camera()
	_write_readout()


## The full-screen flash the effect gives its caster's own screen now (0
## with none), as the game's HUD draws it.
func screen_flash() -> float:
	return _screen_flash.color.a if _screen_flash.visible else 0.0


func _show_screen_flash() -> void:
	var alpha: float = _effect.screen_alpha() if _cast and _effect.has_method("screen_alpha") else 0.0
	_screen_flash.visible = alpha > 0.0
	_screen_flash.color = Color(_presets.drawn_preset().core_colour, alpha)


# --- Scene ---------------------------------------------------------------------

## Floor `kind` (Floors.KINDS) in place of the last, the lab's light unless
## it lights itself; he stands on it.
func _show_floor(kind: String) -> void:
	if _floor != null:
		remove_child(_floor)
		_floor.free()
	floor_kind = kind
	_floor = Floors.build(kind, _tuning)
	add_child(_floor)
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
	_caster = MageLook.build_model()
	_caster.name = "Caster"
	var look: Dictionary = _tuning["look"]
	_caster.set_look(float(look.get("mage_height_m", MageLook.BASE_HEIGHT_M)), OUTLINE,
		float(look.get("mage_outline", 0.5)), float(look.get("mage_lift", 0.0)))
	add_child(_caster)
	_sim = MoveKit.new(_tuning).for_character(id)
	_caster.read_kit(_sim, look)
	if not _offers(move):
		move = _moves()[0]
	_cast = false
	_stand()


## The caster stands at the floor's stand spot (Floors.stand_spot: halfway
## across the ring), on its level round it (Floors.level_round: on the
## slabs, not down in a seam between them), where the effects lay their
## marks (set_ground).
func _stand() -> void:
	if _caster == null or _floor == null:
		return
	var spot := Floors.stand_spot(floor_kind, _tuning)
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
		var reach_m := Vector2(distance, height).length()
		var angle := atan2(height, distance) + deg_to_rad(_rise_deg)
		angle = clampf(angle, deg_to_rad(2.0), deg_to_rad(88.0))
		distance = reach_m * cos(angle)
		height = reach_m * sin(angle)
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


## The HUD: the fps counter top left, and the help and the explanations
## (the cast, the cost, the budget, the reach) in a small box at the bottom
## left; H hides and shows the box.
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
## caster list, then his effects (effects_of, named by their moves). Mouse
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
	for id: String in CHARACTERS:
		_who.add_item(id.capitalize())
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
	_who.select(CHARACTERS.find(character))
	_spell.clear()
	for id: String in effects_of(character):
		var moves := FxMoves.moves_of(id)
		var on := ", ".join(moves).replace("_", " ") if not moves.is_empty() else "any move"
		_spell.add_item("%s  (%s)" % [id.replace("_", " "), on])
	_spell.select(effects_of(character).find(recipe))


## One of the help box's labels, `label_name`d, at HELP_FONT_SIZE in `colour`.
func _small_label(label_name: String, colour: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.add_theme_font_size_override("font_size", HELP_FONT_SIZE)
	label.add_theme_color_override("font_color", colour)
	return label


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
## census and budget, the reach, the GPU cost.
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
