extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	# Hide intro brief overlay so dragon is fully visible
	var siege_ui = scene.get_node_or_null("SiegeUI")
	if siege_ui:
		siege_ui.visible = false
		
	var dragon = scene.get_node("Dragon")
	var cam: Camera3D = scene.get_node("FlightCamera")
	
	# Wait for physics and rendering pipeline
	for f in range(40): await process_frame
	
	# 1. Gameplay follow camera
	var img_flight = root.get_viewport().get_texture().get_image()
	if img_flight:
		img_flight.save_png("c:/Proyectos/Dragon v2/ingame_flight_clean.png")
		print("Saved ingame_flight_clean.png")
		
	# 2. Side-quarter heroic camera to inspect scale relief, horns and wings
	cam.distance = 11.0
	cam.height = 3.5
	for f in range(25): await process_frame
	var img_orbit = root.get_viewport().get_texture().get_image()
	if img_orbit:
		img_orbit.save_png("c:/Proyectos/Dragon v2/ingame_heroic_clean.png")
		print("Saved ingame_heroic_clean.png")
		
	quit(0)
