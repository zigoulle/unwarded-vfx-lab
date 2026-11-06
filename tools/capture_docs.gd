## Captures the guide's screenshots and the README's GIF frames: opens the
## lab in a window, puts it in each state the guide shows and saves what the
## screen draws. Needs a window (not --headless):
##   godot --path . res://tools/capture_docs.tscn
## Writes docs/images/*.png and the GIF's frames to user://gif_frames/;
## tools/make_gif.sh turns those into docs/images/knobs-live.gif.
extends Node

## Where the guide's pictures go, and where the GIF's frames go.
const OUT := "res://docs/images"
const GIF_FRAMES := "user://gif_frames"
## The GIF: this many frames, the knobs moving across them.
const GIF_COUNT := 72

## The lab being captured.
var _lab: Node3D


## A 1600x900 window, then the captures once the scene is in the tree.
func _ready() -> void:
	get_window().size = Vector2i(1600, 900)
	_run.call_deferred()


## Every picture in turn, the GIF's frames last, then quits.
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_lab = (load("res://vfx_lab/vfx_lab.tscn") as PackedScene).instantiate()
	add_child(_lab)
	# Let the shaders compile and the floor settle.
	for i in 30:
		await get_tree().process_frame
	# The overview: the ground shake at its hold, everything on screen.
	_lab.use_recipe("ground_shake")
	await _cast_to(0.12)
	var full := await _grab()
	full.save_png(OUT + "/overview.png")
	_crop(full, _lab.get_node("Hud/Picker")).save_png(OUT + "/picker.png")
	_crop(full, _lab.get_node("Hud/Help")).save_png(OUT + "/readout.png")
	_crop(full, _lab.presets(), 900).save_png(OUT + "/panel.png")
	# The reach: the same frame, the move's reach on the page and 1.5 m more.
	var before := _crop_world(full)
	var spot: Dictionary = _lab.reach()
	_lab.set_reach(float(spot["value"]) + 1.5)
	await _cast_to(0.12)
	var after := _crop_world(await _grab())
	var both := Image.create(before.get_width() * 2 + 8, before.get_height(), false, before.get_format())
	both.fill(Color(0.1, 0.1, 0.1))
	both.blit_rect(before, Rect2i(Vector2i.ZERO, before.get_size()), Vector2i.ZERO)
	both.blit_rect(after, Rect2i(Vector2i.ZERO, after.get_size()), Vector2i(before.get_width() + 8, 0))
	both.save_png(OUT + "/reach.png")
	_lab.set_reach(float(spot["value"]))
	# Advanced open, on the tornado.
	_lab.use_recipe("tornado")
	await _cast_to(0.6)
	_lab.presets().toggle_advanced()
	# Scrolled to the end, where Advanced's knobs open.
	var scroll := _lab.presets().get_child(0) as ScrollContainer
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await get_tree().process_frame
	_crop(await _grab(), _lab.presets(), 900).save_png(OUT + "/advanced.png")
	scroll.scroll_vertical = 0
	_lab.presets().toggle_advanced()
	await _gif()
	get_tree().quit()


## Casts the effect shown and stops `after_hit_s` past its hit, paused.
func _cast_to(after_hit_s: float) -> void:
	_lab.handle_key(KEY_SPACE)
	if not _lab.clock.paused:
		_lab.handle_key(KEY_P)
	_lab.clock.time = _lab.hit_s() + after_hit_s
	_lab.advance(0.0)
	for i in 3:
		await get_tree().process_frame


## What the window shows now.
func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


## `control`'s part of `image` (the window's), at most `max_h` px tall.
func _crop(image: Image, control: Control, max_h: int = 100000) -> Image:
	var scale := Vector2(image.get_size()) / get_viewport().get_visible_rect().size
	var rect := control.get_global_rect()
	var at := Rect2i(Vector2i((rect.position * scale).floor()), Vector2i((rect.size * scale).ceil()))
	at = at.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	at.size.y = mini(at.size.y, max_h)
	return image.get_region(at)


## The 3D view's middle (the caster and his effect), left of the panel.
func _crop_world(image: Image) -> Image:
	var w := image.get_width()
	var h := image.get_height()
	return image.get_region(Rect2i(int(w * 0.12), int(h * 0.12), int(w * 0.5), int(h * 0.76)))


## The GIF's frames: the ground shake held, its knobs moved across the frames
## (its size, then its colours, then its cracks' reach), the panel's sliders
## moving with them.
func _gif() -> void:
	DirAccess.make_dir_recursive_absolute(GIF_FRAMES)
	for f: String in DirAccess.get_files_at(GIF_FRAMES):
		DirAccess.remove_absolute(GIF_FRAMES.path_join(f))
	_lab.use_recipe("ground_shake")
	await _cast_to(0.1)
	# The frame counter reads the capture's own slow frames: hidden, with the help box.
	(_lab.get_node("Hud/Readout") as CanvasItem).visible = false
	(_lab.get_node("Hud/Help") as CanvasItem).visible = false
	var panel = _lab.presets()
	var sliders: Dictionary = panel.sliders()
	var size: HSlider = sliders["size"]
	var own := ""
	for knob: String in sliders:
		if knob.begins_with("cracks"):
			own = knob
			break
	var size_was := size.value
	var core_was: Color = panel.preset.core_colour
	var edge_was: Color = panel.preset.edge_colour
	var own_was: float = (sliders[own] as HSlider).value if own != "" else 0.0
	for i in GIF_COUNT:
		var k := float(i) / float(GIF_COUNT - 1)
		if k < 0.35:
			size.value = lerpf(size_was, size_was * 1.6, sin(k / 0.35 * PI))
		elif k < 0.7:
			var c := sin((k - 0.35) / 0.35 * PI)
			panel.set_knob("core_colour", core_was.lerp(Color(1.0, 0.45, 0.1), c))
			panel.set_knob("edge_colour", edge_was.lerp(Color(0.55, 0.1, 0.05), c))
		elif own != "":
			(sliders[own] as HSlider).value = lerpf(own_was, own_was * 1.8, sin((k - 0.7) / 0.3 * PI))
		await get_tree().process_frame
		(await _grab()).save_png(GIF_FRAMES.path_join("frame_%03d.png" % i))
	size.value = size_was
	panel.set_knob("core_colour", core_was)
	panel.set_knob("edge_colour", edge_was)
	if own != "":
		(sliders[own] as HSlider).value = own_was
	print("[capture] GIF frames in ", ProjectSettings.globalize_path(GIF_FRAMES))
