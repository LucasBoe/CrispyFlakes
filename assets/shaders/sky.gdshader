shader_type canvas_item;

// Early morning
uniform vec4 dawn_top = vec4(0.55, 0.70, 0.95, 1.0);
uniform vec4 dawn_bottom = vec4(0.98, 0.75, 0.55, 1.0);

// Sunrise
uniform vec4 sunrise_top = vec4(0.75, 0.65, 0.90, 1.0);
uniform vec4 sunrise_bottom = vec4(1.00, 0.55, 0.30, 1.0);

// Morning
uniform vec4 morning_top = vec4(0.65, 0.82, 1.00, 1.0);
uniform vec4 morning_bottom = vec4(0.95, 0.82, 0.65, 1.0);

// Midday desert
uniform vec4 midday_top = vec4(0.80, 0.90, 1.00, 1.0);
uniform vec4 midday_bottom = vec4(0.27, 0.51, 0.71, 1.0);

// Afternoon
uniform vec4 afternoon_top = vec4(0.70, 0.85, 1.00, 1.0);
uniform vec4 afternoon_bottom = vec4(0.90, 0.72, 0.50, 1.0);

// Golden hour
uniform vec4 golden_top = vec4(0.90, 0.72, 0.55, 1.0);
uniform vec4 golden_bottom = vec4(1.00, 0.60, 0.25, 1.0);

// Sunset
uniform vec4 sunset_top = vec4(0.45, 0.35, 0.70, 1.0);
uniform vec4 sunset_bottom = vec4(1.00, 0.40, 0.20, 1.0);

// Dusk
uniform vec4 dusk_top = vec4(0.12, 0.22, 0.45, 1.0);
uniform vec4 dusk_bottom = vec4(0.40, 0.28, 0.35, 1.0);

// Blue night
uniform vec4 night_blue_top = vec4(0.02, 0.08, 0.18, 1.0);
uniform vec4 night_blue_bottom = vec4(0.05, 0.16, 0.28, 1.0);

// Blue green night
uniform vec4 night_teal_top = vec4(0.00, 0.10, 0.14, 1.0);
uniform vec4 night_teal_bottom = vec4(0.02, 0.22, 0.18, 1.0);

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

// Keyframe times: 0=night_teal, 5=dawn, 6.5=sunrise, 8=morning, 12=midday,
//                 15=afternoon, 17=golden, 18.5=sunset, 20=dusk, 22=night_blue, 24=night_teal
vec4 sky_top(float t) {
	if (t < 5.0)  return mix(night_teal_top,  dawn_top,      t / 5.0);
	if (t < 6.5)  return mix(dawn_top,         sunrise_top,  (t -  5.0) / 1.5);
	if (t < 8.0)  return mix(sunrise_top,      morning_top,  (t -  6.5) / 1.5);
	if (t < 12.0) return mix(morning_top,      midday_top,   (t -  8.0) / 4.0);
	if (t < 15.0) return mix(midday_top,       afternoon_top,(t - 12.0) / 3.0);
	if (t < 17.0) return mix(afternoon_top,    golden_top,   (t - 15.0) / 2.0);
	if (t < 18.5) return mix(golden_top,       sunset_top,   (t - 17.0) / 1.5);
	if (t < 20.0) return mix(sunset_top,       dusk_top,     (t - 18.5) / 1.5);
	if (t < 22.0) return mix(dusk_top,         night_blue_top,(t - 20.0) / 2.0);
	              return mix(night_blue_top,    night_teal_top,(t - 22.0) / 2.0);
}

vec4 sky_bottom(float t) {
	if (t < 5.0)  return mix(night_teal_bottom,  dawn_bottom,      t / 5.0);
	if (t < 6.5)  return mix(dawn_bottom,         sunrise_bottom,  (t -  5.0) / 1.5);
	if (t < 8.0)  return mix(sunrise_bottom,      morning_bottom,  (t -  6.5) / 1.5);
	if (t < 12.0) return mix(morning_bottom,      midday_bottom,   (t -  8.0) / 4.0);
	if (t < 15.0) return mix(midday_bottom,       afternoon_bottom,(t - 12.0) / 3.0);
	if (t < 17.0) return mix(afternoon_bottom,    golden_bottom,   (t - 15.0) / 2.0);
	if (t < 18.5) return mix(golden_bottom,       sunset_bottom,   (t - 17.0) / 1.5);
	if (t < 20.0) return mix(sunset_bottom,       dusk_bottom,     (t - 18.5) / 1.5);
	if (t < 22.0) return mix(dusk_bottom,         night_blue_bottom,(t - 20.0) / 2.0);
	              return mix(night_blue_bottom,    night_teal_bottom,(t - 22.0) / 2.0);
}

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
