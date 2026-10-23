extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)

	for cl: CanvasLayer in main_scene.find_children("*", "CanvasLayer", true, false):
		cl.visible = false

	var flight_cam = main_scene.get_node_or_null("FlightCamera") as Camera3D
	if flight_cam:
		flight_cam.current = false
		flight_cam.process_mode = Node.PROCESS_MODE_DISABLED

	var landscape = main_scene.get_node_or_null("NaturalLandscape")
	# Disable visibility_range_end on all MultiMeshes
	for c in landscape.get_children():
		if c is MultiMeshInstance3D:
			c.visibility_range_end = 0.0

	var cam := Camera3D.new()
	cam.fov = 65.0
	main_scene.add_child(cam)
	cam.make_current()

	var l_pos: Vector3 = landscape.log_transforms[0].origin
	var cam_offset := Vector3(3.2, 0.0, 3.2)
	var cam_x: float = l_pos.x + cam_offset.x
	var cam_z: float = l_pos.z + cam_offset.z
	var cam_ground: float = landscape.ground_height(cam_x, cam_z)
	var cam_y: float = maxf(l_pos.y + 1.4, cam_ground + 1.2)
	var cam_pos := Vector3(cam_x, cam_y, cam_z)
	cam.global_position = cam_pos
	cam.look_at(l_pos + Vector3(0.0, 0.35, 0.0), Vector3.UP)

	for f in 25:
		await process_frame
	await RenderingServer.frame_post_draw

	var img = root.get_texture().get_image()
	if img:
		img.save_png("res://capture_test_log_vis0.png")
		print("Saved capture_test_log_vis0.png")

	quit(0)
