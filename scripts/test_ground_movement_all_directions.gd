extends SceneTree

# Test for omnidirectional ground locomotion and natural movement

func _init() -> void:
	print("--- Starting Omnidirectional Ground Locomotion Test ---")
	call_deferred("_run_test")

func sim_steps(dragon: Node, count: int, dt: float = 1.0 / 60.0) -> void:
	for i in range(count):
		dragon._physics_process(dt)
		dragon._process(dt)
		await process_frame

func _run_test() -> void:
	var main_scene = load("res://scenes/main.tscn")
	if not main_scene:
		print("FAIL: Could not load main scene")
		quit(1)
		return
		
	var root = main_scene.instantiate()
	get_root().add_child(root)
	
	var dragon = root.find_child("Dragon", true, false)
	if not dragon:
		print("FAIL: Dragon node not found")
		quit(1)
		return

	# Wait for ready and calibration to complete
	while dragon.calibrating:
		await process_frame
	for i in range(10):
		await process_frame

	# Force grounded state at a safe clear location on terrain (Courtyard)
	dragon.global_position = Vector3(300.0, 24.5, 120.0)
	dragon.velocity = Vector3.ZERO
	dragon.rotation = Vector3.ZERO
	dragon.target_yaw = 0.0
	dragon.target_pitch = 0.0
	dragon.target_roll = 0.0
	dragon.locomotion_state = dragon.LocomotionState.GROUNDED
	dragon.ground_blend = 1.0
	dragon.wing_fold_blend = 1.0
	dragon.has_taken_off = true
	dragon.manual_input_override = true
	dragon.manual_move_input = 0.0
	dragon.manual_turn_input = 0.0
	dragon.manual_sprint = false
	
	# Let ground stabilization settle for 30 ticks
	await sim_steps(dragon, 30)
		
	print("Initial Ground State: pos=", dragon.global_position, " rot_y_deg=", rad_to_deg(dragon.rotation.y), " ground_blend=", dragon.ground_blend)
	
	# Test 1: Turn Left on the spot (A)
	print("\n--- Testing In-Place Left Turn (A) ---")
	var initial_rot_y: float = dragon.rotation.y
	var initial_gait: float = dragon.walk_cycle_phase
	dragon.manual_move_input = 0.0
	dragon.manual_turn_input = 1.0 # Turn Left
	
	await sim_steps(dragon, 60) # 1.0 second
		
	var turned_left_deg: float = rad_to_deg(wrapf(dragon.rotation.y - initial_rot_y, -PI, PI))
	var gait_change_turn: float = dragon.walk_cycle_phase - initial_gait
	print("Turned Left: ", turned_left_deg, " degrees, gait change: ", gait_change_turn, " turn_blocked=", dragon.pose_turn_blocked)
	if turned_left_deg < 40.0:
		print("FAIL: In-place left turn was too sluggish or blocked (expected > 40 deg, got ", turned_left_deg, ")")
		quit(1)
		return
	if gait_change_turn <= 0.01:
		print("FAIL: Walk cycle phase did not advance during in-place turning")
		quit(1)
		return

	# Test 2: Turn Right on the spot (D)
	print("\n--- Testing In-Place Right Turn (D) ---")
	initial_rot_y = dragon.rotation.y
	dragon.manual_turn_input = -1.0 # Turn Right
	await sim_steps(dragon, 60)
	var turned_right_deg: float = rad_to_deg(wrapf(dragon.rotation.y - initial_rot_y, -PI, PI))
	print("Turned Right: ", turned_right_deg, " degrees, turn_blocked=", dragon.pose_turn_blocked)
	if turned_right_deg > -40.0:
		print("FAIL: In-place right turn was too sluggish or blocked (expected < -40 deg, got ", turned_right_deg, ")")
		quit(1)
		return

	# Reset turn input
	dragon.manual_turn_input = 0.0
	await sim_steps(dragon, 10)

	# Test 3: Forward Walk (W)
	print("\n--- Testing Forward Walking (W) ---")
	var start_pos: Vector3 = dragon.global_position
	initial_gait = dragon.walk_cycle_phase
	dragon.manual_move_input = 1.0
	dragon.manual_sprint = false
	await sim_steps(dragon, 60)
	var forward_dist: float = Vector2(dragon.global_position.x - start_pos.x, dragon.global_position.z - start_pos.z).length()
	var gait_forward: float = dragon.walk_cycle_phase - initial_gait
	print("Walked Forward distance: ", forward_dist, "m (speed ~", forward_dist, " m/s), gait change: ", gait_forward)
	if forward_dist < 2.0:
		print("FAIL: Forward walk was obstructed or too slow (expected > 2.0m, got ", forward_dist, ")")
		quit(1)
		return

	# Test 4: Reverse Walk (S)
	print("\n--- Testing Reverse Walking (S) ---")
	start_pos = dragon.global_position
	initial_gait = dragon.walk_cycle_phase
	dragon.manual_move_input = -0.6
	await sim_steps(dragon, 60)
	var reverse_dist: float = Vector2(dragon.global_position.x - start_pos.x, dragon.global_position.z - start_pos.z).length()
	print("Walked Backward distance: ", reverse_dist, "m")
	if reverse_dist < 1.0:
		print("FAIL: Reverse walk was obstructed or too slow (expected > 1.0m, got ", reverse_dist, ")")
		quit(1)
		return

	# Test 5: Forward + Left Curve (W + A)
	print("\n--- Testing Forward + Left Curve (W + A) ---")
	start_pos = dragon.global_position
	initial_rot_y = dragon.rotation.y
	dragon.manual_move_input = 1.0
	dragon.manual_turn_input = 1.0
	await sim_steps(dragon, 60)
	var curve_l_dist: float = Vector2(dragon.global_position.x - start_pos.x, dragon.global_position.z - start_pos.z).length()
	var curve_l_turn: float = rad_to_deg(wrapf(dragon.rotation.y - initial_rot_y, -PI, PI))
	print("Curved Left: dist=", curve_l_dist, "m, turn=", curve_l_turn, " deg")
	if curve_l_dist < 2.0 or curve_l_turn < 30.0:
		print("FAIL: Forward-Left curve failed (dist=", curve_l_dist, ", turn=", curve_l_turn, ")")
		quit(1)
		return

	# Test 6: Forward + Right Curve (W + D)
	print("\n--- Testing Forward + Right Curve (W + D) ---")
	start_pos = dragon.global_position
	initial_rot_y = dragon.rotation.y
	dragon.manual_move_input = 1.0
	dragon.manual_turn_input = -1.0
	await sim_steps(dragon, 60)
	var curve_r_dist: float = Vector2(dragon.global_position.x - start_pos.x, dragon.global_position.z - start_pos.z).length()
	var curve_r_turn: float = rad_to_deg(wrapf(dragon.rotation.y - initial_rot_y, -PI, PI))
	print("Curved Right: dist=", curve_r_dist, "m, turn=", curve_r_turn, " deg")
	if curve_r_dist < 2.0 or curve_r_turn > -30.0:
		print("FAIL: Forward-Right curve failed (dist=", curve_r_dist, ", turn=", curve_r_turn, ")")
		quit(1)
		return

	# Test 7: Sprint Forward (Shift + W)
	print("\n--- Testing Ground Sprint (Shift + W) ---")
	start_pos = dragon.global_position
	dragon.manual_move_input = 1.0
	dragon.manual_turn_input = 0.0
	dragon.manual_sprint = true
	await sim_steps(dragon, 60)
	var sprint_dist: float = Vector2(dragon.global_position.x - start_pos.x, dragon.global_position.z - start_pos.z).length()
	print("Sprinted Forward distance: ", sprint_dist, "m (speed ~", sprint_dist, " m/s)")
	if sprint_dist < 4.0:
		print("FAIL: Sprint was slower than expected (expected > 4.0m, got ", sprint_dist, ")")
		quit(1)
		return

	# Test 8: Mouse Steering on Ground
	print("\n--- Testing Mouse Steering on Ground ---")
	dragon.manual_input_override = false
	dragon.manual_move_input = 0.0
	dragon.manual_turn_input = 0.0
	dragon.manual_sprint = false
	dragon.mouse_captured = true # Enable mouse steering mode
	initial_rot_y = dragon.rotation.y
	
	# Simulate mouse motion event (moving mouse rightwards to turn dragon right)
	var motion_event := InputEventMouseMotion.new()
	motion_event.relative = Vector2(250.0, 0.0) # Move mouse right
	dragon._input(motion_event)
	
	await sim_steps(dragon, 30)
	var mouse_turn_deg: float = rad_to_deg(wrapf(dragon.rotation.y - initial_rot_y, -PI, PI))
	print("Mouse steered turn: ", mouse_turn_deg, " degrees")
	if mouse_turn_deg > -10.0:
		print("FAIL: Mouse steering did not turn dragon (expected < -10 deg, got ", mouse_turn_deg, ")")
		quit(1)
		return

	print("\nSUCCESS: All omnidirectional ground movement and turning tests passed perfectly!")
	quit(0)
