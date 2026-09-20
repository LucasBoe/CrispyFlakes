shader_type canvas_item;

#include "res://assets/shaders/sky_colors.gdshaderinc"

uniform float time_of_day : hint_range(0.0, 24.0) = 12.0;

uniform sampler2D cloud_tex_0 : filter_nearest;
uniform sampler2D cloud_tex_1 : filter_nearest;
uniform sampler2D cloud_tex_2 : filter_nearest;
uniform sampler2D cloud_tex_3 : filter_nearest;
uniform sampler2D cloud_tex_4 : filter_nearest;

uniform float cloud_speed : hint_range(0.001, 0.1) = 0.015;
uniform float cloud_scale : hint_range(0.1, 10.0) = 1.0;
uniform vec2 reference_resolution = vec2(640.0, 360.0);
// Vertical band (SCREEN_UV.y, 0 = top of screen, 1 = bottom) that procedural
// clouds spawn within. cloud_y_pos_min is the top-most reachable position,
// cloud_y_pos_max is the bottom-most.
uniform float cloud_y_pos_min : hint_range(0.0, 1.0) = 0.04;
uniform float cloud_y_pos_max : hint_range(0.0, 1.0) = 0.44;
// Extra simple push on top of the fixed quintile quota above: 0 leaves the
// quota's placement untouched, higher values pull every cloud further
// toward the bottom of the band (toward cloud_y_pos_max) on top of whichever
// quintile it already landed in.
uniform float cloud_y_pos_bottom_bias : hint_range(0.0, 1.0) = 0.0;

// Cloud recoloring — tints each cloud sprite from the current sky colors
// instead of only using its baked-in shading, so clouds read as lit by the
// sky rather than always showing the same painted colors. Three independent
// toggles, each one rule from the spec:
//   1) how much to recolor, by time of day
//   2) which sky colors to pick per cloud pixel, by pixel brightness
//   3) how to shift that pick per cloud, by the cloud's vertical position
uniform bool cloud_recolor_daynight_enabled = true;
uniform bool cloud_recolor_gradient_enabled = true;
uniform bool cloud_recolor_vertical_offset_enabled = true;
// Overall multiplier on rule 1's day/night recolor curve (0%/50%/100% at
// noon/midnight/swap) — scales all four keyframes uniformly, so 1.0 is the
// curve as authored and e.g. 0.5 halves the recolor strength everywhere.
uniform float cloud_recolor_daynight_strength_multiplier : hint_range(0.0, 2.0) = 1.0;
// How far a cloud's y position (in the same 0..1 SCREEN_UV space as the
// `data` layout below) can push the brightness sampled for rule 2. A cloud
// sitting at cloud_recolor_vertical_reference_y gets no offset.
uniform float cloud_recolor_vertical_offset_strength : hint_range(0.0, 2.0) = 1.0;
uniform float cloud_recolor_vertical_reference_y : hint_range(0.0, 1.0) = 0.24;
// The cloud sprites' painted shading only spans a narrow, high slice of the
// 0..1 luminance range (measured ~0.76..0.94 across cloud_1..5.png), so raw
// luminance would only ever pick colors from the bright end of the
// top/bottom gradient. These stretch that measured range back out to a full
// 0..1 spread before it's used as the brightness/gradient factor below.
uniform float cloud_brightness_range_min : hint_range(0.0, 1.0) = 0.757;
uniform float cloud_brightness_range_max : hint_range(0.0, 1.0) = 0.940;

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

// Weather tint — flat color overlay across the whole sky (e.g. overcast grey)
uniform bool weather_tint_enabled = false;
uniform vec4 weather_tint_color : source_color = vec4(0.75, 0.77, 0.8, 1.0);
uniform float weather_tint_strength_before : hint_range(0.0, 1.0) = 0.0;
uniform float weather_tint_strength_after : hint_range(0.0, 1.0) = 0.0;

