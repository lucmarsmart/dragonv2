shader_type sky;
uniform vec3 sun_direction=vec3(-0.5,0.55,-0.45);
float hash2(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n2(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){return n2(p)*0.5+n2(p*2.02)*0.25+n2(p*4.03)*0.125+n2(p*8.11)*0.0625;}
void sky(){
 float h=max(EYEDIR.y,0.0);vec3 color=mix(vec3(0.64,0.72,0.75),vec3(0.11,0.29,0.49),pow(h,0.43));
 vec3 sun_dir=normalize(sun_direction);float sun=max(dot(EYEDIR,sun_dir),0.0);
 color+=vec3(1.0,0.76,0.47)*pow(sun,28.0)*0.35+vec3(1.0,0.94,0.77)*pow(sun,1800.0)*2.0;
 if(EYEDIR.y>0.015){vec2 uv=EYEDIR.xz/(EYEDIR.y+0.14)*1.1+vec2(TIME*0.0014,0.0);float cloud=fbm(uv*2.3);float mask=smoothstep(0.49,0.70,cloud)*smoothstep(0.015,0.11,EYEDIR.y);vec3 shade=mix(vec3(0.54,0.63,0.68),vec3(0.96,0.94,0.87),smoothstep(0.46,0.73,cloud));color=mix(color,shade,mask*0.93);}
 if(EYEDIR.y<0.0){color=mix(vec3(0.31,0.39,0.38),vec3(0.64,0.72,0.75),exp(EYEDIR.y*12.0));}
 COLOR=color;
}
