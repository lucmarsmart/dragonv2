shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

// Shader de impacto volumétrico de alta densidad (AAA Cinematic Smoke & Dust)
uniform vec3 dust_color : source_color = vec3(0.68, 0.58, 0.44);
uniform vec3 shadow_color : source_color = vec3(0.28, 0.22, 0.16);

varying vec3 world_pos;

// Generador fractal de volutas de humo (FBM multifrecuencia de alta definición)
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float val = 0.0;
	val += noise(p) * 0.52;
	val += noise(p * 2.15 + vec2(1.2, 3.4)) * 0.28;
	val += noise(p * 4.31 + vec2(5.6, 2.1)) * 0.14;
	val += noise(p * 8.64 + vec2(3.1, 7.8)) * 0.06;
	return val;
}

void vertex() {
	// Billboard esférico perfecto que escala con la simulación física
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX[0] *= length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX[1] *= length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX[2] *= length(MODEL_MATRIX[2].xyz);
	world_pos = (INV_VIEW_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv_c = UV * 2.0 - 1.0;
	float dist = length(uv_c);

	// Caída radial suave y continua (sin discard ni bordes dentados)
	float radial = smoothstep(1.0, 0.1, dist);

	// Micro-volutas de humo fractales en rotación radial continua
	float angle = atan(uv_c.y, uv_c.x);
	vec2 sample_pos = vec2(cos(angle) * 1.5, sin(angle) * 1.5) * dist * 2.2 + world_pos.xz * 0.04;
	float smoke_density = fbm(sample_pos);

	float shape_alpha = radial * mix(0.4, 1.0, smoke_density);
	float core_puff = smoothstep(0.9, 0.15, dist);

	// Iluminación hemisférica 3D con luz solar cenital y sombras de oclusión
	vec3 normal_fake = normalize(vec3(uv_c.x, uv_c.y, sqrt(max(0.001, 1.0 - dist * dist))));
	NORMAL = normal_fake;

	vec3 sun_dir = normalize(vec3(0.5, 0.8, -0.3));
	float sun_diffuse = max(0.0, dot(normal_fake, sun_dir));
	
	// Gradiente de luz en la cresta y sombra en la panza de la voluta
	vec3 final_color = mix(shadow_color, dust_color, sun_diffuse * 0.7 + 0.3);
	final_color = mix(final_color, COLOR.rgb, 0.40);

	// Opacidad real volumétrica suave
	float final_alpha = shape_alpha * COLOR.a * mix(0.70, 1.0, core_puff);

	ALBEDO = final_color;
	ROUGHNESS = 0.96;
	SPECULAR = 0.02;
	ALPHA = final_alpha;
}
