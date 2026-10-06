extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var model=load("res://assets/models/dragon.glb").instantiate()
	root.add_child(model)
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var mat=mesh.mesh.surface_get_material(i)
			print("MATERIAL ",mesh.name," surface",i," ",mat.resource_name," albedo=",mat.albedo_texture.resource_path," normal=",mat.normal_texture.resource_path," roughness=",mat.roughness," specular=",mat.metallic_specular," metallic=",mat.metallic)
	model.queue_free()
	await process_frame
	quit()
