@tool
extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("STARTING SCENIC CAPTURE...")
	var root_node = Node3D.new()
	root.add_child(root_node)

	# Sun
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-39.0, -38.0, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	root_node.add_child(sun)

	# Environment
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.65, 0.78, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.60, 0.65)
	env.ambient_light_energy = 0.65
	env_node.environment = env
	root_node.add_child(env_node)

	# Landscape
	var terrain = load("res://assets/models/terrain.glb").instantiate()
	terrain.set_script(load("res://scripts/terrain.gd"))
	root_node.add_child(terrain)

	var cam := Camera3D.new()
	cam.current = true
	cam.fov = 72.0
	root_node.add_child(cam)

	for f in 15:
		await process_frame

	# 1. Panorama of the rolling green forest with multiple tree species and gentle knolls
	cam.global_position = Vector3(-300, 48, 240)
	cam.look_at(Vector3(-450, 14, -60), Vector3.UP)
	for f in 8:
		await process_frame
	var img1 = root.get_viewport().get_texture().get_image()
	if img1:
		img1.save_png("c:/Proyectos/Dragon v2/nature_hills_view.png")
		print("Saved nature_hills_view.png")

	# 2. Deep forest view along the stream / riachuelo with boulders and streamside trees
	var sx = terrain.stream_west_center(50)
	cam.global_position = Vector3(sx + 3.0, 4.2, 70)
	cam.look_at(Vector3(sx, 1.2, 20), Vector3.UP)
	for f in 8:
		await process_frame
	var img2 = root.get_viewport().get_texture().get_image()
	if img2:
		img2.save_png("c:/Proyectos/Dragon v2/nature_stream_view.png")
		print("Saved nature_stream_view.png")

	# 3. Alpine Forest Lake in the wide clearing (Foto 4)
	cam.global_position = Vector3(-520 + 70, 15.0, -280 + 60)
	cam.look_at(Vector3(-520, 0.7, -280), Vector3.UP)
	for f in 8:
		await process_frame
	var img3 = root.get_viewport().get_texture().get_image()
	if img3:
		img3.save_png("c:/Proyectos/Dragon v2/nature_lake_view.png")
		print("Saved nature_lake_view.png")

	print("ALL THREE PERSPECTIVES CAPTURED SUCCESSFULLY!")
	quit(0)
