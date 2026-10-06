extends SceneTree

func _initialize():
	call_deferred('run')

func run():
	root.size = Vector2i(1280, 720)
	var scene = load('res://scenes/main.tscn').instantiate()
	root.add_child(scene)
	
	# Add a camera overlooking the river
	var cam = Camera3D.new()
	cam.name = "WaterViewCam"
	cam.current = true
	# River center at z=0 is around x=10, water level is 0.7
	cam.position = Vector3(15.0, 4.5, -20.0)
	cam.look_at(Vector3(10.0, 0.7, 30.0), Vector3.UP)
	scene.add_child(cam)
	
	# Wait for shaders and frames to settle
	for i in 60:
		await physics_frame
		await process_frame
		
	var img = root.get_texture().get_image()
	img.save_png("res://test_water_before.png")
	print("SAVED test_water_before.png")
	scene.free()
	quit()
