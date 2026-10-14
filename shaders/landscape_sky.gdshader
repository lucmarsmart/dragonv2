shader_type sky;
render_mode use_half_res_pass;

uniform vec3 sun_direction = vec3(-0.5, 0.55, -0.45);

// Smooth analytical gradient hash without trigonometric sin() precision issues
vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	// Quintic Hermite interpolant for perfectly smooth derivatives without grid/block artifacts
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
	               dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
	           mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
	               dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

// 2D Rotation matrix to eliminate rectilinear grid alignment across noise octaves
const mat2 rot = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));

float fbm_clouds(vec2 p) {
	float f = 0.5000 * gnoise(p); p = rot * p * 2.02;
	f += 0.2500 * gnoise(p); p = rot * p * 2.03;
	f += 0.1250 * gnoise(p); p = rot * p * 2.01;
	f += 0.0625 * gnoise(p);
	return f * 0.5 + 0.5;
}

void sky() {
	float h = clamp(EYEDIR.y, 0.0, 1.0);
	
	// Photorealistic Rayleigh atmospheric gradient (matching reference photo)
	// Deep azure blue at zenith, vibrant cerulean in mid-sky, luminous warm atmospheric haze at horizon
	vec3 sky_zenith = vec3(0.12, 0.38, 0.88);
	vec3 sky_mid    = vec3(0.24, 0.52, 0.92);
	vec3 sky_horizon= vec3(0.64, 0.78, 0.92);
	
	vec3 color = mix(sky_horizon, sky_mid, smoothstep(0.0, 0.30, h));
	color = mix(color, sky_zenith, smoothstep(0.30, 0.95, h));
	
	// Solar disk and natural forward atmospheric glow
	vec3 sun_dir = normalize(sun_direction);
	float sun_dot = max(dot(EYEDIR, sun_dir), 0.0);
	vec3 sun_halo = vec3(1.0, 0.94, 0.82) * (pow(sun_dot, 8.0) * 0.18 + pow(sun_dot, 32.0) * 0.35);
	vec3 sun_disk = vec3(1.0, 0.98, 0.90) * pow(sun_dot, 1500.0) * 3.5;
	color += sun_halo + sun_disk;
	
	// Natural Cumulus Humilis clouds (Foto reference)
	if (EYEDIR.y > 0.01) {
		// Planar perspective projection across the sky dome
		vec2 uv = (EYEDIR.xz / max(EYEDIR.y + 0.15, 0.08)) * 0.38 + vec2(TIME * 0.0016, TIME * 0.0004);
		
		float base_density = fbm_clouds(uv * 1.8);
		// Billowy cumulus cauliflower puff structure: carve softer edges and puffy lobes
		float billow = fbm_clouds(uv * 3.6 + vec2(1.7, 9.2));
		float cloud_density = base_density * 0.68 + billow * 0.32;
		
		// Shape into distinct, puffy cumulus bodies separated by blue sky
		float cloud_alpha = smoothstep(0.46, 0.68, cloud_density);
		
		// Directional illumination from the sun:
		vec2 sun_offset = normalize(sun_dir.xz) * 0.06;
		float sun_sample = fbm_clouds((uv + sun_offset) * 1.8);
		float light_factor = clamp((cloud_density - sun_sample) * 4.5 + 0.65, 0.0, 1.0);
		
		// Silver-white sunlit cloud crest vs soft ambient blue-shaded underside
		vec3 cloud_sunlit = vec3(1.0, 0.99, 0.97);
		vec3 cloud_shaded = mix(vec3(0.62, 0.72, 0.84), vec3(0.78, 0.84, 0.90), light_factor);
		vec3 cloud_color  = mix(cloud_shaded, cloud_sunlit, pow(light_factor, 1.3));
		
		// Atmospheric distance fade just touching the mountain tops
		float horizon_fade = smoothstep(0.015, 0.10, EYEDIR.y);
		color = mix(color, cloud_color, cloud_alpha * horizon_fade * 0.98);
	}
	
	// Nadir (below horizon) soft atmospheric terrain ground tone
	if (EYEDIR.y < 0.0) {
		color = mix(vec3(0.24, 0.36, 0.28), sky_horizon, exp(EYEDIR.y * 14.0));
	}
	
	COLOR = color;
}
