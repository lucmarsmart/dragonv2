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
	float wave1 = sin(s_pos * 0.28 - TIME * 2.2 + c_pos * 0.14) * 0.14;
	float wave2 = sin(s_pos * 0.64 - TIME * 3.4 - c_pos * 0.22) * 0.07;
	float wave3 = cos(s_pos * 1.35 - TIME * 4.6 + c_pos * 0.35) * 0.03;
	
	VERTEX.y += (wave1 + wave2 + wave3) * shore * near_wave;
}

void fragment() {
	vec2 rdir = get_river_direction(wp.z);
	vec2 cdir = vec2(-rdir.y, rdir.x);
	float dist = distance(wp, CAMERA_POSITION_WORLD);
	float dist_fade = 1.0 - smoothstep(60.0, 360.0, dist);
	
	// Stream-aligned flow coordinates
	float stream_coord = dot(wp.xz, rdir);
	float cross_coord  = dot(wp.xz, cdir);
	
	// Multi-scale streaming ripple layers moving downstream
	vec2 flow1 = vec2(cross_coord * 0.35, stream_coord * 0.40 - TIME * 0.85);
	vec2 flow2 = vec2(cross_coord * 0.55 + stream_coord * 0.15, stream_coord * 0.70 - TIME * 1.35);
	vec2 micro = vec2(cross_coord * 1.80, stream_coord * 2.20 - TIME * 2.40);
	
	// Finite-difference normals for crisp wave facets
	const float eps = 0.07;
	float h_c = fbm_grad(flow1) * 0.48 + fbm_grad(flow2) * 0.36 + gnoise(micro) * 0.16;
	float h_x = fbm_grad(flow1 + vec2(eps, 0.0)) * 0.48 + fbm_grad(flow2 + vec2(eps, 0.0)) * 0.36 + gnoise(micro + vec2(eps, 0.0)) * 0.16;
	float h_y = fbm_grad(flow1 + vec2(0.0, eps)) * 0.48 + fbm_grad(flow2 + vec2(0.0, eps)) * 0.36 + gnoise(micro + vec2(0.0, eps)) * 0.16;
	vec2 ripple = vec2(h_x - h_c, h_y - h_c) / eps;
	
	// Broad standing wave swell along the canyon
	vec2 broad_uv = vec2(cross_coord * 0.06, stream_coord * 0.06 - TIME * 0.25);
	float bx = fbm_grad(broad_uv + vec2(0.12, 0.0)) - fbm_grad(broad_uv - vec2(0.12, 0.0));
	float by = fbm_grad(broad_uv + vec2(0.0, 0.12)) - fbm_grad(broad_uv - vec2(0.0, 0.12));
	vec2 broad_ripple = vec2(bx, by) * 0.32;
	
	vec2 total_pert = (ripple * 0.075 * dist_fade + broad_ripple);
	vec3 world_normal = normalize(vec3(-total_pert.x, 1.0, -total_pert.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	
	// Depth reconstruction from depth buffer
	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	vec4 scene_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	float depth = max(0.0, -scene_pos.z / scene_pos.w + VERTEX.z);
	
	// Screen refraction with depth attenuation (no hard border bleeding)
	vec2 refr_offset = total_pert * 0.032 * clamp(depth * 1.6, 0.0, 1.0);
	vec2 refr_uv = clamp(SCREEN_UV + refr_offset, vec2(0.001), vec2(0.999));
	vec3 refracted = textureLod(screen_texture, refr_uv, 0.0).rgb;
	
	// Natural Alpine Mountain River Palette (matches video reference)
	// Shallow: crystal clear, high visibility of pebbles & gravel
	// Mid-depth: natural glacial turquoise / alpine teal
	// Deep pools: rich dark mountain teal
	vec3 color_shallow = vec3(0.09, 0.48, 0.52);
	vec3 color_deep    = vec3(0.015, 0.16, 0.22);
	vec3 water_body = mix(color_shallow, color_deep, clamp(depth / 3.2, 0.0, 1.0));
	
	// Physical Beer-Lambert absorption: red absorbed quickly, green/cyan persists
	vec3 absorption_coeff = vec3(0.60, 0.20, 0.07);
	vec3 transmission = exp(-depth * absorption_coeff);
	
	// Sunlight caustics projected onto shallow riverbed
	vec2 c_uv1 = vec2(cross_coord * 1.5, stream_coord * 1.5 - TIME * 1.1);
	vec2 c_uv2 = vec2(cross_coord * 1.5 + 2.5, stream_coord * 1.5 + TIME * 0.95);
	float caust = pow(clamp(1.0 - abs(gnoise(c_uv1) - gnoise(c_uv2)) * 1.5, 0.0, 1.0), 3.0);
	float caust_mask = (1.0 - smoothstep(0.05, 1.8, depth)) * transmission.r;
	vec3 caustics = vec3(0.92, 0.98, 1.0) * (caust * caust_mask * 0.42);
	
	// Whitewater Rapids & Trailing Foam Wakes (matching video)
	// 1. Shoreline & obstacle contact foam
	float shore_contact = 1.0 - smoothstep(0.02, 0.48, depth);
	// 2. Rapids turbulence along current
	float rapids = smoothstep(0.50, 0.85, fbm_grad(vec2(cross_coord * 0.8, stream_coord * 1.2 - TIME * 1.5)) + 0.5);
	float foam_base = max(shore_contact * 0.92, rapids * 0.65);
	
	// Elongated foam streaks streaming downstream (wake effect)
	vec2 foam_wake_uv = vec2(cross_coord * 2.8, stream_coord * 0.85 - TIME * 1.2);
	float foam_cells = voronoi(vec2(cross_coord * 3.2, stream_coord * 1.2 - TIME * 1.4));
	float foam_noise = fbm_grad(foam_wake_uv) + 0.5;
	float foam_pattern = (1.0 - foam_cells * 0.82) * 0.68 + foam_noise * 0.32;
	float foam_mask = smoothstep(0.32, 0.65, foam_base * foam_pattern);
	vec3 foam_color = vec3(0.96, 0.98, 1.0);
	
	// PBR Water Surface & Volume (NO artificial emission glow!)
	// Underwater scene transmission through crystal water:
	vec3 underwater = (refracted + caustics) * transmission + water_body * (1.0 - transmission);
	
	// Fresnel sky reflection at grazing view angles
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.5);
	vec3 sky_reflection = vec3(0.68, 0.80, 0.94);
	vec3 water_surface = mix(underwater, sky_reflection, fresnel * 0.35);
	
	// Mix surface with aerated frothy whitewater foam
	ALBEDO = mix(water_surface, foam_color, foam_mask);
	
	// Realistic PBR properties: glassy water with sharp sun glints, diffuse foam
	ROUGHNESS = mix(0.025, 0.72, foam_mask);
	METALLIC = 0.0;
	SPECULAR = mix(0.58, 0.15, foam_mask);
	ALPHA = 1.0;
}
