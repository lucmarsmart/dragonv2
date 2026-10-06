shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D needles : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float alpha_cutoff = 0.22;
uniform float wind_strength = 0.18;
varying vec4 tint;
void vertex(){
 tint=COLOR;
 vec3 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float bend=clamp(VERTEX.y/14.0,0.0,1.0);
 VERTEX.x+=sin(TIME*0.9+wp.x*0.031+wp.z*0.043)*bend*bend*wind_strength;
}
void fragment(){vec4 tex=texture(needles,UV);ALBEDO=tex.rgb*tint.rgb;ALPHA=tex.a;ALPHA_SCISSOR_THRESHOLD=alpha_cutoff;ROUGHNESS=0.95;}
