extends SceneTree

func _init() -> void:
	print("Starting Precise Showcase Render...")
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	
	for i in range(20):
		await process_frame
	
	# Hide all CanvasLayers/UI overlays
	for child in main.get_children():
		if child is CanvasLayer:
			child.visible = false
	for node in main.find_children("*", "CanvasLayer", true, false):
		if node is CanvasLayer:
			node.visible = false
	
	var siege := main.find_child("SiegeEnvironment", true, false)
	var combat := main.find_child("SiegeCombat", true, false)
	var dragon := main.find_child("Dragon", true, false)
	
	var cam := Camera3D.new()
	cam.current = true
	cam.fov = 50.0
	main.add_child(cam)
	
	# 1. Close-up of Ground Catapult (Stationed in courtyard at 300, 24, 108)
	cam.global_position = Vector3(300.0, 26.2, 116.5)
	cam.look_at(Vector3(300.0, 25.0, 108.0), Vector3.UP)
	for i in range(5):
		await process_frame
	_save_screenshot("showcase_catapult_ground.png")
	
	# 2. Close-up of Citadel Wall Props (Barrels, Spears, Swords, Axes against wall at 266, 24, 142)
	cam.global_position = Vector3(270.0, 25.2, 142.0)
	cam.look_at(Vector3(266.0, 24.8, 142.0), Vector3.UP)
	for i in range(5):
		await process_frame
	_save_screenshot("showcase_wall_props.png")
	
	# 3. Close-up of Captain & Guard
	var captain_node: Node3D = null
	if combat:
		var enemies = combat.get("enemies")
		for e in enemies:
			if is_instance_valid(e) and e.get("kind") == "captain":
				captain_node = e
				break
	if captain_node:
		var cap_pos = captain_node.global_position
		cam.global_position = cap_pos + Vector3(0.0, 2.5, 4.8)
		cam.look_at(cap_pos + Vector3(0.0, 2.0, 0.0), Vector3.UP)
		for i in range(5):
			await process_frame
		_save_screenshot("showcase_captain_closeup.png")
	
	# 4. Tower Ballista on Tower-top Platform (259.18, 50.35, 163.71)
	cam.global_position = Vector3(253.5, 52.2, 160.0)
	cam.look_at(Vector3(259.18, 51.5, 163.71), Vector3.UP)
	for i in range(5):
		await process_frame
	_save_screenshot("showcase_tower_ballista.png")
	
	# 5. Deadly Nadder Scale (Dragon at 306, 24, 152 next to Captain at 300, 24, 152)
	if dragon:
		dragon.global_position = Vector3(306.0, 24.2, 152.0)
		dragon.global_rotation = Vector3(0, -PI * 0.5, 0)
	cam.global_position = Vector3(296.0, 26.8, 159.5)
	cam.look_at(Vector3(303.0, 25.2, 152.0), Vector3.UP)
	for i in range(5):
		await process_frame
	_save_screenshot("showcase_deadly_nadder_scale.png")
	
	print("Precise Showcase Renders Completed Successfully!")
	quit(0)

func _save_screenshot(filename: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img:
		img.save_png(filename)
		print("Saved screenshot: ", filename)
