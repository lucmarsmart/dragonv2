extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("Instantiating main scene...")
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for i in range(10):
		await process_frame
		
	var cam = scene.get_node_or_null("FlightCamera") as Camera3D
	if cam:
		print("Camera at: ", cam.global_position, " rotation: ", cam.global_rotation)
		
	var vp = root.get_viewport()
	for i in range(5):
		await process_frame
		
	var img = vp.get_texture().get_image()
	var path = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/0549d9c2-5e5f-4a4e-9bb9-ed9a5260b0ea/test_screen.png"
	if img:
		img.save_png(path)
		print("Saved test screen to: ", path)
	else:
		print("No image retrieved")
	quit(0)
