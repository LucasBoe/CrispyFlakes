shader_type canvas_item;

uniform vec4 fill_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    float alpha = texture(TEXTURE, UV).a;
    COLOR = vec4(fill_color.rgb, fill_color.a * alpha);
}
