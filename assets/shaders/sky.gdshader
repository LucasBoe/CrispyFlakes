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

uniform sampler2D sun_tex : filter_nearest;
uniform sampler2D moon_tex : filter_nearest;
uniform float celestial_scale : hint_range(0.1, 3.0) = 0.5;

// Arc placement
uniform float arc_center_y : hint_range(0.0, 1.0) = 0.56;
uniform float arc_radius_x : hint_range(0.0, 1.5) = 0.40;
uniform float arc_radius_y : hint_range(0.0, 1.0) = 0.37;

// Sun appearance
uniform float sun_horizon_size : hint_range(1.0, 4.0) = 1.7;
uniform float sun_size_start : hint_range(0.0, 1.0) = 0.0;  // elevation where swelling begins
uniform float sun_size_end : hint_range(0.0, 1.0) = 0.3;    // elevation where size is back to normal
uniform float sun_aura_cutoff : hint_range(0.0, 1.0) = 0.75;
uniform float sun_aura_elevation : hint_range(0.0, 1.0) = 0.35;
uniform vec4 sun_color_horizon : source_color = vec4(1.0, 0.45, 0.12, 1.0);
uniform vec4 sun_color_morning : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform vec4 sun_color_noon : source_color = vec4(1.0, 0.97, 0.78, 1.0);

// Moon appearance
uniform float moon_alpha_min : hint_range(0.0, 1.0) = 0.25;
uniform float moon_alpha_max : hint_range(0.0, 1.0) = 1.0;

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

// Arc in SCREEN_UV space — zoom-independent since UV is always 0..1
vec2 celestial_uv(float arc_t) {
	float angle = PI * (1.0 - arc_t);
	return vec2(0.5, arc_center_y) + vec2(cos(angle) * arc_radius_x, -sin(angle) * arc_radius_y);
}

vec3 sun_color(float tod) {
	float t = clamp(tod, 6.0, 18.0);
	if (t <= 8.0)  return mix(sun_color_horizon.rgb, sun_color_morning.rgb, smoothstep(6.0, 8.0, t));
	if (t <= 12.0) return mix(sun_color_morning.rgb, sun_color_noon.rgb,    smoothstep(8.0, 12.0, t));
	if (t <= 16.0) return mix(sun_color_noon.rgb,    sun_color_morning.rgb, smoothstep(12.0, 16.0, t));
	return                mix(sun_color_morning.rgb, sun_color_horizon.rgb, smoothstep(16.0, 18.0, t));
}

void fragment() {
	float a = SCREEN_UV.y * 1.5;
	vec4 bottom_col = sky_bottom(time_of_day);
	vec4 col = mix(sky_top(time_of_day), bottom_col, a);
	float sky_lum = dot(bottom_col.rgb, vec3(0.299, 0.587, 0.114));
	float cloud_tint_strength = pow(1.0 - sky_lum, 2.0);

	float screen_aspect = (1.0 / SCREEN_PIXEL_SIZE.x) / (1.0 / SCREEN_PIXEL_SIZE.y);

	// Celestial bodies — before cloud loop so clouds occlude them
	{
		// Sun: rises 6am, peaks noon, sets 6pm
		// Not clamped — position continues below horizon naturally, hidden by the ground node
		float sun_t = (time_of_day - 6.0) / 12.0;
		float sun_elevation = sin(PI * clamp(sun_t, 0.0, 1.0));
		float sun_alpha = 1.0;// (time_of_day >= 6.0 && time_of_day <= 18.0) ? 1.0 : 0.0;

		// Grow larger near the horizon (atmospheric magnification)
		float sun_size = celestial_scale * mix(sun_horizon_size, 1.0, smoothstep(sun_size_start, sun_size_end, sun_elevation));
		vec2 ts = vec2(textureSize(sun_tex, 0));
		float w = (ts.x / reference_resolution.x) * sun_size;
		float h = w * (ts.y / ts.x) * screen_aspect;
		vec2 local_uv = (SCREEN_UV - celestial_uv(sun_t)) / vec2(w, h) + 0.5;
		if (local_uv.x >= 0.0 && local_uv.x <= 1.0 && local_uv.y >= 0.0 && local_uv.y <= 1.0) {
			vec4 c = texture(sun_tex, local_uv);
			c.rgb *= sun_color(time_of_day);
			// Near horizon: cut the soft aura by raising the alpha floor (x),
			// leaving a crisp disc. x=0 at zenith (full aura), x=0.55 at horizon.
			float x = mix(sun_aura_cutoff, 0.0, smoothstep(0.0, sun_aura_elevation, sun_elevation));
			c.a = clamp((c.a - x) / (1.0 - x), 0.0, 1.0) * sun_alpha;
			col.rgb = mix(col.rgb, c.rgb, c.a);
		}
	}
	{
		// Moon: rises 6pm, peaks midnight, sets 6am
		float moon_t = time_of_day >= 18.0
			? (time_of_day - 18.0) / 12.0
			: (time_of_day + 6.0) / 12.0;
		moon_t = clamp(moon_t, 0.0, 1.0);
		float moon_elevation = sin(PI * moon_t);

		// Day/night fade
		float moon_fade = 1.0;
		if (time_of_day >= 6.5 && time_of_day <= 17.5)        moon_fade = 0.0;
		else if (time_of_day > 5.5 && time_of_day < 6.5)      moon_fade = 1.0 - smoothstep(5.5, 6.5, time_of_day);
		else if (time_of_day > 17.5 && time_of_day < 18.5)    moon_fade = smoothstep(17.5, 18.5, time_of_day);

		// Fully opaque at zenith, semi-transparent near horizon
		float moon_alpha = moon_fade * mix(moon_alpha_min, moon_alpha_max, moon_elevation);

		vec2 ts = vec2(textureSize(moon_tex, 0));
		float w = (ts.x / reference_resolution.x) * celestial_scale;
		float h = w * (ts.y / ts.x) * screen_aspect;
		vec2 local_uv = (SCREEN_UV - celestial_uv(moon_t)) / vec2(w, h) + 0.5;
		if (local_uv.x >= 0.0 && local_uv.x <= 1.0 && local_uv.y >= 0.0 && local_uv.y <= 1.0) {
			vec4 c = texture(moon_tex, local_uv);
			c.a *= moon_alpha;
			col.rgb = mix(col.rgb, c.rgb, c.a);
		}
	}

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
			col.rgb = mix(col.rgb, tinted, cloud_c.a);
		}
	}

	COLOR = col;
}
