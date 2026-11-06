// The glow between the floor's slabs: a plane just under them, showing
// through the gaps. Dim in the middle of the floor, hot toward its lava edge.
shader_type spatial;
render_mode unshaded;

// The game's seconds (GameClock): holds while a solo pause holds the tree.
global uniform float game_time;

uniform vec3 cool : source_color = vec3(0.35, 0.06, 0.03);
uniform vec3 hot : source_color = vec3(1.0, 0.42, 0.08);
uniform float half_size_m = 20.0;
uniform float hot_band_m = 6.0;
// The ring arena (zone SOP 6b): when ring_outer_m is above 0 the floor is
// a ring between these radii, hot toward both its lava edges.
uniform float ring_inner_m = 0.0;
uniform float ring_outer_m = 0.0;
uniform float brightness = 1.6;
// How much the slow warm patches heat the middle of the floor.
uniform float patches = 1.0;

varying vec3 world_pos;

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float out_ = max(abs(p.x), abs(p.y));
	float edge = smoothstep(half_size_m - hot_band_m, half_size_m, out_);
	if (ring_outer_m > 0.0) {
		float r = length(p);
		edge = 1.0 - smoothstep(0.0, hot_band_m, min(r - ring_inner_m, ring_outer_m - r));
	}
	float patch = smoothstep(0.4, 0.9, value_noise(p * 0.15 + game_time * 0.05));
	float heat = clamp(edge + patch * 0.5 * patches, 0.0, 1.0);
	vec3 color = mix(cool * 0.4, hot, heat);
	ALBEDO = color;
	EMISSION = color * brightness * (0.25 + heat);
}
