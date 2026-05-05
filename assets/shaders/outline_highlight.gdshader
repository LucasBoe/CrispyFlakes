shader_type canvas_item;

uniform float brightness_threshold : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float outline_size : hint_range(1.0, 16.0, 1.0) = 1.0;
uniform bool corner_pixel = false;

float brightness(vec4 c) {
	return dot(c.rgb, vec3(0.299, 0.587, 0.114)) * c.a;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);

	bool is_highlighted = brightness(base) > brightness_threshold;

	if (is_highlighted) {
		COLOR = vec4(0.0, 0.35, 1.0, base.a);
	} else {
		vec2 step = TEXTURE_PIXEL_SIZE * outline_size;

		bool near_highlighted =
			brightness(texture(TEXTURE, UV + vec2(-step.x, 0.0))) > brightness_threshold ||
			brightness(texture(TEXTURE, UV + vec2( step.x, 0.0))) > brightness_threshold ||
			brightness(texture(TEXTURE, UV + vec2(0.0, -step.y))) > brightness_threshold ||
			brightness(texture(TEXTURE, UV + vec2(0.0,  step.y))) > brightness_threshold ||
			(corner_pixel && (
				brightness(texture(TEXTURE, UV + vec2(-step.x, -step.y))) > brightness_threshold ||
				brightness(texture(TEXTURE, UV + vec2( step.x, -step.y))) > brightness_threshold ||
				brightness(texture(TEXTURE, UV + vec2(-step.x,  step.y))) > brightness_threshold ||
				brightness(texture(TEXTURE, UV + vec2( step.x,  step.y))) > brightness_threshold
			));

		if (near_highlighted) {
			COLOR = vec4(1.0, 1.0, 1.0, 1.0);
		} else {
			COLOR = base;
		}
	}
}
