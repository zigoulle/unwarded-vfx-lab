// Heat shimmer over the lava (zone SOP 6d): a see-through band standing at a
// lava edge that bends what is behind it with a slow rising wobble, plus a
// faint warm haze. Reads the screen behind it (one copy per frame), so it is
// drawn at high quality only.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// The game's seconds (GameClock): holds while a solo pause holds the tree.
global uniform float game_time;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.006;
uniform vec3 haze : source_color = vec3(1.0, 0.35, 0.08);
uniform float haze_amount = 0.06;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	// UV.y runs 0 at the band's top to 1 at its foot: strongest low down.
	float fade = smoothstep(0.0, 0.6, UV.y) * (1.0 - smoothstep(0.85, 1.0, UV.y));
	vec2 p = vec2(UV.x * 120.0, UV.y * 6.0 + game_time * 1.3);
	vec2 wobble = vec2(value_noise(p) - 0.5, value_noise(p + 17.0) - 0.5) * strength * fade;
	vec3 behind = textureLod(screen, SCREEN_UV + wobble, 0.0).rgb;
	ALBEDO = behind + haze * haze_amount * fade;
}
