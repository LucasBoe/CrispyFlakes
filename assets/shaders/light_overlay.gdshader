shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

uniform vec4 light_color : source_color = vec4(1.0, 0.74, 0.38, 1.0);
uniform float color_strength : hint_range(0.0, 4.0) = 1.0;
uniform float overlay_strength : hint_range(0.0, 4.0) = 1.0;

vec3 overlay_blend(vec3 base, vec3 blend) {
	return mix(
		2.0 * base * blend,
		1.0 - 2.0 * (1.0 - base) * (1.0 - blend),
		step(0.5, base)
	);
}

void fragment() {
	vec4 sprite = texture(TEXTURE, UV) * COLOR;
	vec3 scene = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;

	float mask = max(max(sprite.r, sprite.g), sprite.b);
	vec3 tinted_light = mix(sprite.rgb, light_color.rgb * mask, color_strength);
	vec3 blended = overlay_blend(scene, tinted_light);
	float amount = clamp(sprite.a * light_color.a * overlay_strength, 0.0, 1.0);

	COLOR = vec4(mix(scene, blended, amount), 1.0);
}
