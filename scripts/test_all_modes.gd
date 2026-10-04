@tool
extends SceneTree

func _init():
	print("--- VERIFYING ALL 6 FLIGHT MODES IN GAME ---")
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(5): await process_frame
	
	var dragon = scene.get_node("Dragon")
	var cam = scene.get_node("FlightCamera")
	
	# Helper to advance frames naturally
	var advance = func(n_frames):
		for f in range(n_frames):
			await process_frame
			
	# 1. NORMAL CRUISE FLIGHT (after takeoff)
	await advance.call(100)
	var p1 = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/b0204162-bebf-4cb6-b7d8-eda9ec5ebf28/verify_01_normal.png"
	root.get_viewport().get_texture().get_image().save_png(p1)
	print("Saved verify_01_normal")
	
	# 2. CLIMB
	dragon.trigger_climb()
	await advance.call(60)
	var p2 = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/b0204162-bebf-4cb6-b7d8-eda9ec5ebf28/verify_02_climb.png"
	root.get_viewport().get_texture().get_image().save_png(p2)
	print("Saved verify_02_climb")
	
	# 3. GLIDE
	dragon.toggle_glide()
	await advance.call(60)
	var p3 = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/b0204162-bebf-4cb6-b7d8-eda9ec5ebf28/verify_03_glide.png"
	root.get_viewport().get_texture().get_image().save_png(p3)
	print("Saved verify_03_glide")
	
	# 4. DIVE
	dragon.toggle_dive()
	await advance.call(60)
	var p4 = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/b0204162-bebf-4cb6-b7d8-eda9ec5ebf28/verify_04_dive.png"
	root.get_viewport().get_texture().get_image().save_png(p4)
	print("Saved verify_04_dive")
	
	# 5. TURN LEFT (BANKING)
	dragon.trigger_normal()
	dragon.target_yaw += deg_to_rad(35.0)
	await advance.call(60)
	var p5 = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/b0204162-bebf-4cb6-b7d8-eda9ec5ebf28/verify_05_turn_left.png"
	root.get_viewport().get_texture().get_image().save_png(p5)
	print("Saved verify_05_turn_left")
	
	# 6. TURN RIGHT (BANKING)
	dragon.target_yaw -= deg_to_rad(70.0)
	await advance.call(60)
	var p6 = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/b0204162-bebf-4cb6-b7d8-eda9ec5ebf28/verify_06_turn_right.png"
	root.get_viewport().get_texture().get_image().save_png(p6)
	print("Saved verify_06_turn_right")
	
	quit(0)
