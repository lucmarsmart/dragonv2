shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

// Shader cinematográfico para gotas aeradas de agua y espuma (suave, continuo, sin pixelación)
uniform vec3 foam_color : source_color = vec3(0.94, 0.97, 1.0);
uniform vec3 deep_water : source_color = vec3(0.25, 0.55, 0.75);
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

varying vec3 world_pos;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX[0] *= length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX[1] *= length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX[2] *= length(MODEL_MATRIX[2].xyz);
	world_pos = (INV_VIEW_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv_c = UV * 2.0 - 1.0;
	float dist = length(uv_c);

	// Caída radial suave y continua (Gaussian-smooth, sin pixelación ni discard)
	float radial = exp(-dist * dist * 3.2);

	// Turbulencia orgánica de microgotas continua y armónica
	float turbulence = sin(uv_c.x * 5.0 + world_pos.y * 0.4) * cos(uv_c.y * 5.0 + world_pos.x * 0.4) * 0.12;
	float foam_shape = clamp(radial + turbulence * radial, 0.0, 1.0);

	// Normal convexa para curvatura de gota y relieve especular
	vec3 normal_fake = normalize(vec3(uv_c.x * 0.75, uv_c.y * 0.75, sqrt(max(0.01, 1.0 - dist * dist * 0.8))));
	NORMAL = normal_fake;

	// Desvanecimiento suave contra el terreno y superficie del agua (Soft Particles)
	float depth_raw = texture(depth_texture, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 v_pos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	v_pos.xyz /= v_pos.w;
	float scene_depth = -v_pos.z;
	float particle_depth = -VERTEX.z;
	float depth_fade = clamp((scene_depth - particle_depth) / 0.45, 0.0, 1.0);

	// Tonalidad de agua blanca espumosa con retrodispersión de luz
	vec3 col = mix(deep_water, foam_color, foam_shape * 0.85);
	col = mix(col, COLOR.rgb, 0.20);

	// Brillo especular y Fresnel en los bordes de las gotas
	float fresnel = pow(1.0 - max(0.0, dot(NORMAL, vec3(0.0, 0.0, 1.0))), 2.5);
	col += foam_color * fresnel * 0.25;

	float final_alpha = foam_shape * COLOR.a * depth_fade * 0.90;

	ALBEDO = col;
	ROUGHNESS = 0.20;
	SPECULAR = 0.60;
	ALPHA = final_alpha;
}
