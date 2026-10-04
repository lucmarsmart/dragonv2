@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(5): await process_frame
	
	var dragon = scene.get_node("Dragon")
	# Trigger takeoff immediately
	dragon.has_taken_off = true
	dragon.anim_player.play("Qishilong_fly2")
	
	# Let it fly for 90 frames (1.5 seconds)
	for f in range(90): await process_frame
	
	var img_path = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/b0204162-bebf-4cb6-b7d8-eda9ec5ebf28/flight_actual_test.png"
	root.get_viewport().get_texture().get_image().save_png(img_path)
	print("Saved flight_actual_test.png")
	quit(0)
