shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_rough : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth_rough : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_rough : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 wp;
varying vec3 wn;
varying float camera_distance;
float hash3(vec3 p){p=fract(p*0.1031);p+=dot(p,p.yzx+33.33);return fract((p.x+p.y)*p.z);}
float n3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);}
vec3 tricolor(sampler2D tex,vec3 p,vec3 weights){return texture(tex,p.zy).rgb*weights.x+texture(tex,p.xz).rgb*weights.y+texture(tex,p.xy).rgb*weights.z;}
vec3 normal_rg(sampler2D tex,vec2 uv){vec2 xy=texture(tex,uv).rg*2.0-1.0;return vec3(xy,sqrt(max(0.0,1.0-dot(xy,xy))));}
vec3 trinormal(sampler2D tex,vec3 p,vec3 weights,vec3 normal){
 vec3 nx=normal_rg(tex,p.zy);vec3 ny=normal_rg(tex,p.xz);vec3 nz=normal_rg(tex,p.xy);
 return normalize(vec3(nx.z*sign(normal.x),nx.y,nx.x)*weights.x+vec3(ny.x,ny.z*sign(normal.y),ny.y)*weights.y+vec3(nz.x,nz.y,nz.z*sign(normal.z))*weights.z);
}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);camera_distance=length((MODELVIEW_MATRIX*vec4(VERTEX,1.0)).xyz);}
void fragment(){
 vec3 world_normal=normalize(wn);vec3 weights=pow(abs(world_normal),vec3(4.0));weights/=weights.x+weights.y+weights.z;
 float macro=n3(wp*0.018)*0.65+n3(wp*0.037)*0.35;
 float upward=clamp(world_normal.y,0.0,1.0);
 float flatness=smoothstep(0.38,0.68,upward);
 float outcrop=n3(wp*0.009+vec3(41.0,0.0,7.0));
 // Only near-vertical rock walls expose bedrock; green grass covers rolling hills
 float exposed_slope=smoothstep(0.52,0.82,1.0-upward+(outcrop-0.5)*0.06);
 float exposed_height=smoothstep(480.0,800.0,wp.y)*mix(0.35,0.80,outcrop);
 float rock_exposure=clamp(max(exposed_slope,exposed_height)+(1.0-flatness)*smoothstep(0.70,0.92,macro)*0.15,0.0,1.0);
 float soil_cover=1.0-rock_exposure;
 vec3 rock_position=wp+vec3(outcrop*24.0,macro*10.0,outcrop*17.0);
 vec3 broad_position=vec3(rock_position.x*0.798+rock_position.z*0.603,rock_position.y,rock_position.z*0.798-rock_position.x*0.603);
 vec3 rock=mix(tricolor(rock_albedo,rock_position*0.15,weights),tricolor(rock_albedo,broad_position*0.027+vec3(0.37),weights),mix(0.36,0.64,outcrop));
 rock*=mix(vec3(0.81,0.88,0.96),vec3(1.04,0.94,0.83),macro);
 vec3 earth=mix(tricolor(earth_albedo,wp*0.23,weights),tricolor(earth_albedo,wp*0.041+vec3(0.19),weights),0.21);
 vec3 earth_moss=earth*mix(vec3(0.78,1.05,0.62),vec3(0.55,0.92,0.48),macro);
 earth=mix(earth,earth_moss,0.75);
 float court_distance=max(abs(wp.x-300.0)/80.0,abs(wp.z-120.0)/75.0);
 float humidity=smoothstep(0.15,0.65,n3(wp*0.007+vec3(15.0,0.0,93.0)));
 float riverbed=1.0-smoothstep(0.6,1.8,wp.y);
 float vegetation=flatness*soil_cover*(1.0-smoothstep(440.0,760.0,wp.y))*(1.0-riverbed);
 float meadow=vegetation*smoothstep(0.85,1.15,court_distance)*mix(0.82,0.98,humidity);
 // Multi-scale photographic grass detail (micro-blades for near views, field scale for distant hills)
 vec3 grass_micro=tricolor(grass_albedo,wp/3.4,weights);
 vec3 grass_macro=tricolor(grass_albedo,wp/16.0,weights);
 vec3 grass_field=tricolor(grass_albedo,wp/48.0,weights);
 vec3 grass=mix(grass_micro,grass_macro,smoothstep(8.0,60.0,camera_distance));
 grass=mix(grass,grass_field,0.30);
 // Natural polychromatic pasture palette (Photo 1 Andean/Alpine mountain green)
 float pasture_noise=n3(wp*0.006+vec3(31.0,0.0,83.0));
 vec3 sunlit_lime=vec3(0.68,1.25,0.48);
 vec3 deep_emerald=vec3(0.42,0.95,0.38);
 vec3 mountain_scrub=vec3(0.32,0.72,0.30);
 vec3 grass_tint=mix(mix(deep_emerald,sunlit_lime,pasture_noise),mountain_scrub,smoothstep(0.58,0.85,macro));
 grass*=grass_tint*mix(0.92,1.08,smoothstep(0.12,0.66,macro));
 vec3 base=mix(mix(rock,earth,soil_cover),grass,meadow);
 float wet=1.0-smoothstep(0.6,2.4,wp.y);base*=1.0-wet*0.45;
 float snow=smoothstep(630.0,940.0,wp.y+macro*75.0)*smoothstep(0.45,0.93,abs(world_normal.y));
 ALBEDO=mix(base*(0.88+macro*0.22),vec3(0.69,0.75,0.78),snow);
 float roughness=mix(mix(tricolor(rock_rough,rock_position*0.15,weights).r,tricolor(earth_rough,wp*0.23,weights).r,soil_cover),tricolor(grass_rough,wp/15.0,weights).r,meadow);
 ROUGHNESS=clamp(mix(roughness,0.22,wet*0.75),0.18,0.98);
 vec3 detail_normal=mix(trinormal(rock_normal,rock_position*0.15,weights,world_normal),trinormal(earth_normal,wp*0.23,weights,world_normal),soil_cover);
 detail_normal=mix(detail_normal,trinormal(grass_normal,wp/6.0,weights,world_normal),meadow);
 float normal_detail=0.4*(1.0-snow*0.75)*(1.0-smoothstep(55.0,210.0,camera_distance));
 NORMAL=normalize(mat3(VIEW_MATRIX)*mix(world_normal,detail_normal,normal_detail));
}
