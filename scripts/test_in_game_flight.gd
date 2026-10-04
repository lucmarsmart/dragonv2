@tool
extends SceneTree

func _init():
	print("--- TESTING IN-GAME FLIGHT CONTROLLER ---")
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(5): await process_frame
	
	var dragon = scene.get_node("Dragon")
	var cam = scene.get_node("FlightCamera")
	
	print("Dragon position: ", dragon.global_position)
	print("Camera position: ", cam.global_position)
	
	# Run 60 frames for takeoff
	for f in range(60):
		dragon._physics_process(1.0 / 60.0)
		dragon._process(1.0 / 60.0)
		cam._physics_process(1.0 / 60.0)
		await process_frame
		
	var img_path1 = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/b0204162-bebf-4cb6-b7d8-eda9ec5ebf28/ingame_takeoff.png"
	root.get_viewport().get_texture().get_image().save_png(img_path1)
	print("Saved ingame_takeoff.png")
	
	# Run 60 frames for cruise
	for f in range(60):
		dragon._physics_process(1.0 / 60.0)
		dragon._process(1.0 / 60.0)
		cam._physics_process(1.0 / 60.0)
		await process_frame
		
	var img_path2 = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/b0204162-bebf-4cb6-b7d8-eda9ec5ebf28/ingame_cruise.png"
	root.get_viewport().get_texture().get_image().save_png(img_path2)
	print("Saved ingame_cruise.png")
	
	# Turn right
	dragon.target_yaw -= deg_to_rad(45.0)
	for f in range(60):
		dragon._physics_process(1.0 / 60.0)
		dragon._process(1.0 / 60.0)
		cam._physics_process(1.0 / 60.0)
		await process_frame
		
	var img_path3 = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/b0204162-bebf-4cb6-b7d8-eda9ec5ebf28/ingame_turn_right.png"
	root.get_viewport().get_texture().get_image().save_png(img_path3)
	print("Saved ingame_turn_right.png")
	
	quit(0)
