// The flame jet's shared maths (FxFlameJet; its two passes:
// fx_flame_jet_add.gdshader, the light, and fx_flame_jet_mix.gdshader, the
// scorch and smoke). One mesh, built once per count of its pieces, laid
// along -Z from its node: every vertex carries its piece (CUSTOM0.x: KIND_*),
// its seeds and where along the jet it sits (VERTEX.z, 0 at her head .. 1
// at the jet's end); the vertex shader places it from the uniforms each
// frame (the jet's length, the hit's half width, the ball's curve, the
// clock), so a frame never builds geometry. Every piece stays inside the
// hit strip: `reach_m` is half the hit's width and no ground piece is
// wider than it (P-O 2026-10-29: the look never wider than the real hit).
// Drawn from (knobs, seed, time) alone: any frame in any order.

#define KIND_LINE 0.0
#define KIND_FLAME 1.0
#define KIND_EMBER 2.0
#define KIND_SCORCH 3.0
#define KIND_SMOKE 4.0

// Per jet (one beam, one instance uniform: set in one call): its length
// (m), how far it has formed from her head (0..1 of it), its fade (1 full,
// 0 gone) and its seed.
instance uniform vec4 beam : instance_index(0) = vec4(10.0, 1.0, 1.0, 0.0);
#define length_m beam.x
#define grow beam.y
#define fade beam.z
#define seed_off beam.w

uniform float fx_t = 0.0;
// Half the hit's width (m) and the ball's radius under it (0: level ground).
uniform float reach_m = 0.6;
uniform float ball_r = 0.0;
uniform float size = 1.0;
// The ground line's half width, the flames' at her head and at the end
// (shares of reach_m, at most 1); the flames' heights there (m).
uniform float line_x = 1.0;
uniform float root_x = 0.3;
uniform float flame_x = 0.85;
uniform float root_flame_m = 0.6;
uniform float flame_m = 1.6;
uniform float flicker = 2.5;
uniform float ember_rise_m = 2.5;
uniform float ember_life_s = 1.2;
uniform float smoke_rise_m = 3.0;
uniform float smoke_life_s = 2.6;

varying float v_kind;
varying float v_along;
varying float v_seed;
varying float v_life;

float jet_hash(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

float jet_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = jet_hash(i.x + i.y * 57.0);
	float b = jet_hash(i.x + 1.0 + i.y * 57.0);
	float c = jet_hash(i.x + (i.y + 1.0) * 57.0);
	float d = jet_hash(i.x + 1.0 + (i.y + 1.0) * 57.0);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// The flames' half width (m) `along` the jet: from root_x to flame_x of the reach.
float jet_half_width(float along) {
	return reach_m * min(mix(root_x, flame_x, along), 1.0);
}

// The flat frame's point (x across, y up, z = -metres along) laid on the
// ball (curving down round its centre, ball_r under the origin).
vec3 jet_bend(vec3 p) {
	if (ball_r <= 0.0) {
		return p;
	}
	float a = -p.z / ball_r;
	float r = ball_r + p.y;
	return vec3(p.x, r * cos(a) - ball_r, -r * sin(a));
}

vec3 jet_up(float z) {
	if (ball_r <= 0.0) {
		return vec3(0.0, 1.0, 0.0);
	}
	float a = -z / ball_r;
	return vec3(0.0, cos(a), -sin(a));
}

// Places one vertex; what its fragment needs comes back in `piece`
// (kind, along, seed, life: the vertex function hands them to the varyings).
void jet_vertex(inout vec3 vertex, vec4 custom, mat4 modelview, mat4 projection, out vec4 position, out bool placed,
		out vec4 piece) {
	float kind = custom.x;
	float seed = fract(custom.y + seed_off);
	float place = custom.z;
	float along = vertex.z;
	float d = along * length_m;
	float life = 1.0;
	piece = vec4(kind, along, seed, life);
	placed = false;
	position = vec4(0.0);
	if (kind == KIND_LINE || kind == KIND_SCORCH) {
		float lift = kind == KIND_LINE ? 0.05 : 0.035;
		vertex = jet_bend(vec3(vertex.x * reach_m * min(line_x, 1.0), lift, -d));
		return;
	}
	// A card: its centre on the jet, then turned to the camera.
	float half_w = jet_half_width(along) * size;
	vec3 centre;
	vec2 extent;
	bool upright = false;
	if (kind == KIND_FLAME) {
		float card = half_w * 0.6;
		float x0 = (place * 2.0 - 1.0) * max(half_w - card, 0.0);
		float flick = 0.72 + 0.28 * sin(fx_t * flicker * 6.2831853 * (0.6 + seed) + seed * 40.0);
		float tall = mix(root_flame_m, flame_m, along) * size * flick * (0.75 + 0.5 * custom.w);
		centre = vec3(x0, 0.0, -d);
		extent = vec2(card, tall);
		upright = true;
	} else if (kind == KIND_EMBER) {
		float phase = fract(fx_t / max(ember_life_s, 0.05) + seed);
		life = 1.0 - phase;
		float x0 = (place * 2.0 - 1.0) * half_w * 0.8;
		float drift = sin(phase * 5.0 + seed * 30.0) * 0.25 * size;
		centre = vec3(x0 + drift, (0.3 + phase * ember_rise_m) * size, -d + cos(phase * 4.0 + seed * 9.0) * 0.3);
		extent = vec2(0.06, 0.06) * size * (0.6 + 0.4 * life);
	} else {
		float phase = fract(fx_t / max(smoke_life_s, 0.05) + seed);
		life = phase;
		float tip = mix(root_flame_m, flame_m, along) * size;
		float curl = sin(phase * 3.5 + seed * 20.0) * 0.4 * size;
		float grow_r = (0.45 + phase * 0.9) * size;
		centre = vec3((place * 2.0 - 1.0) * half_w * 0.5 + curl, tip * 0.8 + phase * smoke_rise_m * size, -d);
		extent = vec2(grow_r, grow_r);
	}
	vec3 at = jet_bend(centre);
	vec4 c = modelview * vec4(at, 1.0);
	vec3 up_v = normalize((modelview * vec4(jet_up(centre.z), 0.0)).xyz);
	vec3 right_v;
	if (upright) {
		vec3 to_cam = normalize(-c.xyz);
		right_v = cross(up_v, to_cam);
		right_v = length(right_v) > 0.001 ? normalize(right_v) : vec3(1.0, 0.0, 0.0);
		c.xyz += right_v * vertex.x * extent.x + up_v * vertex.y * extent.y;
	} else {
		c.xyz += vec3(vertex.x, vertex.y * 2.0 - 1.0, 0.0) * extent.x;
	}
	position = projection * c;
	placed = true;
	piece.w = life;
}
