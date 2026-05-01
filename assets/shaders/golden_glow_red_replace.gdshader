shader_type canvas_item;

#include "res://assets/shaders/golden_glow_base.gdshaderinc"

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Detect fully red (1,0,0) pixels
	float is_red = step(0.9, tex.r) * step(tex.g, 0.1) * step(tex.b, 0.1) * step(0.1, tex.a);

	vec3 replaced = calcUnlockedColor(SCREEN_UV);

	COLOR = vec4(mix(tex.rgb, replaced, is_red), tex.a);
}
