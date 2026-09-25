shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 steam_tint : source_color = vec4(0.62, 0.88, 0.91, 0.22);

void vertex() {
	float rise = UV.y;
	VERTEX.x += 0.12 * sin(TIME * 0.65 + rise * 5.0);
}

void fragment() {
	float width_fade = smoothstep(0.0, 0.24, UV.x) * (1.0 - smoothstep(0.76, 1.0, UV.x));
	float height_fade = sin(UV.y * 3.14159265);
	float breath = 0.72 + 0.16 * sin(TIME * 0.8 + UV.y * 7.0);
	ALBEDO = steam_tint.rgb;
	ALPHA = steam_tint.a * width_fade * height_fade * breath;
}
