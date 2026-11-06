// The standard player glow (PlayerGlow, ruling Q33): a really faint glow
// round the model's outer edge (a fresnel rim: strongest where the surface
// turns away from the camera), added over the model as a next pass or an
// overlay. Unshaded and added, so it needs neither lights nor the graphics
// glow (off on Low). Never brighter than `peak` (PlayerGlow.brightness, under
// the enemies' danger glow). Looks only.
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, fog_disabled, shadows_disabled;

// The glow's hue, its brightest channel at 1 (PlayerGlow.material).
uniform vec4 glow_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
// The brightest it adds, at the very edge ([look] player_glow_strength).
uniform float peak = 0.0;
// How tight round the edge it hugs: higher keeps it to the silhouette. A
// rendering detail, not a look value.
const float EDGE_POWER = 3.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), EDGE_POWER);
	ALBEDO = glow_color.rgb * peak * rim;
}
