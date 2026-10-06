extends Node3D

func _ready() -> void:
	for instance: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		for surface in instance.mesh.get_surface_count():
			var original := instance.mesh.surface_get_material(surface) as StandardMaterial3D
			if original:
				# Exported IOR=1000 creates mirror highlights on organic skin.
				var skin := original.duplicate() as StandardMaterial3D
				skin.metallic_specular = 0.22
				skin.roughness = maxf(skin.roughness, 0.65)
				instance.set_surface_override_material(surface, skin)
			if original and "body02_2" in original.resource_name:
				var material := ShaderMaterial.new()
				material.shader = preload("res://shaders/dragon_wing.gdshader")
				material.set_shader_parameter("skin_albedo", original.albedo_texture)
				material.set_shader_parameter("skin_normal", original.normal_texture)
				material.set_shader_parameter("skin_roughness", original.roughness)
				instance.set_surface_override_material(surface, material)
