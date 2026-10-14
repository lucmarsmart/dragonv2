extends SceneTree

func _init():
	var d = load("res://assets/models/dragon.glb").instantiate()
	print("Root:", d.name)
	for m in d.find_children("*", "MeshInstance3D", true, false):
		print("MeshInstance: ", m.name)
		print("  mesh: ", m.mesh)
		for s in m.mesh.get_surface_count():
			var mat = m.mesh.surface_get_material(s)
			var active = m.get_active_material(s)
			print("  surface ", s, ": mat=", mat, " active=", active)
			if mat:
				print("    res_name: '", mat.resource_name, "'")
				if mat is StandardMaterial3D:
					print("    albedo_tex: ", mat.albedo_texture)
					print("    normal_tex: ", mat.normal_texture)
	quit(0)
