// lava_mask.gdshader — a Meshy prop's own base-colour texture, lit normally, with only its
// molten parts (bright, warm: red well above blue) glowing. Used on the Caldera volcanoes:
// emitting the whole texture turned the dark rock cream in the frame.
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float glow = 3.6;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	ALBEDO = c;
	ROUGHNESS = 0.9;
	float molten = smoothstep(0.30, 0.55, c.r - c.b) * smoothstep(0.35, 0.6, c.r);
	EMISSION = c * molten * glow;
}
