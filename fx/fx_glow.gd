## The in-effect glow pass (GLOSSARY: Block; VFX lab ticket 04, grill Q11):
## a ribbon's strip drawn a second time, wider, with the halo's soft profile
## and colours, additive: lightning glows from inside the effect, with no
## full-screen bloom. Its half-width is capped to a share of the screen's
## height (in the shader, FxGlow.capped_half_width on the CPU), so a bolt
## right by the camera can't fill the screen with overdraw. A Low version
## (FxLow, ticket 08) leaves it out: set_pass hides it at width 0. Node-free helpers, pure static.
class_name FxGlow
extends RefCounted

## The pass's name under its ribbon.
const PASS_NAME := "Glow"


## Adds a glow pass to `ribbon`: `width_scale` times the core's width,
## `opacity` of its brightness, its half-width at most `screen_cap` of the
## screen's height (0: no cap).
static func add_to(ribbon: FxRibbon, width_scale: float, opacity: float, screen_cap: float) -> MeshInstance3D:
	return ribbon.add_pass(PASS_NAME, {"glow_pass": true, "width_scale": width_scale, "pass_opacity": opacity,
		"screen_cap": screen_cap})


## Re-sets `glow`'s width, opacity and cap (a knob moved). A width or an
## opacity of 0 hides it: no extra pass (a Low version, FxLow).
static func set_pass(glow: MeshInstance3D, width_scale: float, opacity: float, screen_cap: float) -> void:
	glow.visible = width_scale > 0.0 and opacity > 0.0
	var material := glow.material_override as ShaderMaterial
	material.set_shader_parameter("width_scale", width_scale)
	material.set_shader_parameter("pass_opacity", opacity)
	material.set_shader_parameter("screen_cap", screen_cap)


## A half-width of `half_width_m` at `depth_m` in front of a camera whose
## projection's [1][1] is `projection_y`, capped to `screen_cap` of the
## screen's height (0: uncapped): the shader's cap.
static func capped_half_width(half_width_m: float, depth_m: float, projection_y: float, screen_cap: float) -> float:
	if screen_cap <= 0.0:
		return half_width_m
	return minf(half_width_m, screen_cap * 2.0 * maxf(depth_m, 0.01) / projection_y)
