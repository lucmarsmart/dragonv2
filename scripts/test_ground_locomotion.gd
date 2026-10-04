@tool
extends SceneTree

# Test de locomoción y aterrizaje
func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for f in range(25): await process_frame
	
	var dragon = scene.get_node("Dragon")
	print("Dragon initial pos: ", dragon.global_position)
	print("Initial locomotion state: ", dragon.get("locomotion_state"))
	
	quit(0)
