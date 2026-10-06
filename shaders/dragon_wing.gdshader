shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D skin_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform float skin_roughness = 0.89;
void fragment() {
 ALBEDO = texture(skin_albedo, UV).rgb;
 // This material's normal map uses UV2 in the original GLTF. The stock importer
 // samples UV instead; construct its tangent frame from the correct UV derivatives.
 vec3 dp1 = dFdx(VERTEX), dp2 = dFdy(VERTEX);
 vec2 duv1 = dFdx(UV2), duv2 = dFdy(UV2);
 vec3 p1 = cross(dp2, NORMAL), p2 = cross(NORMAL, dp1);
 vec3 t = p1 * duv1.x + p2 * duv2.x;
 vec3 b = p1 * duv1.y + p2 * duv2.y;
 float length_sq = max(dot(t,t),dot(b,b));
 // Godot stores imported normal maps in RG compression: reconstruct positive Z.
 vec2 normal_xy = (texture(skin_normal, UV2).rg * 2.0 - 1.0) * 0.65;
 vec3 detail = vec3(normal_xy, sqrt(max(0.0, 1.0-dot(normal_xy,normal_xy))));
 if (length_sq > 0.000001) {
  float inv_length = inversesqrt(length_sq);
  NORMAL = normalize((t * detail.x + b * detail.y) * inv_length + NORMAL * detail.z);
 }
 METALLIC = 0.0;
 SPECULAR = 0.3;
 ROUGHNESS = skin_roughness;
}
