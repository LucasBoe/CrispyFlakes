shader_type canvas_item;

uniform float fill_ratio : hint_range(0.0, 1.0) = 0.0;
uniform float fill_color_ratio : hint_range(0.0, 1.0) = 0.0;
uniform bool blink_enabled = false;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 empty_fill_color : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform vec4 low_fill_color : source_color = vec4(0.86, 0.2, 0.18, 1.0);
uniform vec4 high_fill_color : source_color = vec4(0.25, 0.95, 0.32, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a <= 0.01) {
		COLOR = vec4(0.0);
	} else {
		bool is_outline = tex.r > 0.8 && tex.g > 0.8 && tex.b > 0.8;
		bool is_red_border = tex.r > 0.65 && tex.g < 0.35 && tex.b < 0.35;
		if (is_outline) {
			COLOR = vec4(outline_color.rgb, tex.a * outline_color.a);
		} else if (is_red_border) {
			COLOR = vec4(outline_color.rgb, tex.a * outline_color.a);
		} else {
			float fill_line = 1.0 - fill_ratio;
			bool filled = UV.y >= fill_line;
			vec4 fill_color = mix(low_fill_color, high_fill_color, fill_color_ratio);
			if (blink_enabled) {
				float blink = step(0.0, sin(TIME * 8.0));
				fill_color.rgb *= mix(0.45, 1.0, blink);
			}

			vec4 result = filled ? fill_color : empty_fill_color;
			COLOR = vec4(result.rgb, tex.a * result.a);
		}
	}
}
