shader_type spatial;
render_mode cull_back;
uniform vec4 tint : source_color = vec4(0.2,0.15,0.12,1.0);
uniform bool masonry = false;
uniform bool floor_tiles = false;
uniform float metalness = 0.0;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
 vec2 p = floor_tiles ? world.xz : world.xy;
 float grain = mix(0.5,hash(floor(p*95.0)),1.0-smoothstep(0.005,0.035,length(fwidth(p))));
 vec3 color = tint.rgb * (0.96 + grain*0.06);
 if (masonry || floor_tiles) {
  vec2 grid = p / (floor_tiles ? vec2(1.5,2.0) : vec2(0.70,0.28));
  if (!floor_tiles) { grid.x += mod(floor(grid.y),2.0)*0.5; }
  vec2 cell = fract(grid);
  float edge = min(min(cell.x,1.0-cell.x),min(cell.y,1.0-cell.y));
  float aa = min(0.15,max(fwidth(grid.x),fwidth(grid.y))*0.5);
  float seam = smoothstep(0.018-aa,0.04+aa,edge);
  color *= mix(0.36,0.80+hash(floor(grid))*0.35,seam);
 }
 ALBEDO = color;
 // Painted-in warm spill: no lights, shadow passes or screen-space effects.
 if (masonry) {
  float pane = abs(mod(world.x+16.0,4.0)-2.0);
  EMISSION = vec3(0.10,0.035,0.006) * exp(-pane*pane-0.4*pow(world.y-3.4,2.0)) * step(world.z,-12.0);
 }
 METALLIC = metalness;
 ROUGHNESS = 0.72 + grain*0.17;
}
