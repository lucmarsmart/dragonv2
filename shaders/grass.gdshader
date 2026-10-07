shader_type spatial;
render_mode cull_disabled, diffuse_burley;

// Realistic Grass Shader with fluid wind physics and organic root-to-tip gradients
uniform vec3 color_root : source_color = vec3(0.08, 0.15, 0.04);
uniform vec3 color_base : source_color = vec3(0.20, 0.38, 0.08);
uniform vec3 color_mid  : source_color = vec3(0.32, 0.52, 0.11);
uniform vec3 color_tip  : source_color = vec3(0.48, 0.66, 0.15);

uniform vec2 wind_direction = vec2(0.85, 0.52);
uniform float wind_speed = 2.2;
uniform float wind_strength = 0.30;
uniform float wind_turbulence = 0.35;
uniform float roughness = 0.58;
uniform float specular = 0.22;
uniform vec3 backlight_tint = vec3(0.36, 0.52, 0.14);
uniform float ambient_occlusion_strength = 0.65;

varying vec3 v_world_pos;
varying float v_height;
varying vec3 v_color;

void vertex() {
	v_color = COLOR.rgb;
	v_height = clamp(UV.y, 0.0, 1.0);
	
	// Base world position of this instance
	vec3 world_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// Vertex world position
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Height factor: base (0.0) is locked to soil, tip (1.0) moves fluidly
	float height_factor = pow(v_height, 1.6);
	
	vec2 w_dir = normalize(wind_direction);
	vec2 w_perp = vec2(-w_dir.y, w_dir.x);
	
	// 1. Broad rolling gusts traversing the landscape (large scale wavelength)
	float gust_wave = sin(TIME * (wind_speed * 0.8) + dot(world_origin.xz, w_dir) * 0.12);
	// 2. Cross-wind turbulence for organic swirling / billowing
	float cross_wave = sin(TIME * (wind_speed * 1.4) + dot(world_origin.xz, w_perp) * 0.22 + world_origin.x * 0.04);
	// 3. High-frequency micro-flutter (individual blade trembling in breeze)
	float flutter = sin(TIME * (wind_speed * 3.4) + COLOR.b * 12.0 + dot(v_world_pos.xz, w_dir) * 0.7) * 0.20;
	
	// Forward lean in wind direction (always leaning with gusts, smoothly bounded)
	float lean = wind_strength * max(0.12, 0.55 + 0.45 * gust_wave + cross_wave * 0.20 * wind_turbulence + flutter * wind_turbulence);
	float side_sway = wind_strength * 0.30 * (cross_wave * 0.65 + flutter * 0.35) * wind_turbulence;
	
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
	VERTEX.y -= (lean * lean * 0.25) * height_factor;
}

void fragment() {
	// Smooth organic gradient from dark root to pointed tip
	vec3 col;
	if (v_height < 0.22) {
		col = mix(color_root, color_base, v_height / 0.22);
	} else if (v_height < 0.72) {
		col = mix(color_base, color_mid, (v_height - 0.22) / 0.50);
	} else {
		col = mix(color_mid, color_tip, (v_height - 0.72) / 0.28);
	}
	
	// Subtle macro terrain hue variation
	float terrain_var = sin(v_world_pos.x * 0.035 + v_world_pos.z * 0.025) * 0.04;
	col = clamp(col + vec3(terrain_var * 0.4, terrain_var, -terrain_var * 0.2), 0.0, 1.0);
	
	// Individual blade stiffness/tone variation
	float blade_tone = mix(0.92, 1.08, v_color.g);
	col *= blade_tone;
	
	// Ambient occlusion at blade roots (rooted into dark soil)
	float ao = mix(1.0 - ambient_occlusion_strength, 1.0, smoothstep(0.0, 0.35, v_height));
	ALBEDO = col * ao;
	
	// Soft volumetric normal adjustment
	NORMAL = mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.35);
	
	// Surface shading
	ROUGHNESS = roughness;
	SPECULAR = specular;
	
	// Translucent backlight glow when facing sunlight
	BACKLIGHT = backlight_tint * col * 0.90;
}
