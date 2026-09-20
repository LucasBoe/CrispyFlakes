shader_type canvas_item;

#include "res://assets/shaders/sky_colors.gdshaderinc"

global uniform float sky_time_of_day;
global uniform vec4 weather_tint_color : source_color;
global uniform float weather_tint_strength;
varying vec4 modulate_color;

// How strongly the sky color is mixed onto the sprite (0 = no tint, 1 = full tint)
uniform float tint_strength : hint_range(0.0, 1.0) = 0.3;
// How much of the ambient tint comes from the sky's bottom color vs. its top
// color (0 = top only, 1 = bottom only).
uniform float sky_ambient_mix : hint_range(0.0, 1.0) = 0.5;

void vertex() {
	modulate_color = COLOR;
}

void fragment() {
	vec4 sprite = texture(TEXTURE, UV);

	// Blend of top and bottom sky colors as the ambient tint, weighted by
	// sky_ambient_mix (0 = top only, 1 = bottom only) instead of a flat 50/50,
	// so layers near the horizon can be tuned to match the sky's bottom color.
	vec3 sky = mix(sky_top(sky_time_of_day).rgb, sky_bottom(sky_time_of_day).rgb, sky_ambient_mix);

	// Multiply-blend toward sky color, scaled to neutral white at strength 0.
	// The multiply blend reaches full strength by 0.7 (rather than 1.0); past
	// that point the sprite's own color increasingly gives way to a flat sky
	// color instead, so the furthest layers fade into the sky like real
	// atmospheric haze instead of just darkening/tinting further.
	const float MIX_CAP = 0.7;
	vec3 tinted = sprite.rgb * mix(vec3(1.0), sky * 2.0, min(tint_strength, MIX_CAP) / MIX_CAP);
	float replace_amount = clamp((tint_strength - MIX_CAP) / (1.0 - MIX_CAP), 0.0, 1.0);
	tinted = mix(tinted, sky, replace_amount);

	// Weather overlay — same multiply-toward-color approach as the sky
	// shader's own weather tint pass, so foreground objects darken/tint in
	// step with the sky during weather effects instead of staying neutral.
	tinted *= mix(vec3(1.0), weather_tint_color.rgb, weather_tint_strength);

	COLOR = vec4(tinted, sprite.a) * modulate_color;
}
