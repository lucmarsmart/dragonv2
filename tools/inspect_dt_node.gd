extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)

	for f in 35:
		await process_frame

	var landscape := main_scene.get_node_or_null("NaturalLandscape") as Node3D
	var dt = landscape.get_node_or_null("FallenOldGrowthTrunks") as MultiMeshInstance3D
	if dt:
		print("Node: ", dt.name)
		print("  visible: ", dt.visible)
		print("  is_inside_tree: ", dt.is_inside_tree())
		print("  global_position: ", dt.global_position)
		print("  visibility_range_end: ", dt.visibility_range_end)
		print("  multimesh: ", dt.multimesh)
		if dt.multimesh:
			print("    mesh: ", dt.multimesh.mesh)
			print("    instance_count: ", dt.multimesh.instance_count)
			if dt.multimesh.mesh:
				print("    mesh surfaces: ", dt.multimesh.mesh.get_surface_count())
				print("    mesh AABB: ", dt.multimesh.mesh.get_aabb())
	else:
		print("dt is NULL!")

	quit(0)
