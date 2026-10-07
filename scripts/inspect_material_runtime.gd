extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var model=load("res://assets/models/dragon.glb").instantiate()
	root.add_child(model)
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var mat=mesh.mesh.surface_get_material(i)
			print("MATERIAL ",mesh.name," surface",i," ",mat.resource_name," albedo=",mat.albedo_texture.resource_path," normal=",mat.normal_texture.resource_path if mat.normal_texture else "null"," normal_enabled=",mat.normal_enabled," normal_scale=",mat.normal_scale," roughness=",mat.roughness," specular=",mat.metallic_specular," metallic=",mat.metallic," uv2=",mesh.mesh.surface_get_arrays(i)[Mesh.ARRAY_TEX_UV2] != null)
	model.queue_free()
	await process_frame
	quit()
