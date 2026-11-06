## The graphics options of the settings screen (perf loop pass 4, P-O's
## ruling: the look trade-offs are the player's; volcano-climb ticket 14's
## GPU cuts): how big the 3D is drawn (render scale, FSR upscales it to the
## window below 100%), glow, how many lava lights light the ring arena,
## multisampling (MSAA), screen-space anti-aliasing (SMAA or FXAA) and the
## scenery's detail (the forest's haze layers, the lava sea's bottomless
## look). A quality preset sets them together but the render scale: High is
## the look the game had before the perf loop, Medium and Low trade effects
## for speed on weak graphics chips; changing one option by hand makes it
## "Custom" (preset()). The render scale is the last resort, the player's
## alone: 100% unless he picks less, whatever the preset.
##
## Saved per PC in GameSettings' file, section [graphics]. First launch (no
## section yet): High on a discrete GPU, Low on an integrated one
## (default_preset). `--graphics=high|medium|low` on the command line forces
## a preset for the run without saving it (the perf benchmark).
## Pure values and their mapping to the viewport; main.gd applies them
## (the viewport here, the glow and lights in RingArenaView.apply_graphics,
## the scenery in VolcanoZoneView.apply_scenery).
class_name GraphicsSettings
extends RefCounted

const HIGH := "high"
const MEDIUM := "medium"
const LOW := "low"
const CUSTOM := "custom"
## The presets, best look first.
const PRESETS: Array[String] = [HIGH, MEDIUM, LOW]
## The render scales offered (percent of the window's size): the diagnosis
## (2026-10-21) found the GPU pixel bound, half the size about half the time.
const SCALES: Array[int] = [100, 90, 80, 70, 60, 50]
## Multisampling: 4x (the original look; ~4 ms with SMAA on Iris Xe at
## 1080p, the 2026-10-21 diagnosis), 2x, none.
const MSAA_4X := "4x"
const MSAA_2X := "2x"
const MSAA_OFF := "off"
const MSAAS: Array[String] = [MSAA_4X, MSAA_2X, MSAA_OFF]
## Screen-space anti-aliasing over the image: SMAA (~0.5 ms on Iris Xe),
## FXAA (cheaper, a little softer), none.
const SCREEN_AA_SMAA := "smaa"
const SCREEN_AA_FXAA := "fxaa"
const SCREEN_AA_OFF := "off"
const SCREEN_AAS: Array[String] = [SCREEN_AA_SMAA, SCREEN_AA_FXAA, SCREEN_AA_OFF]
## The ring arena's lava lights: all of them, or a reduced set
## (RingArenaView.REDUCED_LIGHTS) that keeps the room lit with fewer.
const LIGHTS_FULL := "full"
const LIGHTS_REDUCED := "reduced"
const LIGHTS: Array[String] = [LIGHTS_FULL, LIGHTS_REDUCED]
## The scenery's detail: full, or light (one haze layer over the ash forest
## instead of three; the lava sea's bottomless look from one noise instead
## of five). The diagnosis: haze 2.6-3.9 ms, the sea's bottom 2.5-3 ms.
const SCENERY_FULL := "full"
const SCENERY_LIGHT := "light"
const SCENERIES: Array[String] = [SCENERY_FULL, SCENERY_LIGHT]
## Each preset's options (the render scale is no preset's). Costs measured
## on Iris Xe at 1080p (.scratch/perf-loop/runs/2026-10-21-diagnosis.md).
const VALUES := {
	HIGH: {"glow": true, "lava_lights": LIGHTS_FULL, "msaa": MSAA_4X, "screen_aa": SCREEN_AA_SMAA,
		"scenery": SCENERY_FULL},
	MEDIUM: {"glow": true, "lava_lights": LIGHTS_REDUCED, "msaa": MSAA_OFF, "screen_aa": SCREEN_AA_FXAA,
		"scenery": SCENERY_LIGHT},
	LOW: {"glow": false, "lava_lights": LIGHTS_REDUCED, "msaa": MSAA_OFF, "screen_aa": SCREEN_AA_FXAA,
		"scenery": SCENERY_LIGHT},
}
## The options a preset sets.
const PRESET_KEYS: Array[String] = ["glow", "lava_lights", "msaa", "screen_aa", "scenery"]
## The older single anti-aliasing choice (saved before MSAA and SMAA were two
## options) as [msaa, screen_aa].
const OLD_AA := {"msaa": [MSAA_4X, SCREEN_AA_SMAA], "smaa": [MSAA_OFF, SCREEN_AA_SMAA],
	"off": [MSAA_OFF, SCREEN_AA_OFF]}
const SECTION := "graphics"

var render_scale: int = 100
var glow: bool = VALUES[HIGH]["glow"]
var lava_lights: String = VALUES[HIGH]["lava_lights"]
var msaa: String = VALUES[HIGH]["msaa"]
var screen_aa: String = VALUES[HIGH]["screen_aa"]
var scenery: String = VALUES[HIGH]["scenery"]


