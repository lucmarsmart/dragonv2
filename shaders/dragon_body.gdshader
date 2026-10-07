shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

// ==============================================================================
// SHADER BIOMECÁNICO DE PIEL Y ESCAMAS DE DRAGÓN HIPERREALISTA
// Inspirado en anatomía miológica/osteológica y referencia artística colosal:
// - Relieve 3D profundo en escamas con micro-relieve y oclusión de cavidades
// - Vientre/garganta con placas ventrales articuladas en tono hueso/cuero
// - Cuernos y espinas dorsales oscuras de queratina con relieve óseo
// - Dispersión subsuperficial (SSS) y resplandor Fresnel de tejido vivo
// ==============================================================================

uniform sampler2D skin_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap_anisotropic;

// Parámetros de relieve de escamas
uniform float scale_relief_strength : hint_range(1.0, 3.5) = 2.2;
uniform float micro_scale_intensity : hint_range(0.0, 1.5) = 0.65;
uniform float micro_scale_tile : hint_range(10.0, 120.0) = 48.0;
uniform float cavity_occlusion_depth : hint_range(0.0, 1.0) = 0.75;

// Parámetros orgánicos de vida y color
uniform float living_subsurface_weight : hint_range(0.0, 1.0) = 0.35;
uniform vec3 subsurface_color : source_color = vec3(0.38, 0.12, 0.05);
uniform float ventral_countershade_boost : hint_range(0.0, 1.0) = 0.45;
uniform float spine_darkness : hint_range(0.0, 1.0) = 0.55;

// Parámetros de brillo y aspereza
uniform float base_roughness : hint_range(0.1, 1.0) = 0.38;
uniform float scale_specular : hint_range(0.1, 1.0) = 0.52;
uniform float rim_intensity : hint_range(0.0, 1.0) = 0.48;

// Ruido analítico pseudo-Voronoi para relieve fino de escamas secundarias
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
	vec3 base_rgb = base_color_sample.rgb;
	
	// 1. RECONSTRUCCIÓN Y AMPLIFICACIÓN DEL MAPA DE NORMALES (RELIEVE 3D)
	// Godot importa los mapas normales con compresión RG. Descomprimimos Z.
	vec2 norm_xy = (texture(skin_normal, UV).rg * 2.0 - 1.0) * scale_relief_strength;
	float norm_len_sq = dot(norm_xy, norm_xy);
	float norm_z = sqrt(max(0.001, 1.0 - min(0.99, norm_len_sq * 0.25)));
	vec3 tangent_norm = normalize(vec3(norm_xy, norm_z));
	
	// 2. MICRO-RELIEVE PROCEDURAL DE ESCAMAS REPTILIANAS
	// Agrega bisel y filo a cada escama individual para que capture luz direccional
	vec2 micro_uv = UV * micro_scale_tile;
	float cell = voronoi_scale(micro_uv);
	float cell_dx = voronoi_scale(micro_uv + vec2(0.08, 0.0)) - cell;
	float cell_dy = voronoi_scale(micro_uv + vec2(0.0, 0.08)) - cell;
	vec2 micro_grad = vec2(cell_dx, cell_dy) * micro_scale_intensity * 3.5;
	
	tangent_norm.xy += micro_grad;
	tangent_norm = normalize(tangent_norm);
	
	// Construir marco tangente a partir de derivadas de posición y UV
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
	
	// 3. OCLUSIÓN DE CAVIDADES / HENDIDURAS ENTRE ESCAMAS
	// Las grietas y surcos entre escamas se oscurecen naturalmente (crevice AO)
	float crevice = clamp(tangent_norm.z, 0.0, 1.0);
	float cavity_shadow = mix(1.0 - cavity_occlusion_depth, 1.0, smoothstep(0.2, 0.85, crevice));
	
	// 4. TONOS ORGÁNICOS BIOMECÁNICOS Y CORRECCIÓN DE COLOR VIVO
	// Atenuamos el tono magenta/púrpura original hacia el tono pizarra/carbón hiperrealista
	// con brillo cálido subcutáneo en pliegues y surcos
	float luma = dot(base_rgb, vec3(0.299, 0.587, 0.114));
	vec3 slate_charcoal = vec3(luma * 0.82, luma * 0.85, luma * 0.90);
	vec3 organic_skin = mix(base_rgb, slate_charcoal, 0.42);
	
	// Detectar áreas de espinas dorsales (que originalmente eran magenta/rojo chillón)
	// y convertirlas en espinas de queratina oscura y hueso con textura mineral (ref. arte colosal)
	float is_red_spine = clamp((base_rgb.r - max(base_rgb.g, base_rgb.b)) * 3.5, 0.0, 1.0);
	vec3 keratin_bone = mix(vec3(0.12, 0.12, 0.13), vec3(0.30, 0.28, 0.24), smoothstep(0.2, 0.7, luma));
	organic_skin = mix(organic_skin, keratin_bone, is_red_spine * 0.95);
	
	// Sombreado de contracolor ventral (vientre más claro en tono hueso/arena)
	// Los dragones y depredadores apex tienen contrasombreado ventral (Thayer's Law)
	float ventral_mask = clamp(-NORMAL.y * 0.75 + 0.35, 0.0, 1.0);
	vec3 ventral_buff = mix(organic_skin, vec3(0.48, 0.42, 0.34), ventral_countershade_boost * ventral_mask);
	organic_skin = ventral_buff;
	
	// Inyección subcutánea viva (hemoglobina en pliegues y tejido muscular interno)
	vec3 live_tissue = organic_skin + subsurface_color * (1.0 - crevice) * living_subsurface_weight;
	
	ALBEDO = live_tissue * cavity_shadow;
	
	// 5. PROPIEDADES DE SUPERFICIE: ASPEREZA, ESPECULAR Y FRESNEL
	// Las coronas de las escamas son duras y reflectantes (roughness ~0.32)
	// Las hendiduras son secas y mates (roughness ~0.78)
	float scale_rough = mix(0.78, base_roughness, smoothstep(0.25, 0.85, crevice));
	// Espinas de queratina tienen brillo propio
	scale_rough = mix(scale_rough, 0.30, is_red_spine * 0.8);
	ROUGHNESS = scale_rough;
	METALLIC = 0.0;
	SPECULAR = scale_specular;
	
	// Oclusión ambiental
	AO = cavity_shadow;
	AO_LIGHT_AFFECT = 0.75;
	
	// Resplandor Fresnel de piel reptiliana viva
	RIM = rim_intensity;
	RIM_TINT = 0.3;
	
	// Sutil transmisión en pliegues y bordes
	BACKLIGHT = subsurface_color * 0.35 * (1.0 - crevice);
}
