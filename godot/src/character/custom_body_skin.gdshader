// custom_body_skin.gdshader — recolours a "Crea atleta" Meshy body (2026-09-27).
//
// The bodies were generated in fixed neutral colours on purpose
// (art/character-creator/RICHIESTA-2D-CORPI.md): a light grey t-shirt, mid grey shorts,
// white socks, charcoal shoes, one even skin tone. Each region is found by colour AND by
// height on the body (so the white socks and the eyes never take the shirt colour), and
// re-tinted keeping the texture's own shading (its luminance over the reference's).
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec3 shirt_color : source_color = vec3(0.85, 0.30, 0.26);
uniform vec3 shorts_color : source_color = vec3(0.12, 0.16, 0.20);
uniform vec3 skin_color : source_color = vec3(0.79, 0.56, 0.39);
// World-space heights relative to the mesh node's origin, set from the mesh's rest bounds.
uniform float feet_y = 0.0;
uniform float body_height = 1.75;
// The generated texture's own reference tones (measured on the four bodies).
uniform float shirt_ref_lum = 0.84;
uniform float shorts_ref_lum = 0.48;
uniform float skin_ref_lum = 0.55;

varying float h;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	h = clamp((world.y - origin.y - feet_y) / max(body_height, 0.01), 0.0, 1.2);
}

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.001);
	float lum = luma(c);
	float neutral = 1.0 - smoothstep(0.07, 0.14, sat);
	// Shirt: light, neutral, between the hips and the shoulders.
	float shirt = neutral * smoothstep(0.55, 0.66, lum) * smoothstep(0.44, 0.50, h) * (1.0 - smoothstep(0.86, 0.885, h));
	// Shorts: mid grey, neutral, from mid-thigh to the hips.
	float shorts = neutral * smoothstep(0.22, 0.30, lum) * (1.0 - smoothstep(0.62, 0.70, lum)) * smoothstep(0.30, 0.36, h) * (1.0 - smoothstep(0.52, 0.58, h));
	// Skin: warm and saturated, anywhere.
	float warm = step(c.b, c.r) * step(c.b, c.g + 0.08);
	float skin = warm * smoothstep(0.18, 0.30, sat) * (1.0 - max(shirt, shorts));
	vec3 out_c = c;
	out_c = mix(out_c, shirt_color * (lum / shirt_ref_lum), shirt);
	out_c = mix(out_c, shorts_color * (lum / shorts_ref_lum), shorts);
	out_c = mix(out_c, skin_color * (lum / skin_ref_lum), skin);
	ALBEDO = clamp(out_c, 0.0, 1.0);
	ROUGHNESS = 0.8;
}
