shader_type spatial;
render_mode diffuse_burley, cull_disabled;

// PBR Realistic Bark Shader with Per-Instance Procedural Variation,
// Multi-layer Species Material Calibration, and Organic Crevice Depth.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ao_tex : filter_linear_mipmap_anisotropic, repeat_enable;

// Species mode:
// 0 = Oak (deep mossy furrows, weathered gray-brown)
// 1 = Eucalyptus (smooth cream inner wood + dark peeling ribbons)
// 2 = Birch (chalky white + dark eye scars and lenticels)
// 3 = Pine Plates (ash gray surface plates + bright terracotta crevices)
// 4 = Corrugated (dense vertical ridges, rich earthy brown)
uniform int species_type : hint_range(0, 4) = 0;

uniform vec2 uv_scale = vec2(1.0, 3.0);
uniform float normal_scale : hint_range(0.5, 4.0) = 2.4;
uniform vec3 moss_color : source_color = vec3(0.22, 0.34, 0.14);
uniform float moss_amount : hint_range(0.0, 1.0) = 0.35;
uniform float wetness_at_base : hint_range(0.0, 1.0) = 0.45;
uniform vec3 trunk_tint : source_color = vec3(1.0, 1.0, 1.0);

varying vec3 world_pos;
varying vec3 world_normal;
varying float tree_height;
varying float instance_seed;

