// The flame jet's light (FxFlameJet; fx_flame_jet.gdshaderinc places it):
// the glowing ground line (a hot core down its middle and a thin bright
// edge on the hit's true width), the flame tongues (rough, flickering,
// licking up from the ground, wider and taller away from her head) and the
// embers flying off. Additive, unshaded, one pass.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://fx/shaders/fx_flame_jet.gdshaderinc"

uniform vec3 core_colour : source_color = vec3(1.0, 0.62, 0.18);
uniform vec3 edge_colour : source_color = vec3(0.85, 0.18, 0.03);
uniform float energy = 1.6;
uniform float opacity = 0.9;
uniform float line_heat = 1.2;

void vertex() {
	bool placed;
	vec4 pos;
	vec4 piece;
	jet_vertex(VERTEX, CUSTOM0, MODELVIEW_MATRIX, PROJECTION_MATRIX, pos, placed, piece);
	v_kind = piece.x;
	v_along = piece.y;
	v_seed = piece.z;
	v_life = piece.w;
	POSITION = placed ? pos : PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	if (v_along > grow) {
		discard;
	}
	vec3 colour;
	float a;
	if (v_kind == KIND_LINE) {
		float across = abs(UV.x * 2.0 - 1.0);
		float n = jet_noise(vec2(v_along * length_m * 1.3, fx_t * 0.9 + v_seed * 7.0));
		float hot = 1.0 - smoothstep(0.0, 0.4, across);
		float rim = smoothstep(0.82, 0.95, across) * (1.0 - smoothstep(0.95, 1.0, across));
		colour = mix(edge_colour, core_colour, hot);
		a = (hot * 0.9 + rim * 0.7 + 0.12) * line_heat * (0.75 + 0.5 * n);
	} else if (v_kind == KIND_FLAME) {
		vec2 uv = UV;
		float n = jet_noise(vec2(uv.x * 3.0 + v_seed * 13.0, uv.y * 2.4 - fx_t * flicker * 1.4));
		float n2 = jet_noise(vec2(uv.x * 7.0 - v_seed * 5.0, uv.y * 5.0 - fx_t * flicker * 2.3));
		float width = pow(max(1.0 - uv.y, 0.0), 0.6) * 0.5;
		float off = abs(uv.x - 0.5) + (n - 0.5) * 0.22 + (n2 - 0.5) * 0.08;
		float shape = 1.0 - smoothstep(width * 0.55, width, off);
		shape *= smoothstep(0.0, 0.3, (1.0 - uv.y) - (n - 0.5) * 0.45);
		float heat = clamp((1.0 - uv.y) * 1.2 * shape, 0.0, 1.0);
		colour = mix(edge_colour, core_colour, heat);
		a = shape * opacity;
	} else {
		float r = length(UV * 2.0 - 1.0);
		colour = mix(core_colour, vec3(1.0, 0.9, 0.6), 0.4);
		a = (1.0 - smoothstep(0.25, 1.0, r)) * v_life * 1.6;
	}
	ALBEDO = colour * energy * a * fade;
}
