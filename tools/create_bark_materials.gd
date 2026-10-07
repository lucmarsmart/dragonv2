@tool
extends SceneTree

func _init() -> void:
	print("Creating Multi-layer PBR Bark Materials...")
	var shader = load("res://shaders/realistic_bark.gdshader") as Shader
	if not shader:
		push_error("Could not load realistic_bark.gdshader")
		quit(1)
		return
		
	var configs = [
		{
			"id": "oak",
			"species_type": 0,
			"uv_scale": Vector2(2.4, 5.0),
			"normal_scale": 2.8,
			"moss_color": Color(0.24, 0.36, 0.16),
			"moss_amount": 0.38,
			"wetness_at_base": 0.48,
			"trunk_tint": Color(0.96, 0.94, 0.90)
		},
		{
			"id": "eucalyptus",
			"species_type": 1,
			"uv_scale": Vector2(1.2, 3.6),
			"normal_scale": 2.2,
			"moss_color": Color(0.28, 0.36, 0.22),
			"moss_amount": 0.20,
			"wetness_at_base": 0.32,
			"trunk_tint": Color(1.03, 1.01, 0.97)
		},
		{
			"id": "birch",
			"species_type": 2,
			"uv_scale": Vector2(1.2, 3.8),
			"normal_scale": 2.0,
			"moss_color": Color(0.22, 0.30, 0.18),
			"moss_amount": 0.18,
			"wetness_at_base": 0.35,
			"trunk_tint": Color(1.25, 1.25, 1.20)
		},
		{
			"id": "pine_plates",
			"species_type": 3,
			"uv_scale": Vector2(1.6, 4.2),
			"normal_scale": 2.8,
			"moss_color": Color(0.20, 0.27, 0.14),
			"moss_amount": 0.26,
			"wetness_at_base": 0.42,
			"trunk_tint": Color(1.0, 0.97, 0.94)
		},
		{
			"id": "corrugated",
			"species_type": 4,
			"uv_scale": Vector2(2.4, 6.5),
			"normal_scale": 2.6,
			"moss_color": Color(0.21, 0.29, 0.14),
			"moss_amount": 0.32,
			"wetness_at_base": 0.45,
			"trunk_tint": Color(0.95, 0.91, 0.87)
		}
	]
	
	for cfg in configs:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		var prefix = "res://assets/environment/bark/bark_" + cfg["id"] + "_"
		
		var diff = load(prefix + "diff_2k.png")
		var nor = load(prefix + "nor_gl_2k.png")
		var rough = load(prefix + "rough_2k.png")
		var ao = load(prefix + "ao_2k.png")
		
		mat.set_shader_parameter("species_type", cfg["species_type"])
		mat.set_shader_parameter("albedo_tex", diff)
		mat.set_shader_parameter("normal_tex", nor)
		mat.set_shader_parameter("roughness_tex", rough)
		mat.set_shader_parameter("ao_tex", ao)
		mat.set_shader_parameter("uv_scale", cfg["uv_scale"])
		mat.set_shader_parameter("normal_scale", cfg["normal_scale"])
		mat.set_shader_parameter("moss_color", cfg["moss_color"])
		mat.set_shader_parameter("moss_amount", cfg["moss_amount"])
		mat.set_shader_parameter("wetness_at_base", cfg["wetness_at_base"])
		mat.set_shader_parameter("trunk_tint", cfg["trunk_tint"])
		
		var save_path = "res://assets/environment/bark/mat_bark_" + cfg["id"] + ".tres"
		var err = ResourceSaver.save(mat, save_path)
		print("Saved PBR bark material: ", save_path, " (res=", err, ")")
		
	quit(0)
