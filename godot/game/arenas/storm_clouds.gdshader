// storm_clouds.gdshader — the cloud sea under "Bastione della Tempesta": dark rolling
// storm clouds below the deck, drifting slowly, briefly lit from inside by `flash`
// (driven by the arena's lightning, 0..1). World-space so no tile seams.
shader_type spatial;
render_mode unshaded;

uniform vec3 deep = vec3(0.03, 0.05, 0.12);
uniform vec3 lit = vec3(0.24, 0.33, 0.55);
uniform vec3 flash_tint = vec3(0.65, 0.80, 1.0);
uniform float flash = 0.0;
uniform vec2 drift = vec2(0.010, 0.006);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int k = 0; k < 5; k++) { v += a * noise(p); p *= 2.02; a *= 0.5; }
	return v;
}

void fragment() {
	vec2 p = world_pos.xz * 0.025 + TIME * drift;
	float n = fbm(p + fbm(p * 1.3 + TIME * drift * 0.5));
	float puff = smoothstep(0.35, 0.8, n);
	vec3 c = mix(deep, lit, puff);
	c += flash_tint * flash * puff * 0.9;
	float fade = clamp(1.0 - length(world_pos.xz) / 520.0, 0.0, 1.0);
	ALBEDO = mix(deep, c, fade);
}
