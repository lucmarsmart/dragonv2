@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(10): await process_frame
	
	var dragon = scene.get_node("Dragon")
	var cam = scene.get_node("FlightCamera")
	
	dragon.has_taken_off = true
	dragon.trigger_normal()
	# Fly and turn left
	dragon.manual_input_override = true
	dragon.manual_turn_input = 1.0 # Left turn
	for f in range(50):
		dragon._physics_process(1.0 / 60.0)
		dragon._process(1.0 / 60.0)
		cam._physics_process(1.0 / 60.0)
		await process_frame
		
	var img = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png("c:/Proyectos/Dragon v2/test_turn_ingame.png")
		print("Saved test_turn_ingame.png successfully!")
		
	quit(0)
