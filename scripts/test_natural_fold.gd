@tool
extends SceneTree

func _init():
	root.size = Vector2i(1280, 720)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(20): await process_frame
	
	for c in scene.get_children():
		if c is CanvasLayer: c.visible = false
	
	var dragon: DragonController = scene.get_node("Dragon")
	var sk: Skeleton3D = dragon.skeleton
	
	dragon.has_taken_off = true
	dragon.locomotion_state = dragon.LocomotionState.GROUNDED
	dragon.wing_fold_blend = 1.0
	dragon.ground_blend = 1.0
	dragon.global_position = Vector3(300, 24, 120)
	
	# Override _refit_compact_wings behavior directly for testing
	# Natural fold: shoulder down/back, elbow tight against flank, digits extending backward (+Z) along body
	var test_side = func(side_data: Array, weight: float):
		var b_root = side_data[0]
		var b_elbow = side_data[1]
		var b_wrist = side_data[2]
		var b_tip1 = side_data[3]
		var b_dig2 = side_data[4]
		var b_tip2 = side_data[5]
		var b_dig3 = side_data[6]
		var b_tip3 = side_data[7]
		var s = side_data[8]
		
		# 1. Aim Shoulder: down, back along thorax
		dragon._aim_bone_direction(sk, b_root, b_elbow, dragon.global_basis * Vector3(s * 0.45, -0.4, 2.0), weight)
		sk.force_update_all_bone_transforms()
		
		# 2. Aim Forearm / Elbow: tight back along flank
		dragon._aim_bone_direction(sk, b_elbow, b_wrist, dragon.global_basis * Vector3(s * 0.35, -0.2, 2.5), weight)
		sk.force_update_all_bone_transforms()
		
		# 3. Aim Digits: streaming backward (+Z) along flank towards pelvis/tail
		dragon._aim_bone_direction(sk, b_wrist, b_tip1, dragon.global_basis * Vector3(s * 0.28, -0.1, 4.2), weight)
		dragon._aim_bone_direction(sk, b_dig2, b_tip2, dragon.global_basis * Vector3(s * 0.30, -0.15, 4.0), weight)
		dragon._aim_bone_direction(sk, b_dig3, b_tip3, dragon.global_basis * Vector3(s * 0.32, -0.2, 3.8), weight)
		sk.force_update_all_bone_transforms()

	for f in range(30):
		dragon._physics_process(0.016)
		dragon._process(0.016)
		# Apply our test fold
		test_side.call([96,97,104,108,98,102,111,115,-1.0], 1.0)
		test_side.call([120,121,128,132,122,126,135,139,1.0], 1.0)
		await process_frame
		
	var cam: Camera3D = scene.get_node("FlightCamera")
	cam.set_process(false)
	cam.set_physics_process(false)
	cam.global_position = dragon.global_position + Vector3(0, 10, 18)
	cam.look_at(dragon.global_position + Vector3(0, 1, 0))
	
	for f in range(5): await process_frame
	await RenderingServer.frame_post_draw
	
	var img = root.get_texture().get_image()
	img.save_png("res://test_folded_wings_natural.png")
	print("Saved test_folded_wings_natural.png")
	
	var b108_p = dragon.global_basis.inverse() * (sk.to_global(sk.get_bone_global_pose(108).origin) - dragon.global_position)
	var b132_p = dragon.global_basis.inverse() * (sk.to_global(sk.get_bone_global_pose(132).origin) - dragon.global_position)
	print("New tips in GROUNDED: 108(L)=%s, 132(R)=%s" % [str(b108_p), str(b132_p)])
	quit(0)