## Options at preset `name` (HIGH for an unknown one), the 3D at full size.
static func for_preset(name: String) -> GraphicsSettings:
	var g := GraphicsSettings.new()
	g.set_preset(name)
	return g


## The preset a first launch gets: Low on an integrated GPU (Iris Xe class:
## the full look runs near 30 FPS there), High otherwise.
static func default_preset(integrated_gpu: bool) -> String:
	return LOW if integrated_gpu else HIGH


## `--graphics=<preset>` in `args`, or "" (none, or not a preset).
static func preset_from_args(args: PackedStringArray) -> String:
	for arg in args:
		if arg.begins_with("--graphics="):
			var name := arg.trim_prefix("--graphics=")
			return name if name in PRESETS else ""
	return ""


## Every option a preset sets at preset `name`'s value (HIGH for an unknown
## one); the render scale stays as it is.
func set_preset(name: String) -> void:
	var values: Dictionary = VALUES.get(name, VALUES[HIGH])
	for key: String in PRESET_KEYS:
		set(key, values[key])


## The preset the options match (the render scale aside), or CUSTOM.
func preset() -> String:
	for name: String in PRESETS:
		var values: Dictionary = VALUES[name]
		var same := true
		for key: String in PRESET_KEYS:
			if get(key) != values[key]:
				same = false
		if same:
			return name
	return CUSTOM


func msaa_3d() -> Viewport.MSAA:
	match msaa:
		MSAA_4X:
			return Viewport.MSAA_4X
		MSAA_2X:
			return Viewport.MSAA_2X
	return Viewport.MSAA_DISABLED


func screen_space_aa() -> Viewport.ScreenSpaceAA:
	match screen_aa:
		SCREEN_AA_SMAA:
			return Viewport.SCREEN_SPACE_AA_SMAA
		SCREEN_AA_FXAA:
			return Viewport.SCREEN_SPACE_AA_FXAA
	return Viewport.SCREEN_SPACE_AA_DISABLED


## FSR 1 upscales a 3D drawn below the window's size (sharper than plain
## stretching); at 100% nothing is upscaled.
func scaling_3d_mode() -> Viewport.Scaling3DMode:
	return Viewport.SCALING_3D_MODE_FSR if render_scale < 100 else Viewport.SCALING_3D_MODE_BILINEAR


func scaling_3d_scale() -> float:
	return render_scale / 100.0


## The 3D drawing options on `viewport` (the HUD is drawn at full size).
func apply_viewport(viewport: Viewport) -> void:
	viewport.msaa_3d = msaa_3d()
	viewport.screen_space_aa = screen_space_aa()
	viewport.scaling_3d_mode = scaling_3d_mode()
	viewport.scaling_3d_scale = scaling_3d_scale()


func write(file: ConfigFile) -> void:
	file.set_value(SECTION, "render_scale", render_scale)
	for key: String in PRESET_KEYS:
		file.set_value(SECTION, key, get(key))
	if file.has_section_key(SECTION, "antialiasing"):
		file.erase_section_key(SECTION, "antialiasing")


## Reads the options saved in `file`: false (and every option at preset
## `default`, the render scale 100%) when nothing is saved there yet; a bad
## value falls back to `default`'s. A file from before MSAA and SMAA were
## two options keeps its one choice (OLD_AA) and the full scenery it had.
func read(file: ConfigFile, default: String) -> bool:
	set_preset(default)
	render_scale = 100
	if not file.has_section(SECTION):
		return false
	var fallback: Dictionary = VALUES.get(default, VALUES[HIGH]).duplicate()
	var old: Variant = file.get_value(SECTION, "antialiasing", "") if file.has_section_key(SECTION, "antialiasing") else ""
	if old is String and OLD_AA.has(old) and not file.has_section_key(SECTION, "msaa"):
		fallback["msaa"] = OLD_AA[old][0]
		fallback["screen_aa"] = OLD_AA[old][1]
		fallback["scenery"] = SCENERY_FULL
	var scale: Variant = file.get_value(SECTION, "render_scale", 100)
	render_scale = scale if typeof(scale) == TYPE_INT and scale in SCALES else 100
	var on: Variant = file.get_value(SECTION, "glow", fallback["glow"])
	glow = on if typeof(on) == TYPE_BOOL else fallback["glow"]
	lava_lights = _one_of(file, "lava_lights", LIGHTS, fallback)
	msaa = _one_of(file, "msaa", MSAAS, fallback)
	screen_aa = _one_of(file, "screen_aa", SCREEN_AAS, fallback)
	scenery = _one_of(file, "scenery", SCENERIES, fallback)
	return true


static func _one_of(file: ConfigFile, key: String, allowed: Array[String], fallback: Dictionary) -> String:
	var value: Variant = file.get_value(SECTION, key, fallback[key])
	return value if typeof(value) == TYPE_STRING and value in allowed else fallback[key]
