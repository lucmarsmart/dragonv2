shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

// ==============================================================================
// SHADER BIOMECÁNICO DE PIEL Y ESCAMAS DE DRAGÓN COLOSAL HIPERREALISTA
// Implementado fiel a las láminas de referencia anatómica (Miológica y Osteológica):
// - Dorso y Flancos: Escamas de tono gris carbón / pizarra oscuro con relieve 3D profundo
// - Zona Ventral: Placas gulares y gastralia transversales en tono marfil/crema pálido
// - Crestas dorsales y cola: Espinas cónicas de queratina/hueso oscuro mineralizado
// - Micro-relieve Voronoi de escamas y oclusión profunda de cavidades (Crevice AO)
// - Tejido muscular vivo con dispersión subcutánea (SSS) y resplandor de vida
// ==============================================================================

uniform sampler2D skin_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap_anisotropic;

// Parámetros de relieve 3D de escamas y osteodermos
uniform float scale_relief_strength : hint_range(1.0, 4.0) = 2.6;
uniform float micro_scale_intensity : hint_range(0.0, 2.0) = 0.85;
uniform float micro_scale_tile : hint_range(10.0, 150.0) = 54.0;
uniform float cavity_occlusion_depth : hint_range(0.0, 1.0) = 0.82;

// Paleta de color según referencia anatómica (Aspecto Vivo)
uniform vec3 charcoal_base : source_color = vec3(0.12, 0.13, 0.14);
uniform vec3 charcoal_highlight : source_color = vec3(0.24, 0.25, 0.27);
uniform vec3 ventral_cream : source_color = vec3(0.74, 0.68, 0.55);
uniform vec3 ventral_shadow : source_color = vec3(0.36, 0.32, 0.25);
uniform vec3 keratin_dark : source_color = vec3(0.10, 0.09, 0.09);
uniform vec3 keratin_crest : source_color = vec3(0.22, 0.20, 0.18);
uniform vec3 subcutaneous_vascular : source_color = vec3(0.44, 0.09, 0.04);

// Parámetros de acabado de superficie
uniform float base_roughness : hint_range(0.1, 1.0) = 0.35;
uniform float scale_specular : hint_range(0.1, 1.0) = 0.55;
uniform float rim_intensity : hint_range(0.0, 1.0) = 0.45;

varying vec3 v_model_pos;
varying vec3 v_model_normal;

void vertex() {
	v_model_pos = VERTEX;
	v_model_normal = NORMAL;
}

// Generador de pseudo-Voronoi para facetado tridimensional de escamas individuales
vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453123);
}

float voronoi_scale(vec2 uv) {
	vec2 g = floor(uv);
	vec2 f = fract(uv);
	float res = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 lattice = vec2(float(x), float(y));
			vec2 offset = hash2(g + lattice);
			vec2 delta = lattice + offset - f;
			float d = dot(delta, delta);
			res = min(res, d);
		}
	}
	return sqrt(res);
}

