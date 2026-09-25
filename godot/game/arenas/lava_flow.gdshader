// lava_flow.gdshader — the moat of "Caldera del Titano": slow flowing molten rock, crusted
// dark plates drifting over a hot core. World-space noise so tiles never show a seam;
// bounded speed so it never strobes behind the play.
shader_type spatial;

uniform vec3 hot = vec3(0.95, 0.28, 0.05);
uniform vec3 core = vec3(1.0, 0.62, 0.18);
uniform vec3 crust = vec3(0.10, 0.03, 0.02);
uniform float energy = 1.5;
uniform vec2 flow = vec2(0.035, 0.022);

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
	for (int k = 0; k < 4; k++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void fragment() {
	vec2 p = world_pos.xz * 0.35;
	float n = fbm(p + TIME * flow * 4.0);
	float m = fbm(p * 1.7 - TIME * flow * 2.5 + n);
	float heat = smoothstep(0.42, 0.78, m);
	vec3 molten = mix(hot, core, smoothstep(0.7, 0.95, m));
	float crusted = smoothstep(0.52, 0.34, m);
	ALBEDO = mix(molten * 0.25, crust, crusted);
	ROUGHNESS = 0.9;
	EMISSION = molten * heat * energy * (1.0 - crusted * 0.9);
}
