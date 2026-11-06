// The sand slash trail's ribbon (MageModel, StaffTrail; playtest ruling 7):
// sand-gold, grainy, and dissolving as it ages rather than fading evenly, so
// it reads as sand blown off the staff. UV.x runs along the staff head's path
// (metres, fixed to the ribbon), UV.y across it (0 at the head, 1 down the
// shaft); UV2.x is the age fade (1 newest, 0 gone); COLOR carries the colour
// and the opacity. Textures: Kenney Particle Pack (CC0), smoke for the grain
// and a trace streak for the slash's lines.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D grain_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D streak_tex : filter_linear_mipmap, repeat_disable;
// How many grain patches per metre of the head's path.
uniform float grain_per_m = 1.6;
// How soft the dissolving edge is (0: hard specks, 0.5: an even fade).
uniform float dissolve_soft = 0.18;
// How bright the sand is drawn (feel page [trail] glow; 1 = its colour).
uniform float glow = 1.0;

varying float fade;

void vertex() {
	fade = UV2.x;
}

void fragment() {
	// The middle of the smoke puff (its edges are empty), tiled along the path.
	vec2 g = vec2(0.2 + 0.6 * fract(UV.x * grain_per_m), 0.2 + 0.6 * UV.y);
	float grain = texture(grain_tex, g).a;
	// The streak's bright band runs along the ribbon, its wiggle along the path.
	float streak = texture(streak_tex, vec2(0.25 + 0.5 * UV.y, fract(UV.x * 0.8))).a;
	float density = clamp(0.55 * grain + 0.45 * streak + 0.35 * (1.0 - UV.y), 0.0, 1.0);
	// Dissolve: the newest ribbon is whole; as it ages only the densest sand stays.
	float keep = smoothstep(1.0 - fade - dissolve_soft, 1.0 - fade + dissolve_soft, density);
	ALBEDO = COLOR.rgb * (0.8 + 0.35 * grain) * glow;
	ALPHA = COLOR.a * keep;
}
