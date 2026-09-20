shader_type canvas_item;
uniform bool enabled = true;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	if (enabled) {
		float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
		COLOR = vec4(vec3(luminance), source.a);
	} else {
		COLOR = source * COLOR;
	}
}
