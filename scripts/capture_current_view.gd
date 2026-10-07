@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(15):
		await process_frame
	
	var img_path = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/0549d9c2-5e5f-4a4e-9bb9-ed9a5260b0ea/current_view.png"
	root.get_viewport().get_texture().get_image().save_png(img_path)
	print("Saved current_view.png")
	quit(0)
