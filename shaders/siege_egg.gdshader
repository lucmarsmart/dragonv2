shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D shell_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float freed = 0.0;
float hash2(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise2(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 float mottling=noise2(UV*17.0)*0.65+noise2(UV*49.0)*0.35;
 float speckles=smoothstep(0.74,0.83,noise2(UV*160.0));
 ALBEDO=mix(vec3(0.61,0.56,0.43),vec3(0.80,0.74,0.57),mottling)*(1.0-speckles*0.38);
 NORMAL_MAP=texture(shell_normal,UV*2.5).rgb;
 NORMAL_MAP_DEPTH=0.12;
 ROUGHNESS=0.48+mottling*0.13;
 float pulse=0.85+sin(TIME*1.6)*0.15;
 EMISSION=vec3(0.16,0.43,0.33)*freed*pulse*0.55;
}
