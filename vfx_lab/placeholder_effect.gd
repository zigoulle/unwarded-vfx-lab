## The lab's placeholder effect (ticket 01): a burst of blue-white sparks
## thrown out from the move's hit and falling, drawn only from (seed, time
## since the cast), so any frame can be drawn in any order. One MultiMesh of
## additive billboards. Stands in until the real blocks (ticket 04).
##
## Drawn from its preset's shared core knobs (FxPreset, recipe RECIPE),
## re-read every frame it draws (ticket 02): the colours (core at the burst,
## edge as it ends), the size (its spread and sparks), form, hold and fade
## (how long and how bright), the intensity and the trigger offset (the burst
## against the hit), so a slider moved in the lab shows at once, paused too.
extends Node3D

## The recipe its presets are saved under (FxPresets).
const RECIPE := "placeholder"

const COUNT := 32
## How long a spark lives after the hit (s), with no preset: its fade.
const LIFE_S := 0.6
const GRAVITY := 9.0
const SPEED_MIN := 2.0
const SPEED_MAX := 6.0
const RISE_MIN := 1.0
const RISE_MAX := 4.0
const SIZE_M := 0.12
const COLOR := Color(0.65, 0.85, 1.0)

## When the sparks fly: seconds after the cast (the move's hit marker),
## before the preset's trigger offset.
var impact_s := 0.0
## The knobs it is drawn with, read each frame (default_preset when none).
var preset: FxPreset = default_preset()

var _multimesh := MultiMesh.new()
var _drawn: Array = []
var _colour := Color(0, 0, 0, 0)


## Builds its sparks' glowing billboard quads, hidden until a cast.
func _init() -> void:
	name = "PlaceholderEffect"
	var quad := QuadMesh.new()
	quad.size = Vector2(SIZE_M, SIZE_M)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	quad.material = material
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = quad
	_multimesh.instance_count = COUNT
	_multimesh.visible_instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.name = "Sparks"
	instance.multimesh = _multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


## The placeholder's own look: ticket 01's sparks (blue-white, a 0.6 s fade).
static func default_preset() -> FxPreset:
	var out := FxPreset.new()
	out.recipe = RECIPE
	out.core_colour = COLOR
	out.edge_colour = COLOR
	out.form_s = 0.0
	out.hold_s = 0.0
	out.fade_s = LIFE_S
	return out


## The sparks' places (local to the effect) `t` seconds after the cast, for a
## hit `impact` seconds in, from `seed`, with `knobs` (default_preset when
## null): none before the burst (the hit plus the trigger offset) or once its
## form, hold and fade are over. The size scales their spread.
static func sparks(seed: int, t: float, impact: float, knobs: FxPreset = null) -> PackedVector3Array:
	if knobs == null:
		knobs = default_preset()
	var out := PackedVector3Array()
	var age := t - impact - knobs.trigger_offset_s
	if age < 0.0 or age > knobs.life_s():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in COUNT:
		var angle := rng.randf() * TAU
		var speed := rng.randf_range(SPEED_MIN, SPEED_MAX)
		var rise := rng.randf_range(RISE_MIN, RISE_MAX)
		var out_dir := Vector3(cos(angle), 0.0, sin(angle))
		out.append((out_dir * speed * age + Vector3.UP * (rise * age - 0.5 * GRAVITY * age * age)) * knobs.size)
	return out


## How bright the sparks are `age` seconds into the burst (0 to 1): rising
## through the form, full in the hold, falling through the fade.
static func alpha(age: float, knobs: FxPreset) -> float:
	if age < 0.0 or age > knobs.life_s():
		return 0.0
	if age < knobs.form_s:
		return age / knobs.form_s
	if age <= knobs.form_s + knobs.hold_s:
		return 1.0
	return 1.0 - clampf((age - knobs.form_s - knobs.hold_s) / maxf(knobs.fade_s, 0.0001), 0.0, 1.0)


## Draws the frame `t` seconds after a cast with `seed`, with the preset's
## knobs as they are now.
func show_at(seed: int, t: float) -> void:
	var points := sparks(seed, t, impact_s, preset)
	var age := t - impact_s - preset.trigger_offset_s
	var share := clampf(age / maxf(preset.life_s(), 0.0001), 0.0, 1.0)
	var tint := preset.core_colour.lerp(preset.edge_colour, share) * preset.intensity
	_colour = Color(tint.r, tint.g, tint.b, alpha(age, preset))
	_drawn = Array(points)
	_multimesh.visible_instance_count = points.size()
	var spark_basis := Basis().scaled(Vector3.ONE * preset.size)
	for i in points.size():
		_multimesh.set_instance_transform(i, Transform3D(spark_basis, points[i]))
		_multimesh.set_instance_color(i, _colour)


## When its burst plays (s after the cast): the hit plus the trigger offset.
func impact_time() -> float:
	return impact_s + preset.trigger_offset_s


## Where its burst plays (world).
func impact_point() -> Vector3:
	return global_position


## The sparks drawn now (local places).
func drawn() -> Array:
	return _drawn


## The colour the sparks were last drawn in (alpha: their brightness).
func drawn_colour() -> Color:
	return _colour
