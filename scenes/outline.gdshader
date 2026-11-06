// The outline (playtest ruling 1, replacing the fresnel rim): an inverted
// hull drawn as a next pass over the model's own materials. Its back faces
// are pushed out along the normal by a distance scaled with clip-space w and
// the viewport size, so the line is `width_px` screen pixels wide near or
// far, and mixed in (not added) at `strength`. The mage's is his player
// colour, every enemy's one dark colour. Looks only.
shader_type spatial;
render_mode blend_mix, unshaded, cull_front, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// 0 is no outline, 1 the full colour ([look] mage_outline / enemy_outline).
uniform float strength = 0.5;
// The line's width on screen ([look] outline_width_px).
uniform float width_px = 2.0;
// The hull is drawn this far (m) behind the model, so where the mesh folds
// (sleeves, robe layers) the pushed-out back faces stay hidden behind its
// own front faces instead of drawing lines across it. A rendering detail,
// not a look value: the silhouette is unchanged.
const float DEPTH_BIAS_M = 0.05;

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// The view looks down -Z: further away is more negative.
	view.z -= DEPTH_BIAS_M;
	vec4 clip = PROJECTION_MATRIX * view;
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	// The normal's direction on screen, in pixels (so the aspect ratio does
	// not stretch the line).
	vec2 screen_normal = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy * VIEWPORT_SIZE;
	float len = length(screen_normal);
	if (len > 1e-6) {
		// NDC spans 2 per viewport size; times w undoes the perspective divide.
		clip.xy += screen_normal / len * width_px * 2.0 / VIEWPORT_SIZE * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = clamp(strength, 0.0, 1.0) * outline_color.a;
}
