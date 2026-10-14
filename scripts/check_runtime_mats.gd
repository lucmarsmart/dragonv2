extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	# Wait for scene tree to process _ready
	for i in range(10):
		await process_frame
		
	var dragon_model = scene.get_node("Dragon/VisualModel/DragonModel")
	print("dragon_model script: ", dragon_model.get_script())
	
	for m: MeshInstance3D in dragon_model.find_children("*", "MeshInstance3D", true, false):
		print("MeshInstance: ", m.name)
		for s in m.mesh.get_surface_count():
			var override_mat = m.get_surface_override_material(s)
			var active_mat = m.get_active_material(s)
			print("  surface ", s, ": override=", override_mat, " active=", active_mat)
			if override_mat is ShaderMaterial:
				print("    Shader: ", override_mat.shader.resource_path if override_mat.shader else "null")
	quit(0)
