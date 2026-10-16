shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// ==============================================================================
// SHADER DE ALAS DE DRAGÓN COLOSAL - MEMBRANA ALAR (PATAGIO) TRANSLÚCIDA
// Implementado fiel a las láminas de referencia anatómica (Miológica y Osteológica):
// - Membrana viva: Cuero elástico en tono pardo-rojizo a ocre amarillento / ámbar
// - Vascularización Visible: Denso entramado capilar ramificado visible en el patagio
// - Huesos y Falanges Hipertrofiadas: Húmero, radio, cúbito y dedos alares opacos
// - Retroiluminación / SSS: La luz solar atraviesa el patagio en cálido resplandor ámbar
// ==============================================================================

uniform sampler2D skin_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap_anisotropic;

uniform float wing_relief_strength : hint_range(1.0, 4.0) = 2.4;
uniform float wing_roughness : hint_range(0.2, 1.0) = 0.52;
uniform float wing_specular : hint_range(0.1, 1.0) = 0.45;

// Paleta de cuero vivo y patagio según Lámina 1 y 2
uniform vec3 patagium_amber_base : source_color = vec3(0.70, 0.46, 0.26);
uniform vec3 patagium_ochre_bright : source_color = vec3(0.86, 0.62, 0.36);
uniform vec3 patagium_shadow_edge : source_color = vec3(0.38, 0.24, 0.14);
uniform vec3 wing_bone_charcoal : source_color = vec3(0.13, 0.14, 0.15);
uniform vec3 capillary_vein_color : source_color = vec3(0.38, 0.08, 0.03);

// Transmisión de luz solar a través de la membrana
uniform vec3 wing_backlight_color : source_color = vec3(0.95, 0.52, 0.16);
uniform float wing_translucency : hint_range(0.0, 2.0) = 1.15;
uniform float vascular_vein_density : hint_range(10.0, 100.0) = 48.0;

// Deformación aerodinámica de vuelo
uniform float aero_wind_speed : hint_range(0.0, 60.0) = 0.0;
uniform float aero_billow_amount : hint_range(0.0, 1.0) = 0.0;
uniform float aero_flutter_intensity : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	float span_factor = clamp((abs(VERTEX.x) - 1.2) / 6.0, 0.0, 1.0);
	if (span_factor > 0.01) {
		float billow = aero_billow_amount * span_factor * 0.16;
		VERTEX.y += billow;
		
		if (aero_wind_speed > 25.0) {
			float flutter_freq = TIME * (24.0 + aero_wind_speed * 0.35);
			float flutter = sin(flutter_freq + VERTEX.x * 2.5 + VERTEX.z * 1.8) * aero_flutter_intensity * 0.045 * span_factor;
			VERTEX.y += flutter;
			VERTEX.z += flutter * 0.4;
		}
	}
}

// Red de capilares y venas ramificadas analíticas (Lámina 1 y 2)
float procedural_veins(vec2 uv) {
	vec2 p = uv * vascular_vein_density;
	float v1 = abs(sin(p.x * 0.65 + cos(p.y * 1.15) * 2.2));
	float v2 = abs(cos(p.y * 0.85 + sin(p.x * 1.35) * 2.4));
	float primary = min(v1, v2);
	
	// Bifurcaciones secundarias más finas
	vec2 p2 = uv * (vascular_vein_density * 2.2);
	float v3 = abs(sin(p2.x * 0.8 + sin(p2.y * 1.4) * 1.8));
	float secondary = min(primary, v3 * 1.3);
	
	return 1.0 - smoothstep(0.05, 0.22, secondary);
}

