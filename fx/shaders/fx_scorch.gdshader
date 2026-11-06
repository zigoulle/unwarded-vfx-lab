// The ground marks' scorch (FxGroundMarks; VFX lab ticket 05): a dark burn
// laid on the ground through the ground seam (SurfaceMesh), its mesh in the
// frame at the impact's ground point, so its flat offset from the middle is
// the vertex's x and z there. Charred to a ragged edge (hashed by bearing
// with the cast's seed), its middle tinted by the effect while it glows.
// No clock of its own: `fade` and `glow` come from the effect's time.
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://fx/shaders/fx_noise.gdshaderinc"

uniform float radius = 1.0;
uniform float seed = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform vec4 char_colour : source_color = vec4(0.04, 0.03, 0.03, 1.0);
uniform vec4 tint : source_color = vec4(0.3, 0.6, 1.0, 1.0);

varying vec2 flat_at;

void vertex() {
	flat_at = VERTEX.xz;
}

void fragment() {
	float r = length(flat_at) / max(radius, 0.001);
	float bearing = atan(flat_at.y, flat_at.x) / 6.2831853 + 0.5;
	float cell = floor(bearing * 18.0);
	float ragged = mix(hash11(cell + seed), hash11(cell + 1.0 + seed), fract(bearing * 18.0));
	float edge = 0.7 + 0.3 * ragged;
	float burn = 1.0 - smoothstep(edge * 0.55, edge, r);
	ALBEDO = mix(char_colour.rgb, tint.rgb, glow * (1.0 - smoothstep(0.0, 0.6, r)));
	ALPHA = burn * fade * 0.9;
}
