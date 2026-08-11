shader_type canvas_item;

uniform float service_amount : hint_range(0.0, 1.0) = 0.0;
uniform float activity_amount : hint_range(0.0, 1.0) = 0.0;
uniform float unstable_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 disconnected_cable_color : source_color = vec4(0.23, 0.24, 0.27, 1.0);
uniform vec4 connected_cable_color : source_color = vec4(0.92, 0.72, 0.18, 1.0);
uniform vec4 electricity_color : source_color = vec4(0.92, 1.0, 0.92, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float max_other = max(tex.g, tex.b);
	float red_mask = smoothstep(0.12, 0.42, tex.r - max_other) * step(0.05, tex.a);

	float unstable_blink = step(0.0, sin(TIME * 7.0));
	float visible_service = mix(service_amount, service_amount * unstable_blink, unstable_amount);
	float visible_activity = mix(activity_amount, activity_amount * unstable_blink, unstable_amount);
	vec3 cable_base = mix(disconnected_cable_color.rgb, connected_cable_color.rgb, visible_service);
	float wave = 0.5 + 0.5 * sin(UV.x * 30.0 - TIME * 10.0 + UV.y * 7.0);
	float spark = step(0.1, pow(wave, 10.0) * visible_activity);
	float service_glow = 0.12 + 0.20 * visible_service;
	vec3 cable_lit = cable_base * (1.0 + service_glow);
	cable_lit += electricity_color.rgb * spark * 0.9;

	COLOR = vec4(mix(tex.rgb, cable_lit, red_mask), tex.a);
}
