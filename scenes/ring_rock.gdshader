// The ring arena's rock (zone SOP 6b: cave walls, bridges, pillars, vent
// craters; RockMesh pieces): rock.gdshader's flat-shaded facets in dark
// purple-brown, lit from below by the lava, plus
// - dark cracks (no glow: a pillar is not dangerous) spreading over the
//   faces with `crack_amount` (a pillar's slams);
// - `opacity` below 1 dithers the rock away (a pillar hiding a player)
//   while it stays in the opaque pass (no sorting against the characters);
// - within `near_fade_m` of the camera the rock dithers away too (the camera
//   may swing behind the cave wall over the bridges);
// - above `dark_above_y` the rock sinks into darkness (the implied ceiling,
//   ruling Q2).
// Vertex COLOR: r = shade (dark .. light), g = lava glow on the face.
// The surface's up (a per-zone uniform, ticket 08): on the level ground
// (`sphere_radius` 0) height is world y and up world +Y; on the lava ball
// height is the distance out from the planet (`sphere_radius` round
// `sphere_centre`) and up points away from its core, so `lava_y` and
// `dark_above_y` are heights over the surface there.
shader_type spatial;

uniform vec3 rock_dark : source_color = vec3(0.09, 0.065, 0.08);
uniform vec3 rock_light : source_color = vec3(0.34, 0.25, 0.27);
uniform vec3 glow_color : source_color = vec3(1.0, 0.36, 0.08);
uniform vec3 crack_dark : source_color = vec3(0.02, 0.012, 0.012);
uniform float lava_y = -0.7;
uniform float glow_height_m = 0.8;
uniform float glow = 1.2;
uniform float rim = 0.25;
uniform float crack_amount = 0.0;
uniform float crack_cell_m = 0.55;
uniform float opacity = 1.0;
uniform float near_fade_m = 0.0;
uniform float dark_above_y = 1000.0;
uniform float dark_band_m = 4.0;
// The lava's light on the rock (the room's only light, ruling Q14): faces
// turned toward the nearer lava (the pit inside `ring_inner_m`, the outer
// lava past `ring_outer_m`) take its warm light, fading over `bounce_m`
// from the lava's edge. 0 = none.
uniform float bounce = 0.0;
uniform float bounce_m = 7.0;
uniform float ring_inner_m = 6.67;
uniform float ring_outer_m = 20.0;
// Past the ring (ticket 12): when above 0, the lava lies all round at
// lava_y (the islands, the connector's stream), so faces turned sideways or
// down take its light, fading over `bounce_m` up from it.
uniform float lava_all_round = 0.0;
uniform float sphere_radius = 0.0;
uniform vec3 sphere_centre = vec3(0.0);

varying vec3 world_pos;

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

// Distance to the nearest 3D Voronoi border: thin cracks over any face.
float crack_edge(vec3 p) {
	vec3 ip = floor(p);
	vec3 fp = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int k = -1; k <= 1; k++) {
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec3 g = vec3(float(i), float(j), float(k));
				vec3 r = g + hash3(ip + g) - fp;
				float d = dot(r, r);
				if (d < d1) {
					d2 = d1;
					d1 = d;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return sqrt(d2) - sqrt(d1);
}

// A 4x4 ordered dither threshold for the screen pixel.
float bayer(vec2 pixel) {
	int x = int(mod(pixel.x, 4.0));
	int y = int(mod(pixel.y, 4.0));
	int index = x + y * 4;
	int table[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(table[index]) + 0.5) / 16.0;
}

// Height over the ground and its up at `p` (world space).
float ground_height(vec3 p) {
	return sphere_radius > 0.0 ? length(p - sphere_centre) - sphere_radius : p.y;
}

vec3 ground_up(vec3 p) {
	return sphere_radius > 0.0 ? normalize(p - sphere_centre) : vec3(0.0, 1.0, 0.0);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float keep = opacity;
	if (near_fade_m > 0.0) {
		keep *= smoothstep(near_fade_m * 0.5, near_fade_m, distance(world_pos, CAMERA_POSITION_WORLD));
	}
	if (keep < 0.999 && keep <= bayer(FRAGCOORD.xy)) {
		discard;
	}
	vec3 base = mix(rock_dark, rock_light, COLOR.r);
	if (crack_amount > 0.0) {
		float edge = crack_edge(world_pos / crack_cell_m);
		// More of the borders show as the amount grows; each is a thin dark line.
		float shown = step(hash3(floor(world_pos / (crack_cell_m * 2.5)) + 7.0).x, crack_amount);
		float crack = (1.0 - smoothstep(0.03, 0.09, edge)) * shown;
		base = mix(base, crack_dark, crack);
	}
	float height = ground_height(world_pos);
	float dark = smoothstep(dark_above_y, dark_above_y + dark_band_m, height);
	ALBEDO = base * (1.0 - dark);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	float above = max(height - lava_y, 0.0);
	float near_lava = exp(-above / glow_height_m);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	float facing_down = clamp(-dot((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz, ground_up(world_pos)), 0.0, 1.0);
	vec3 lit = vec3(0.0);
	if (bounce > 0.0) {
		vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		float r = max(length(world_pos.xz), 0.001);
		vec2 out_dir = world_pos.xz / r;
		float to_pit = max(r - ring_inner_m, 0.0);
		float to_outer = max(ring_outer_m - r, 0.0);
		// Toward the nearer lava, and a little up from below it.
		vec2 toward = to_pit < to_outer ? -out_dir : out_dir;
		float near = exp(-min(to_pit, to_outer) / bounce_m);
		float facing = max(dot(n, normalize(vec3(toward.x, -0.35, toward.y))), 0.0);
		if (lava_all_round > 0.0) {
			near = exp(-max(world_pos.y - lava_y, 0.0) / bounce_m) * lava_all_round;
			facing = clamp(1.0 - n.y, 0.0, 1.2) * 0.8;
		}
		lit = glow_color * base * bounce * near * (0.06 + facing * facing);
	}
	EMISSION = (glow_color * (glow * near_lava * near_lava * (0.5 + 0.5 * facing_down)
		+ COLOR.g * 0.6 * near_lava + rim * fres * (0.15 + near_lava)) + lit) * (1.0 - dark);
}
