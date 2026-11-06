// Low-poly volcanic rock (RockMesh pieces): flat-shaded facets in dark
// purple, lit orange from below by the lava and rimmed warm at the edges.
// Vertex COLOR: r = shade (dark .. light purple), g = lava glow on the face.
// The surface's up (a per-zone uniform, ticket 08): on the level ground
// (`sphere_radius` 0) the lava's height is world y; on the lava ball it is
// a height over the planet (`sphere_radius` round `sphere_centre`).
shader_type spatial;

uniform vec3 rock_dark : source_color = vec3(0.10, 0.08, 0.13);
uniform vec3 rock_light : source_color = vec3(0.32, 0.26, 0.38);
uniform vec3 glow_color : source_color = vec3(1.0, 0.36, 0.08);
// The lava surface's height; faces near it glow.
uniform float lava_y = -6.0;
uniform float glow_height_m = 2.0;
uniform float glow = 1.6;
// Warm light catching edges turned away from the camera.
uniform float rim = 0.35;

uniform float sphere_radius = 0.0;
uniform vec3 sphere_centre = vec3(0.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = mix(rock_dark, rock_light, COLOR.r);
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	float height = sphere_radius > 0.0 ? length(world_pos - sphere_centre) - sphere_radius : world_pos.y;
	vec3 up = sphere_radius > 0.0 ? normalize(world_pos - sphere_centre) : vec3(0.0, 1.0, 0.0);
	float above = max(height - lava_y, 0.0);
	float near_lava = exp(-above / glow_height_m);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	float facing_down = clamp(-dot((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz, up), 0.0, 1.0);
	EMISSION = glow_color * (glow * near_lava * near_lava * (0.6 + 0.4 * facing_down)
		+ COLOR.g * 0.6 * near_lava + rim * fres * (0.25 + near_lava));
}
