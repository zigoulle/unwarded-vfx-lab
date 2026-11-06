// The ribbon's shape (FxRibbon; VFX lab tickets 04, 07): its uniforms and
// its vertex shader, shared by the ribbon's two looks: fx_ribbon.gdshader
// (additive light: lightning) and fx_ribbon_cel.gdshader (flat cel tones:
// sand). See fx_ribbon.gdshader for the shape's steps; FxRibbon.point is
// its CPU twin.
//
// The maths is ported from LinearAbiltyCastingThreeJS by mohamedachrefelouafi
// (src/materials/LightningMaterial.js, MIT licence; THIRD_PARTY_LICENSES.md).

#include "res://fx/shaders/fx_noise.gdshaderinc"

// The draw: the effect's seconds, its seed, its two ends and the side the
// fan starts from (world).
uniform float fx_t = 0.0;
uniform float seed = 0.0;
uniform vec3 origin = vec3(0.0);
uniform vec3 target = vec3(0.0, 0.0, -1.0);
uniform vec3 side_dir = vec3(1.0, 0.0, 0.0);
// The phase: how far the strike front has run (0..1, past 1 the whole
// bolt) and how faded it is (1 full, 0 gone).
uniform float progress = 1.0;
uniform float fade = 1.0;

// The shape.
uniform float sag = 0.2;
uniform float restrike = 24.0;
uniform float strands = 5.0;
uniform float spread = 0.75;
uniform float spread_near = 0.05;
uniform float spread_curve = 1.6;
// The innermost strand's share of the reach (0: on the axis, lightning's
// main strand; the tornado's bands all ride off it).
uniform float radial_min = 0.0;
uniform float twist = 0.45;
uniform float twist_speed = 0.8;
uniform float jitter = 0.34;
uniform float jitter_scale = 0.85;
uniform float octaves = 4.0;
uniform float jitter_falloff = 0.55;
uniform float crawl = 3.2;
uniform float pinch = 0.14;
uniform float converge = 0.8;

// Bent into a ring (0: a line from origin to target).
uniform float ring_radius = 0.0;
uniform float ring_start = 0.0;
uniform float ring_span = 6.28318530718;
uniform vec3 ring_up = vec3(0.0, 1.0, 0.0);

// The width (m) and its profile.
uniform float width = 0.085;
uniform float width_tip = 0.5;
uniform float width_curve = 1.0;
uniform float core_width = 2.1;
uniform float core_sharp = 3.4;
uniform float glow_falloff = 2.4;
uniform float strand_flash = 0.5;

// The light.
uniform float flicker = 0.3;
uniform float flicker_speed = 34.0;
uniform float tip_glow = 2.0;
uniform float tip_length = 0.08;
uniform float branch_dim = 0.72;
uniform float opacity = 1.0;
uniform float glow = 2.3;
uniform vec4 colour_core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 colour_inner : source_color = vec4(0.78, 0.92, 1.0, 1.0);
uniform vec4 colour_outer : source_color = vec4(0.22, 0.62, 1.0, 1.0);
uniform vec4 colour_halo : source_color = vec4(0.04, 0.24, 0.78, 1.0);

// The pass: the core (false) or the glow (true), its width and opacity, and
// the most its half-width may cover (a share of the screen's height; 0: no cap).
uniform bool glow_pass = false;
uniform float width_scale = 1.0;
uniform float pass_opacity = 1.0;
uniform float screen_cap = 0.0;

varying float v_t;
varying float v_side;
varying float v_strand;
varying float v_flash;

// One strand's offset from the axis, across it: `span` keeps jitter_scale in
// kinks per metre however far the bolt reaches.
vec2 kink(float t, float strand_seed, float span) {
	vec2 o = vec2(0.0);
	float amp = 1.0;
	float freq = max(jitter_scale, 0.01) * span;
	float scroll = fx_t * crawl;
	for (int i = 0; i < 5; i++) {
		float on = step(float(i), octaves - 1.0);
		o.x += on * amp * vnoise(t * freq + scroll, strand_seed + 13.0 * float(i));
		o.y += on * amp * vnoise(t * freq + scroll * 1.17, strand_seed + 71.3 + 13.0 * float(i));
		amp *= jitter_falloff;
		freq *= 2.0;
		scroll *= 1.63;
	}
	return o;
}

