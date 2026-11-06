// The trail block (FxTrail; enemy-vfx ticket 01): a stream of soft dots
// shed behind a moving point (the fireball's flames and embers), worked
// out here, in the vertex shader, from its uniforms alone: the CPU sets a
// dozen numbers a frame and touches no instance (perf pass 17: a crowd of
// fireballs worked out on the CPU, a grain at a time, cost ~0.4 ms each).
//
// Instance `slot` of `count` holds one particle at a time: particle
// k = slot + count * n is born at k * life_s / count after the stream began
// (`since` is the seconds since), so `count` are alive at once and each
// slot is reborn every life_s with its next particle. Each particle's life,
// cone direction and speed are hashed from `seed` and k (FxParticles'
// numbers), so every frame, peer and replay draws the same; none born at or
// after `born_before` shows (the stream stopped there). It flies from
// `origin` (the head now, which moves on as the stream does) along `dir`
// within `cone`, pulled down `up` by `gravity` (negative: it rises), shrinking
// as it fades. Its clock is the effect's own (`since`), never the engine's:
// it holds with a pause. The CPU twin is FxTrail.at.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, world_vertex_coords;

uniform float since = 0.0;
uniform float count = 1.0;
uniform float life_s = 0.4;
uniform float life_jitter = 0.3;
uniform float speed_m_s = 1.0;
uniform float speed_jitter = 0.0;
uniform float cone = 0.0;
uniform float gravity = 0.0;
uniform float size_m = 0.1;
uniform float born_before = 1000000.0;
// A burst (>= 0): each slot one particle, born within burst_s (FxTrail.at).
uniform float burst_s = -1.0;
// A disc (> 0, m): each born within it round the origin, across `up`
// (the fire puddle's flames; FxTrail.at).
uniform float disc_m = 0.0;
uniform float seed = 0.0;
uniform vec3 origin = vec3(0.0);
uniform vec3 dir = vec3(0.0, 0.0, 1.0);
uniform vec3 up = vec3(0.0, 1.0, 0.0);
uniform vec4 colour : source_color = vec4(1.0);

varying float v_alpha;

// FxParticles._rand: particle k's j-th number, 0..1.
float rand(float k, float j) {
	float p = (seed * 1.618 + k * 7.31 + j * 113.17) * 0.1031;
	p = fract(p);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

void vertex() {
	float slot = float(INSTANCE_ID);
	float n_count = max(count, 1.0);
	float life_full = max(life_s, 0.001);
	float dt = life_full / n_count;
	float n = floor((since - slot * dt) / life_full);
	float k = slot + n_count * n;
	float born = k * dt;
	if (burst_s >= 0.0) {
		n = 0.0;
		k = slot;
		born = burst_s * rand(k, 0.0);
	}
	float life = life_full * (1.0 - life_jitter * rand(k, 1.0));
	float a = since - born;
	float alive = (n >= 0.0 && a >= 0.0 && a < life && born < born_before && slot < count) ? 1.0 : 0.0;
	vec3 d = normalize(dir);
	vec3 side = normalize(cross(d, abs(d.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 other = cross(d, side);
	float off_axis = cone * PI / 2.0 * sqrt(rand(k, 2.0));
	float round_it = TAU * rand(k, 3.0);
	vec3 way = normalize(d * cos(off_axis) + (side * cos(round_it) + other * sin(round_it)) * sin(off_axis));
	float speed = speed_m_s * (1.0 - speed_jitter * rand(k, 4.0));
	vec3 u = normalize(up);
	vec3 flat_a = normalize(cross(u, abs(u.z) < 0.99 ? vec3(0.0, 0.0, -1.0) : vec3(1.0, 0.0, 0.0)));
	vec3 flat_b = cross(u, flat_a);
	float disc_r = disc_m * sqrt(rand(k, 5.0));
	float round_disc = TAU * rand(k, 6.0);
	vec3 born_at = (flat_a * cos(round_disc) + flat_b * sin(round_disc)) * disc_r;
	vec3 centre = origin + born_at + way * speed * a - normalize(up) * 0.5 * gravity * a * a;
	float left = clamp(1.0 - a / max(life, 0.001), 0.0, 1.0);
	float s = alive * size_m * (0.4 + 0.6 * left);
	v_alpha = alive * left;
	// A camera-facing quad: its corners from its UVs, across the view.
	vec2 corner = vec2(UV.x - 0.5, 0.5 - UV.y);
	VERTEX = centre + (INV_VIEW_MATRIX[0].xyz * corner.x + INV_VIEW_MATRIX[1].xyz * corner.y) * s;
}

void fragment() {
	if (v_alpha <= 0.0) {
		discard;
	}
	// FxParticles.soft_dot: white in its middle, 0.8 at 0.35 out, clear at its rim.
	float r = length(UV - vec2(0.5)) * 2.0;
	float dot_alpha = r < 0.35 ? mix(1.0, 0.8, r / 0.35) : mix(0.8, 0.0, (r - 0.35) / 0.65);
	ALBEDO = colour.rgb;
	ALPHA = clamp(colour.a * v_alpha * clamp(dot_alpha, 0.0, 1.0), 0.0, 1.0);
}
