shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
varying vec3 wp;
float hash2(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise2(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1,1)),f.x),f.y);}
float flow_noise(vec2 p){return noise2(p)*0.6+noise2(p*2.03+vec2(8.3,1.7))*0.28+noise2(p*4.09+vec2(2.7,7.8))*0.12;}
float river_center(float z){return sin(z*0.0041)*62.0+sin(z*0.0103+0.6)*18.0;}
float river_width(float z){return 63.0+sin(z*0.006+1.5)*9.0+sin(z*0.019)*2.4;}
void vertex(){
 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float shore=clamp((river_width(wp.z)-abs(wp.x-river_center(wp.z)))/7.0,0.0,1.0);
 float near_wave=1.0-smoothstep(60.0,230.0,distance(wp,CAMERA_POSITION_WORLD));
 VERTEX.y+=(flow_noise(wp.xz*0.14+vec2(0.03,-TIME*0.3))-0.5)*0.12*shore*near_wave;
}
void fragment(){
 vec2 flow=wp.xz*0.31+vec2(TIME*0.07,-TIME*0.5);
 float nx=flow_noise(flow+vec2(0.12,0.0))-flow_noise(flow-vec2(0.12,0.0));
 float ny=flow_noise(flow+vec2(0.0,0.12))-flow_noise(flow-vec2(0.0,0.12));
 float distance_fade=1.0-smoothstep(90.0,400.0,distance(wp,CAMERA_POSITION_WORLD));
 vec2 broad_flow=wp.xz*0.055+vec2(TIME*0.015,-TIME*0.13);
 float broad_x=flow_noise(broad_flow+vec2(0.18,0.0))-flow_noise(broad_flow-vec2(0.18,0.0));
 float broad_z=flow_noise(broad_flow+vec2(0.0,0.18))-flow_noise(broad_flow-vec2(0.0,0.18));
 vec2 ripple=vec2(nx,ny)*0.065*distance_fade+vec2(broad_x,broad_z)*0.38;
 NORMAL=normalize(mat3(VIEW_MATRIX)*vec3(-ripple.x,1.0,-ripple.y));
 float raw_depth=texture(depth_texture,SCREEN_UV).r;
 vec4 scene_pos=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,raw_depth,1.0);
 float depth=max(0.0,-scene_pos.z/scene_pos.w+VERTEX.z);
 vec2 refraction=SCREEN_UV+ripple*0.05*clamp(depth/2.0,0.0,1.0);
 vec3 refracted=textureLod(screen_texture,clamp(refraction,vec2(0.001),vec2(0.999)),0.0).rgb;
 vec3 absorption=mix(vec3(0.066,0.116,0.071),vec3(0.018,0.047,0.032),clamp(depth/4.0,0.0,1.0));
 float transmission=exp(-depth*0.48);
 ALBEDO=absorption*(1.0-transmission);
 EMISSION=refracted*transmission;
 float shallow=1.0-smoothstep(0.03,0.8,depth);
 float turbulence=flow_noise(wp.xz*1.7+vec2(0.1,-TIME*0.45));
 float foam=shallow*smoothstep(0.42,0.73,turbulence)*0.55;
 ALBEDO=mix(ALBEDO,vec3(0.63,0.68,0.62),foam);
 EMISSION*=1.0-foam;
 ROUGHNESS=mix(0.11+flow_noise(broad_flow)*0.12,0.53,foam);
 METALLIC=0.0;
 SPECULAR=0.32;
 ALPHA=1.0;
}
