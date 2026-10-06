extends SceneTree
var scene: Node3D
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var dragon = scene.get_node("Dragon")
	dragon.set_physics_process(false)
	dragon.set_process(false)
	var cam: Camera3D = scene.get_node("FlightCamera")
	cam.set_process(false)
	cam.set_physics_process(false)
	cam.far = 7000
	var hud = scene.get_node("HUD")
	hud.visible = false
	DirAccess.make_dir_recursive_absolute("res://artifacts/environment")
	var views = [
		[Vector3(380, 370, 650), Vector3(-160, 80, -250), "aerial"],
		[Vector3(-210, 170, 260), Vector3(-180, 110, -300), "valley"],
		[dragon.global_position + Vector3(0, 12, 38), dragon.global_position, "dragon_landscape"]
	]
	var landscape = scene.get_node("NaturalLandscape")
	var landing = landscape.find_landing_site(Vector3(180, 100, 120))
	views.append([Vector3(88, landscape.ground_height(88, 120) + 7, 120), Vector3(-60, 8, -10), "ground_detail"])
	var close_h = landscape.ground_height(110, 0)
	views.append([Vector3(110, close_h + 2.2, 0), Vector3(108, close_h + 0.15, -6), "texture_detail"])
	for view in views:
		cam.global_position = view[0]
		cam.look_at(view[1])
		landscape._update_forest_lods()
		for i in 35:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/environment/" + view[2] + ".png")
		print("CAPTURE environment/", view[2], " fps=", Performance.get_monitor(Performance.TIME_FPS), " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	scene.queue_free()
	await process_frame
	quit()
