// Keyframe times: 0=night_teal, 5=dawn, 6.5=sunrise, 8=morning, 12=midday,
//                 15=afternoon, 17=golden, 18.5=sunset, 20=dusk, 22=night_blue, 24=night_teal

// Early morning
uniform vec4 dawn_top    = vec4(0.55, 0.70, 0.95, 1.0);
uniform vec4 dawn_bottom = vec4(0.98, 0.75, 0.55, 1.0);

// Sunrise
uniform vec4 sunrise_top    = vec4(0.75, 0.65, 0.90, 1.0);
uniform vec4 sunrise_bottom = vec4(1.00, 0.55, 0.30, 1.0);

// Morning
uniform vec4 morning_top    = vec4(0.65, 0.82, 1.00, 1.0);
uniform vec4 morning_bottom = vec4(0.95, 0.82, 0.65, 1.0);

// Midday desert
uniform vec4 midday_top    = vec4(0.80, 0.90, 1.00, 1.0);
uniform vec4 midday_bottom = vec4(0.27, 0.51, 0.71, 1.0);

// Afternoon
uniform vec4 afternoon_top    = vec4(0.70, 0.85, 1.00, 1.0);
uniform vec4 afternoon_bottom = vec4(0.90, 0.72, 0.50, 1.0);

// Golden hour
uniform vec4 golden_top    = vec4(0.90, 0.72, 0.55, 1.0);
uniform vec4 golden_bottom = vec4(1.00, 0.60, 0.25, 1.0);

// Sunset
uniform vec4 sunset_top    = vec4(0.45, 0.35, 0.70, 1.0);
uniform vec4 sunset_bottom = vec4(1.00, 0.40, 0.20, 1.0);

// Dusk
uniform vec4 dusk_top    = vec4(0.12, 0.22, 0.45, 1.0);
uniform vec4 dusk_bottom = vec4(0.40, 0.28, 0.35, 1.0);

// Blue night
uniform vec4 night_blue_top    = vec4(0.02, 0.08, 0.18, 1.0);
uniform vec4 night_blue_bottom = vec4(0.05, 0.16, 0.28, 1.0);

// Blue green night
uniform vec4 night_teal_top    = vec4(0.00, 0.10, 0.14, 1.0);
uniform vec4 night_teal_bottom = vec4(0.02, 0.22, 0.18, 1.0);

vec4 sky_top(float t) {
	if (t < 5.0)  return mix(night_teal_top,  dawn_top,        t / 5.0);
	if (t < 6.5)  return mix(dawn_top,        sunrise_top,    (t -  5.0) / 1.5);
	if (t < 8.0)  return mix(sunrise_top,     morning_top,    (t -  6.5) / 1.5);
	if (t < 12.0) return mix(morning_top,     midday_top,     (t -  8.0) / 4.0);
	if (t < 15.0) return mix(midday_top,      afternoon_top,  (t - 12.0) / 3.0);
	if (t < 17.0) return mix(afternoon_top,   golden_top,     (t - 15.0) / 2.0);
	if (t < 18.5) return mix(golden_top,      sunset_top,     (t - 17.0) / 1.5);
	if (t < 20.0) return mix(sunset_top,      dusk_top,       (t - 18.5) / 1.5);
	if (t < 22.0) return mix(dusk_top,        night_blue_top, (t - 20.0) / 2.0);
	              return mix(night_blue_top,   night_teal_top, (t - 22.0) / 2.0);
}

vec4 sky_bottom(float t) {
	if (t < 5.0)  return mix(night_teal_bottom,  dawn_bottom,        t / 5.0);
	if (t < 6.5)  return mix(dawn_bottom,         sunrise_bottom,   (t -  5.0) / 1.5);
	if (t < 8.0)  return mix(sunrise_bottom,      morning_bottom,   (t -  6.5) / 1.5);
	if (t < 12.0) return mix(morning_bottom,      midday_bottom,    (t -  8.0) / 4.0);
	if (t < 15.0) return mix(midday_bottom,       afternoon_bottom, (t - 12.0) / 3.0);
	if (t < 17.0) return mix(afternoon_bottom,    golden_bottom,    (t - 15.0) / 2.0);
	if (t < 18.5) return mix(golden_bottom,       sunset_bottom,    (t - 17.0) / 1.5);
	if (t < 20.0) return mix(sunset_bottom,       dusk_bottom,      (t - 18.5) / 1.5);
	if (t < 22.0) return mix(dusk_bottom,         night_blue_bottom,(t - 20.0) / 2.0);
	              return mix(night_blue_bottom,    night_teal_bottom,(t - 22.0) / 2.0);
}
