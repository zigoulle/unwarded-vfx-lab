## The dire zone (progression spec "The dire zone (lighting only)"; GLOSSARY:
## Danger clock): from red to black on the danger clock the zone's lighting
## blends by DangerClock.dire toward `[danger_look]` (volcano page; the
## lava ball's scenery too, on the zone's one clock): the lights and the ambient dimmer
## (`dim_at_black`, the share of their energy kept), the environment and the
## lights redder (`tint_at_black`, a colour they are multiplied by), the
## lava's emission hotter (`lava_glow_at_black`, its brightness multiplier).
## No new meshes, textures or lights.
##
## Within the Graphics presets (GraphicsSettings): it scales only what the
## zone view has; it never touches glow_enabled or a light's visibility, so
## Low keeps its glow off and its reduced lights. Cheap on weak chips: values
## are written only when dire moved by STEP (a few times a minute between
## red and black), never before red.
##
## One per zone view (RingArenaView, its VolcanoZoneView child included;
## BallArenaView): `DireLook.new(view, environment)`, then show(dire) each
## frame. The lights and lava materials under the view are gathered the
## first time the zone turns dire, after the view is built.
class_name DireLook
extends RefCounted

const VOLCANO_SECTION := "danger_look"
## The keys (presentation only) are in Tuning.BASE_SCHEMA.
## The smallest change of dire that is written to the view.
const STEP := 1.0 / 128.0
## The lava shaders whose `brightness` is the lava's emission.
const LAVA_SHADERS: Array[Shader] = [
	preload("res://scenes/lava.gdshader"),
	preload("res://scenes/lava_fall.gdshader"),
]
## Their `brightness` uniform's default, in the same order.
const DEFAULT_BRIGHTNESS: Array[float] = [1.6, 2.2]

var _root: Node
var _environment: Environment
var _shown := 0.0
var _gathered := false
var _ambient_colour: Color
var _ambient_energy: float
var _fog_colour: Color
## [light, energy, colour] for each light under the view.
var _lights: Array = []
## [material, brightness] for each lava material under the view.
var _lava: Array = []


## The section a run on `tuning` reads: the zone's, wherever it is drawn.
static func section_of(_tuning: Dictionary) -> String:
	return VOLCANO_SECTION


## The look on the clock: {light: share of energy kept, tint: Color the
## lights and environment are multiplied by, lava: emission multiplier}.
## White, 1 and 1 before red (or with no `[danger_look]` on the page).
static func at(tuning: Dictionary, clock: int) -> Dictionary:
	var row: Dictionary = tuning.get(section_of(tuning), {})
	if row.is_empty():
		return of(0.0, 1.0, Color.WHITE, 1.0)
	return of(DangerClock.dire(tuning, clock), float(row["dim_at_black"]), Color.html(str(row["tint_at_black"])),
		float(row["lava_glow_at_black"]))


## The look at `dire` (0 to 1) toward the values at black.
static func of(dire: float, dim_at_black: float, tint_at_black: Color, lava_glow_at_black: float) -> Dictionary:
	return {
		"light": lerpf(1.0, dim_at_black, dire),
		"tint": Color.WHITE.lerp(tint_at_black, dire),
		"lava": lerpf(1.0, lava_glow_at_black, dire),
		"dire": dire,
	}


func _init(root: Node, environment: Environment) -> void:
	_root = root
	_environment = environment


## The zone at `look` (at()); written only when its dire moved by STEP.
func show(look: Dictionary) -> void:
	var dire := float(look["dire"])
	if absf(dire - _shown) < STEP and not (dire == 0.0 and _shown != 0.0):
		return
	if not _gathered:
		_gather()
	_shown = dire
	var light := float(look["light"])
	var tint: Color = look["tint"]
	if _environment:
		_environment.ambient_light_color = _ambient_colour * tint
		_environment.ambient_light_energy = _ambient_energy * light
		_environment.fog_light_color = _fog_colour * tint
	for entry: Array in _lights:
		var l: Light3D = entry[0]
		if is_instance_valid(l):
			l.light_energy = float(entry[1]) * light
			l.light_color = Color(entry[2]) * tint
	var lava := float(look["lava"])
	for entry: Array in _lava:
		(entry[0] as ShaderMaterial).set_shader_parameter("brightness", float(entry[1]) * lava)


func _gather() -> void:
	_gathered = true
	if _environment:
		_ambient_colour = _environment.ambient_light_color
		_ambient_energy = _environment.ambient_light_energy
		_fog_colour = _environment.fog_light_color
	for node: Node in _root.find_children("*", "Light3D", true, false):
		var l := node as Light3D
		_lights.append([l, l.light_energy, l.light_color])
	var seen := {}
	for node: Node in _root.find_children("*", "MeshInstance3D", true, false):
		var material := (node as MeshInstance3D).material_override as ShaderMaterial
		if material == null or not (material.shader in LAVA_SHADERS) or seen.has(material):
			continue
		seen[material] = true
		var brightness: Variant = material.get_shader_parameter("brightness")
		if brightness == null:
			# Left at the shader's default (the headless renderer cannot read it).
			brightness = DEFAULT_BRIGHTNESS[LAVA_SHADERS.find(material.shader)]
		_lava.append([material, float(brightness)])
