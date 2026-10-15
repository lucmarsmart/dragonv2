shader_type sky;
// Cielo de altura (ref. Dragontwin): gradiente atmosférico, sol con halo y un campo de cúmulos
// procedurales proyectado sobre una capa a cierta altura. Sin texturas externas ni TIME para que
// el cubemap de radiancia no se recalcule cada cuadro.

uniform vec3 zenith_color : source_color = vec3(0.20, 0.40, 0.78);
uniform vec3 horizon_color : source_color = vec3(0.70, 0.79, 0.88);
uniform vec3 ground_color : source_color = vec3(0.32, 0.36, 0.38);
uniform float horizon_softness = 0.35;
uniform float sun_disk_size : hint_range(0.0, 0.05) = 0.012;
uniform float sun_glow = 0.55;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.48;
uniform float cloud_sharpness = 2.4;
uniform float cloud_scale = 1.6;
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 cloud_shade : source_color = vec3(0.56, 0.62, 0.72);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 6; i++) {
		v += a * noise(p);
		p = r * p * 2.03 + 11.7;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = dir.y;
	// Gradiente: horizonte claro y lechoso, cenit profundo.
	float t = pow(clamp(up, 0.0, 1.0), horizon_softness);
	vec3 col = mix(horizon_color, zenith_color, t);
	if (up < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-up * 3.0, 0.0, 1.0));
	}
	vec3 sun_dir = LIGHT0_DIRECTION;
	float sun_dot = max(dot(dir, sun_dir), 0.0);
	vec3 sun_col = LIGHT0_COLOR * LIGHT0_ENERGY;
	// Dispersión cálida alrededor del sol (más fuerte cerca del horizonte).
	col += sun_col * pow(sun_dot, 8.0) * sun_glow * (0.35 + 0.65 * (1.0 - t));
	col += sun_col * pow(sun_dot, 64.0) * 0.6;

	// Nubes: proyección sobre un plano (dir.xz / dir.y), atenuadas hacia el horizonte.
	if (up > 0.01) {
		vec2 uv = dir.xz / (up + 0.12) * cloud_scale;
		float n = fbm(uv);
		float density = clamp((n - (1.0 - cloud_coverage)) * cloud_sharpness, 0.0, 1.0);
		// Iluminación barata: muestra desplazada hacia el sol para oscurecer la base.
		float n_sun = fbm(uv + sun_dir.xz * 0.18);
		float shade = clamp(0.55 + (n - n_sun) * 2.6, 0.0, 1.0);
		vec3 cloud = mix(cloud_shade, cloud_lit, shade);
		cloud += sun_col * pow(sun_dot, 6.0) * 0.35 * (1.0 - density);
		float fade = smoothstep(0.01, 0.22, up);
		col = mix(col, cloud, density * fade * 0.92);
	}
	// Disco solar sobre las nubes delgadas.
	float disk = smoothstep(1.0 - sun_disk_size, 1.0 - sun_disk_size * 0.6, sun_dot);
	if (!AT_CUBEMAP_PASS) {
		col += sun_col * disk * 6.0;
	}
	COLOR = col;
}
