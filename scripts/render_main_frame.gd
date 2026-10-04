@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(5): await process_frame
	
	var dragon = scene.get_node("Dragon")
	var cam = scene.get_node("FlightCamera")
	
	# Test rendering a frame
	var img_path = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/b0204162-bebf-4cb6-b7d8-eda9ec5ebf28/current_main_frame.png"
	root.get_viewport().get_texture().get_image().save_png(img_path)
	print("Saved current_main_frame.png")
	quit(0)
