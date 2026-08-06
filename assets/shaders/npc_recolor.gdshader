shader_type canvas_item;

// Reads body_poses_spritesheet.png and head_variants_spritesheet.png
// (both 8x8 grids, 24x24 cells). Columns are outfit types in both
// sheets. Body rows are poses (row 7 is the apron overlay, not a pose);
// head rows are head variants. Assign the spritesheets to "body_sheet" /
// "head_sheet" on the ShaderMaterial; the host node's own texture is not
// used.
//
// "body_type", "body_pose", and "head_variant" are all set once per NPC
// (no animation) - pose/head/outfit are per-instance choices, not
// something that cycles at runtime. Enable "show_apron_overlay" to
// composite row 7 of the body sheet on top. Outline and
// gun_texture/use_gun behavior both mirror npc_with_outline.gdshader
// directly (a flat 1:1 texture, not a grid).

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool corner_pixel = false;

uniform sampler2D body_sheet : filter_nearest;
uniform ivec2 cell_pixel_size = ivec2(24, 24);

uniform sampler2D head_sheet : filter_nearest;
uniform ivec2 head_cell_pixel_size = ivec2(24, 24);
uniform bool show_head_overlay = true;
uniform int head_variant : hint_range(0, 7) = 0;

uniform sampler2D gun_texture : filter_nearest;
uniform bool use_gun = false;

uniform int body_type : hint_enum(
    "Default", "Cowboy", "Investor", "Farmer",
    "Settler", "Outlaw", "Miner", "Undefined"
) = 0;

uniform int body_pose : hint_enum(
    "Standing", "Sitting", "Panic", "Riding",
    "Fight", "Single Gun", "Double Gun", "Carry"
) = 0;

uniform bool show_apron_overlay = false;

// Debug recolor: bucket known material colors into a distinct green per
// category (see debug_palette_categorize.gdshader) so palette coverage
// can be checked directly on the animated pose.
uniform bool debug_recolor = false;
uniform float match_threshold : hint_range(0.0, 0.3) = 0.04;
uniform float green_saturation : hint_range(0.0, 1.0) = 0.75;
uniform float green_value_min : hint_range(0.0, 1.0) = 0.25;
uniform float green_value_max : hint_range(0.0, 1.0) = 0.95;

const int APRON_ROW = 8;

const int MARKER_COUNT = 19;

const vec3 MARKER_COLORS[MARKER_COUNT] = vec3[](
    vec3(0.8706, 0.5804, 0.4157), // #de946a skin dark
    vec3(0.9451, 0.7059, 0.4824), // #f1b47b skin light
    vec3(0.3804, 0.2078, 0.1333), // #613522 hair
    vec3(0.4000, 0.2235, 0.1922), // #663931 leather dark
    vec3(0.5608, 0.3373, 0.2314), // #8f563b leather light
    vec3(0.5098, 0.3686, 0.2235), // #825e39 wool dark
    vec3(0.6353, 0.4588, 0.2784), // #a27547 wool light
    vec3(0.2510, 0.1961, 0.1569), // #403228 black leather dark
    vec3(0.3137, 0.2471, 0.1961), // #503f32 black leather light
    vec3(0.6157, 0.5373, 0.4902), // #9d897d linen dark
    vec3(0.7961, 0.6941, 0.6353), // #cbb1a2 linen light
    vec3(0.2471, 0.2902, 0.4275), // #3f4a6d jeans dark
    vec3(0.3412, 0.4039, 0.5529), // #57678d jeans light
    vec3(0.6745, 0.1961, 0.1961), // #ac3232 decoration bright
    vec3(0.4902, 0.1647, 0.2039), // #7d2a34 decoration dark
    vec3(0.8627, 0.7137, 0.1647), // #dcb62a belt buckle
    vec3(0.0863, 0.1020, 0.1216), // #161a1f suit black
    vec3(0.1333, 0.1255, 0.2039), // #222034 suit dark
    vec3(0.2196, 0.2157, 0.2667)  // #383744 suit light
);

