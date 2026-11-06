// The fighting floor's basalt slabs (RockMesh slab tops): matte purple-grey
// stone, each slab its own shade (vertex COLOR.r), with faint hairline
// cracks that glow only where the floor is hot (near its lava edge) so
// players and enemies keep their contrast in the middle.
shader_type spatial;

// The game's seconds (GameClock): holds while a solo pause holds the tree.
global uniform float game_time;

uniform vec3 stone_dark : source_color = vec3(0.16, 0.14, 0.20);
uniform vec3 stone_light : source_color = vec3(0.34, 0.30, 0.39);
uniform vec3 crack_color : source_color = vec3(1.0, 0.36, 0.08);
// Half the floor's width: cracks glow more toward this edge.
uniform float half_size_m = 20.0;
uniform float hot_band_m = 5.0;
// The ring arena (zone SOP 6b): when ring_outer_m is above 0 the floor is
// a ring between these radii, and the cracks warm toward both its lava edges.
uniform float ring_inner_m = 0.0;
uniform float ring_outer_m = 0.0;
uniform float crack_cell_m = 1.4;
uniform float glow = 1.0;
// The lit rim (ticket 12, the islands and the connector): faces marked
// with vertex COLOR.g (RockMesh.add_polygon_slabs: slab sides and bevels
// on the shore) take the lava's light, strongest low down by the lava.
uniform float shore_glow = 0.0;
uniform float shore_y = -0.35;

varying vec3 world_pos;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i).x, hash2(i + vec2(1.0, 0.0)).x, u.x),
		mix(hash2(i + vec2(0.0, 1.0)).x, hash2(i + vec2(1.0, 1.0)).x, u.x), u.y);
}

// Distance to the nearest Voronoi border (hairline cracks).
float crack_edge(vec2 p) {
	vec2 ip = floor(p);
	vec2 fp = fract(p);
	float best = 8.0;
	vec2 best_r = vec2(0.0);
	vec2 best_g = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + hash2(ip + g) - fp;
			float d = dot(r, r);
			if (d < best) {
				best = d;
				best_r = r;
				best_g = g;
			}
		}
	}
	float edge = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = best_g + vec2(float(i), float(j));
			vec2 r = g + hash2(ip + g) - fp;
			if (dot(best_r - r, best_r - r) > 0.0001) {
				edge = min(edge, dot(0.5 * (best_r + r), normalize(r - best_r)));
			}
		}
	}
	return edge;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float grain = value_noise(p * 2.3) * 0.5 + value_noise(p * 7.1) * 0.5;
	vec3 stone = mix(stone_dark, stone_light, clamp(COLOR.r + (grain - 0.5) * 0.25, 0.0, 1.0));
	float edge = crack_edge(p / crack_cell_m + vec2(value_noise(p * 0.7), value_noise(p * 0.7 + 9.0)) * 0.6);
	// Only some hairlines show: masked by a slow noise.
	float shown = smoothstep(0.45, 0.65, value_noise(p * 0.35 + 3.0));
	float crack = (1.0 - smoothstep(0.015, 0.04, edge)) * shown;
	float out_ = max(abs(p.x), abs(p.y));
	float hot = smoothstep(half_size_m - hot_band_m, half_size_m, out_);
	if (ring_outer_m > 0.0) {
		float r = length(p);
		hot = 1.0 - smoothstep(0.0, hot_band_m, min(r - ring_inner_m, ring_outer_m - r));
	}
	float pulse = 0.8 + 0.2 * sin(game_time * 1.1 + p.x * 0.3 + p.y * 0.2);
	ALBEDO = mix(stone, stone_dark * 0.35, crack);
	EMISSION = crack_color * glow * crack * mix(0.05, 1.6, hot) * pulse;
	if (shore_glow > 0.0) {
		float low = clamp(world_pos.y / shore_y, 0.0, 1.0);
		EMISSION += crack_color * shore_glow * COLOR.g * mix(0.3, 1.0, low * low) * pulse;
	}
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
}