void fragment() {
	vec4 raw_sample = texture(skin_albedo, UV);
	vec3 raw_rgb = raw_sample.rgb;
	
	// 1. RECONSTRUCCIÓN DEL MARCO TANGENTE SOBRE UV2 (Normal map de alas)
	vec3 dp1 = dFdx(VERTEX);
	vec3 dp2 = dFdy(VERTEX);
	vec2 duv1 = dFdx(UV2);
	vec2 duv2 = dFdy(UV2);
	vec3 p1 = cross(dp2, NORMAL);
	vec3 p2 = cross(NORMAL, dp1);
	vec3 t = p1 * duv1.x + p2 * duv2.x;
	vec3 b = p1 * duv1.y + p2 * duv2.y;
	float length_sq = max(dot(t, t), dot(b, b));
	
	vec2 normal_xy = (texture(skin_normal, UV2).rg * 2.0 - 1.0) * wing_relief_strength;
	float norm_len_sq = dot(normal_xy, normal_xy);
	float norm_z = sqrt(max(0.001, 1.0 - min(0.99, norm_len_sq * 0.25)));
	vec3 detail = normalize(vec3(normal_xy, norm_z));
	
	if (length_sq > 0.000001) {
		float inv_length = inversesqrt(length_sq);
		NORMAL = normalize((t * detail.x + b * detail.y) * inv_length + NORMAL * detail.z);
	}
	
	// 2. DISCRIMINACIÓN ANATÓMICA: MEMBRANA INTERDIGITAL VS FALANGES/HUESOS
	// skin_albedo llega en espacio lineal (source_color): la clasificación se hace en espacio
	// perceptual. En lineal la mediana del ala es ~0.06 y todo caía bajo el umbral de membrana,
	// pintando la membrana como hueso carbón (alas que parecían ramas).
	float luma = pow(max(dot(raw_rgb, vec3(0.299, 0.587, 0.114)), 0.0), 1.0 / 2.2);
	// Las falanges y huesos son oscuros/densos en la textura; el patagio interdigital es translúcido y más claro
	float is_membrane = smoothstep(0.19, 0.26, luma);
	
	// 3. COLORACIÓN DE CUERO Y PATAGIO VIVO (100% LIBRE DE VIOLETA SINTÉTICO)
	vec3 patagium_leather = mix(patagium_shadow_edge, patagium_amber_base, smoothstep(0.22, 0.32, luma));
	patagium_leather = mix(patagium_leather, patagium_ochre_bright, smoothstep(0.32, 0.45, luma));
	
	// Huesos alares (falanges hipertrofiadas, húmero y radio) en tono gris carbón / pizarra acorazado
	vec3 wing_bone = mix(wing_bone_charcoal * 0.8, wing_bone_charcoal * 1.4, smoothstep(0.12, 0.22, luma));
	vec3 base_wing = mix(wing_bone, patagium_leather, is_membrane);
	
	// 4. INYECCIÓN DEL ENTRAMADO CAPILAR Y VASCULARIZACIÓN VIVA
	float vein_mask = procedural_veins(UV2) * is_membrane;
	base_wing = mix(base_wing, capillary_vein_color, vein_mask * 0.35);
	
	// Sombra de hendiduras y pliegues alares
	float crevice = clamp(detail.z, 0.0, 1.0);
	float wing_ao = mix(0.40, 1.0, smoothstep(0.2, 0.82, crevice));
	
	ALBEDO = base_wing * wing_ao;
	
	// 5. RETROILUMINACIÓN SOLAR / SSS (LUZ ATRAVESANDO LA MEMBRANA)
	// La membrana alar brilla intensamente en contraluz; las venas y huesos bloquean la luz creando siluetas orgánicas
	float light_transmission = is_membrane * (1.0 - vein_mask * 0.65);
	BACKLIGHT = wing_backlight_color * wing_translucency * light_transmission;
	
	// 6. PROPIEDADES DE SUPERFICIE
	METALLIC = 0.0;
	ROUGHNESS = mix(0.6, wing_roughness, is_membrane); // Hueso con queratina mate, sin brillo de plástico
	SPECULAR = mix(0.35, wing_specular, is_membrane);
	AO = wing_ao;
	AO_LIGHT_AFFECT = 0.8;
}
