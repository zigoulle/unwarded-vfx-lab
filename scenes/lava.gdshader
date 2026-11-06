// Flowing lava: bright orange-yellow molten rock streaked with red bands,
// carrying a few dark cooling crust plates with glowing edges, all drifting
// round the arena (flow-mapped, two phases blended so it never snaps).
// Unlit and emissive so it glows (and blooms) whatever the light.
// The surface's up (a per-zone uniform, ticket 08): on the level ground
// (`sphere_radius` 0) it flows on the world floor round the arena's centre;
// on a sphere (`sphere_radius` round `sphere_centre`: the lava ball's
// molten sky, lava on the planet) there is no one flat plane to flow in, so
// it is mapped three ways (triplanar on the position from the centre; the
// gravity spike's sky), each way only where it shows.
shader_type spatial;
render_mode unshaded;

// The game's seconds (GameClock): holds while a solo pause holds the tree.
global uniform float game_time;

uniform vec3 crust : source_color = vec3(0.16, 0.05, 0.05);
uniform vec3 deep : source_color = vec3(0.75, 0.13, 0.08);
uniform vec3 hot : source_color = vec3(0.95, 0.40, 0.10);
uniform vec3 white_hot : source_color = vec3(1.0, 0.72, 0.28);
uniform float scale_m = 6.0;
// Metres per second the surface drifts round the arena's centre.
uniform float flow_speed = 0.6;
uniform float brightness = 1.6;
// Share of the plates that have cooled to dark crust.
uniform float crust_amount = 0.2;
// Within this radius of the centre the flow turns to one steady direction,
// so a round pit centred there has no whirl at its middle (0 = none).
uniform float still_core_m = 0.0;
// The lava sea's bottomless look (volcano-climb ticket 07; 0 none): between
// the bright patches the surface turns a dark glowing skin over a deeper
// layer seen through it with parallax (shifting with the view, deeper than
// the surface), so the sea shows no floor, unlike the wadeable lava.
uniform float abyss = 0.0;
// How deep the layer under the skin looks (m).
uniform float abyss_depth_m = 6.0;
// The light scenery detail (GraphicsSettings, volcano-climb ticket 14): the
// layer under the skin from one noise instead of five (the same parallax,
// a plainer deep layer).
uniform bool light_scenery = false;
uniform float sphere_radius = 0.0;
uniform vec3 sphere_centre = vec3(0.0);

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

float fbm(vec2 p) {
	float total = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		total += amp * value_noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		amp *= 0.5;
	}
	return total;
}

// Crust plates: x = distance to the nearest Voronoi border, y = cell random.
vec2 plates(vec2 p) {
	vec2 ip = floor(p);
	vec2 fp = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 h = hash2(ip + g);
			vec2 r = g + h - fp;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = h.y;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec2(sqrt(d2) - sqrt(d1), id);
}

vec3 surface(vec2 p, vec2 flow_dir) {
	// Bands stretched along the flow.
	vec2 across = vec2(-flow_dir.y, flow_dir.x);
	vec2 q = vec2(dot(p, flow_dir) * 0.35, dot(p, across));
	vec2 warp = vec2(fbm(p * 0.7), fbm(p * 0.7 + 5.2));
	float n = fbm(q * 0.8 + warp * 1.5);
	vec3 color = mix(deep, hot, smoothstep(0.32, 0.55, n));
	color = mix(color, white_hot, smoothstep(0.55, 0.75, n));
	vec2 plate = plates(p * 0.9 + warp);
	float is_crust = step(1.0 - crust_amount, plate.y) * smoothstep(0.08, 0.2, plate.x);
	float rim = step(1.0 - crust_amount, plate.y) * (1.0 - smoothstep(0.0, 0.12, plate.x));
	color = mix(color, crust, is_crust * 0.9);
	color = mix(color, white_hot * 1.2, rim * 0.6);
	return color;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// The flow at `w` (metres on a plane) heading `flow_dir`: two phases
// blended so it never snaps.
vec3 flowing(vec2 w, vec2 flow_dir) {
	vec2 p = w / scale_m;
	float t = game_time * flow_speed / scale_m;
	float ph0 = fract(t);
	float ph1 = fract(t + 0.5);
	float blend = abs(ph0 * 2.0 - 1.0);
	float period = 1.0;
	vec3 a = surface(p - flow_dir * ph0 * period + vec2(0.0, 0.0), flow_dir);
	vec3 b = surface(p - flow_dir * ph1 * period + vec2(3.7, 1.3), flow_dir);
	return mix(a, b, blend);
}

// On a sphere: three planar flows weighted by how squarely each faces the
// point's direction from the centre (a weight under 1% is skipped).
vec3 on_sphere(vec3 q) {
	vec3 weights = pow(abs(normalize(q)), vec3(4.0));
	weights /= weights.x + weights.y + weights.z;
	vec3 color = vec3(0.0);
	if (weights.x > 0.01) {
		color += flowing(q.yz, vec2(0.6, 0.8)) * weights.x;
	}
	if (weights.y > 0.01) {
		color += flowing(q.xz + vec2(11.0, 3.0), vec2(-0.8, 0.6)) * weights.y;
	}
	if (weights.z > 0.01) {
		color += flowing(q.xy + vec2(-7.0, 5.0), vec2(0.7, -0.7)) * weights.z;
	}
	return color;
}

void fragment() {
	vec3 color;
	if (sphere_radius > 0.0) {
		color = on_sphere(world_pos - sphere_centre);
	} else {
		vec2 w = world_pos.xz;
		float r = max(length(w), 0.001);
		vec2 flow_dir = normalize(vec2(-w.y, w.x) / r + 0.25 * w / r);
		if (still_core_m > 0.0) {
			flow_dir = normalize(mix(vec2(0.6, 0.8), flow_dir, smoothstep(0.3 * still_core_m, still_core_m, r)) + 0.0001);
		}
		color = flowing(w, flow_dir);
		if (abyss > 0.0) {
			vec3 to_eye = normalize(CAMERA_POSITION_WORLD - world_pos);
			vec2 par = to_eye.xz / max(to_eye.y, 0.25) * abyss_depth_m;
			vec3 below;
			if (light_scenery) {
				float under = value_noise((w - par) / (scale_m * 1.6) * 2.0 + vec2(game_time * 0.03, 0.0));
				below = crust * 0.6 + deep * 0.55 * smoothstep(0.35, 0.8, under);
			} else {
				float under = fbm((w - par) / (scale_m * 1.6) + vec2(game_time * 0.015, 0.0));
				float far_under = value_noise((w - par * 2.2) / (scale_m * 3.0) - vec2(0.0, game_time * 0.01));
				below = crust * 0.6 + deep * (0.45 * smoothstep(0.42, 0.72, under) + 0.2 * smoothstep(0.5, 0.8, far_under));
			}
			float skin = smoothstep(0.3, 0.75, dot(color, vec3(0.333)));
			color = mix(color, below, abyss * (1.0 - skin));
		}
	}
	ALBEDO = color;
	EMISSION = color * brightness;
}
