extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("=== VERIFYING NEW ENVIRONMENT IMPLEMENTATION ===")
	root.size = Vector2i(1280, 720)
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)

	for cl: CanvasLayer in main_scene.find_children("*", "CanvasLayer", true, false):
		cl.visible = false

	for f in 35:
		await process_frame

	var world_env := main_scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env and world_env.environment and world_env.environment.sky:
		var sky = world_env.environment.sky
		print("Sky material type: ", sky.sky_material.get_class())
		if sky.sky_material is PanoramaSkyMaterial:
			var pano = (sky.sky_material as PanoramaSkyMaterial).panorama
			print("Active Panorama texture: ", pano.resource_path if pano else "null")

	var fort := main_scene.get_node_or_null("SiegeEnvironment") as Node3D
	var landscape := main_scene.get_node_or_null("NaturalLandscape") as Node3D
	if not landscape:
		landscape = main_scene.get_node_or_null("Landscape") as Node3D

	if landscape:
		var sb = landscape.get_node_or_null("ScannedGraniteBoulders_01") as MultiMeshInstance3D
		var nb = landscape.get_node_or_null("NamaqualandMonolithBoulders") as MultiMeshInstance3D
		var dt = landscape.get_node_or_null("FallenOldGrowthTrunks") as MultiMeshInstance3D
		if sb and sb.multimesh:
			print("ScannedGraniteBoulders_01 count: ", sb.multimesh.instance_count)
		if nb and nb.multimesh:
			print("NamaqualandMonolithBoulders count: ", nb.multimesh.instance_count)
		if dt and dt.multimesh:
			print("FallenOldGrowthTrunks count: ", dt.multimesh.instance_count)

	if fort:
		var castle = fort.get_node_or_null("MedievalCastleCitadel")
		print("MedievalCastleCitadel present: ", castle != null)
		var sentinels = fort.find_children("RoyalArmorSentinel*", "Node3D", true, false)
		var swords = fort.find_children("FortressRelicGreatsword*", "Node3D", true, false)
		print("RoyalArmorSentinels count: ", sentinels.size())
		print("FortressRelicGreatswords count: ", swords.size())

	var flight_cam = main_scene.get_node_or_null("FlightCamera") as Camera3D
	if flight_cam:
		flight_cam.current = false
		flight_cam.process_mode = Node.PROCESS_MODE_DISABLED

	var cam := Camera3D.new()
	cam.fov = 70.0
	main_scene.add_child(cam)
	cam.make_current()

	var c : Vector3 = fort.arena_center if fort else Vector3(300, 24, 120)

	# 1. Majestic Castle Citadel Vista (Opción A) with entrance breach, towers & sentinel guards
	cam.global_position = c + Vector3(0.0, 16.0, 92.0)
	cam.look_at(c + Vector3(0.0, 8.0, 10.0), Vector3.UP)
	for f in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	var img1 = root.get_texture().get_image()
	if img1:
		img1.save_png("res://capture_castle_citadel.png")
		print("Saved capture_castle_citadel.png")

	# 2. Scanned Granite & Monolith Boulders on fortress slopes & riverbed
	var b_pos: Vector3 = landscape.boulder_transforms[0].origin if landscape and landscape.boulder_transforms.size() > 0 else Vector3(300.0, 24.0, 120.0)
	cam.global_position = b_pos + Vector3(3.8, 1.8, 3.8)
	cam.look_at(b_pos + Vector3(0, 0.4, 0), Vector3.UP)
	for f in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	var img2 = root.get_texture().get_image()
	if img2:
		img2.save_png("res://capture_riverbed_boulders.png")
		print("Saved capture_riverbed_boulders.png at boulder pos ", b_pos)

	# 3. Forest Clearings & Low-Gliding Valley with Fallen Old-Growth Timber
	var l_pos: Vector3 = landscape.log_transforms[0].origin if landscape and landscape.log_transforms.size() > 0 else Vector3(180.0, 30.0, 110.0)
	cam.global_position = l_pos + Vector3(3.5, 1.6, 3.5)
	cam.look_at(l_pos + Vector3(0, 0.3, 0), Vector3.UP)
	for f in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	var img3 = root.get_texture().get_image()
	if img3:
		img3.save_png("res://capture_fallen_logs.png")
		print("Saved capture_fallen_logs.png at log pos ", l_pos)

	# 4. Castle Inner Courtyard with Sanctum Egg, Chains & Flanking Relics
	cam.global_position = c + Vector3(0.0, 4.5, 12.0)
	cam.look_at(c + Vector3(0.0, 2.5, -36.0), Vector3.UP)
	for f in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	var img4 = root.get_texture().get_image()
	if img4:
		img4.save_png("res://capture_castle_courtyard.png")
		print("Saved capture_castle_courtyard.png")

	print("=== ALL 4 CAPTURES COMPLETED ===")
	quit(0)
