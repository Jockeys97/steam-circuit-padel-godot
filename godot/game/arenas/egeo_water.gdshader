shader_type spatial;
render_mode unshaded, cull_back;

// Opaque analytic water: no screen/depth reads, reflection viewport or textures.
uniform float wave_time = -1.0; // Negative uses TIME; fixed value for capture tests.
uniform vec2 coast_extent = vec2(18.0, 17.0);
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float t = wave_time < 0.0 ? TIME : wave_time;
	vec2 p = world_position.xz;
	float distance_to_eye = length(CAMERA_POSITION_WORLD - world_position);
	// Filter fine ripples before they become sub-pixel sparkles at the horizon.
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	float fine = 1.0 - smoothstep(0.18, 1.4, footprint);
	float a = dot(p, vec2(0.65, 0.31)) + t * 0.55 + sin(p.y * 0.19 + p.x * 0.11) * 1.7;
	float b = dot(p, vec2(-0.29, 0.83)) - t * 0.42 + sin(p.x * 0.23 - p.y * 0.07) * 1.4;
	float c = dot(p, vec2(2.3, 1.7)) + t * 0.8;
	float swell_filter = 1.0 - smoothstep(0.8, 5.0, footprint);
	vec2 slope = vec2(0.65, 0.31) * cos(a) * 0.045 * swell_filter;
	slope += vec2(-0.29, 0.83) * cos(b) * 0.04 * swell_filter;
	slope += vec2(2.3, 1.7) * cos(c) * 0.016 * fine;
	vec3 n = normalize(vec3(-slope.x, 1.0, -slope.y));
	vec3 view_direction = normalize(CAMERA_POSITION_WORLD - world_position);
	float fresnel = pow(1.0 - max(dot(n, view_direction), 0.0), 4.0);
	// Distance from terrace footprint approximates coastal colour, not bathymetry.
	vec2 q = abs(p) - coast_extent;
	float coast = length(max(q, vec2(0.0)));
	float shallow = exp(-coast * 0.10);
	vec3 colour = mix(vec3(0.025, 0.19, 0.29), vec3(0.04, 0.43, 0.46), shallow);
	colour *= 1.0 + (sin(a) + sin(b)) * 0.025 * swell_filter;
	vec3 reflected_sky = vec3(0.40, 0.65, 0.76);
	colour = mix(colour, reflected_sky, fresnel * 0.68);
	vec3 sun_direction = normalize(vec3(-0.25, 0.83, 0.50));
	vec3 half_direction = normalize(view_direction + sun_direction);
	float glint = pow(max(dot(n, half_direction), 0.0), 48.0);
	colour += vec3(0.95, 0.84, 0.62) * glint * 0.22;
	float wash = 0.5 + 0.5 * sin(coast * 4.0 - t * 0.65 + sin(a) * 0.4);
	float foam = exp(-coast * 1.8) * smoothstep(0.62, 0.95, wash) * fine;
	colour = mix(colour, vec3(0.67, 0.84, 0.82), foam * 0.28);
	colour = mix(colour, reflected_sky, smoothstep(180.0, 1000.0, distance_to_eye) * 0.6);
	ALBEDO = colour;
}
