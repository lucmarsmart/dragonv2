shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// ==============================================================================
// SHADER DE ALAS DE DRAGÓN TRANSLÚCIDAS - CUERO BIOMECÁNICO VIVO
// Con dispersión subsuperficial (SSS), retroiluminación vascular ámbar y relieve
// ==============================================================================

uniform sampler2D skin_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap_anisotropic;

uniform float wing_relief_strength : hint_range(1.0, 3.0) = 2.0;
uniform float wing_roughness : hint_range(0.2, 1.0) = 0.58;
uniform float wing_specular : hint_range(0.1, 1.0) = 0.42;

// Retroiluminación alar (luz solar atravesando la membrana alar como en murciélagos/pterosaurios)
uniform vec3 wing_backlight_color : source_color = vec3(0.72, 0.36, 0.12);
uniform float wing_translucency : hint_range(0.0, 1.5) = 0.85;
uniform float vascular_contrast : hint_range(0.0, 1.5) = 0.65;
uniform float membrane_warmth : hint_range(0.0, 1.0) = 0.50;

void fragment() {
	vec4 albedo_sample = texture(skin_albedo, UV);
	vec3 base_rgb = albedo_sample.rgb;
	
	// 1. RECONSTRUCCIÓN DEL MARCO TANGENTE SOBRE UV2
	// El modelo original mapea los normales del ala en UV2
	vec3 dp1 = dFdx(VERTEX);
	vec3 dp2 = dFdy(VERTEX);
	vec2 duv1 = dFdx(UV2);
	vec2 duv2 = dFdy(UV2);
	vec3 p1 = cross(dp2, NORMAL);
	vec3 p2 = cross(NORMAL, dp1);
	vec3 t = p1 * duv1.x + p2 * duv2.x;
	vec3 b = p1 * duv1.y + p2 * duv2.y;
	float length_sq = max(dot(t, t), dot(b, b));
	
	// Mapa de normales con fuerza de relieve completa
	vec2 normal_xy = (texture(skin_normal, UV2).rg * 2.0 - 1.0) * wing_relief_strength;
	float norm_len_sq = dot(normal_xy, normal_xy);
	float norm_z = sqrt(max(0.001, 1.0 - min(0.99, norm_len_sq * 0.25)));
	vec3 detail = normalize(vec3(normal_xy, norm_z));
	
	if (length_sq > 0.000001) {
		float inv_length = inversesqrt(length_sq);
		NORMAL = normalize((t * detail.x + b * detail.y) * inv_length + NORMAL * detail.z);
	}
	
	// 2. DETECCIÓN DE MEMBRANA ALAR VS HUESOS/FALANGES
	// La membrana es más delgada y translúcida; los huesos (falanges hipertrofiadas) son opacos
	float luma = dot(base_rgb, vec3(0.299, 0.587, 0.114));
	// Las áreas de membrana tienen tono medio-alto y menor grosor en el modelo
	float membrane_mask = smoothstep(0.12, 0.45, luma);
	
	// Contraste vascular: las venas absorben más luz que la membrana translúcida
	float vein_factor = 1.0 - smoothstep(0.15, 0.38, luma) * vascular_contrast * 0.5;
	
	// 3. COLORACIÓN DE CUERO Y PATAGIO VIVO
	// Atenuamos el violeta saturado hacia el cuero orgánico ámbar/grisáceo de la referencia
	vec3 slate_leather = vec3(luma * 0.78, luma * 0.72, luma * 0.65);
	vec3 warm_leather = mix(slate_leather, vec3(0.52, 0.35, 0.22) * luma * 2.2, membrane_warmth * membrane_mask);
	vec3 wing_rgb = mix(base_rgb, warm_leather, 0.55);
	
	// Sombra de hendiduras / arrugas del ala
	float crevice = clamp(detail.z, 0.0, 1.0);
	float wing_ao = mix(0.45, 1.0, smoothstep(0.2, 0.8, crevice));
	
	ALBEDO = wing_rgb * wing_ao;
	
	// 4. RETROILUMINACIÓN / DISPERSIÓN SUBSUPERFICIAL (SSS)
	// Cuando el sol está detrás de las alas, la membrana brilla en cálido ámbar/rojo vascular
	BACKLIGHT = wing_backlight_color * wing_translucency * membrane_mask * vein_factor;
	
	// 5. PROPIEDADES DE SUPERFICIE
	METALLIC = 0.0;
	SPECULAR = mix(wing_specular, 0.55, 1.0 - membrane_mask); // Huesos más brillantes que el cuero
	ROUGHNESS = mix(wing_roughness, 0.42, 1.0 - membrane_mask);
	AO = wing_ao;
	AO_LIGHT_AFFECT = 0.7;
	
	// Resplandor en el borde de la membrana alar
	RIM = 0.45;
	RIM_TINT = 0.4;
}
