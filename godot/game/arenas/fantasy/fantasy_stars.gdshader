// fantasy_stars.gdshader — Orrery's starfield shell (and the Abyssal deep field).
//
// A hashed point field over the shell's own UV, so a single sphere or wall gives a
// continuous star field with no texture and no draw cost beyond itself. `twinkle` is
// bounded and slow by construction — the amplitude is capped at 0.35 and the rate at
// ~0.5 rad/s — so the field shimmers instead of blinking. `nebula_amount` mixes a
// second, much larger-scale field under the stars for the reference's galaxy band.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;

uniform vec3 sky_low : source_color = vec3(0.02, 0.02, 0.08);
uniform vec3 sky_high : source_color = vec3(0.06, 0.05, 0.20);
uniform vec3 star_color : source_color = vec3(0.92, 0.95, 1.0);
uniform vec3 warm_star_color : source_color = vec3(1.0, 0.86, 0.62);
uniform vec3 nebula_color : source_color = vec3(0.42, 0.24, 0.72);
uniform float density = 220.0;
uniform float star_size : hint_range(0.0005, 0.02) = 0.004;
uniform float twinkle : hint_range(0.0, 0.35) = 0.18;
uniform float nebula_amount : hint_range(0.0, 1.0) = 0.45;
uniform float energy : hint_range(0.0, 3.0) = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void fragment() {
	vec3 col = mix(sky_low, sky_high, clamp(UV.y, 0.0, 1.0));
	// Slow, large-scale nebula wash.
	float n = sin(UV.x * 9.4 + 1.3) * 0.5 + 0.5;
	float n2 = sin(UV.y * 5.1 - 2.1) * 0.5 + 0.5;
	float neb = clamp((n * n2) * 1.4, 0.0, 1.0);
	col = mix(col, nebula_color, neb * nebula_amount);
	// Star field: one candidate per cell, kept when the hash clears the threshold.
	vec2 cell = floor(UV * density);
	vec2 local = fract(UV * density);
	float h = hash21(cell);
	if (h > 0.90) {
		vec2 at = vec2(hash21(cell + 3.1), hash21(cell + 7.7));
		float d = length(local - at);
		// `1.0 - smoothstep(0.0, edge, d)` rather than `smoothstep(edge, 0.0, d)`: the
		// reversed-edge form is defined but reads backwards, and the explicit subtraction
		// states "a bright disc of radius `edge`" without relying on which way the ramp runs.
		float bright = 1.0 - smoothstep(0.0, star_size * 60.0, d);
		float flick = 1.0 - twinkle + twinkle * (sin(TIME * 0.5 + h * 40.0) * 0.5 + 0.5) * 2.0;
		vec3 sc = mix(star_color, warm_star_color, h);
		col += sc * bright * flick * 1.6;
	}
	ALBEDO = col * energy;
	EMISSION = col * energy;
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
}
