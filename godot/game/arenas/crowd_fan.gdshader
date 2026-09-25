// crowd_fan.gdshader — one 3D spectator type (the owner's Meshy fans, 2026-09-25), drawn as
// a MultiMesh. Per instance (INSTANCE_CUSTOM): r = phase, g/b/a = shirt tint.
// The t-shirt (and the scarf) were generated light neutral grey on purpose: texels that are
// bright and unsaturated take the tint, skin/hair/trousers keep their own colour.
// Motion is all here, driven by three uniforms the crowd node sets once a frame: an idle
// bob, a lean-in during long rallies, a jump on a point, and the torso turning towards the
// ball. The vertex shader only moves the model; it never leaves the seat's footprint.
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float t = 0.0;         // seconds
uniform float bob = 0.035;     // metres of idle/cheer vertical travel (model space scaled)
uniform float rate = 2.8;      // radians per second of the bob
uniform float lean = 0.0;      // 0..1, long-rally lean towards the court
uniform float jump = 0.0;      // 0..1, a point just landed
uniform float ball_z = 0.0;    // world z of the ball: the stands run along the court length (z)
uniform float model_h = 1.15;  // metres: the scale the instances carry

varying vec3 tint;

void vertex() {
	float phase = INSTANCE_CUSTOM.r * 6.2831;
	tint = INSTANCE_CUSTOM.gba;
	// Height of this vertex in the model (the GLB is 1 tall, centred): 0 feet .. 1 head.
	float up = clamp(VERTEX.y + 0.5, 0.0, 1.0);
	// Torso turn towards the ball, only above the hips, a few degrees.
	vec3 inst = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float turn = clamp((ball_z - inst.z) * 0.035, -0.35, 0.35) * smoothstep(0.35, 0.75, up);
	float c = cos(turn); float s = sin(turn);
	VERTEX.xz = mat2(vec2(c, -s), vec2(s, c)) * VERTEX.xz;
	// Lean in (towards the model's front, +Z) with the upper body during long rallies.
	VERTEX.z += lean * 0.08 * smoothstep(0.35, 1.0, up);
	// Bob + jump: the whole body, in model units (1 = the fan's height).
	float b = abs(sin(t * rate + phase));
	VERTEX.y += (bob / model_h) * b + jump * 0.22 * b;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float shirt = smoothstep(0.62, 0.78, mx) * (1.0 - smoothstep(0.06, 0.14, mx - mn));
	ALBEDO = mix(c, tint * (0.55 + 0.45 * mx), shirt);
	ROUGHNESS = 0.85;
}
