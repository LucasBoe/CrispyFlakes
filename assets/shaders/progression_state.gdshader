shader_type canvas_item;

uniform vec4 wave_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform bool is_unlocked = false;
uniform bool is_active = false;

#include "res://assets/shaders/golden_glow_base.gdshaderinc"

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
