shader_type canvas_item;

#include "res://assets/shaders/sky_colors.gdshaderinc"

global uniform float sky_time_of_day;

uniform float tint_strength : hint_range(0.0, 1.0) = 0.25;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool corner_pixel = false;

varying vec4 modulate_color;

void vertex() {
	modulate_color = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);

	if (base.a > 0.0) {
		vec3 sky = mix(sky_top(sky_time_of_day).rgb, sky_bottom(sky_time_of_day).rgb, 0.5);
		vec3 tinted = base.rgb * mix(vec3(1.0), sky * 2.0, tint_strength);
		COLOR = vec4(tinted, base.a) * modulate_color;
	} else {
		vec2 ps = TEXTURE_PIXEL_SIZE;

		bool valid_side =
			texture(TEXTURE, UV + vec2(-ps.x, 0.0)).a > 0.0 ||
			texture(TEXTURE, UV + vec2( ps.x, 0.0)).a > 0.0 ||
			texture(TEXTURE, UV + vec2(0.0, -ps.y)).a > 0.0 ||
			texture(TEXTURE, UV + vec2(0.0,  ps.y)).a > 0.0;

		bool valid_corner =
			texture(TEXTURE, UV + vec2(-ps.x, -ps.y)).a > 0.0 ||
			texture(TEXTURE, UV + vec2( ps.x, -ps.y)).a > 0.0 ||
			texture(TEXTURE, UV + vec2(-ps.x,  ps.y)).a > 0.0 ||
			texture(TEXTURE, UV + vec2( ps.x,  ps.y)).a > 0.0;

		if (valid_side || (corner_pixel && valid_corner)) {
			COLOR = outline_color * modulate_color;
		} else {
			COLOR = vec4(0.0);
		}
	}
}
