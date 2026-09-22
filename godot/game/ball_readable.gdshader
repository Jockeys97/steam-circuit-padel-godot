shader_type spatial;
// One opaque pass: stable visibility without glow, transparent shells or trails.
render_mode unshaded;
uniform vec4 ball_color : source_color = vec4(0.84, 0.98, 0.075, 1.0);
uniform vec4 seam_color : source_color = vec4(0.95, 0.98, 0.67, 1.0);
uniform vec4 edge_color : source_color = vec4(0.12, 0.18, 0.025, 1.0);
varying vec3 sphere_normal;

void vertex() {
	sphere_normal = normalize(VERTEX);
}

void fragment() {
	vec3 n = normalize(sphere_normal);
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	// Wavy closed seam. Fade subpixel details rather than introduce shimmer.
	float longitude = atan(n.z, n.x);
	float seam_distance = abs(n.y - 0.42 * sin(2.0 * longitude));
	float pixel_width = max(fwidth(seam_distance), 0.0001);
	float detail = 1.0 - smoothstep(0.04, 0.18, pixel_width);
	float seam = (1.0 - smoothstep(0.015, 0.015 + pixel_width, seam_distance)) * detail;
	// Broad matte shading, never dependent on arena exposure or shadow lights.
	float shade = 0.80 + 0.20 * max(dot(normalize(NORMAL), normalize(vec3(-0.4, 0.6, 1.0))), 0.0);
	vec3 surface = mix(ball_color.rgb, seam_color.rgb, seam * 0.8) * shade;
	float rim = 1.0 - smoothstep(0.10, 0.30, facing);
	ALBEDO = mix(surface, edge_color.rgb, rim * 0.85);
}
