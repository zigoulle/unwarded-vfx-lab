// The ultimate's hourglass glass (HourglassLook, mage step 6c): a fresnel
// hologram shell, bright at the silhouette and faint face-on, so the mage
// stays readable inside. Derived from Binbun Battle FX `shield_shell.gdshader`
// (CC0, game/vfx/binbun/BinbunVFX_Vol2/BattleFX/shader/): the same fresnel
// and two-colour ramp, plus an `opacity` the cast, the shatter and the
// marker fade by, a faint face-on base, both faces drawn, and no proximity
// fade (it read the depth buffer for an edge the hourglass does not need).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 primary_color : source_color = vec3(1.0, 0.9, 0.6);
uniform vec3 secondary_color : source_color = vec3(0.95, 0.65, 0.25);
uniform float emission = 1.0;
// How much of the glass shows face-on (0: only the silhouette glows).
uniform float base_alpha = 0.03;
// How sharp the glowing silhouette is (higher: a thinner rim).
uniform float rim_power = 3.0;
uniform float opacity = 1.0;

void fragment() {
	float fresnel = 1.0 - abs(dot(VIEW, NORMAL));
	float value = smoothstep(0.0, 1.0, fresnel);
	ALBEDO = mix(secondary_color, primary_color, value) * emission;
	ALPHA = clamp(base_alpha + 0.85 * pow(value, rim_power), 0.0, 1.0) * opacity;
}
