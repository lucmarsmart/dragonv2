shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec3 mouth_position;
uniform vec3 breath_direction = vec3(0.0,0.0,-1.0);
uniform float reach = 26.0;
uniform bool has_impact = false;
uniform bool attack_view = false;
uniform vec3 impact_point;
uniform vec3 impact_normal = vec3(0.0,1.0,0.0);
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void vertex() {
 // Billboard preserves particle scale and world-space trails.
 MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
 MODELVIEW_MATRIX[0] *= length(MODEL_MATRIX[0].xyz);
 MODELVIEW_MATRIX[1] *= length(MODEL_MATRIX[1].xyz);
 MODELVIEW_MATRIX[2] *= length(MODEL_MATRIX[2].xyz);
 world_pos = (INV_VIEW_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
 if(has_impact && dot(world_pos-impact_point,impact_normal)<-0.015) discard;
 float along=dot(world_pos-mouth_position, breath_direction);
 if(along>reach || along < 0.0) discard;
 // Match the production damaging cone (0.55m base, 7 degree half angle).
 // Billboard edges must not look like fire touching an unreachable soldier.
 float radius=0.55+along*0.12278456;
 float lateral=length(world_pos-mouth_position-breath_direction*along);
 if(lateral>radius) discard;
 vec2 p=UV*2.0-1.0;
 float n=noise(UV*9.0+vec2(TIME*2.0,-TIME*5.0));
 float shape=smoothstep(1.0,0.12,length(p*vec2(1.0,0.82))+(n-0.5)*0.32);
 float core=smoothstep(0.72,0.0,length(p));
 ALBEDO=COLOR.rgb;
 EMISSION=COLOR.rgb*(1.2+core*1.5);
 ALPHA=shape*COLOR.a*0.72*smoothstep(radius,max(0.0,radius-0.12),lateral);
 // Looking along the jet stacks many additive billboards over the target.
 // Keep its outline readable in the player's attack camera.
 if(attack_view) {
  vec3 toward_camera=normalize(INV_VIEW_MATRIX[3].xyz-world_pos);
  ALPHA*=mix(1.0,0.18,smoothstep(0.85,0.98,abs(dot(toward_camera,breath_direction))));
 }
}
