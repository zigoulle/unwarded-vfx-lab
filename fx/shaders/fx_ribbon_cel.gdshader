// The ribbon in flat cel tones (FxRibbon.CEL_SHADER; VFX lab ticket 07):
// the same strip, shaped by the same vertex shader (fx_ribbon_shape), drawn
// as sand from target_sand-tornado_v1: hard-edged bands in flat tones, with
// no glow (P-O's ruling for sand, spec story 34). Opaque: it covers what is
// behind it and never adds light; its opacity is a screen-door dither, so
// it costs no transparent layer and needs no sorting.
//
//   1. the band: it tapers to a hard point at both ends, and its strike
//      front (`progress`) cuts it clean while it forms;
//   2. the tones: the light one (`colour_core`) down its middle, its
//      `cel_split` of the width; the mid one (`colour_inner`) out to its
//      edges;
//   3. the streaks: `streaks` dark ones (`colour_outer`) along each band,
//      sliding `streak_speed` a second, hard-edged, covering `streak_share`.
// Its clock is the effect's own time, `fx_t`, never TIME.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_opaque, shadows_disabled, fog_disabled, world_vertex_coords;

#include "res://fx/shaders/fx_ribbon_shape.gdshaderinc"

uniform float cel_split = 0.45;
uniform float streaks = 6.0;
uniform float streak_speed = 1.5;
uniform float streak_share = 0.35;
// The share of the band's length over which each end tapers to its point.
uniform float end_taper = 0.15;

// A 4x4 ordered dither, 0..1: the opacity's screen door.
float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int index = i.x + i.y * 4;
	const float M[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0,
		5.0);
	return (M[index] + 0.5) / 16.0;
}

void fragment() {
	if (v_t > progress) {
		discard;
	}
	float v = clamp(abs(v_side), 0.0, 1.0);
	float taper = max(end_taper, 1e-3);
	float ends = min(min(v_t / taper, (1.0 - v_t) / taper), 1.0);
	if (v > ends) {
		discard;
	}
	vec3 colour = v < cel_split ? colour_core.rgb : colour_inner.rgb;
	float streak = vnoise(v_t * streaks - fx_t * streak_speed, seed + v_strand * 17.0) * 0.5 + 0.5;
	if (streak < streak_share) {
		colour = colour_outer.rgb;
	}
	float alpha = opacity * pass_opacity * fade * mix(1.0, clamp(branch_dim, 0.0, 1.0), v_strand);
	if (alpha < bayer4(FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = colour;
}
