## The flash block (GLOSSARY: Block; VFX lab ticket 05, grill Q13): a flash
## of light at an impact. LOCAL by default: a light round the impact, its
## reach the preset's radius, so four players' spells in co-op don't blind
## each other (spec story 40). Full-screen only when a preset asks for it,
## and never while the player's "Reduce flashing" is on (story 39). Off by
## default in each preset (brightness 0); its light is capped and follows
## the effect's intensity (story 38). Lit and faded from the time since the
## impact alone (`at`). Looks only: the simulation never reads it.
class_name FxFlash
extends Node3D

## The most light it gives (the light's energy), and the most a full-screen
## flash covers the screen (its alpha): a photosensitivity cap.
const CAP := 8.0
const SCREEN_CAP := 0.35
## A full-screen flash's alpha per unit of brightness (before the cap).
const SCREEN_PER_BRIGHTNESS := 0.15

## The player's "Reduce flashing" setting (GameSettings.apply sets it,
## ticket 08): no full-screen flash anywhere, whatever a caller passes.
static var player_reduces := false


## Off (brightness 0); local when on.
static func default_knobs() -> Dictionary:
	return {"brightness": 0.0, "radius_m": 4.0, "length_s": 0.15, "full_screen": false}


## The flash `age` s after its impact with knobs {brightness (0: off),
## radius_m, length_s, full_screen} at the effect's `intensity`, with the
## Reduce flashing `reduce_flashing` (or the player's, player_reduces): {energy (the local light's),
## radius_m (its reach), screen_alpha (0: no full-screen flash)}.
static func at(knobs: Dictionary, intensity: float, age: float, reduce_flashing: bool) -> Dictionary:
	var length := float(knobs["length_s"])
	var brightness := minf(float(knobs["brightness"]) * maxf(intensity, 0.0), CAP)
	if brightness <= 0.0 or length <= 0.0 or age < 0.0 or age >= length:
		return {"energy": 0.0, "radius_m": float(knobs["radius_m"]), "screen_alpha": 0.0}
	var left := 1.0 - age / length
	var envelope := left * left
	var screen := 0.0
	if bool(knobs["full_screen"]) and not reduce_flashing and not player_reduces:
		screen = minf(brightness * SCREEN_PER_BRIGHTNESS, SCREEN_CAP) * envelope
	return {"energy": brightness * envelope, "radius_m": float(knobs["radius_m"]), "screen_alpha": screen}


var _light := OmniLight3D.new()
var _layer := CanvasLayer.new()
var _screen := ColorRect.new()


## Builds its local light and its full-screen layer, both off until an impact.
func _init() -> void:
	name = "Flash"
	_light.name = "Light"
	_light.top_level = true
	_light.shadow_enabled = false
	_light.visible = false
	add_child(_light)
	_layer.name = "Screen"
	add_child(_layer)
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.visible = false
	_layer.add_child(_screen)


## The local light.
func light() -> OmniLight3D:
	return _light


## The full-screen layer (shown only when a preset asks).
func screen() -> ColorRect:
	return _screen


## Lights the flash `age` s after an impact at `origin` (world), in
## `colour`, at `intensity`, with Reduce flashing `reduce_flashing`.
func show_at(knobs: Dictionary, intensity: float, age: float, origin: Vector3, colour: Color,
		reduce_flashing: bool) -> void:
	var now := at(knobs, intensity, age, reduce_flashing)
	_light.visible = float(now["energy"]) > 0.0
	_light.transform = Transform3D(Basis(), origin)
	_light.light_energy = float(now["energy"])
	_light.omni_range = float(now["radius_m"])
	_light.light_color = colour
	_screen.visible = float(now["screen_alpha"]) > 0.0
	_screen.color = Color(colour, float(now["screen_alpha"]))
