// The flame jet's dark pieces (FxFlameJet; fx_flame_jet.gdshaderinc places
// them): the scorched band burnt into the ground along the hit's true
// width, and the dark smoke curling up off the flames. Blended (see-through
// dark), unshaded, drawn under the light pass.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://fx/shaders/fx_flame_jet.gdshaderinc"

uniform vec3 scorch_colour : source_color = vec3(0.05, 0.025, 0.015);
uniform vec3 smoke_colour : source_color = vec3(0.09, 0.07, 0.06);
uniform vec3 edge_colour : source_color = vec3(0.85, 0.18, 0.03);
uniform float scorch = 0.6;
uniform float smoke_opacity = 0.45;

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
	if (v_kind == KIND_SCORCH) {
		float across = abs(UV.x * 2.0 - 1.0);
		float n = jet_noise(vec2(v_along * length_m * 2.0, UV.x * 4.0 + v_seed * 3.0));
		ALBEDO = scorch_colour;
		ALPHA = scorch * (1.0 - smoothstep(0.88, 1.0, across)) * (0.7 + 0.3 * n) * fade;
	} else {
		float n = jet_noise(UV * 3.0 + vec2(v_seed * 11.0, -fx_t * 0.4));
		float r = length(UV * 2.0 - 1.0) + (n - 0.5) * 0.35;
		// Lit warm from the flames under it while young, grey as it rises.
		ALBEDO = mix(smoke_colour + edge_colour * 0.25, smoke_colour, v_life);
		ALPHA = (1.0 - smoothstep(0.2, 1.0, r)) * sin(3.14159 * v_life) * smoke_opacity * fade;
	}
}
