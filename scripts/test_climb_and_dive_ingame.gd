@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(15): await process_frame
	
	var dragon = scene.get_node("Dragon")
	var cam = scene.get_node("FlightCamera")
	dragon.has_taken_off = true
	
	# Warm up in normal flight
	dragon.trigger_normal()
	for f in range(40):
		dragon._physics_process(1.0 / 60.0)
		dragon._process(1.0 / 60.0)
		cam._physics_process(1.0 / 60.0)
		await process_frame
		
	# 1. TRIGGER CLIMB
	dragon.trigger_climb()
	for f in range(60):
		dragon._physics_process(1.0 / 60.0)
		dragon._process(1.0 / 60.0)
		cam._physics_process(1.0 / 60.0)
		await process_frame
		
	var img_climb = root.get_viewport().get_texture().get_image()
	if img_climb:
		img_climb.save_png("c:/Proyectos/Dragon v2/test_climb_ingame.png")
		print("Saved test_climb_ingame.png")
		
	# 2. TRIGGER DIVE
	dragon.toggle_dive()
	for f in range(60):
		dragon._physics_process(1.0 / 60.0)
		dragon._process(1.0 / 60.0)
		cam._physics_process(1.0 / 60.0)
		await process_frame
		
	var img_dive = root.get_viewport().get_texture().get_image()
	if img_dive:
		img_dive.save_png("c:/Proyectos/Dragon v2/test_dive_ingame.png")
		print("Saved test_dive_ingame.png")
		
	quit(0)
