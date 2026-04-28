shader_type canvas_item;

uniform vec4 wave_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform bool is_unlocked = false;
uniform bool is_active = false;

float multiStep(float x) {
    float v = 0.0;

    v += step(0.25, x);
    v += step(0.50, x);
    v += step(0.75, x);

    return v / 3.0;
}

vec3 calcUnlockedColor(vec2 suv) {
	// Diamond (L1) distance from screen center
	vec2 centered = (suv * vec2(1.6,.9)) - vec2(0.5);
	float diamond_dist = abs(centered.x) + abs(centered.y);

	float wave = (sin(diamond_dist * 2.0 * TAU - TIME * 2.0) + 1.0) / 2.0;
	float wave_h  = (sin(diamond_dist * 4.0 * TAU - TIME * 6.0) + 1.0) / 2.0;
	float wave_h2 = (sin(diamond_dist * 1.7 * TAU + TIME * 3.0) + 1.0) / 2.0;
	float lerp = multiStep(wave);

	vec3 lerped = mix(vec3(1.0, 1.0, 0.0), vec3(1.0, 0.5, 0.0), lerp);

	float band  = smoothstep(0.15, 0.0, wave_h);
	float white = band * wave_h2;
	return mix(lerped, vec3(1.0,1.0,1.0), white);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float a = step(0.9, tex.r * tex.a);

	vec3 color_disabled = vec3(.4, .4, .4);
	vec3 color_unlocked = calcUnlockedColor(SCREEN_UV);
	vec3 color_hovered_and_selected = vec3(1.0, 1.0, 1.0);

	vec3 color;
	if (is_active) {
		color = color_hovered_and_selected;
	} else if (is_unlocked) {
		color = color_unlocked;
	} else {
		color = color_disabled;
	}
	
	vec4 c = vec4(color, tex.a);

	COLOR = mix(tex, c, a);
}