// Category per marker, in the same order as MARKER_COLORS above.
// 0 = skin, 1 = hair, 2 = leather, 3 = wool, 4 = black_leather, 5 = linen,
// 6 = jeans, 7 = decoration, 8 = belt_buckle, 9 = suit
const int MARKER_CATEGORY[MARKER_COUNT] = int[](
    0, 0,
    1,
    2, 2,
    3, 3,
    4, 4,
    5, 5,
    6, 6,
    7, 7,
    8,
    9, 9, 9
);

const int CATEGORY_COUNT = 10;

// Random "channels": a handful of shared per-NPC random values that
// categories can be assigned to (see the "*_random_channel" uniforms
// below). Categories on the same channel move together (e.g. jeans
// linked to skin, or a linen shirt linked to hair) - each category's own
// *_hue_shift_range / *_brightness_range still controls how far it
// personally moves, only the direction/magnitude is shared. One channel
// per category by default, so nothing is linked out of the box - assign
// two categories the same channel letter to link them.
//
// channel_hue_random / channel_brightness_random are set once per NPC
// (e.g. from NPCLookInfo, via randf_range(-1.0, 1.0) per channel) rather
// than driven by an in-shader RNG, so the same NPC looks identical every
// frame and every NPC gets independently randomized colors.
const int CHANNEL_COUNT = 10;
uniform float channel_hue_random[CHANNEL_COUNT];
uniform float channel_brightness_random[CHANNEL_COUNT];

// Real hue-shift recoloring. Masking uses the same nearest-known-color
// match as the green debug bucket-test (MARKER_COLORS/MARKER_CATEGORY
// below) rather than a hue-only band: a hue-only mask can't separate
// categories that share nearly the same hue but differ in saturation or
// value (e.g. skin vs. black_leather), and skin's own shading ramp turned
// out to vary in hue more than a single center+radius could capture.
// Once a category is determined, its hue and brightness (HSV value) are
// each offset by +-range * channel_*_random[channel] (a range of 0 means
// "no change" for that category).
uniform bool hue_shift_recolor = true;
uniform float hue_shift_match_threshold : hint_range(0.0, 0.3) = 0.04;

// Debug isolation: when not "All Categories", every pixel that would
// have matched a *different* category is forced to pass through raw,
// so exactly one category's behavior can be inspected with zero
// interference from the others. Defaults to "All Categories" - only
// narrow this while debugging a specific category, not for production.
uniform int solo_category : hint_enum(
    "All Categories", "Skin", "Hair", "Leather", "Wool", "Black Leather",
    "Linen", "Jeans", "Decoration", "Belt Buckle", "Suit"
) = 0;

// Uniform arrays can't carry inline default values in Godot's shader
// language (only const/local arrays can), so each category gets its own
// scalar uniforms here instead, grouped for the Inspector.

// "*_random_channel" assigns which of the CHANNEL_COUNT shared
// oscillators drives that category. Each category defaults to its own
// channel (no links), so nothing moves together out of the box - give
// two categories the same letter to link them (e.g. jeans + skin).

group_uniforms skin;
uniform float skin_hue_shift_range : hint_range(0.0, 0.5) = 0.04;
uniform float skin_brightness_range : hint_range(0.0, 1.0) = 0.06;
uniform int skin_random_channel : hint_enum("A", "B", "C", "D", "E", "F", "G", "H", "I", "J") = 0;

group_uniforms hair;
uniform float hair_hue_shift_range : hint_range(0.0, 0.5) = 0.08;
uniform float hair_brightness_range : hint_range(0.0, 1.0) = 0.08;
uniform int hair_random_channel : hint_enum("A", "B", "C", "D", "E", "F", "G", "H", "I", "J") = 1;

group_uniforms leather;
uniform float leather_hue_shift_range : hint_range(0.0, 0.5) = 0.02;
uniform float leather_brightness_range : hint_range(0.0, 1.0) = 0.05;
uniform int leather_random_channel : hint_enum("A", "B", "C", "D", "E", "F", "G", "H", "I", "J") = 2;

group_uniforms wool;
uniform float wool_hue_shift_range : hint_range(0.0, 0.5) = 0.15;
uniform float wool_brightness_range : hint_range(0.0, 1.0) = 0.12;
uniform int wool_random_channel : hint_enum("A", "B", "C", "D", "E", "F", "G", "H", "I", "J") = 3;