void fragment() {
	vec4 base_color_sample = texture(skin_albedo, UV);
	vec3 raw_rgb = base_color_sample.rgb;
	
	// 1. RECONSTRUCCIÓN Y AMPLIFICACIÓN DEL MAPA DE NORMALES (RELIEVE 3D)
	vec2 norm_xy = (texture(skin_normal, UV).rg * 2.0 - 1.0) * scale_relief_strength;
	float norm_len_sq = dot(norm_xy, norm_xy);
	float norm_z = sqrt(max(0.001, 1.0 - min(0.99, norm_len_sq * 0.25)));
	vec3 tangent_norm = normalize(vec3(norm_xy, norm_z));
	
	// 2. MICRO-RELIEVE PROCEDURAL DE ESCAMAS IMBRICADAS (ARISTAS Y BISELES)
	vec2 micro_uv = UV * micro_scale_tile;
	float cell = voronoi_scale(micro_uv);
	float cell_dx = voronoi_scale(micro_uv + vec2(0.08, 0.0)) - cell;
	float cell_dy = voronoi_scale(micro_uv + vec2(0.0, 0.08)) - cell;
	vec2 micro_grad = vec2(cell_dx, cell_dy) * micro_scale_intensity * 3.5;
	
	tangent_norm.xy += micro_grad;
	tangent_norm = normalize(tangent_norm);
	
	// Marco tangente desde derivadas de pantalla
	vec3 dp1 = dFdx(VERTEX);
	vec3 dp2 = dFdy(VERTEX);
	vec2 duv1 = dFdx(UV);
	vec2 duv2 = dFdy(UV);
	vec3 p1 = cross(dp2, NORMAL);
	vec3 p2 = cross(NORMAL, dp1);
	vec3 t = p1 * duv1.x + p2 * duv2.x;
	vec3 b = p1 * duv1.y + p2 * duv2.y;
	float len_sq = max(dot(t, t), dot(b, b));
	if (len_sq > 0.000001) {
		float inv_len = inversesqrt(len_sq);
		NORMAL = normalize((t * tangent_norm.x + b * tangent_norm.y) * inv_len + NORMAL * tangent_norm.z);
	}
	
	// 3. OCLUSIÓN DE CAVIDADES / HENDIDURAS ENTRE ESCAMAS (CREVICE AO)
	float crevice = clamp(tangent_norm.z, 0.0, 1.0);
	float cavity_shadow = mix(1.0 - cavity_occlusion_depth, 1.0, smoothstep(0.18, 0.85, crevice));
	
	// 4. MAPEO ANATÓMICO FIEL A LA REFERENCIA (100% LIBRE DE VIOLETA SINTÉTICO)
	// Extraemos la luminancia estructural de las escamas
	float luma = dot(raw_rgb, vec3(0.299, 0.587, 0.114));
	
	// A) Dorso y Flancos: Gris carbón / pizarra oscuro mate con realce en coronas
	vec3 dorsal_scales = mix(charcoal_base * 0.7, charcoal_base, smoothstep(0.1, 0.45, luma));
	dorsal_scales = mix(dorsal_scales, charcoal_highlight, smoothstep(0.45, 0.82, luma));
	
	// B) Identificación de Espinas Dorsales y Cuernos de Queratina
	// El modelo original codificaba espinas en el canal rojo/magenta
	float is_spine = clamp((raw_rgb.r - max(raw_rgb.g, raw_rgb.b) * 1.15) * 4.0, 0.0, 1.0);
	vec3 keratin_bone = mix(keratin_dark, keratin_crest, smoothstep(0.25, 0.75, luma));
	vec3 skin_with_spines = mix(dorsal_scales, keratin_bone, is_spine);
	
	// C) Zona Ventral: Placas gulares y gastralia (garganta, pecho y vientre en tono marfil/crema pálido)
	// Se activa en la cara inferior anatómica (v_model_normal y orientación del cuello/vientre)
	float ventral_factor = clamp(-v_model_normal.y * 1.25 + 0.25, 0.0, 1.0);
	// Además, el cuello en S expone su cara anterior ventral
	float neck_throat = clamp(-v_model_normal.z * 0.8 - v_model_normal.y * 0.6, 0.0, 1.0) * step(0.0, v_model_pos.y);
	float total_ventral = clamp(ventral_factor + neck_throat * 0.6, 0.0, 1.0) * (1.0 - is_spine);
	
	// Estrías de compresión elástica transversales en las placas gulares y gastralia
	float rib_freq = sin(v_model_pos.z * 16.0 + v_model_pos.y * 8.0) * 0.5 + 0.5;
	float plate_groove = smoothstep(0.15, 0.50, rib_freq);
	vec3 ventral_plates = mix(ventral_shadow, ventral_cream, plate_groove * smoothstep(0.15, 0.65, luma));
	
	vec3 final_albedo = mix(skin_with_spines, ventral_plates, total_ventral * 0.88);
	
	// D) Rubor subcutáneo vascular en pliegues y surcos de piel viva
	vec3 living_flush = subcutaneous_vascular * (1.0 - crevice) * 0.45;
	final_albedo += living_flush;
	
	// 5. PROPIEDADES DE SUPERFICIE: QUERATINA DURA Y ESCAMAS MINERALIZADAS
	// Piel natural mate (ref. Dragontwin): grietas muy rugosas, placas apenas satinadas.
	float scale_rough = mix(0.86, base_roughness, smoothstep(0.25, 0.85, crevice));
	scale_rough = mix(scale_rough, 0.28, is_spine * 0.85); // Espinas más lustrosas
	
	// E) Ojo reptiliano noble (un solo ojo por lado en la cabeza)
	bool is_eye_gold = (raw_rgb.r > 0.45 && raw_rgb.g > 0.28 && raw_rgb.b < 0.22 && UV.y > 0.84 && UV.x > 0.58 && UV.x < 0.92);
	bool is_eye_pupil = (raw_rgb.r < 0.12 && raw_rgb.g < 0.10 && raw_rgb.b < 0.10 && UV.y > 0.85 && UV.y < 0.91 && ((UV.x > 0.63 && UV.x < 0.67) || (UV.x > 0.84 && UV.x < 0.88)));
	if (is_eye_gold) {
		final_albedo = vec3(0.95, 0.65, 0.14);
		cavity_shadow = 1.0;
		scale_rough = 0.08;
		EMISSION = vec3(0.40, 0.22, 0.04);
	} else if (is_eye_pupil) {
		final_albedo = vec3(0.01, 0.01, 0.01);
		cavity_shadow = 1.0;
		scale_rough = 0.05;
	}
	
	ALBEDO = final_albedo * cavity_shadow;
	ROUGHNESS = scale_rough;
	METALLIC = 0.0;
	SPECULAR = mix(scale_specular, 0.4, is_spine);
	
	// Oclusión ambiental
	AO = cavity_shadow;
	AO_LIGHT_AFFECT = 0.85;
	
	// Resplandor de borde (Rim Lighting) para silueta viva
	RIM = rim_intensity;
	RIM_TINT = 0.25;
	
	// Transmisión de luz en crestas delgadas
	BACKLIGHT = subcutaneous_vascular * 0.35 * (1.0 - crevice);
}
