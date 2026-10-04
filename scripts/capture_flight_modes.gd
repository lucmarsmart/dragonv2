@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	# Add a camera looking at the dragon from a good 3/4 perspective
	var test_cam = Camera3D.new()
	test_cam.name = "TestCam"
	test_cam.position = Vector3(15, 6, 20)
	scene.add_child(test_cam)
	test_cam.look_at_from_position(test_cam.position, Vector3(0, 2, 0), Vector3.UP)
	test_cam.current = true
	test_cam.far = 1000.0
	
	for f in range(30): await process_frame
	
	var dragon = scene.get_node("Dragon")
	var ap: AnimationPlayer = dragon.anim_player
	dragon.has_taken_off = true
	
	# 1. Capture Normal Flight
	dragon.trigger_normal()
	ap.play("Qishilong_fly2")
	for f in range(20):
		dragon._process(0.016)
		await process_frame
	_save_screenshot("test_screen_normal.png")
	print("Captured test_screen_normal.png")
	
	# 2. Capture Climb Mode
	dragon.trigger_climb()
	for f in range(30):
		dragon._process(0.016)
		await process_frame
	_save_screenshot("test_screen_climb.png")
	print("Captured test_screen_climb.png")
	
	# 3. Capture Dive Mode
	dragon.toggle_dive()
	for f in range(30):
		dragon._process(0.016)
		await process_frame
	_save_screenshot("test_screen_dive.png")
	print("Captured test_screen_dive.png")
	
	quit(0)

func _save_screenshot(filename: String) -> void:
	var img = root.get_viewport().get_texture().get_image()
	img.save_png(filename)
