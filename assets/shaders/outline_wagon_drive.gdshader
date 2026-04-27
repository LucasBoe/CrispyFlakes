shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_size : hint_range(1.0, 16.0, 1.0) = 1.0;
uniform bool corner_pixel = false;

// Defaults are tuned to the current 74x37 wagon sprites.
uniform sampler2D back_wheel_texture : filter_nearest;
uniform sampler2D front_wheel_texture : filter_nearest;
uniform vec2 back_wheel_texture_size = vec2(12.0, 12.0);
uniform vec2 front_wheel_texture_size = vec2(12.0, 12.0);
uniform vec2 back_left_wheel_center_px = vec2(20.0, 30.5);
uniform vec2 back_right_wheel_center_px = vec2(39.0, 30.5);
uniform vec2 front_left_wheel_center_px = vec2(16.0, 30.5);
uniform vec2 front_right_wheel_center_px = vec2(35.0, 30.5);
uniform vec4 left_wheel_cutout_px = vec4(10.0, 24.0, 16.0, 13.0);
uniform vec4 right_wheel_cutout_px = vec4(29.0, 24.0, 16.0, 13.0);
uniform float wheel_spin_speed = 8.0;
uniform float wheel_scale = 1.0;
uniform float wheel_phase = 0.0;

varying vec4 modulate_color;

void vertex() {
	modulate_color = COLOR;
}

bool is_inside_rect(vec2 pixel_pos, vec4 rect_px) {
	return pixel_pos.x >= rect_px.x && pixel_pos.x < rect_px.x + rect_px.z
		&& pixel_pos.y >= rect_px.y && pixel_pos.y < rect_px.y + rect_px.w;
}

vec2 pixel_pos_from_uv(vec2 uv, vec2 texture_pixel_size) {
	return uv / texture_pixel_size - vec2(0.5);
}

vec4 sample_wagon_body(sampler2D tex, vec2 uv, vec2 texture_pixel_size) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return vec4(0.0);
	}

	vec2 pixel_pos = pixel_pos_from_uv(uv, texture_pixel_size);
	if (is_inside_rect(pixel_pos, left_wheel_cutout_px) || is_inside_rect(pixel_pos, right_wheel_cutout_px)) {
		return vec4(0.0);
	}

	return texture(tex, uv);
}

vec4 sample_wheel_instance(
	sampler2D wheel_tex,
	vec2 wheel_tex_size,
	vec2 pixel_pos,
	vec2 wheel_center_px,
	float angle
) {
	vec2 wheel_half_size = wheel_tex_size * 0.5;
	vec2 local = (pixel_pos - wheel_center_px) / max(wheel_scale, 0.001);

	float sin_a = sin(angle);
	float cos_a = cos(angle);
	vec2 source_pixel = vec2(
		cos_a * local.x + sin_a * local.y,
		-sin_a * local.x + cos_a * local.y
	) + wheel_half_size;

	if (source_pixel.x < 0.0 || source_pixel.y < 0.0
			|| source_pixel.x >= wheel_tex_size.x || source_pixel.y >= wheel_tex_size.y) {
		return vec4(0.0);
	}

	vec2 source_uv = source_pixel / wheel_tex_size;
	return texture(wheel_tex, source_uv);
}

vec4 composite_over(vec4 base, vec4 overlay) {
	float out_alpha = overlay.a + base.a * (1.0 - overlay.a);
	if (out_alpha <= 0.0) {
		return vec4(0.0);
	}

	vec3 out_rgb = (
		overlay.rgb * overlay.a +
		base.rgb * base.a * (1.0 - overlay.a)
	) / out_alpha;

	return vec4(out_rgb, out_alpha);
}

vec4 sample_composite(sampler2D tex, vec2 uv, vec2 texture_pixel_size) {
	vec4 result = vec4(0.0);
	vec2 pixel_pos = pixel_pos_from_uv(uv, texture_pixel_size);
	float angle = TIME * wheel_spin_speed + wheel_phase;

	vec4 back_left_wheel = sample_wheel_instance(
		back_wheel_texture,
		back_wheel_texture_size,
		pixel_pos,
		back_left_wheel_center_px,
		angle
	);
	vec4 back_right_wheel = sample_wheel_instance(
		back_wheel_texture,
		back_wheel_texture_size,
		pixel_pos,
		back_right_wheel_center_px,
		angle
	);
	vec4 body = sample_wagon_body(tex, uv, texture_pixel_size);
	vec4 front_left_wheel = sample_wheel_instance(
		front_wheel_texture,
		front_wheel_texture_size,
		pixel_pos,
		front_left_wheel_center_px,
		angle
	);
	vec4 front_right_wheel = sample_wheel_instance(
		front_wheel_texture,
		front_wheel_texture_size,
		pixel_pos,
		front_right_wheel_center_px,
		angle
	);

	result = composite_over(result, back_left_wheel);
	result = composite_over(result, back_right_wheel);
	result = composite_over(result, body);
	result = composite_over(result, front_left_wheel);
	result = composite_over(result, front_right_wheel);
	return result;
}

void fragment() {
	vec4 composite = sample_composite(TEXTURE, UV, TEXTURE_PIXEL_SIZE);

	if (composite.a > 0.0) {
		COLOR = composite * modulate_color;
	} else {
		vec2 step = TEXTURE_PIXEL_SIZE * outline_size;

		bool valid_side =
			sample_composite(TEXTURE, UV + vec2(-step.x, 0.0), TEXTURE_PIXEL_SIZE).a > 0.0 ||
			sample_composite(TEXTURE, UV + vec2( step.x, 0.0), TEXTURE_PIXEL_SIZE).a > 0.0 ||
			sample_composite(TEXTURE, UV + vec2(0.0, -step.y), TEXTURE_PIXEL_SIZE).a > 0.0 ||
			sample_composite(TEXTURE, UV + vec2(0.0,  step.y), TEXTURE_PIXEL_SIZE).a > 0.0;

		bool valid_corner =
			sample_composite(TEXTURE, UV + vec2(-step.x, -step.y), TEXTURE_PIXEL_SIZE).a > 0.0 ||
			sample_composite(TEXTURE, UV + vec2( step.x, -step.y), TEXTURE_PIXEL_SIZE).a > 0.0 ||
			sample_composite(TEXTURE, UV + vec2(-step.x,  step.y), TEXTURE_PIXEL_SIZE).a > 0.0 ||
			sample_composite(TEXTURE, UV + vec2( step.x,  step.y), TEXTURE_PIXEL_SIZE).a > 0.0;

		if (valid_side || (corner_pixel && valid_corner)) {
			COLOR = outline_color * modulate_color;
		} else {
			COLOR = vec4(0.0);
		}
	}
}
