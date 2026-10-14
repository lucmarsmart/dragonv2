shader_type spatial;
render_mode cull_disabled, diffuse_burley;

// ==============================================================================
// PHOTO-REALISTIC 3D ANIMATED GRASS BLADE SHADER
// Features: Multi-frequency fluid wind physics, PBR texture mapping,
// subsurface sunlight translucency (backlight), root AO, and natural color variance.
// ==============================================================================

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;
uniform sampler2D texture_normal : hint_normal, filter_linear_mipmap;
uniform sampler2D texture_arm : hint_default_white, filter_linear_mipmap;
uniform bool use_photographic_texture = true;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.35;

// Botanical coloration
uniform vec3 color_root : source_color = vec3(0.12, 0.22, 0.05);
uniform vec3 color_base : source_color = vec3(0.22, 0.40, 0.08);
uniform vec3 color_mid  : source_color = vec3(0.36, 0.56, 0.12);
uniform vec3 color_tip  : source_color = vec3(0.50, 0.70, 0.16);

// Wind physics
uniform vec2 wind_direction = vec2(0.85, 0.52);
uniform float wind_speed = 2.4;
uniform float wind_strength = 0.34;
uniform float wind_turbulence = 0.38;

// PBR surface properties
uniform float roughness = 0.58;
uniform float specular = 0.22;
uniform vec3 backlight_tint : source_color = vec3(0.42, 0.58, 0.15);
uniform float ambient_occlusion_strength = 0.70;

varying vec3 v_world_pos;
varying float v_height;
varying vec3 v_color;

void vertex() {
	v_color = COLOR.rgb;
	
	// Base world position of this grass instance
	vec3 world_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// Vertex world position
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Height factor: support both procedural UV.y and gltf VERTEX.y
	float h_val = max(UV.y, clamp(VERTEX.y * 3.4, 0.0, 1.0));
	v_height = h_val;
	
	// Quadratic height bending: root (0.0) is firmly anchored in dirt, tip (1.0) arches fluidly
	float height_factor = pow(h_val, 1.6);
	
	vec2 w_dir = normalize(wind_direction);
	vec2 w_perp = vec2(-w_dir.y, w_dir.x);
	
	// 1. Broad rolling gusts traversing the landscape (large scale wavelength)
	float gust_wave = sin(TIME * (wind_speed * 0.85) + dot(world_origin.xz, w_dir) * 0.14);
	// 2. Cross-wind turbulence for organic billowing and swirling
	float cross_wave = sin(TIME * (wind_speed * 1.45) + dot(world_origin.xz, w_perp) * 0.24 + world_origin.x * 0.04);
	// 3. High-frequency micro-flutter (individual blade trembling in breeze)
	float flutter = sin(TIME * (wind_speed * 3.8) + dot(v_world_pos.xz, w_dir) * 0.85 + world_origin.z * 0.35) * 0.22;
	
	// Forward lean in wind direction (always leaning with gusts, smoothly bounded)
	float lean = wind_strength * max(0.10, 0.58 + 0.42 * gust_wave + cross_wave * 0.22 * wind_turbulence + flutter * wind_turbulence);
	float side_sway = wind_strength * 0.32 * (cross_wave * 0.65 + flutter * 0.35) * wind_turbulence;
	
	// Combined displacement in world space
	vec3 world_disp = vec3(
		w_dir.x * lean + w_perp.x * side_sway,
		0.0,
		w_dir.y * lean + w_perp.y * side_sway
	) * height_factor;
	
	// Convert world displacement into local model space
	mat3 inv_model = inverse(mat3(MODEL_MATRIX));
	vec3 local_disp = inv_model * world_disp;
	VERTEX += local_disp;
	
	// Natural downward droop as blade bends under wind pressure
	VERTEX.y -= (lean * lean * 0.28) * height_factor;
}

void fragment() {
	// Smooth organic gradient from dark soil root to pointed sunlit tip
	vec3 col;
	if (v_height < 0.22) {
		col = mix(color_root, color_base, v_height / 0.22);
	} else if (v_height < 0.72) {
		col = mix(color_base, color_mid, (v_height - 0.22) / 0.50);
	} else {
		col = mix(color_mid, color_tip, (v_height - 0.72) / 0.28);
	}
	
	if (use_photographic_texture) {
		vec4 tex_col = texture(texture_albedo, UV);
		if (tex_col.a < alpha_scissor_threshold) {
			discard;
		}
		// Blend photographic grain with natural gradient
		col = mix(col, tex_col.rgb * col * 1.85, 0.75);
	}
	
	// Subtle macro terrain hue variation
	float terrain_var = sin(v_world_pos.x * 0.035 + v_world_pos.z * 0.025) * 0.04;
	col = clamp(col + vec3(terrain_var * 0.3, terrain_var * 0.8, -terrain_var * 0.2), 0.0, 1.0);
	
	// Individual blade stiffness/tone variation
	float blade_tone = mix(0.92, 1.08, v_color.g);
	col *= blade_tone;
	
	// Ambient occlusion at blade roots (rooted into dark soil)
	float ao_tex = texture(texture_arm, UV).r;
	float ao_height = mix(1.0 - ambient_occlusion_strength, 1.0, smoothstep(0.0, 0.38, v_height));
	float total_ao = min(ao_tex, ao_height);
	ALBEDO = col * total_ao;
	
	// Normal mapping for realistic 3D blade relief
	if (use_photographic_texture) {
		NORMAL_MAP = texture(texture_normal, UV).rgb;
		NORMAL_MAP_DEPTH = 1.0;
	} else {
		NORMAL = mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.35);
	}
	
	// Surface roughness
	float r_tex = texture(texture_arm, UV).g;
	ROUGHNESS = mix(roughness, r_tex, 0.65);
	SPECULAR = specular;
	
	// Translucent backlight glow when facing sunlight (simulating light passing through leaf cells)
	BACKLIGHT = backlight_tint * col * 0.95;
}