// Snow — placed and sampled with the exact same technique as the cloud loop
// below (UV-fraction space, single texture instance per slot), just falling
// vertically instead of drifting horizontally. Temporary: once this renders
// correctly we can bring back per-flake scatter/parallax on top of it.
// Reuses the sampler slot freed by dropping cloud_tex_5 (6 clouds -> 5),
// testing whether a *new* distinct sampler slot was the actual problem.
uniform bool snow_enabled = false;
uniform sampler2D snow_tex : filter_nearest;
uniform float snow_amount : hint_range(0.0, 1.0) = 0.5;
uniform float snow_speed : hint_range(0.05, 2.0) = 0.4;
uniform float snow_scale : hint_range(0.1, 10.0) = 1.0;
uniform float snow_wind_strength : hint_range(0.0, 1.0) = 0.5;

vec4 sample_cloud(int idx, vec2 uv) {
	if (idx == 0) return texture(cloud_tex_0, uv);
	if (idx == 1) return texture(cloud_tex_1, uv);
	if (idx == 2) return texture(cloud_tex_2, uv);
	if (idx == 3) return texture(cloud_tex_3, uv);
	return texture(cloud_tex_4, uv);
}

vec2 cloud_tex_size(int idx) {
	if (idx == 0) return vec2(textureSize(cloud_tex_0, 0));
	if (idx == 1) return vec2(textureSize(cloud_tex_1, 0));
	if (idx == 2) return vec2(textureSize(cloud_tex_2, 0));
	if (idx == 3) return vec2(textureSize(cloud_tex_3, 0));
	return vec2(textureSize(cloud_tex_4, 0));
}

// Arc in SCREEN_UV space — zoom-independent since UV is always 0..1
vec2 celestial_uv(float arc_t) {
	float angle = PI * (1.0 - arc_t);
	return vec2(0.5, arc_center_y) + vec2(cos(angle) * arc_radius_x, -sin(angle) * arc_radius_y);
}

// Smooth 1D value noise — used to fake gusting wind (a slowly, irregularly
// varying value is far more convincing than a pure sine wave, which just
// reads as a uniform sway).
float hash1(float n) {
	return fract(sin(n) * 43758.5453);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash1(i), hash1(i + 1.0), smoothstep(0.0, 1.0, f));
}

// Rule 1: how strongly clouds get recolored from the sky, by time of day.
// 0% at peak daytime (noon), 50% at peak nighttime (midnight), 100% at the
// 50/50 day-night swap points (sunrise/sunset) — piecewise-linear between
// those four key times, same style as sky_top()/sky_bottom() above.
float cloud_recolor_daynight_strength(float t) {
	float strength;
	if (t < 6.0)       strength = mix(0.5, 1.0, t / 6.0);
	else if (t < 12.0) strength = mix(1.0, 0.0, (t - 6.0) / 6.0);
	else if (t < 18.0) strength = mix(0.0, 1.0, (t - 12.0) / 6.0);
	else               strength = mix(1.0, 0.5, (t - 18.0) / 6.0);
	return strength * cloud_recolor_daynight_strength_multiplier;
}

