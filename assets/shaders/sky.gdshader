shader_type canvas_item;

#include "res://assets/shaders/sky_colors.gdshaderinc"

uniform float time_of_day : hint_range(0.0, 24.0) = 12.0;

uniform sampler2D cloud_tex_0 : filter_nearest;
uniform sampler2D cloud_tex_1 : filter_nearest;
uniform sampler2D cloud_tex_2 : filter_nearest;
uniform sampler2D cloud_tex_3 : filter_nearest;
uniform sampler2D cloud_tex_4 : filter_nearest;
uniform sampler2D cloud_tex_5 : filter_nearest;

uniform float cloud_speed : hint_range(0.001, 0.1) = 0.015;
uniform float cloud_scale : hint_range(0.1, 10.0) = 1.0;
uniform vec2 reference_resolution = vec2(640.0, 360.0);

vec4 sample_cloud(int idx, vec2 uv) {
	if (idx == 0) return texture(cloud_tex_0, uv);
	if (idx == 1) return texture(cloud_tex_1, uv);
	if (idx == 2) return texture(cloud_tex_2, uv);
	if (idx == 3) return texture(cloud_tex_3, uv);
	if (idx == 4) return texture(cloud_tex_4, uv);
	return texture(cloud_tex_5, uv);
}

vec2 cloud_tex_size(int idx) {
	if (idx == 0) return vec2(textureSize(cloud_tex_0, 0));
	if (idx == 1) return vec2(textureSize(cloud_tex_1, 0));
	if (idx == 2) return vec2(textureSize(cloud_tex_2, 0));
	if (idx == 3) return vec2(textureSize(cloud_tex_3, 0));
	if (idx == 4) return vec2(textureSize(cloud_tex_4, 0));
	return vec2(textureSize(cloud_tex_5, 0));
}

void fragment() {
	float a = SCREEN_UV.y * 1.5;
	vec4 bottom_col = sky_bottom(time_of_day);
	vec4 col = mix(sky_top(time_of_day), bottom_col, a);
	float sky_lum = dot(bottom_col.rgb, vec3(0.299, 0.587, 0.114));
	float cloud_tint_strength = pow(1.0 - sky_lum, 2.0);

	// 8 cloud instances across the sky using all 6 textures
	// layout: [x_start_offset, y_pos, speed_multiplier, tex_index]
	float data[32] = float[32](
		0.00, 0.20, 1.00, 0.0,
		0.20, 0.08, 0.75, 1.0,
		0.45, 0.32, 1.20, 2.0,
		0.60, 0.12, 0.90, 3.0,
		0.10, 0.44, 0.60, 4.0,
		0.75, 0.24, 1.10, 5.0,
		0.35, 0.04, 0.85, 2.0,
		0.85, 0.36, 1.30, 0.0
	);

	for (int i = 0; i < 8; i++) {
		float x_off = data[i * 4 + 0];
		float y_pos = data[i * 4 + 1];
		float spd   = data[i * 4 + 2];
		int   tex   = int(data[i * 4 + 3]);

		vec2 ts = cloud_tex_size(tex);
		// w: texture pixels → screen UV x using reference resolution
		// h: derived from w via texture aspect ratio, corrected for screen aspect ratio
		//    (UV x and y cover different pixel counts on a non-square screen)
		float screen_aspect = (1.0 / SCREEN_PIXEL_SIZE.x) / (1.0 / SCREEN_PIXEL_SIZE.y);
		float w = (ts.x / reference_resolution.x) * cloud_scale;
		float h = w * (ts.y / ts.x) * screen_aspect;

		// map fract to -w..1.0 so cloud fully enters and exits before wrapping
		float t  = fract(x_off + TIME * cloud_speed * spd);
		float cx = t * (1.0 + w) - w;

		float lx = (SCREEN_UV.x - cx) / w;
		float ly = (SCREEN_UV.y - y_pos) / h;

		if (lx >= 0.0 && lx <= 1.0 && ly >= 0.0 && ly <= 1.0) {
			vec4 cloud_c = sample_cloud(tex, vec2(lx, ly));
			vec3 tinted = mix(cloud_c.rgb, cloud_c.rgb * bottom_col.rgb, cloud_tint_strength);
			col.rgb = max(col.rgb, tinted * cloud_c.a);
		}
	}

	COLOR = col;
}
