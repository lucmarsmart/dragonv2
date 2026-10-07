@tool
extends SceneTree

func _init() -> void:
	print("Capturing unobstructed in-game flight over diverse botanical forest...")
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(20):
		await process_frame
		
	# Completely hide UI canvas items
	var mission_ui = scene.get_node_or_null("MissionUI")
	if mission_ui:
		mission_ui.visible = false
		for c in mission_ui.get_children():
			if c is CanvasItem:
				c.visible = false
				
	var hud = scene.get_node_or_null("HUD")
	if hud:
		hud.visible = false
		for c in hud.get_children():
			if c is CanvasItem:
				c.visible = false
				
	var dragon = scene.get_node_or_null("Dragon")
	if dragon:
		dragon.has_taken_off = true
		dragon.position = Vector3(160.0, 48.0, 140.0)
		
	var cam = scene.get_node_or_null("FlightCamera") as Camera3D
	if cam:
		cam.current = true
		# Camera behind and above dragon looking across the river valley and forest
		cam.position = Vector3(125.0, 52.0, 95.0)
		cam.look_at_from_position(cam.position, Vector3(180.0, 35.0, 175.0), Vector3.UP)
		
	for f in range(25):
		await process_frame
		
	var vp = root.get_viewport()
	var img = vp.get_texture().get_image()
	var out_path = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/a53d2dc3-e34f-480b-b77b-efaadb2bef9c/in_flight_botanical_world.png"
	if img:
		img.save_png(out_path)
		print("Saved final in-flight world screenshot: ", out_path)
		
	quit(0)
