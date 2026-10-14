extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	# Wait for frames so _ready, physics, materials, and camera update
	for i in range(120):
		await process_frame
		
	var img = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png("c:/Proyectos/Dragon v2/ingame_current_dragon.png")
		print("SAVED ingame_current_dragon.png")
	quit(0)
