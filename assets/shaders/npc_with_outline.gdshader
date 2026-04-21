shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool corner_pixel = false;
uniform sampler2D sprite_sheet : filter_nearest;
uniform ivec2 sprite_index = ivec2(0, 0);
uniform vec2 cell_pixel_size = vec2(24.0, 16.0);
uniform vec3 base_hue_offset = vec3(0.1, -0.33, 0.0);

uniform sampler2D apron_sheet : filter_nearest;
uniform bool use_apron = false;

uniform sampler2D gun_texture : filter_nearest;
uniform bool use_gun = false;

const vec3 rgbh = vec3(0.0, 0.333333,  0.666667);

varying vec4 modulate_color;

ivec2 posmod(ivec2 a, ivec2 b) {
    return ivec2(
        ((a.x % b.x) + b.x) % b.x,
        ((a.y % b.y) + b.y) % b.y
    );
}

vec3 rgb2hsv(vec3 c) { vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0); vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g)); vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r)); float d = q.x - min(q.w, q.y); float e = 0.00001; return vec3( abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x ); } vec3 hsv2rgb(vec3 c) { vec3 rgb = clamp(abs(mod(c.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0); return c.z * mix(vec3(1.0), rgb, c.y); }

float mask_to_float(vec3 one, vec3 two) {
	vec3 v3 = one * two;
	return v3.x + v3.y + v3.z;
}

void vertex() {
    modulate_color = COLOR;
}

float hue_dist(float a, float b) {
    float d = abs(a - b);
    return min(d, 1.0 - d);
}

vec4 tint_rgb(vec4 base, sampler2D tex, vec2 uv, vec3 filter) {
    vec4 raw = texture(tex, uv);
    vec3 hsv = rgb2hsv(raw.rgb);

    float target = mask_to_float(rgbh, filter);
    float delta = hue_dist(hsv.x, target);

    float threshold = 0.05;
    float mask = 1.0 - step(threshold, delta);

    float offset = mask_to_float(base_hue_offset, filter);
    hsv.x = fract(hsv.x + offset);
    raw.rgb = hsv2rgb(hsv);

    //return vec4(delta * 1.0, delta * 1.0, delta * 1.0, 1.0);
    return mix(base, raw, mask);
}

vec4 base_color(sampler2D tex, vec2 uv) {
    vec4 raw = texture(tex, uv);
	raw = tint_rgb(raw, tex, uv, vec3(1.0, 0.0, 0.0));
	raw = tint_rgb(raw, tex, uv, vec3(0.0, 1.0, 0.0));
	raw = tint_rgb(raw, tex, uv, vec3(0.0, 0.0, 1.0));
	return raw;
}

vec4 composite(sampler2D tex, vec2 uv, vec2 tex_pixel_size) {
    vec4 base = base_color(tex, uv);

    vec2 region_pixel_size = 1.0 / tex_pixel_size;

    ivec2 sheet_pixel_size = textureSize(sprite_sheet, 0);
    ivec2 cell_count = max(sheet_pixel_size / ivec2(cell_pixel_size), ivec2(1, 1));
    ivec2 wrapped_index = posmod(sprite_index, cell_count);

    vec2 cell_uv_size = 1.0 / vec2(cell_count);
    vec2 cell_origin = vec2(wrapped_index) * cell_uv_size;

    vec2 scaled_uv = uv * (region_pixel_size / cell_pixel_size);
    vec2 sheet_uv = cell_origin + scaled_uv * cell_uv_size;

    vec4 overlay = texture(sprite_sheet, sheet_uv);

    float mask = 1.0 - step(0.71, uv.y);
    vec4 result = mix(base, overlay, overlay.a * mask);

    if (use_apron) {
        vec4 apron = texture(apron_sheet, uv);
        result = mix(result, apron, apron.a);
    }
	
	if (use_gun) {
        vec4 gun = texture(gun_texture, uv);
        result = mix(result, gun, gun.a);
    }
    return result;
}
void fragment() {
    vec4 comp = composite(TEXTURE, UV, TEXTURE_PIXEL_SIZE);

    if (comp.a > 0.0) {
        COLOR = comp * modulate_color;
    } else {
        vec2 px = TEXTURE_PIXEL_SIZE;

        bool valid_side =
            composite(TEXTURE, UV + vec2(-px.x, 0.0), TEXTURE_PIXEL_SIZE).a > 0.0 ||
            composite(TEXTURE, UV + vec2( px.x, 0.0), TEXTURE_PIXEL_SIZE).a > 0.0 ||
            composite(TEXTURE, UV + vec2(0.0, -px.y), TEXTURE_PIXEL_SIZE).a > 0.0 ||
            composite(TEXTURE, UV + vec2(0.0,  px.y), TEXTURE_PIXEL_SIZE).a > 0.0;

        bool valid_corner =
            composite(TEXTURE, UV + vec2(-px.x, -px.y), TEXTURE_PIXEL_SIZE).a > 0.0 ||
            composite(TEXTURE, UV + vec2( px.x, -px.y), TEXTURE_PIXEL_SIZE).a > 0.0 ||
            composite(TEXTURE, UV + vec2(-px.x,  px.y), TEXTURE_PIXEL_SIZE).a > 0.0 ||
            composite(TEXTURE, UV + vec2( px.x,  px.y), TEXTURE_PIXEL_SIZE).a > 0.0;

        if (valid_side || (corner_pixel && valid_corner)) {
            COLOR = outline_color * modulate_color;
        } else {
            COLOR = vec4(0.0);
        }
    }
}