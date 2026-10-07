@tool
extends SceneTree

const CollisionEffects = preload("res://scripts/collision_effects.gd")

func _init() -> void:
	call_deferred("_run")

func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	if img:
		img.save_png(path)
		print("SAVED_EFFECT_IMAGE: ", path)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := Node3D.new()
	scene.name = "TestScene"
	root.add_child(scene)
	
	# Light
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	light.shadow_enabled = true
	scene.add_child(light)
	
	# Environment
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.65, 0.78, 0.9)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.8)
	env_node.environment = env
	scene.add_child(env_node)
	
	# Terrain
	var landscape = (load("res://assets/models/terrain.glb") as PackedScene).instantiate()
	landscape.set_script(load("res://scripts/terrain.gd"))
	scene.add_child(landscape)
	
	# Camera
	var cam := Camera3D.new()
	cam.current = true
	cam.fov = 70.0
	scene.add_child(cam)
	
	for i in 12:
		await process_frame
		await physics_frame
		
	# --- 1. POLVO: Nube densa de impacto en suelo seco ---
	var dust_pos := Vector3(200, landscape.ground_height(200, 100), 100)
	cam.global_position = dust_pos + Vector3(14, 7, 22)
	cam.look_at(dust_pos + Vector3.UP * 3.5)
	
	CollisionEffects.spawn_dust_impact(scene, dust_pos, Vector3.UP, 3.2, false)
	
	for i in 8:
		await process_frame
		await physics_frame
	await _save("res://rendered_dust_impact.png")
	
	# --- 2. AGUA: Géiser y salpicadura masiva en el río ---
	var water_z: float = 150.0
	var water_x: float = landscape.river_center(water_z)
	var water_y: float = landscape.get_water_level()
	var water_pos := Vector3(water_x, water_y, water_z)
	
	cam.global_position = water_pos + Vector3(16, 7.5, 24)
	cam.look_at(water_pos + Vector3.UP * 4.0)
	
	CollisionEffects.spawn_water_splash(scene, water_pos, Vector3.UP, 3.5, false)
	
	for i in 10:
		await process_frame
		await physics_frame
	await _save("res://rendered_water_splash.png")
	
	print("CAPTURE_FINISHED")
	scene.queue_free()
	quit(0)
