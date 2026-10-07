extends Node3D

func _ready() -> void:
	for instance: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		for surface in instance.mesh.get_surface_count():
			var original := instance.mesh.surface_get_material(surface) as StandardMaterial3D
			if not original:
				continue
				
			if "body02_2" in original.resource_name:
				# Alas de dragón translúcidas con retroiluminación y relieve vascular
				var wing_mat := ShaderMaterial.new()
				wing_mat.shader = preload("res://shaders/dragon_wing.gdshader")
				wing_mat.set_shader_parameter("skin_albedo", original.albedo_texture)
				wing_mat.set_shader_parameter("skin_normal", original.normal_texture)
				instance.set_surface_override_material(surface, wing_mat)
			else:
				# Cuerpo, escamas con relieve 3D, micro-textura, oclusión de cavidades y SSS
				var body_mat := ShaderMaterial.new()
				body_mat.shader = preload("res://shaders/dragon_body.gdshader")
				body_mat.set_shader_parameter("skin_albedo", original.albedo_texture)
				body_mat.set_shader_parameter("skin_normal", original.normal_texture)
				instance.set_surface_override_material(surface, body_mat)
