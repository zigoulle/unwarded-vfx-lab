// The ribbon block (FxRibbon; VFX lab ticket 04): a static strip whose
// vertices carry only (along, edge) in UV and their strand in UV2.x; the
// whole bolt is shaped here, in the vertex shader, from its uniforms, so a
// knob moved in the lab re-shapes a bolt already drawn, paused too.
//
//   1. the axis: a line from `origin` to `target`, bowed by `sag`;
//   2. the fan: each strand set off the axis in the plane across it, from
//      `spread_near` at the origin to `spread` at the target, rolled by `twist`;
//   3. the kinks: octaves of LINEAR value noise (sharp corners);
//   4. the restrikes: `restrike` times a second every strand snaps onto a new
//      shape (a new seed); the crawl slides it in between.
// Bent into a ring (ticket 06): with `ring_radius` over 0 the axis is an
// arc of that radius round `origin`, level with it (round `ring_up`), from
// `ring_start` on for `ring_span` radians; the fan and kinks work out from
// the ring and up. 0: the line.
// The strip then turns to face the camera. The glow pass (FxGlow) draws the
// same strip wider with the halo profile, its width capped to a share of
// the screen (`screen_cap`) so a close-up bolt can't flood it.
//
// The maths is ported from LinearAbiltyCastingThreeJS by mohamedachrefelouafi
// (src/materials/LightningMaterial.js, MIT licence; THIRD_PARTY_LICENSES.md).
// Its clock is the effect's own time, `fx_t` (the seconds since the cast, as
// the lab's clock or the move's ticks give it), never the engine's: it holds
// with a pause and steps with a frame step. The CPU twin is FxRibbon.point.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, world_vertex_coords;

#include "res://fx/shaders/fx_ribbon_shape.gdshaderinc"

void fragment() {
	float tip = max(tip_length, 1e-3);
	// Ahead of the strike front there is no bolt yet: clipped, never scaled,
	// so its shape holds while the front runs.
	float drawn = 1.0 - smoothstep(progress - tip, progress, v_t);
	if (drawn <= 0.002) {
		discard;
	}
	float v = clamp(abs(v_side), 0.0, 1.0);
	vec3 colour;
	float alpha;
	if (glow_pass) {
		float profile = pow(1.0 - v, max(glow_falloff, 0.05));
		colour = mix(colour_halo.rgb, colour_outer.rgb, profile);
		alpha = profile;
	} else {
		float profile = pow(1.0 - v, max(core_sharp, 0.05));
		colour = mix(colour_outer.rgb, colour_inner.rgb, smoothstep(0.0, 0.5, profile));
		colour = mix(colour, colour_core.rgb, smoothstep(0.45, 1.0, profile));
		alpha = profile;
	}
	// The leading edge, where the air breaks down.
	colour += colour_core.rgb * smoothstep(progress - tip * 2.0, progress, v_t) * tip_glow;
	// Quantised: lightning stutters between brightnesses, it doesn't breathe.
	float flick = 1.0 - flicker * hash11(floor(fx_t * flicker_speed) + seed);
	alpha *= drawn * flick * v_flash * fade * pass_opacity * opacity;
	alpha *= mix(1.0, clamp(branch_dim, 0.0, 1.0), v_strand);
	if (alpha < 0.003) {
		discard;
	}
	ALBEDO = colour * glow;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
