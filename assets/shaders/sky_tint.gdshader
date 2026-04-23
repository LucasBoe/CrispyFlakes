shader_type canvas_item;

#include "res://assets/shaders/sky_colors.gdshaderinc"

global uniform float sky_time_of_day;

// How strongly the sky color is mixed onto the sprite (0 = no tint, 1 = full tint)
uniform float tint_strength : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec4 sprite = texture(TEXTURE, UV);

	// Use the average of top and bottom sky colors as the ambient tint
	vec3 sky = mix(sky_top(sky_time_of_day).rgb, sky_bottom(sky_time_of_day).rgb, 0.5);

	// Multiply-blend toward sky color, scaled to neutral white at strength 0
	vec3 tinted = sprite.rgb * mix(vec3(1.0), sky * 2.0, tint_strength);

	COLOR = vec4(tinted, sprite.a);
}
