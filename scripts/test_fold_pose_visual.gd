@tool
extends SceneTree

func _init():
	root.size = Vector2i(1280, 720)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(20): await process_frame
	
	var hud = scene.find_child("HUD", true, false)
	if hud: hud.visible = false
	var siege_ui = scene.find_child("SiegeUI", true, false)
	if siege_ui: siege_ui.visible = false
	for c in scene.get_children():
		if c is CanvasLayer: c.visible = false
	
	var dragon: DragonController = scene.get_node("Dragon")
	var sk: Skeleton3D = dragon.skeleton
	
	dragon.has_taken_off = true
	dragon.locomotion_state = dragon.LocomotionState.GROUNDED
	dragon.wing_fold_blend = 1.0
	dragon.ground_blend = 1.0
	dragon.global_position = Vector3(300, 24, 120)
	
	for f in range(40):
		dragon._physics_process(0.016)
		dragon._process(0.016)
		await process_frame
		
	var cam: Camera3D = scene.get_node("FlightCamera")
	cam.set_process(false)
	cam.set_physics_process(false)
	
	# View from behind and above looking at dragon's back and wings
	cam.global_position = dragon.global_position + Vector3(0, 10, 18)
	cam.look_at(dragon.global_position + Vector3(0, 1, 0))
	
	for f in range(5): await process_frame
	await RenderingServer.frame_post_draw
	
	var img = root.get_texture().get_image()
	img.save_png("res://test_folded_wings_current.png")
	print("Saved test_folded_wings_current.png without UI")
	quit(0)