group_uniforms black_leather;
uniform float black_leather_hue_shift_range : hint_range(0.0, 0.5) = 0.02;
uniform float black_leather_brightness_range : hint_range(0.0, 1.0) = 0.05;
uniform int black_leather_random_channel : hint_enum("A", "B", "C", "D", "E", "F", "G", "H", "I", "J") = 4;

group_uniforms linen;
uniform float linen_hue_shift_range : hint_range(0.0, 0.5) = 0.15;
uniform float linen_brightness_range : hint_range(0.0, 1.0) = 0.12;
uniform int linen_random_channel : hint_enum("A", "B", "C", "D", "E", "F", "G", "H", "I", "J") = 5;

group_uniforms jeans;
uniform float jeans_hue_shift_range : hint_range(0.0, 0.5) = 0.5;
uniform float jeans_brightness_range : hint_range(0.0, 1.0) = 0.2;
uniform int jeans_random_channel : hint_enum("A", "B", "C", "D", "E", "F", "G", "H", "I", "J") = 6;

group_uniforms decoration;
uniform float decoration_hue_shift_range : hint_range(0.0, 0.5) = 0.5;
uniform float decoration_brightness_range : hint_range(0.0, 1.0) = 0.2;
uniform int decoration_random_channel : hint_enum("A", "B", "C", "D", "E", "F", "G", "H", "I", "J") = 7;

group_uniforms belt_buckle;
uniform float belt_buckle_hue_shift_range : hint_range(0.0, 0.5) = 0.03;
uniform float belt_buckle_brightness_range : hint_range(0.0, 1.0) = 0.08;
uniform int belt_buckle_random_channel : hint_enum("A", "B", "C", "D", "E", "F", "G", "H", "I", "J") = 8;

group_uniforms suit;
uniform float suit_hue_shift_range : hint_range(0.0, 0.5) = 0.15;
uniform float suit_brightness_range : hint_range(0.0, 1.0) = 0.12;
uniform int suit_random_channel : hint_enum("A", "B", "C", "D", "E", "F", "G", "H", "I", "J") = 9;

group_uniforms;

varying vec4 modulate_color;

