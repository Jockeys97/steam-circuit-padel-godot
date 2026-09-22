shader_type spatial;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 base_color : source_color = vec4(1.0);
void fragment() {
 vec4 source = texture(albedo_texture, UV) * base_color;
 // Only the turquoise canopy family, not people, sponsor marks or metalwork.
 float cyan = smoothstep(0.10,0.28,min(source.g,source.b)-source.r);
 vec3 canvas = vec3(0.085,0.13,0.12) * (0.65+source.g*0.5);
 ALBEDO = mix(source.rgb,canvas,cyan);
 ROUGHNESS = 0.92;
}
