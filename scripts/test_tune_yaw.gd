@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for f in range(5): await process_frame
	
	var dragon = scene.get_node("Dragon")
	dragon.has_taken_off = true
	dragon.anim_player.play("Qishilong_fly2")
	
	for test_yaw in [-10.0, -15.0, -20.0, -25.0, -30.0]:
		dragon.model_yaw_offset = test_yaw
		# Advance 30 frames
		for f in range(30): await process_frame
		
		var img_path = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/b0204162-bebf-4cb6-b7d8-eda9ec5ebf28/yaw_tune_%.0f.png" % abs(test_yaw)
		root.get_viewport().get_texture().get_image().save_png(img_path)
		print("Saved yaw_tune_%.0f" % abs(test_yaw))
		
	quit(0)
