shader_type canvas_item;

uniform float glow_alpha : hint_range(0.0, 1.0) = 0.38;

#include "res://assets/shaders/golden_glow_base.gdshaderinc"

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(calcUnlockedColor(SCREEN_UV), tex.a * glow_alpha);
}
