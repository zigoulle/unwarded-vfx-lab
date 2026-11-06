// A rising ember: a tiny camera-facing glowing dot, colour and fade from
// the particle's colour ramp, bright enough to bloom.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform float brightness = 4.0;

void vertex() {
	mat4 m = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	m = m * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * m;
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float a = 1.0 - smoothstep(0.2, 1.0, d);
	ALBEDO = COLOR.rgb * brightness * a * COLOR.a;
}
