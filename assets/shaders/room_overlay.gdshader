shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

uniform vec2 room_size = vec2(48.0);
uniform float temperature_strength : hint_range(0.0, 4.0) = 1.35;

uniform sampler2D aura_texture_0 : source_color, filter_nearest;
uniform vec4 aura_rect_0 = vec4(0.0);
uniform vec4 aura_color_0 : source_color = vec4(1.0);
uniform sampler2D aura_texture_1 : source_color, filter_nearest;
uniform vec4 aura_rect_1 = vec4(0.0);
uniform vec4 aura_color_1 : source_color = vec4(1.0);
uniform sampler2D aura_texture_2 : source_color, filter_nearest;
uniform vec4 aura_rect_2 = vec4(0.0);
uniform vec4 aura_color_2 : source_color = vec4(1.0);
uniform sampler2D aura_texture_3 : source_color, filter_nearest;
uniform vec4 aura_rect_3 = vec4(0.0);
uniform vec4 aura_color_3 : source_color = vec4(1.0);

vec3 overlay_blend(vec3 base, vec3 blend) {
	return mix(
		2.0 * base * blend,
		1.0 - 2.0 * (1.0 - base) * (1.0 - blend),
		step(0.5, base)
	);
}

vec3 apply_overlay(vec3 base, vec3 blend, float amount) {
	return mix(base, overlay_blend(base, blend), clamp(amount, 0.0, 1.0));
}

bool contains(vec2 position, vec4 rect) {
	return position.x >= rect.x && position.y >= rect.y
		&& position.x <= rect.x + rect.z && position.y <= rect.y + rect.w;
}

vec3 apply_aura(vec3 base, vec4 aura, vec4 tint) {
	float mask = max(max(aura.r, aura.g), aura.b);
	return apply_overlay(base, tint.rgb * mask, aura.a * tint.a);
}

void fragment() {
	vec4 temperature = texture(TEXTURE, UV) * COLOR;
	vec3 result = texture(screen_texture, SCREEN_UV).rgb;
	result = apply_overlay(result, temperature.rgb, temperature.a * temperature_strength);

	vec2 local_position = UV * room_size;
	if (contains(local_position, aura_rect_0)) {
		vec2 aura_uv = (local_position - aura_rect_0.xy) / aura_rect_0.zw;
		result = apply_aura(result, texture(aura_texture_0, aura_uv), aura_color_0);
	}
	if (contains(local_position, aura_rect_1)) {
		vec2 aura_uv = (local_position - aura_rect_1.xy) / aura_rect_1.zw;
		result = apply_aura(result, texture(aura_texture_1, aura_uv), aura_color_1);
	}
	if (contains(local_position, aura_rect_2)) {
		vec2 aura_uv = (local_position - aura_rect_2.xy) / aura_rect_2.zw;
		result = apply_aura(result, texture(aura_texture_2, aura_uv), aura_color_2);
	}
	if (contains(local_position, aura_rect_3)) {
		vec2 aura_uv = (local_position - aura_rect_3.xy) / aura_rect_3.zw;
		result = apply_aura(result, texture(aura_texture_3, aura_uv), aura_color_3);
	}

	COLOR = vec4(result, 1.0);
}
