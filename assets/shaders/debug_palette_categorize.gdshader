shader_type canvas_item;

// Debug/test shader: matches each pixel against a fixed set of known
// "real" material colors and recolors it to a shade of green that is
// unique per category (skin, hair, leather, wool, black_leather, linen,
// jeans) but identical across the dark/light variants of that category.
// Use this to visually verify that a sprite's palette cleanly separates
// into the intended material categories before wiring up real recoloring.

uniform float match_threshold : hint_range(0.0, 0.3) = 0.04;
uniform float green_saturation : hint_range(0.0, 1.0) = 0.75;
uniform float green_value_min : hint_range(0.0, 1.0) = 0.25;
uniform float green_value_max : hint_range(0.0, 1.0) = 0.95;
uniform bool show_unmatched_as_original = true;

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

vec3 hsv2rgb(vec3 c) {
    vec3 rgb = clamp(abs(mod(c.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
    return c.z * mix(vec3(1.0), rgb, c.y);
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
        return show_unmatched_as_original ? raw : vec4(0.0, 0.0, 0.0, 0.0);
    }

    int category = MARKER_CATEGORY[best_marker];
    float t = float(category) / float(CATEGORY_COUNT - 1);
    float value = mix(green_value_min, green_value_max, t);
    vec3 green = hsv2rgb(vec3(1.0 / 3.0, green_saturation, value));

    return vec4(green, raw.a);
}

void fragment() {
    vec4 raw = texture(TEXTURE, UV);
    COLOR = categorize(raw);
}
