shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec3 mouth_position;
uniform vec3 breath_direction=vec3(0.0,0.0,-1.0);
uniform float reach=26.0;
uniform bool has_impact = false;
uniform bool attack_view = false;
uniform vec3 impact_point;
uniform vec3 impact_normal = vec3(0.0,1.0,0.0);
varying vec3 world_pos;
void vertex() {
 MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
 MODELVIEW_MATRIX[0] *= length(MODEL_MATRIX[0].xyz);
 MODELVIEW_MATRIX[1] *= length(MODEL_MATRIX[1].xyz);
 world_pos=(INV_VIEW_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
 if(has_impact && dot(world_pos-impact_point,impact_normal)<-0.015) discard;
 if(dot(world_pos-mouth_position,breath_direction)>reach+0.6) discard;
 float r=length(UV*2.0-1.0);
 ALBEDO=COLOR.rgb;
 ALPHA=smoothstep(1.0,0.05,r)*COLOR.a*0.28;
 if(attack_view) {
  vec3 toward_camera=normalize(INV_VIEW_MATRIX[3].xyz-world_pos);
  ALPHA*=mix(1.0,0.3,smoothstep(0.85,0.98,abs(dot(toward_camera,breath_direction))));
 }
}
