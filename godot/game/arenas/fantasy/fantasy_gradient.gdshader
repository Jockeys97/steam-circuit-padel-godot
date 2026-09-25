// fantasy_gradient.gdshader — the six fantasy arenas' continuous background shell.
//
// Unshaded so it reads as atmosphere rather than a lit surface, and driven by the
// fragment's world height so ONE material works on a dome, a hall wall or a sea
// floor without a per-mesh UV layout. Three stops (bottom, mid at `mid_point`, top)
// plus an optional emissive gain let each arena paint its own sky/sea/rock column.
//
// No per-frame work: nothing here animates, so a shell costs one draw call and no
// script. `haze` mixes a fourth colour in by horizontal distance, which is what
// gives the far silhouettes their depth on top of the geometry's own albedo.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;

uniform vec3 bottom_color : source_color = vec3(0.05, 0.06, 0.10);
uniform vec3 mid_color : source_color = vec3(0.16, 0.20, 0.30);
uniform vec3 top_color : source_color = vec3(0.05, 0.08, 0.16);
uniform float mid_point : hint_range(0.0, 1.0) = 0.5;
uniform float y_min = -20.0;
uniform float y_max = 60.0;
uniform vec3 haze_color : source_color = vec3(0.5, 0.5, 0.6);
uniform float haze_begin = 40.0;
uniform float haze_end = 260.0;
uniform float haze_amount : hint_range(0.0, 1.0) = 0.0;
uniform float energy : hint_range(0.0, 4.0) = 1.0;

// WORLD POSITION, passed explicitly. `VERTEX` inside `fragment()` is NOT world space in
// Godot: the vertex stage output reaches the fragment stage in VIEW space, so reading
// `VERTEX.y` in the fragment gave a height that moved with the camera pitch, and
// `length(VERTEX - CAMERA_POSITION_WORLD)` mixed two different spaces and produced a
// meaningless haze distance. Both are computed here in world space and interpolated.
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = clamp((world_pos.y - y_min) / max(y_max - y_min, 0.001), 0.0, 1.0);
	vec3 col = t < mid_point
		? mix(bottom_color, mid_color, t / max(mid_point, 0.001))
		: mix(mid_color, top_color, (t - mid_point) / max(1.0 - mid_point, 0.001));
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float haze_t = clamp((dist - haze_begin) / max(haze_end - haze_begin, 0.001), 0.0, 1.0);
	col = mix(col, haze_color, haze_t * haze_amount);
	ALBEDO = col * energy;
	EMISSION = col * max(energy - 1.0, 0.0);
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
}