// A ring's two directions in its plane: ahead (-Z, or +X when its up is
// along Z) and a quarter turn on (FxRibbon.ring_frame).
vec3 ring_ahead(vec3 up) {
	vec3 ref = abs(up.z) < 0.99 ? vec3(0.0, 0.0, -1.0) : vec3(1.0, 0.0, 0.0);
	return normalize(ref - up * dot(ref, up));
}

vec3 bolt_point(float t, float strand_seed, float radial, vec3 line_n1, vec3 line_n2, float line_span) {
	vec3 axis;
	vec3 n1 = line_n1;
	vec3 n2 = line_n2;
	float span = line_span;
	vec3 up = vec3(0.0, 1.0, 0.0);
	if (ring_radius > 0.0) {
		up = normalize(ring_up);
		vec3 ahead = ring_ahead(up);
		float a = ring_start + t * ring_span;
		n1 = ahead * cos(a) + cross(up, ahead) * sin(a);
		n2 = up;
		axis = origin + n1 * ring_radius;
		span = max(ring_radius * abs(ring_span), 0.01);
	} else {
		axis = mix(origin, target, t);
	}
	axis += up * sag * sin(t * PI);
	float pinch_at = max(pinch, 1e-3);
	float ends = smoothstep(0.0, pinch_at, t)
			* mix(1.0, smoothstep(0.0, pinch_at, 1.0 - t), clamp(converge, 0.0, 1.0));
	vec2 offset = kink(t, strand_seed, span) * jitter * ends;
	float angle = strand_seed * TAU + (t * twist + fx_t * twist_speed) * TAU;
	float reach = mix(spread_near, spread, pow(clamp(t, 0.0, 1.0), max(spread_curve, 0.01)));
	offset += vec2(cos(angle), sin(angle)) * reach * radial;
	return axis + n1 * offset.x + n2 * offset.y;
}

void vertex() {
	float t = UV.x;
	float edge = UV.y;
	float strand = UV2.x;
	v_t = t;
	v_side = edge;

	vec3 delta = target - origin;
	float span = max(length(delta), 0.01);
	vec3 dir = delta / span;
	vec3 n1 = side_dir - dir * dot(side_dir, dir);
	n1 = length(n1) > 1e-4 ? normalize(n1) : normalize(cross(dir, vec3(0.0, 1.0, 0.0)));
	vec3 n2 = normalize(cross(dir, n1));

	float strike = floor(fx_t * max(restrike, 0.01));
	float strand_seed = hash11(strand * 7.13 + seed + strike * 3.77) * 97.0;
	float radial = mix(radial_min, 1.0, strands <= 1.0 ? 0.0 : strand / (strands - 1.0));
	v_strand = radial;

	vec3 here = bolt_point(t, strand_seed, radial, n1, n2, span);
	float step_t = 0.02;
	float ahead = t + step_t;
	float flip = 1.0;
	if (ahead > 1.0) {
		ahead = t - step_t;
		flip = -1.0;
	}
	vec3 next = bolt_point(ahead, strand_seed, radial, n1, n2, span);
	vec3 tangent = (next - here) * flip;
	tangent = length(tangent) > 1e-5 ? normalize(tangent) : dir;

	vec3 camera_at = INV_VIEW_MATRIX[3].xyz;
	vec3 to_camera = normalize(camera_at - here);
	vec3 binormal = cross(tangent, to_camera);
	float bl = length(binormal);
	binormal = bl > 1e-4 ? binormal / bl : n1;

	float flash = mix(1.0, hash11(floor(fx_t * flicker_speed) + strand * 3.7 + seed), strand_flash);
	v_flash = flash;

	float half_width = width * width_scale;
	half_width *= mix(1.0, width_tip, pow(clamp(t, 0.0, 1.0), max(width_curve, 0.01)));
	half_width *= mix(core_width, 1.0, radial);
	half_width *= flash * fade;
	if (screen_cap > 0.0) {
		float depth = max(-(VIEW_MATRIX * vec4(here, 1.0)).z, 0.01);
		half_width = min(half_width, screen_cap * 2.0 * depth / PROJECTION_MATRIX[1][1]);
	}
	VERTEX = here + binormal * edge * half_width;
}