ivec2 posmod(ivec2 a, ivec2 b) {
    return ivec2(
        ((a.x % b.x) + b.x) % b.x,
        ((a.y % b.y) + b.y) % b.y
    );
}

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 0.00001;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
    vec3 rgb = clamp(abs(mod(c.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
    return c.z * mix(vec3(1.0), rgb, c.y);
}

vec4 hue_shift_categorize(vec4 raw) {
    // Mask by nearest known literal color (same approach as the green
    // debug bucket-test), not by hue distance - see the comment above
    // hue_shift_recolor for why.
    float best_dist = 1.0e9;
    int best_marker = -1;
    for (int i = 0; i < MARKER_COUNT; i++) {
        float d = distance(raw.rgb, MARKER_COLORS[i]);
        if (d < best_dist) {
            best_dist = d;
            best_marker = i;
        }
    }

    if (best_marker == -1 || best_dist > hue_shift_match_threshold) {
        return raw;
    }

    int category = MARKER_CATEGORY[best_marker];

    if (solo_category != 0 && category != solo_category - 1) {
        return raw;
    }

    // Local arrays (unlike uniform arrays) may be built from arbitrary
    // expressions, so assemble them here from the per-category uniforms.
    float hue_range[CATEGORY_COUNT] = float[](
        skin_hue_shift_range, hair_hue_shift_range, leather_hue_shift_range, wool_hue_shift_range,
        black_leather_hue_shift_range, linen_hue_shift_range, jeans_hue_shift_range,
        decoration_hue_shift_range, belt_buckle_hue_shift_range, suit_hue_shift_range
    );
    float brightness_range[CATEGORY_COUNT] = float[](
        skin_brightness_range, hair_brightness_range, leather_brightness_range, wool_brightness_range,
        black_leather_brightness_range, linen_brightness_range, jeans_brightness_range,
        decoration_brightness_range, belt_buckle_brightness_range, suit_brightness_range
    );
    int channel[CATEGORY_COUNT] = int[](
        skin_random_channel, hair_random_channel, leather_random_channel, wool_random_channel,
        black_leather_random_channel, linen_random_channel, jeans_random_channel,
        decoration_random_channel, belt_buckle_random_channel, suit_random_channel
    );

    // Categories assigned to the same channel share the same random
    // value, so they move together.
    int ch = channel[category];
    float r_hue = channel_hue_random[ch];
    float r_brightness = channel_brightness_random[ch];

    vec3 hsv = rgb2hsv(raw.rgb);
    hsv.x = fract(hsv.x + hue_range[category] * r_hue);
    hsv.z = clamp(hsv.z + brightness_range[category] * r_brightness, 0.0, 1.0);
    return vec4(hsv2rgb(hsv), raw.a);
}

vec4 sample_cell(sampler2D sheet, ivec2 cell_pixels, ivec2 cell_index, vec2 uv) {
    ivec2 sheet_pixel_size = textureSize(sheet, 0);
    ivec2 cell_count = max(sheet_pixel_size / cell_pixels, ivec2(1, 1));
    ivec2 index = posmod(cell_index, cell_count);
    vec2 cell_uv_size = 1.0 / vec2(cell_count);
    vec2 cell_origin = vec2(index) * cell_uv_size;
    vec2 sheet_uv = cell_origin + uv * cell_uv_size;
    return texture(sheet, sheet_uv);
}

vec4 categorize(vec4 raw) {
    float best_dist = 1.0e9;
    int best_marker = -1;

    for (int i = 0; i < MARKER_COUNT; i++) {
        float d = distance(raw.rgb, MARKER_COLORS[i]);
        if (d < best_dist) {
            best_dist = d;
            best_marker = i;
        }
    }

    if (best_marker == -1 || best_dist > match_threshold) {
        return raw;
    }

    int category = MARKER_CATEGORY[best_marker];
    float t = float(category) / float(CATEGORY_COUNT - 1);
    float value = mix(green_value_min, green_value_max, t);
    vec3 green = hsv2rgb(vec3(1.0 / 3.0, green_saturation, value));

    return vec4(green, raw.a);
}

vec4 composite(vec2 uv) {
    vec4 result = sample_cell(body_sheet, cell_pixel_size, ivec2(body_type, body_pose), uv);

    if (show_apron_overlay) {
        vec4 apron = sample_cell(body_sheet, cell_pixel_size, ivec2(body_type, APRON_ROW), uv);
        result = mix(result, apron, apron.a);
    }

    if (show_head_overlay) {
        vec4 head = sample_cell(head_sheet, head_cell_pixel_size, ivec2(body_type, head_variant), uv);
        result = mix(result, head, head.a);
    }

    if (use_gun) {
        vec4 gun = texture(gun_texture, uv);
        result = mix(result, gun, gun.a);
    }

    if (debug_recolor) {
        result = categorize(result);
    } else if (hue_shift_recolor) {
        result = hue_shift_categorize(result);
    }

    return result;
}

vec4 sample_composite(vec2 uv) {
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
        return vec4(0.0);
    return composite(uv);
}

void vertex() {
    modulate_color = COLOR;
    // Expand the mesh 1px outward on all sides so the outline has room
    // to render beyond the base sprite boundary.
    vec2 dir = sign(UV - 0.5);
    VERTEX += dir * 1.0;
    UV += dir * (1.0 / vec2(cell_pixel_size));
}

void fragment() {
    vec4 comp = sample_composite(UV);
    vec2 px = 1.0 / vec2(cell_pixel_size);

    if (comp.a > 0.0) {
        COLOR = comp * modulate_color;
    } else {
        bool valid_side =
            sample_composite(UV + vec2(-px.x, 0.0)).a > 0.0 ||
            sample_composite(UV + vec2( px.x, 0.0)).a > 0.0 ||
            sample_composite(UV + vec2(0.0, -px.y)).a > 0.0 ||
            sample_composite(UV + vec2(0.0,  px.y)).a > 0.0;

        bool valid_corner =
            sample_composite(UV + vec2(-px.x, -px.y)).a > 0.0 ||
            sample_composite(UV + vec2( px.x, -px.y)).a > 0.0 ||
            sample_composite(UV + vec2(-px.x,  px.y)).a > 0.0 ||
            sample_composite(UV + vec2( px.x,  px.y)).a > 0.0;

        if (valid_side || (corner_pixel && valid_corner)) {
            COLOR = outline_color * modulate_color;
        } else {
            COLOR = vec4(0.0);
        }
    }
}
