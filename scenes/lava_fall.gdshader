// A lava fall: a sheet (UV x across, UV y from the lip down) of bright
// molten rock streaming down, streaks racing downward, ragged dark-red
// edges, white-hot at the lip. Unlit and emissive.
shader_type spatial;
render_mode unshaded, cull_disabled;

// The game's seconds (GameClock): holds while a solo pause holds the tree.
global uniform float game_time;

uniform vec3 edge_color : source_color = vec3(0.75, 0.12, 0.05);
uniform vec3 hot : source_color = vec3(1.0, 0.45, 0.08);
uniform vec3 white_hot : source_color = vec3(1.0, 0.82, 0.35);
// Sheet lengths per second the streaks fall.
uniform float speed = 0.5;
uniform float brightness = 2.2;

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
	float x = UV.x;
	float y = UV.y;
	float streak = value_noise(vec2(x * 14.0, y * 2.0 - game_time * speed * 6.0)) * 0.6
		+ value_noise(vec2(x * 32.0, y * 4.0 - game_time * speed * 9.0)) * 0.4;
	float centre = 1.0 - abs(x * 2.0 - 1.0);
	float ragged = value_noise(vec2(x * 6.0, y * 8.0 - game_time * speed * 6.0));
	if (centre < 0.08 + 0.25 * ragged * (0.3 + y)) {
		discard;
	}
	vec3 color = mix(edge_color, hot, smoothstep(0.1, 0.6, centre * (0.6 + streak * 0.8)));
	color = mix(color, white_hot, smoothstep(0.55, 0.85, streak) * centre);
	color = mix(color, white_hot, (1.0 - smoothstep(0.0, 0.12, y)) * 0.8);
	ALBEDO = color;
	EMISSION = color * brightness;
}
