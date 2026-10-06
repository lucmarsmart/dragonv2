@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	# Wait for ready and a few frames for LOD to compute
	for f in range(15):
		await process_frame
	
	var terrain = scene.get_node("NaturalLandscape")
	var cam = scene.get_node("FlightCamera")
	
	# Find a tree position to point camera at
	var tree_pos = Vector3.ZERO
	if terrain._tree_transforms.size() > 0:
		tree_pos = terrain._tree_transforms[0].origin
	
	# Position camera to look at the tree up close
	var test_cam = Camera3D.new()
	test_cam.current = true
	test_cam.position = tree_pos + Vector3(4.0, 3.0, 6.0)
	test_cam.look_at(tree_pos + Vector3(0, 2.5, 0), Vector3.UP)
	scene.add_child(test_cam)
	
	# Force LOD update
	terrain._update_forest_lods()
	
	for f in range(5):
		await process_frame
	
	var img_path = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/a53d2dc3-e34f-480b-b77b-efaadb2bef9c/initial_trees.png"
	root.get_viewport().get_texture().get_image().save_png(img_path)
	print("Saved initial_trees.png at pos: ", test_cam.position, " looking at: ", tree_pos)
	quit(0)
