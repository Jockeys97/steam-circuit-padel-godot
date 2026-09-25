// night_windows.gdshader — the skyline towers of "Sopraelevata della Luna": dark facades
// with a grid of windows, some lit warm, a few cool, none on the roofs. The per-tower seed
// comes from the MultiMesh custom data, so every tower lights a different pattern.
shader_type spatial;

uniform vec3 wall_color = vec3(0.045, 0.055, 0.095);
uniform vec3 warm = vec3(1.0, 0.76, 0.42);
uniform vec3 cool = vec3(0.55, 0.75, 1.0);
uniform float lit_share = 0.42;
uniform float energy = 1.8;

varying vec3 world_pos;
varying vec3 world_normal;
varying float tower_seed;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	tower_seed = INSTANCE_CUSTOM.r;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	ALBEDO = wall_color;
	ROUGHNESS = 0.85;
	float facade = 1.0 - step(0.5, abs(world_normal.y));
	float u = abs(world_normal.z) > 0.5 ? world_pos.x : world_pos.z;
	vec2 g = vec2(u / 2.4, world_pos.y / 3.2);
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float window = step(0.22, f.x) * step(f.x, 0.72) * step(0.28, f.y) * step(f.y, 0.74);
	float h = hash(cell + vec2(tower_seed, tower_seed * 1.7));
	float lit = step(1.0 - lit_share, h) * window * facade * step(1.5, world_pos.y);
	vec3 c = mix(warm, cool, step(0.93, h));
	EMISSION = c * lit * energy * (0.6 + 0.4 * hash(cell.yx + tower_seed));
}
