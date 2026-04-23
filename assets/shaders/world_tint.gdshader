shader_type canvas_item;
render_mode blend_mix;

#include "res://assets/shaders/sky_colors.gdshaderinc"

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

global uniform float sky_time_of_day;

uniform float tint_strength : hint_range(0.0, 1.0) = .15;

// overlay: multiplies darks, screens lights — adds contrast and color shift
vec3 overlay(vec3 base, vec3 blend) {
	return mix(
		2.0 * base * blend,
		1.0 - 2.0 * (1.0 - base) * (1.0 - blend),
		step(0.5, base)
	);
}

void fragment() {
	vec3 scene = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	vec3 sky = sky_bottom(sky_time_of_day).rgb;

	vec3 blended = overlay(scene, sky);
	COLOR = vec4(mix(scene, blended, tint_strength), 1.0);
}
