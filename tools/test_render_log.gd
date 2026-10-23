extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)

	for cl: CanvasLayer in main_scene.find_children("*", "CanvasLayer", true, false):
		cl.visible = false

	for f in 35:
		await process_frame

	var landscape := main_scene.get_node_or_null("NaturalLandscape") as Node3D
	if not landscape:
		print("ERROR: NaturalLandscape not found")
		quit(1)
		return

	var logs = landscape.get("log_transforms") as Array
	print("Found logs: ", logs.size())
	if logs.is_empty():
		quit(1)
		return

	var flight_cam = main_scene.get_node_or_null("FlightCamera") as Camera3D
	if flight_cam:
		flight_cam.current = false
		flight_cam.process_mode = Node.PROCESS_MODE_DISABLED

	var cam := Camera3D.new()
	cam.fov = 65.0
	main_scene.add_child(cam)
	cam.make_current()

	# Take first log in valley
	var log_xf: Transform3D = logs[0]
	var pos: Vector3 = log_xf.origin
	print("Testing log at: ", pos)

	# Look directly at the log from 3.2m away, 1.2m high
	cam.global_position = pos + Vector3(2.5, 1.4, 2.5)
	cam.look_at(pos + Vector3(0, 0.3, 0), Vector3.UP)

	for f in 20:
		await process_frame
	await RenderingServer.frame_post_draw

	var img = root.get_texture().get_image()
	if img:
		img.save_png("res://capture_log_closeup.png")
		print("Saved capture_log_closeup.png")

	quit(0)
