shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D earth_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 wp;
varying vec3 wn;
varying float camera_distance;
float hash3(vec3 p){p=fract(p*0.1031);p+=dot(p,p.yzx+33.33);return fract((p.x+p.y)*p.z);}
float n3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);}
vec3 biplanar_rock(sampler2D tex, vec3 p, vec3 weights){
	return (texture(tex, p.zy).rgb * weights.x + texture(tex, p.xy).rgb * weights.z) / max(weights.x + weights.z, 0.001) * (1.0 - weights.y) + texture(tex, p.xz).rgb * weights.y;
}
void vertex(){
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	camera_distance = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}
void fragment(){
	vec3 world_normal = length(wn) > 0.001 ? normalize(wn) : vec3(0.0, 1.0, 0.0);
	vec3 weights = pow(abs(world_normal), vec3(4.0));
	float w_sum = weights.x + weights.y + weights.z;
	weights = w_sum > 0.0001 ? (weights / w_sum) : vec3(0.0, 1.0, 0.0);
	float macro = n3(wp * 0.018) * 0.65 + n3(wp * 0.037) * 0.35;
	float upward = clamp(world_normal.y, 0.0, 1.0);
	float flatness = smoothstep(0.38, 0.68, upward);
	float outcrop = n3(wp * 0.009 + vec3(41.0, 0.0, 7.0));
	// Only near-vertical rock walls expose bedrock; green grass covers rolling hills
	float exposed_slope = smoothstep(0.52, 0.82, 1.0 - upward + (outcrop - 0.5) * 0.06);
	float exposed_height = smoothstep(480.0, 800.0, wp.y) * mix(0.35, 0.80, outcrop);
	float rock_exposure = clamp(max(exposed_slope, exposed_height) + (1.0 - flatness) * smoothstep(0.70, 0.92, macro) * 0.15, 0.0, 1.0);
	float soil_cover = 1.0 - rock_exposure;
	vec3 rock_position = wp + vec3(outcrop * 24.0, macro * 10.0, outcrop * 17.0);
	vec3 rock = biplanar_rock(rock_albedo, rock_position * 0.08, weights);
	rock *= mix(vec3(0.81, 0.88, 0.96), vec3(1.04, 0.94, 0.83), macro);
	vec3 earth = texture(earth_albedo, wp.xz * 0.12).rgb;
	vec3 earth_moss = earth * mix(vec3(0.78, 1.05, 0.62), vec3(0.55, 0.92, 0.48), macro);
	earth = mix(earth, earth_moss, 0.75);
	float court_distance = max(abs(wp.x - 300.0) / 28.0, abs(wp.z - 120.0) / 24.0);
	float humidity = smoothstep(0.15, 0.65, outcrop);
	float riverbed = 1.0 - smoothstep(0.6, 1.8, wp.y);
	float vegetation = flatness * soil_cover * (1.0 - smoothstep(440.0, 760.0, wp.y)) * (1.0 - riverbed);
	float meadow = vegetation * smoothstep(0.85, 1.15, court_distance) * mix(0.82, 0.98, humidity);
	// Multi-scale photographic grass detail (micro-blades for near views, field scale for distant hills)
	vec3 grass_near = texture(grass_albedo, wp.xz / 3.4).rgb;
	vec3 grass_far = texture(grass_albedo, wp.xz / 24.0).rgb;
	vec3 grass = mix(grass_near, grass_far, smoothstep(8.0, 60.0, camera_distance) * 0.7 + 0.3);
	// Natural polychromatic pasture and dense forest canopy palette (matching reference photo)
	float pasture_noise = n3(wp * 0.006 + vec3(31.0, 0.0, 83.0));
	vec3 valley_lime = vec3(0.48, 0.92, 0.38);
	vec3 deep_emerald = vec3(0.22, 0.52, 0.20);
	vec3 mountain_scrub = vec3(0.18, 0.40, 0.16);
	vec3 grass_tint = mix(mix(deep_emerald, valley_lime, pasture_noise), mountain_scrub, smoothstep(0.58, 0.85, macro));
	
	// On hills and distant mountain ranges, blend into deep lush forest canopy tones (Photo reference)
	float hill_factor = clamp((wp.y - 8.0) / 35.0 + smoothstep(750.0, 1200.0, length(wp.xz)), 0.0, 1.0);
	float canopy_clusters = macro * 0.70 + pasture_noise * 0.30;
	vec3 forest_canopy_dark = vec3(0.15, 0.34, 0.13);
	vec3 forest_canopy_bright = vec3(0.28, 0.55, 0.20);
	vec3 forest_tint = mix(forest_canopy_dark, forest_canopy_bright, canopy_clusters);
	grass_tint = mix(grass_tint, forest_tint, hill_factor * 0.85);
	
	grass *= grass_tint * mix(0.92, 1.08, smoothstep(0.12, 0.66, macro));
	vec3 base = mix(mix(rock, earth, soil_cover), grass, meadow);
	float wet = 1.0 - smoothstep(0.6, 2.4, wp.y); base *= 1.0 - wet * 0.45;
	float snow = smoothstep(630.0, 940.0, wp.y + macro * 75.0) * smoothstep(0.45, 0.93, abs(world_normal.y));
	ALBEDO = clamp(mix(base * (0.88 + macro * 0.22), vec3(0.69, 0.75, 0.78), snow), vec3(0.0), vec3(1.0));
	ROUGHNESS = 0.85;
}
