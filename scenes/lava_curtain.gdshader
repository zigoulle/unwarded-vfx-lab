// The lavafall's falling lava over the entrance bridge's two burning lanes
// (zone SOP 6c, ruling Q1): streaks of molten rock raining down through a
// box standing over each lane, added on top of what is behind (see-through)
// and fading out toward its top, so the camera, up behind a player on the
// bridge, sees through and over it (the greybox found full-height sheets
// filled the view). Unlit; bright enough to bloom.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// The game's seconds (GameClock): holds while a solo pause holds the tree.
global uniform float game_time;

uniform vec3 hot : source_color = vec3(1.0, 0.42, 0.08);
uniform vec3 white_hot : source_color = vec3(1.0, 0.78, 0.35);
uniform float opacity = 0.55;
// The box's height (m): the streaks fade out over its upper part.
uniform float height_m = 2.2;
uniform float floor_y = 0.0;
uniform float speed = 4.0;
// Thinned out within this distance of the camera (the camera sits over the
// entrance bridge at the start), gone at half of it.
uniform float camera_clear_m = 7.0;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float across = world_pos.x * 7.0 + world_pos.z * 5.0;
	float y = world_pos.y - floor_y;
	float streak = value_noise(vec2(across, y * 1.4 + game_time * speed)) * 0.65
		+ value_noise(vec2(across * 2.3, y * 2.6 + game_time * speed * 1.4)) * 0.35;
	float lines = smoothstep(0.5, 0.85, streak);
	float h = clamp(y / max(height_m, 0.01), 0.0, 1.0);
	// Thick at the lane, thinning out toward the top: the fall seems to pour
	// from above the frame.
	float fade = (1.0 - smoothstep(0.35, 1.0, h)) * (0.35 + 0.65 * (1.0 - h));
	vec3 color = mix(hot, white_hot, smoothstep(0.75, 0.95, streak));
	float clear = smoothstep(camera_clear_m * 0.5, camera_clear_m, distance(world_pos, CAMERA_POSITION_WORLD));
	ALBEDO = color * lines * fade * opacity * clear * 1.6;
}
