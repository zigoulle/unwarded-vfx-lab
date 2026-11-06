// The fire puddle's pool (FxFirePuddle; polish step 9, P-O 2026-10-29): a
// patch of burning lava laid flat on the floor, as wide as the boots' patch
// burns. A molten middle (the core colour) cooling to the edge colour, a
// ragged licking rim, dark crust drifting over it. Drawn on a 2 x 2 plane
// (UV 0..1 across it) scaled to the drawn radius. No clock of its own:
// `since` is the effect's seconds, `fade` its brightness now (0 gone), so
// a pause, a frame step back and every peer draw the same.
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://fx/shaders/fx_noise.gdshaderinc"

uniform float since = 0.0;
uniform float seed = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float bright = 0.8;
uniform float crust : hint_range(0.0, 1.0) = 0.4;
uniform float flicker = 1.0;
uniform float edge_soft : hint_range(0.0, 1.0) = 0.25;
uniform float opacity : hint_range(0.0, 1.0) = 0.9;
uniform vec4 core_colour : source_color = vec4(1.0, 0.55, 0.14, 1.0);
uniform vec4 edge_colour : source_color = vec4(0.8, 0.16, 0.03, 1.0);

// Light pours off the molten middle this much brighter than its colour.
const float HOT = 1.8;
const vec3 CRUST = vec3(0.07, 0.035, 0.025);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float t = since * flicker;
	float s = fract(seed * 0.000173) * 97.0;
	// The rim licks in and out round its bearing.
	float lick = snoise(vec3(normalize(p + 1e-4) * 1.7, s + t * 0.6)) * 0.5 + 0.5;
	float edge = 1.0 - edge_soft * lick;
	float mask = 1.0 - smoothstep(edge * (1.0 - 0.6 * edge_soft) - 0.02, edge, r);
	// Molten churn, hottest in the middle.
	float churn = fbm3(vec3(p * 2.6 + s, t * 0.45)) * 0.5 + 0.5;
	float heat = clamp(0.35 + 0.9 * churn - 0.55 * r, 0.0, 1.0);
	vec3 colour = mix(edge_colour.rgb, core_colour.rgb * HOT, heat) * bright;
	// Dark crust floating on it, thinning where it is hottest.
	float crusted = smoothstep(0.52, 0.7, snoise01(vec3(p * 3.8 + s * 1.7, t * 0.12)));
	colour = mix(colour, CRUST, crusted * crust * (1.0 - 0.5 * heat));
	ALBEDO = colour;
	ALPHA = clamp(mask * opacity * fade, 0.0, 1.0);
}
