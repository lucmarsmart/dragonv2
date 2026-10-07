@tool
extends SceneTree

const CollisionEffects = preload("res://scripts/collision_effects.gd")

func _init() -> void:
	call_deferred("_run")

func _save_shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	if img:
		img.save_png(path)
		print("CAPTURE_SAVED: ", path)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for i in 25:
		await process_frame
		await physics_frame
		
	var landscape = scene.get_node("NaturalLandscape")
	var dragon = scene.get_node("Dragon")
	var camera = scene.get_node("FlightCamera")
	camera.set_physics_process(false)
	
	var siege_ui = scene.get_node_or_null("SiegeUI")
	if siege_ui: siege_ui.visible = false
	var hud = scene.get_node_or_null("HUD")
	if hud: hud.visible = false
	
	# --- SCENARIO 1: IMPACTO Y POLVO EN ROCA / TIERRA ---
	var dust_target := Vector3(300, 24.5, 120)
	camera.global_position = dust_target + Vector3(8, 4.5, 12)
	camera.look_at(dust_target + Vector3.UP * 1.2)
	
	CollisionEffects.spawn_dust_impact(scene, dust_target, Vector3.UP, 2.8, false)
	camera.add_trauma(0.65)
	
	for i in 12:
		await process_frame
		await physics_frame
	await _save_shot("res://collision_dust_test.png")
	
	# --- SCENARIO 2: IMPACTO Y SALPICADURA EN AGUA ---
	var water_target := Vector3(0, landscape.get_water_level(), 0)
	camera.global_position = water_target + Vector3(10, 4.0, 14)
	camera.look_at(water_target + Vector3.UP * 1.5)
	
	CollisionEffects.spawn_water_splash(scene, water_target, Vector3.UP, 3.0, false)
	camera.add_trauma(0.7)
	
	for i in 14:
		await process_frame
		await physics_frame
	await _save_shot("res://collision_water_test.png")
	
	# --- SCENARIO 3: DRAGON TOUCHDOWN / ATERRIZAJE ---
	dragon.global_position = Vector3(300, 24.1, 135)
	dragon.rotation = Vector3.ZERO
	camera.global_position = dragon.global_position + Vector3(0, 5, 16)
	camera.look_at(dragon.global_position + Vector3.UP * 2)
	
	CollisionEffects.spawn_dust_impact(scene, dragon.global_position, Vector3.UP, 2.2, false)
	CollisionEffects.spawn_surface_wash(scene, dragon.global_position + Vector3(-3, 0, 0), Vector3(0, 0, -5), false)
	CollisionEffects.spawn_surface_wash(scene, dragon.global_position + Vector3(3, 0, 0), Vector3(0, 0, -5), false)
	
	for i in 10:
		await process_frame
		await physics_frame
	await _save_shot("res://collision_landing_test.png")
	
	print("ALL SCENARIOS CAPTURED!")
	scene.queue_free()
	quit(0)
