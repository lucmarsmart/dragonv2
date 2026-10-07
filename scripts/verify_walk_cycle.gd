@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(15): await process_frame
	
	var dragon = scene.get_node("Dragon")
	dragon.has_taken_off = true
	dragon.locomotion_state = dragon.LocomotionState.GROUNDED
	dragon.ground_blend = 1.0
	dragon.manual_input_override = true
	
	# Place on stable ground
	var ray_start = dragon.global_position + Vector3(0, 50, 0)
	var ray_hit = dragon.ground_pose._ray(dragon, ray_start)
	if not ray_hit.is_empty():
		dragon.global_position.y = ray_hit.position.y
	
	# Create lateral camera to inspect walking from the side like reference video
	var cam = Camera3D.new()
	cam.current = true
	scene.add_child(cam)
	
	# Warm up grounded pose
	for f in range(30):
		dragon._physics_process(1.0 / 60.0)
		dragon._process(1.0 / 60.0)
		await process_frame
		
	print("Starting grounded walk cycle verification...")
	dragon.manual_move_input = 1.0
	
	var captured_frames := 0
	for step in range(180):
		dragon._physics_process(1.0 / 60.0)
		dragon._process(1.0 / 60.0)
		
		# Position side-on camera tracking dragon
		cam.global_position = dragon.global_position + dragon.global_basis * Vector3(-12.0, 3.0, 0.0)
		cam.look_at(dragon.global_position + Vector3(0, 2.0, 0))
		await process_frame
		
		# Capture every 45 frames (representing key poses across the walk cycle)
		if step in [30, 60, 90, 120]:
			var vp = root.get_viewport()
			if vp:
				var img = vp.get_texture().get_image()
				if img:
					var path = "artifacts/walk_frame_%d.png" % captured_frames
					img.save_png(path)
					print("Saved walk frame %d: %s (phase=%.2f)" % [captured_frames, path, dragon.walk_cycle_phase])
					captured_frames += 1
					
	print("Verification complete! Total captured frames: %d" % captured_frames)
	quit(0)
