extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	# Hide UI overlay
	var siege_ui = scene.get_node_or_null("SiegeUI")
	if siege_ui: siege_ui.visible = false
	var hud = scene.get_node_or_null("HUD")
	if hud: hud.visible = false
	
	var dragon = scene.get_node("Dragon")
	var cam: Camera3D = scene.get_node("FlightCamera")
	
	# Wait for materials and flight physics to calibrate
	for f in range(40): await process_frame
	
	# 1. Colossal dragon heroic follow view
	cam.distance = 18.0
	cam.height = 4.5
	for f in range(10): await process_frame
	var img_hero = root.get_viewport().get_texture().get_image()
	if img_hero:
		img_hero.save_png("c:/Proyectos/Dragon v2/showcase_colossal_flight.png")
		print("Saved showcase_colossal_flight.png")
		
	# 2. Side-quarter heroic profile showing colossal wingspan and body
	cam.distance = 22.0
	cam.height = 6.0
	for f in range(10): await process_frame
	var img_profile = root.get_viewport().get_texture().get_image()
	if img_profile:
		img_profile.save_png("c:/Proyectos/Dragon v2/showcase_colossal_profile.png")
		print("Saved showcase_colossal_profile.png")
		
	# 3. Close-up of the HEAD showing SINGLE EYE PER SIDE
	var skel: Skeleton3D = dragon.skeleton
	var b_head = dragon.bone_head_idx
	var head_world = skel.global_transform * skel.get_bone_global_pose(b_head).origin
	
	cam.set_script(null) # Detach flight camera script for manual inspection placement
	cam.fov = 32.0
	cam.global_position = head_world + dragon.global_basis.x * 2.8 + dragon.global_basis.y * 0.8 - dragon.global_basis.z * 1.5
	cam.look_at(head_world, Vector3.UP)
	for f in range(5): await process_frame
	var img_head = root.get_viewport().get_texture().get_image()
	if img_head:
		img_head.save_png("c:/Proyectos/Dragon v2/showcase_single_eye_head.png")
		print("Saved showcase_single_eye_head.png")
		
	quit(0)
