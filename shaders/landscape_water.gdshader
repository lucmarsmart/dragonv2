shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

varying vec3 wp;
varying vec3 view_pos;

// High quality pseudo-random hash
float hash2(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(vec2(p.x * p.y, (p.x + p.y) * 91.13));
}

// 2D Gradient Noise with quintic smoothstep (continuous derivatives, no lattice seams)
vec2 grad(vec2 p) {
	float a = hash2(p) * 6.2831853;
	return vec2(cos(a), sin(a));
}

float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(dot(grad(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
	               dot(grad(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
	           mix(dot(grad(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
	               dot(grad(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

float fbm_grad(vec2 p) {
	return gnoise(p) * 0.52 +
	       gnoise(p * 2.05 + vec2(4.1, 1.7)) * 0.28 +
	       gnoise(p * 4.19 + vec2(1.9, 5.3)) * 0.14 +
	       gnoise(p * 8.37 + vec2(7.2, 3.1)) * 0.06;
}

// Fast Voronoi cellular noise for organic froth bubbles
float voronoi(vec2 p) {
	vec2 g = floor(p);
	vec2 f = fract(p);
	float d = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 lattice = vec2(float(x), float(y));
			vec2 offset = hash22(g + lattice);
			vec2 r = lattice + offset - f;
			d = min(d, dot(r, r));
		}
	}
	return sqrt(d);
}

// River path geometry matching terrain generation
float river_center(float z) {
	return sin(z * 0.0041) * 62.0 + sin(z * 0.0103 + 0.6) * 18.0;
}

float river_width(float z) {
	return 63.0 + sin(z * 0.006 + 1.5) * 9.0 + sin(z * 0.019) * 2.4;
}

vec2 get_river_direction(float z) {
	float dcenter_dz = cos(z * 0.0041) * 0.2542 + cos(z * 0.0103 + 0.6) * 0.1854;
	return normalize(vec2(dcenter_dz, 1.0));
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	float dist = distance(wp, CAMERA_POSITION_WORLD);
	float near_wave = 1.0 - smoothstep(60.0, 280.0, dist);
	
	// Shore attenuation: 0 at the bank edges, 1 in the channel center
	float dist_from_center = abs(wp.x - river_center(wp.z));
	float half_w = river_width(wp.z) + 32.0;
	float shore = clamp((half_w - dist_from_center) / 10.0, 0.0, 1.0);
	
	// River flow tangent
	vec2 rdir = get_river_direction(wp.z);
	float s_pos = dot(wp.xz, rdir);
	float c_pos = dot(wp.xz, vec2(-rdir.y, rdir.x));
	
	// Multi-frequency directional waves traveling downstream
	float wave1 = sin(s_pos * 0.26 - TIME * 1.7 + c_pos * 0.12) * 0.13;
	float wave2 = sin(s_pos * 0.58 - TIME * 2.7 - c_pos * 0.18) * 0.065;
	float wave3 = cos(s_pos * 1.22 - TIME * 3.8 + c_pos * 0.30) * 0.03;
	
	VERTEX.y += (wave1 + wave2 + wave3) * shore * near_wave;
}

void fragment() {
	vec2 rdir = get_river_direction(wp.z);
	float dist = distance(wp, CAMERA_POSITION_WORLD);
	float dist_fade = 1.0 - smoothstep(60.0, 360.0, dist);
	
	// Dual flow texture coordinates streaming downriver with interference
	vec2 flow1 = wp.xz * 0.42 + rdir * (TIME * 0.75);
	vec2 flow2 = wp.xz * 0.65 + vec2(rdir.y, -rdir.x) * 0.20 + rdir * (TIME * 1.10);
	vec2 micro = wp.xz * 2.20 + rdir * (TIME * 1.90);
	
	// Finite-difference normals for smooth organic ripples
	const float eps = 0.08;
	float h_c = fbm_grad(flow1) * 0.50 + fbm_grad(flow2) * 0.34 + gnoise(micro) * 0.16;
	float h_x = fbm_grad(flow1 + vec2(eps, 0.0)) * 0.50 + fbm_grad(flow2 + vec2(eps, 0.0)) * 0.34 + gnoise(micro + vec2(eps, 0.0)) * 0.16;
	float h_y = fbm_grad(flow1 + vec2(0.0, eps)) * 0.50 + fbm_grad(flow2 + vec2(0.0, eps)) * 0.34 + gnoise(micro + vec2(0.0, eps)) * 0.16;
	vec2 ripple = vec2(h_x - h_c, h_y - h_c) / eps;
	
	// Broad standing wave swell
	vec2 broad_uv = wp.xz * 0.05 + rdir * (TIME * 0.20);
	float bx = fbm_grad(broad_uv + vec2(0.12, 0.0)) - fbm_grad(broad_uv - vec2(0.12, 0.0));
	float by = fbm_grad(broad_uv + vec2(0.0, 0.12)) - fbm_grad(broad_uv - vec2(0.0, 0.12));
	vec2 broad_ripple = vec2(bx, by) * 0.30;
	
	vec2 total_pert = ripple * 0.065 * dist_fade + broad_ripple;
	vec3 world_normal = normalize(vec3(-total_pert.x, 1.0, -total_pert.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	
	// Depth reconstruction from depth buffer
	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	vec4 scene_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	float depth = max(0.0, -scene_pos.z / scene_pos.w + VERTEX.z);
	
	// Screen refraction
	vec2 refr_offset = total_pert * 0.035 * clamp(depth * 1.5, 0.0, 1.0);
	vec2 refr_uv = clamp(SCREEN_UV + refr_offset, vec2(0.001), vec2(0.999));
	vec3 refracted = textureLod(screen_texture, refr_uv, 0.0).rgb;
	
	// Mountain Glacial River Palette (matching reference video)
	// Shallow: crystal clear alpine turquoise
	// Deep: rich mountain emerald / dark teal
	vec3 color_shallow = vec3(0.13, 0.65, 0.68);
	vec3 color_deep    = vec3(0.02, 0.21, 0.28);
	vec3 water_body = mix(color_shallow, color_deep, clamp(depth / 3.6, 0.0, 1.0));
	
	// Physical Beer-Lambert light absorption
	vec3 absorption = vec3(0.48, 0.15, 0.06);
	vec3 transmission = exp(-depth * absorption);
	
	// Caustics on shallow riverbed stones and submerged rocks
	vec2 c_uv1 = wp.xz * 1.5 + rdir * (TIME * 0.90);
	vec2 c_uv2 = wp.xz * 1.5 - rdir * (TIME * 0.78) + vec2(2.7, 1.3);
	float caust = pow(clamp(1.0 - abs(gnoise(c_uv1) - gnoise(c_uv2)) * 1.5, 0.0, 1.0), 2.8);
	float caust_mask = (1.0 - smoothstep(0.05, 2.2, depth)) * transmission.r;
	vec3 caustics = vec3(0.88, 0.97, 1.0) * (caust * caust_mask * 0.40);
	
	// Frothy White-water Foam & Shoreline Breakers (matching video)
	// 1. Shoreline and rock contact foam
	float shore_contact = 1.0 - smoothstep(0.02, 0.52, depth);
	// 2. Rapids turbulence along current
	float rapids = smoothstep(0.50, 0.84, fbm_grad(wp.xz * 0.95 + rdir * (TIME * 1.35)) + 0.5);
	float foam_strength = max(shore_contact * 0.88, rapids * 0.62);
	
	// Cellular froth pattern
	vec2 foam_uv = wp.xz * 3.0 + rdir * (TIME * 1.05);
	float foam_cells = voronoi(foam_uv);
	float foam_fbm = fbm_grad(wp.xz * 1.3 + rdir * (TIME * 0.60)) + 0.5;
	float foam_pattern = (1.0 - foam_cells * 0.85) * 0.65 + foam_fbm * 0.35;
	float foam_mask = smoothstep(0.32, 0.64, foam_strength * foam_pattern);
	vec3 foam_color = vec3(0.95, 0.98, 1.0);
	
	// Fresnel sky reflection at grazing angles
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.5);
	vec3 sky_tint = vec3(0.62, 0.75, 0.90);
	
	// Lit water albedo + transmitted underwater scene
	vec3 water_lit = mix(water_body * (1.0 - transmission), sky_tint, fresnel * 0.30);
	vec3 underwater = (refracted + caustics) * transmission;
	
	ALBEDO = mix(water_lit, foam_color, foam_mask);
	EMISSION = underwater * (1.0 - foam_mask);
	
	// Glassy water surface with diffuse aerated foam
	ROUGHNESS = mix(0.03, 0.68, foam_mask);
	METALLIC = 0.0;
	SPECULAR = mix(0.55, 0.16, foam_mask);
	ALPHA = 1.0;
}
