// fantasy_drift.gdshader — bounded, slow volumetric-looking layers.
//
// One material covers the arenas' moving atmosphere: storm cloud banks, submarine
// depth haze, rising lava/ember glow and drifting dust. The motion is a pair of
// sine-scrolled value bands at deliberately low frequencies and a capped amplitude,
// so nothing can strobe (the storm mandate: "restrained distant lightning, no rapid
// strobe") and the cost stays one draw call per layer with zero per-frame script.
//
// `pulse_speed` is in radians/second and `pulse_amount` caps the brightness swing;
// the six arena builders keep both far below one cycle per second.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled, blend_mix;

uniform vec3 color_a : source_color = vec3(0.20, 0.35, 0.55);
uniform vec3 color_b : source_color = vec3(0.55, 0.75, 0.95);
uniform float scale = 0.05;
uniform float speed = 0.02;
uniform float band_strength : hint_range(0.0, 2.0) = 1.0;
uniform float pulse_speed = 0.15;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.10;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform float energy : hint_range(0.0, 4.0) = 1.0;
uniform float edge_fade : hint_range(0.0, 1.0) = 0.0;

float bands(vec2 p, float t) {
	float a = sin(p.y * 1.0 + t * 0.7) * 0.5 + 0.5;
	float b = sin(p.x * 0.62 - t * 0.43 + 1.7) * 0.5 + 0.5;
	float c = sin((p.x + p.y) * 0.31 + t * 0.29 + 4.1) * 0.5 + 0.5;
	return clamp((a * 0.5 + b * 0.32 + c * 0.18), 0.0, 1.0);
}

void fragment() {
	vec2 p = UV * scale * 60.0;
	float t = TIME * speed * 60.0;
	float g = bands(p, t);
	vec3 col = mix(color_a, color_b, smoothstep(0.25, 0.85, g) * band_strength);
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;
	float a = alpha;
	if (edge_fade > 0.0) {
		float e = min(min(UV.x, UV.y), min(1.0 - UV.x, 1.0 - UV.y));
		a *= mix(1.0, smoothstep(0.0, 0.22, e), edge_fade);
	}
	ALBEDO = col * energy;
	EMISSION = col * energy * 0.6 * pulse;
	ALPHA = a;
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
}