float hash1(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

vec3 hash3(vec3 p) {
	vec3 q = vec3(
		dot(p, vec3(127.1, 311.7, 74.7)),
		dot(p, vec3(269.5, 183.3, 246.1)),
		dot(p, vec3(113.5, 271.9, 124.6))
	);
	return fract(sin(q) * 43758.5453123);
}

// Procedural simplex-like noise for warping and micro-detail
float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash1(vec3(i, 0.0));
	float b = hash1(vec3(i + vec2(1.0, 0.0), 0.0));
	float c = hash1(vec3(i + vec2(0.0, 1.0), 0.0));
	float d = hash1(vec3(i + vec2(1.0, 1.0), 0.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	tree_height = VERTEX.y;
	
	// Extract unique seed per tree instance from its world position
	vec3 inst_origin = MODEL_MATRIX[3].xyz;
	instance_seed = hash1(inst_origin * 0.071 + vec3(17.3, 43.1, 91.7));
	
	// Gentle natural wind sway on upper branches
	float bend = clamp(VERTEX.y / 16.0, 0.0, 1.0);
	float sway = sin(TIME * 0.85 + inst_origin.x * 0.04 + inst_origin.z * 0.06);
	VERTEX.x += sway * bend * bend * 0.09;
	VERTEX.z += cos(TIME * 0.72 + inst_origin.z * 0.05) * bend * bend * 0.07;
}

void fragment() {
	// Every single tree gets its own randomized UV starting offset and subtle domain warp
	// so no two trees share identical bark features, knot positions, or seam lines!
	vec2 uv_offset = vec2(fract(instance_seed * 13.37), fract(instance_seed * 7.91));
	
	// Domain warp prevents straight parallel texture repeats
	float warp_x = noise2d(UV * vec2(3.0, 8.0) + uv_offset * 10.0) * 0.06 - 0.03;
	float warp_y = noise2d(UV * vec2(4.0, 12.0) + uv_offset * 15.0) * 0.04 - 0.02;
	vec2 warped_uv = (UV + vec2(warp_x, warp_y)) * uv_scale + uv_offset;
	
	vec4 albedo_sample = texture(albedo_tex, warped_uv);
	vec3 norm_sample = texture(normal_tex, warped_uv).rgb * 2.0 - 1.0;
	float rough_sample = texture(roughness_tex, warped_uv).r;
	float ao_sample = texture(ao_tex, warped_uv).r;
	
	// Per-tree individual natural tint variation
	vec3 tree_color_seed = hash3(vec3(instance_seed * 47.1, instance_seed * 83.3, instance_seed * 29.7));
	float tint_warmth = (tree_color_seed.x - 0.5) * 0.14;
	float tint_brightness = 0.94 + tree_color_seed.y * 0.12;
	vec3 tint_shift = vec3(1.0 + tint_warmth, 1.0 + tint_warmth * 0.5, 1.0 - tint_warmth * 0.5) * tint_brightness;
	
	vec3 base_color = albedo_sample.rgb * trunk_tint * tint_shift;
	float final_roughness = rough_sample;
	
	// SPECIES-SPECIFIC MATERIAL CALIBRATION (matching the 5 photos):
	if (species_type == 0) {
		// OAK (Foto 3): Deep weathered fissures, gray-brown ridges, strong cavity occlusion
		// Deep crevices are darker and flatter
		float crevice = 1.0 - ao_sample;
		base_color *= mix(vec3(1.0), vec3(0.55, 0.48, 0.40), crevice * 0.7);
		final_roughness = mix(rough_sample, 0.96, crevice * 0.5);
	}
	else if (species_type == 1) {
		// EUCALYPTUS (Foto 1): Peeling ribbons with silky cream under-wood
		// Light areas are exposed smooth wood (satin sheen), dark areas are dry weathered ribbons (rough matte)
		float is_exposed_wood = smoothstep(0.40, 0.75, albedo_sample.r);
		final_roughness = mix(0.96, 0.52, is_exposed_wood); // silky exposed wood
		// Subtle olive/sage undertone in exposed wood
		vec3 wood_glow = vec3(1.04, 1.02, 0.92);
		base_color = mix(base_color, base_color * wood_glow, is_exposed_wood * 0.6);
	}
	else if (species_type == 2) {
		// BIRCH (Foto 2): Chalky white bark with dark scars / eyes
		// Dark scars (eyes) are rough and brownish-black
		float is_dark_scar = 1.0 - smoothstep(0.35, 0.65, albedo_sample.r);
		final_roughness = mix(0.68, 0.97, is_dark_scar);
		// Enhance contrast of eye scars
		base_color = mix(base_color, base_color * vec3(0.70, 0.62, 0.55), is_dark_scar * 0.4);
	}
	else if (species_type == 3) {
		// PINE PLATES (Foto 4): Dark ash-gray surface plates + bright terracotta/amber under-cracks!
		float is_crevice = 1.0 - ao_sample;
		// Inside cracks: vibrant warm terracotta / cinnamon / amber glow (matching Photo 4)
		vec3 terracotta = vec3(0.78, 0.38, 0.16) * albedo_sample.rgb * 1.8;
		base_color = mix(base_color, terracotta, smoothstep(0.35, 0.85, is_crevice) * 0.85);
		final_roughness = mix(0.78, 0.95, is_crevice);
	}
	else if (species_type == 4) {
		// CORRUGATED (Foto 5): Dense vertical fibrous grooves
		float groove = 1.0 - ao_sample;
		base_color *= mix(vec3(1.0), vec3(0.60, 0.50, 0.42), groove * 0.6);
		final_roughness = clamp(rough_sample * 1.05, 0.70, 0.98);
	}
	
	// Root flare ground moisture: darker and slightly glossy near soil
	float base_distance = max(0.0, tree_height);
	float root_moisture = (1.0 - smoothstep(0.0, 3.2, base_distance)) * wetness_at_base;
	base_color *= mix(vec3(1.0), vec3(0.65, 0.60, 0.52), root_moisture);
	final_roughness = mix(final_roughness, final_roughness * 0.65, root_moisture);
	
	// Crevice moss & organic lichen growth:
	// Concentrated in deep crevices, upward slopes, and tree base
	float up_facing = clamp(world_normal.y, 0.0, 1.0);
	float crevice_depth = pow(1.0 - ao_sample, 1.5);
	float moss_probability = crevice_depth * 0.75 + root_moisture * 0.60 + up_facing * 0.40;
	
	// Modulate moss in organic natural patches
	float moss_noise = noise2d(world_pos.xz * 1.8 + vec2(instance_seed * 23.0));
	float moss_mask = smoothstep(0.42, 0.82, moss_probability * (0.5 + moss_noise * 0.9)) * moss_amount;
	
	// Velvet moss appearance (soft diffuse tint, high roughness)
	vec3 moss_patch = moss_color * (0.8 + moss_noise * 0.45);
	base_color = mix(base_color, moss_patch, moss_mask);
	final_roughness = mix(final_roughness, 0.96, moss_mask);
	
	// High-fidelity normal mapping with depth
	vec3 normal_mapped = norm_sample;
	normal_mapped.xy *= normal_scale;
	vec3 world_tangent_normal = normalize(TANGENT * normal_mapped.x + BINORMAL * normal_mapped.y + NORMAL * normal_mapped.z);
	
	ALBEDO = base_color;
	NORMAL = world_tangent_normal;
	ROUGHNESS = clamp(final_roughness, 0.42, 0.98);
	SPECULAR = 0.20;
	AO = mix(ao_sample, 0.15, root_moisture * 0.5);
	AO_LIGHT_AFFECT = 0.90; // Shadows deeply darken the crevices
}
