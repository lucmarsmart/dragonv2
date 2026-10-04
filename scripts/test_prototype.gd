@tool
extends SceneTree

# Prototype testing full takeoff -> normal flight -> turns
func _init():
	print("--- TESTING PROTOTYPE FLIGHT ---")
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(2): await process_frame
	
	var dragon = scene.get_node("Dragon")
	var cam = scene.get_node("FlightCamera")
	print("Dragon: ", dragon, " Camera: ", cam)
	
	quit(0)
