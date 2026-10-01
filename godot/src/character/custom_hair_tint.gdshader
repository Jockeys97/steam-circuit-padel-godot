// custom_hair_tint.gdshader — a "Crea atleta" hair piece, generated in neutral grey, tinted
// to the chosen hair colour keeping its own clump shading (2026-09-27).
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec3 hair_color : source_color = vec3(0.35, 0.23, 0.14);
uniform float ref_lum = 0.72;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	ALBEDO = clamp(hair_color * (lum / ref_lum) * 1.1, 0.0, 1.0);
	ROUGHNESS = 0.7;
}
