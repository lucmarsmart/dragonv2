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

	var sc := load("res://assets/environment/trees/dead_tree_trunk_02.glb") as PackedScene
	var inst := sc.instantiate()
	var mi := inst.find_child("*", true, false) as MeshInstance3D
	var mesh = mi.mesh

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D(Basis().scaled(Vector3.ONE * 2.0), Vector3(300, 25.0, 140)))

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "TestMMI"
	mmi.multimesh = mm
	main_scene.add_child(mmi)

	var cam := Camera3D.new()
	cam.fov = 65.0
	main_scene.add_child(cam)
	cam.make_current()

	cam.global_position = Vector3(300, 26.5, 145)
	cam.look_at(Vector3(300, 25.0, 140), Vector3.UP)

	for f in 25:
		await process_frame
	await RenderingServer.frame_post_draw

	var img = root.get_texture().get_image()
	if img:
		img.save_png("res://capture_test_mmi_log.png")
		print("Saved capture_test_mmi_log.png")

	quit(0)
