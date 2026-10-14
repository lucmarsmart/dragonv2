shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D needles : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float alpha_cutoff = 0.25;
uniform float wind_strength = 0.18;
uniform float normal_curve = 0.75;

varying vec4 tint;
varying vec3 local_pos;

void vertex() {
	tint = COLOR;
	local_pos = VERTEX;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float bend = clamp(VERTEX.y / 16.0, 0.0, 1.0);
	
	// Organic wind swaying and leaf flutter
	float gust = sin(TIME * 1.8 + wp.x * 0.04 + wp.z * 0.05);
	float flutter = sin(TIME * 4.2 + wp.y * 0.8 + dot(wp.xz, vec2(0.5, 0.5))) * 0.08;
	VERTEX.x += (gust * 0.25 + flutter) * bend * bend * wind_strength;
	VERTEX.z += (sin(TIME * 1.4 + wp.z * 0.06) * 0.20 + flutter) * bend * bend * wind_strength;
}

void fragment() {
	vec4 tex = texture(needles, UV);
	if (tex.a < alpha_cutoff) {
		discard;
	}
	ALBEDO = tex.rgb * tint.rgb;
	ROUGHNESS = 0.72;
	SPECULAR = 0.18;
	
	// Volumetric spherical normal smoothing: softens flat card appearance into organic foliage volume
	vec3 crown_normal = normalize(local_pos + vec3(0.0, 1.5, 0.0));
	NORMAL = normalize(mix(NORMAL, crown_normal, normal_curve));
	
	// Subsurface scattering translucency for sunlight glowing through leaves
	BACKLIGHT = vec3(0.40, 0.55, 0.20) * ALBEDO * 0.90;
}
