@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	var dragon = scene.get_node("Dragon")
	var vm = dragon.get_node("VisualModel")
	var cam = scene.get_node("FlightCamera")
	
	print("--- AT INIT ---")
	print("Dragon rotation_degrees: ", dragon.rotation_degrees)
	print("VisualModel rotation_degrees: ", vm.rotation_degrees)
	print("Cam pos: ", cam.global_position)
	print("Cam rot: ", cam.rotation_degrees)
	
	for f in range(10): await process_frame
	
	print("--- AT FRAME 10 ---")
	print("Dragon rotation_degrees: ", dragon.rotation_degrees)
	print("VisualModel rotation_degrees: ", vm.rotation_degrees)
	print("Cam pos: ", cam.global_position)
	print("Cam rot: ", cam.rotation_degrees)
	
	quit(0)