// Assigns cloud index i (of 20) to a vertical quintile by a fixed quota,
// bottom-most quintile first: 10 clouds in the bottom 20% of the band, 6 in
// the next 20%, then 2, then 1, then 1 in the topmost 20%. Returns the
// quintile's [low, high) normalized range (0 = top of band, 1 = bottom);
// hash-jittering within that range is left to the caller so clouds in the
// same quintile aren't all stacked at the exact same height.
vec2 cloud_y_pos_quintile_range(int i) {
	if (i < 10) return vec2(0.8, 1.0); // bottom 20%: 10 clouds (50%)
	if (i < 16) return vec2(0.6, 0.8); // next 20%: 6 clouds (30%)
	if (i < 18) return vec2(0.4, 0.6); // next 20%: 2 clouds (10%)
	if (i < 19) return vec2(0.2, 0.4); // next 20%: 1 cloud (5%)
	              return vec2(0.0, 0.2); // top 20%: 1 cloud (5%)
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
	vec4 top_col = sky_top(time_of_day);
	vec4 col = mix(top_col, bottom_col, a);

	// Rule 1 is time-based only, so it's computed once per frame rather
	// than per cloud pixel. Disabling this checkbox turns recoloring off
	// entirely, same as the other two toggles.
	float cloud_recolor_amount = cloud_recolor_daynight_enabled ? cloud_recolor_daynight_strength(time_of_day) : 0.0;

	float screen_aspect = (1.0 / SCREEN_PIXEL_SIZE.x) / (1.0 / SCREEN_PIXEL_SIZE.y);

	// Weather tint, pass 1 — darkens/tints the base sky gradient before
	// stars/sun/moon/clouds/snow are drawn on top of it. Paired with a
	// second pass at the very end (see bottom of fragment()) that grades
	// the fully composited frame, so both the backdrop and everything
	// drawn over it end up tinted rather than just one or the other.
	if (weather_tint_enabled && weather_tint_strength_before > 0.0) {
		col.rgb *= mix(vec3(1.0), weather_tint_color.rgb, weather_tint_strength_before);
	}

	// Stars — before celestial bodies and clouds so both occlude them
	{
		float star_fade = 0.0;
		if (time_of_day >= 18.5)     star_fade = smoothstep(18.5, 20.5, time_of_day);
		else if (time_of_day <= 5.5) star_fade = smoothstep(5.5, 4.0, time_of_day);

		if (star_fade > 0.0) {
			vec2 px = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
			float cell_size = 22.0;
			vec2 cell = floor(px / cell_size);
			float h = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
			if (h > 0.78) {
				float h2 = fract(sin(dot(cell, vec2(269.5, 183.3))) * 17381.1234);
				float h3 = fract(sin(dot(cell, vec2(113.5, 457.3))) * 78241.4321);
				vec2 star_px = floor(vec2(h2, h3) * cell_size);
				vec2 local_px = mod(px, cell_size);
				if (abs(local_px.x - star_px.x) < 0.5 && abs(local_px.y - star_px.y) < 0.5) {
					col.rgb = mix(col.rgb, vec3(1.0), star_fade * (0.5 + h * 0.5));
				}
			}
		}
	}

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

	// 20 cloud instances across the sky, procedurally placed per-index
	// (rather than hand-authored) so the count can scale without listing
	// every instance by hand. Vertical placement follows a fixed quota by
	// quintile (see cloud_y_pos_quintile_range) rather than a continuous
	// random skew, so the bottom-heavy distribution is exact regardless of
	// how the per-cloud hash rolls land.
	for (int i = 0; i < 20; i++) {
		float fi = float(i);
		float x_off = hash1(fi * 12.9898 + 1.0);
		vec2 y_quintile = cloud_y_pos_quintile_range(i);
		float y_norm = mix(y_quintile.x, y_quintile.y, hash1(fi * 78.233 + 3.0));
		y_norm = mix(y_norm, 1.0, cloud_y_pos_bottom_bias);
		float y_pos = mix(cloud_y_pos_min, cloud_y_pos_max, y_norm);
		float spd = mix(0.6, 1.3, hash1(fi * 37.719 + 5.0));
		int tex = int(hash1(fi * 91.345 + 7.0) * 5.0);

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
			vec3 tinted = cloud_c.rgb;

			if (cloud_recolor_amount > 0.0) {
				float brightness = dot(cloud_c.rgb, vec3(0.299, 0.587, 0.114));
				brightness = clamp((brightness - cloud_brightness_range_min) / (cloud_brightness_range_max - cloud_brightness_range_min), 0.0, 1.0);

				// Rule 3: shift which brightness bucket a cloud pixel falls
				// into based on the cloud's own vertical placement — clouds
				// lower on screen (higher y_pos) lean toward the bottom-sky
				// pick, clouds higher up lean toward the top-sky pick.
				if (cloud_recolor_vertical_offset_enabled) {
					float vertical_bias = (y_pos - cloud_recolor_vertical_reference_y) * cloud_recolor_vertical_offset_strength;
					brightness = clamp(brightness + vertical_bias, 0.0, 1.0);
				}

				vec3 gradient_color;
				if (cloud_recolor_gradient_enabled) {
					// Rule 2: brightest cloud pixels -> sky bottom color,
					// darkest -> sky top color, mid tones interpolated.
					gradient_color = mix(top_col.rgb, bottom_col.rgb, brightness);
				} else {
					// Gradient off: fall back to a single flat 50/50
					// top/bottom tint applied uniformly across the cloud.
					gradient_color = mix(top_col.rgb, bottom_col.rgb, 0.5);
				}

				tinted = mix(cloud_c.rgb, gradient_color, cloud_recolor_amount);
			}

			col.rgb = mix(col.rgb, tinted, cloud_c.a);
		}
	}

	// Snow — snow_tex tiled infinitely (fract-wrapped UV) instead of placed
	// as individual instances. A handful of parallax layers, each a
	// differently-scaled/sped-up tiling of the same texture, reads as
	// continuous falling snow for the cost of one sample per layer.
	if (snow_enabled && snow_amount > 0.0) {
		vec2 sts = vec2(textureSize(snow_tex, 0));

		// Gusting wind: a slow base drift plus a faster wobble on top, both
		// from smooth noise rather than a pure sine — reads as irregular
		// gusts instead of a metronomic sway.
		float wind_base = (noise1(TIME * 0.12) - 0.5) * 2.0;
		float wind_gust = (noise1(TIME * 0.45 + 31.7) - 0.5) * 2.0;
		float wind = (wind_base * 0.7 + wind_gust * 0.3) * snow_wind_strength;

		// layout: [tile_scale, speed_multiplier, alpha_multiplier, wind_response]
		// Nearer/faster layers react more to wind, same as real snow does.
		float snow_layers[16] = float[16](
			1.6, 0.5, 0.55, 0.5,
			1.0, 0.8, 0.75, 0.8,
			0.65, 1.2, 0.90, 1.0,
			0.4, 1.8, 1.00, 1.3
		);

		int active = int(snow_amount * 4.0 + 0.999);
		for (int i = 0; i < 4; i++) {
			if (i >= active) {
				break;
			}
			float tile_scale    = snow_layers[i * 4 + 0];
			float speed_mult    = snow_layers[i * 4 + 1];
			float alpha_mult    = snow_layers[i * 4 + 2];
			float wind_response = snow_layers[i * 4 + 3];

			float tw = (sts.x / reference_resolution.x) * snow_scale * tile_scale;
			float th = tw * (sts.y / sts.x) * screen_aspect;

			// Per-layer jitter so gusts don't hit every layer in lockstep.
			float layer_gust = (noise1(TIME * 0.6 + float(i) * 9.1) - 0.5) * 2.0;
			float layer_wind = (wind * 0.75 + layer_gust * snow_wind_strength * 0.25) * wind_response;

			// Drift meanders the tiling sideways over time; skew tilts it
			// diagonally with vertical position, so flakes read as blown at
			// an angle while falling rather than just wobbling in place.
			float drift = layer_wind * 0.6;
			float skew = layer_wind * 0.35;
			vec2 uv = vec2(
				(SCREEN_UV.x + drift + SCREEN_UV.y * skew) / tw,
				(SCREEN_UV.y - TIME * snow_speed * speed_mult) / th
			);

			vec4 flake = texture(snow_tex, fract(uv));
			col.rgb = mix(col.rgb, flake.rgb, flake.a * alpha_mult);
		}
	}

	// Weather tint, pass 2 — grades the fully composited frame (stars,
	// sun/moon, clouds, snow included), pairing with pass 1 above so
	// everything ends up tinted, not just the backdrop or just what's drawn
	// on top of it. Multiply blend (not mix/lerp) so it scales existing
	// brightness down instead of replacing it outright — a dark tint darkens
	// proportionally rather than flattening the sky to one flat color.
	if (weather_tint_enabled && weather_tint_strength_after > 0.0) {
		vec3 tint_mul = mix(vec3(1.0), weather_tint_color.rgb, weather_tint_strength_after);
		col.rgb *= tint_mul;
	}

	COLOR = col;
}
