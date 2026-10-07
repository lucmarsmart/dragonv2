shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

// Shader de onda de choque radial expansiva en el terreno (suave, continuo, sin pixelación)
uniform vec3 ring_color : source_color = vec3(0.78, 0.70, 0.58);
uniform float ring_thickness : hint_range(0.05, 0.6) = 0.28;

void fragment() {
	vec2 uv_c = UV * 2.0 - 1.0;
	float dist = length(uv_c);

	// Perfil de anillo suave continuo sin escalones de píxel
	float center_r = 1.0 - ring_thickness * 0.5;
	float diff = abs(dist - center_r);
	float half_thick = ring_thickness * 0.5;
	float ring_shape = smoothstep(half_thick, 0.0, diff);

	ALBEDO = ring_color;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
	ALPHA = ring_shape * COLOR.a * 0.90;
}
