@tool
extends SceneTree

func _init() -> void:
	var main_packed = load("res://scenes/main.tscn")
	var main = main_packed.instantiate()
	root.add_child(main)
	
	var dragon = main.get_node("Dragon") as DragonController
	var sk = dragon.skeleton
	
	print("--- INICIANDO DIAGNÓSTICO DE AUTO-COLISIÓN (SELF-COLLISION) ---")
	
	# Let's wait a few physics frames to allow ready / initialization
	# Since it's a SceneTree script in _init, let's defer or run in a method
	call_deferred("_run_tests", dragon, sk)

func _run_tests(dragon: DragonController, sk: Skeleton3D) -> void:
	# Test 1: Ground Wings Folded
	print("\n=== TEST 1: ALAS PLEGADAS EN TIERRA (wing_fold_blend = 1.0) ===")
	dragon.locomotion_state = dragon.LocomotionState.GROUNDED
	dragon.ground_blend = 1.0
	dragon.wing_fold_blend = 1.0
	dragon.dive_fold_blend = 0.0
	dragon.has_taken_off = true
	
	# Apply biomechanical posture
	dragon._apply_biomechanical_posture_to_skeleton(sk)
	
	# Check wing bone global origins
	# Left wing: 96 (root), 97 (mid/elbow), 104, 108 (tip)
	# Right wing: 120 (root), 121 (mid/elbow), 128, 132 (tip)
	var l_elbow = sk.get_bone_global_pose(97).origin
	var r_elbow = sk.get_bone_global_pose(121).origin
	var l_tip = sk.get_bone_global_pose(108).origin
	var r_tip = sk.get_bone_global_pose(132).origin
	var spine = sk.get_bone_global_pose(dragon.bone_spine_indices[1]).origin
	
	print("Left elbow global: ", l_elbow, " (x=", l_elbow.x, ")")
	print("Right elbow global: ", r_elbow, " (x=", r_elbow.x, ")")
	print("Left tip global: ", l_tip, " (x=", l_tip.x, ")")
	print("Right tip global: ", r_tip, " (x=", r_tip.x, ")")
	print("Spine global: ", spine, " (x=", spine.x, ")")
	print("Distance L_tip to R_tip: ", l_tip.distance_to(r_tip))
	print("L_tip.x - R_tip.x: ", l_tip.x - r_tip.x)
	if l_tip.x > r_tip.x:
		print("¡ALERTA CRÍTICA!: Las puntas de las alas se cruzaron (Left tip x > Right tip x)!")
	if l_elbow.x > r_elbow.x:
		print("¡ALERTA CRÍTICA!: Los codos de las alas se cruzaron!")

	# Test 2: Dive Fold
	print("\n=== TEST 2: PICADA / DIVE FOLD (dive_fold_blend = 1.0) ===")
	dragon.locomotion_state = dragon.LocomotionState.FLYING
	dragon.ground_blend = 0.0
	dragon.wing_fold_blend = 0.0
	dragon.dive_fold_blend = 1.0
	dragon._apply_biomechanical_posture_to_skeleton(sk)
	
	l_elbow = sk.get_bone_global_pose(97).origin
	r_elbow = sk.get_bone_global_pose(121).origin
	l_tip = sk.get_bone_global_pose(108).origin
	r_tip = sk.get_bone_global_pose(132).origin
	print("Distance L_tip to R_tip en picada: ", l_tip.distance_to(r_tip))
	print("L_tip.x en picada: ", l_tip.x, " R_tip.x: ", r_tip.x)

	# Test 3: Sharp Turn & Tail Curl
	print("\n=== TEST 3: GIRO BRUSCO Y FLEXIÓN DE COLA (turn = 1.4) ===")
	dragon.smoothed_turn_rate = 1.4
	dragon.ground_blend = 0.0
	dragon.dive_fold_blend = 0.0
	dragon.tail_lag_strength = 0.90
	dragon._apply_biomechanical_posture_to_skeleton(sk)
	
	# Check distances between tail vertebrae and hind legs
	var r_thigh = sk.get_bone_global_pose(dragon.bone_r_thigh).origin
	var r_calf = sk.get_bone_global_pose(dragon.bone_r_calf).origin
	var r_foot = sk.get_bone_global_pose(dragon.bone_r_foot).origin
	var l_thigh = sk.get_bone_global_pose(dragon.bone_l_thigh).origin
	var l_calf = sk.get_bone_global_pose(dragon.bone_l_calf).origin
	var l_foot = sk.get_bone_global_pose(dragon.bone_l_foot).origin
	
	for i in range(dragon.bone_tail_indices.size()):
		var b = dragon.bone_tail_indices[i]
		var t_pos = sk.get_bone_global_pose(b).origin
		var dist_r_thigh = t_pos.distance_to(r_thigh)
		var dist_r_calf = t_pos.distance_to(r_calf)
		var dist_l_thigh = t_pos.distance_to(l_thigh)
		var dist_l_calf = t_pos.distance_to(l_calf)
		print("Tail vertebra ", i, " pos: ", t_pos, " dist to R_thigh: ", dist_r_thigh, " dist to L_thigh: ", dist_l_thigh)
		if dist_r_thigh < 0.5 or dist_r_calf < 0.5:
			print("¡ALERTA CRÍTICA!: La vértebra de la cola ", i, " atraviesa o colisiona con la pata trasera derecha!")
		if dist_l_thigh < 0.5 or dist_l_calf < 0.5:
			print("¡ALERTA CRÍTICA!: La vértebra de la cola ", i, " atraviesa o colisiona con la pata trasera izquierda!")

	# Test 3b: Turn left (-1.4)
	print("\n=== TEST 3b: GIRO BRUSCO A LA IZQUIERDA (turn = -1.4) ===")
	dragon.smoothed_turn_rate = -1.4
	dragon._apply_biomechanical_posture_to_skeleton(sk)
	for i in range(dragon.bone_tail_indices.size()):
		var b = dragon.bone_tail_indices[i]
		var t_pos = sk.get_bone_global_pose(b).origin
		var dist_r_thigh = t_pos.distance_to(r_thigh)
		var dist_l_thigh = t_pos.distance_to(l_thigh)
		if dist_r_thigh < 0.5:
			print("¡ALERTA CRÍTICA!: La vértebra ", i, " atraviesa la pata trasera derecha! Dist: ", dist_r_thigh)
		if dist_l_thigh < 0.5:
			print("¡ALERTA CRÍTICA!: La vértebra ", i, " atraviesa la pata trasera izquierda! Dist: ", dist_l_thigh)

	# Test 4: Head Aim
	print("\n=== TEST 4: APUNTADO DE CABEZA / CUELLO ===")
	dragon.set_head_aim(deg_to_rad(45.0), deg_to_rad(-30.0))
	dragon.head_pose.apply(dragon, sk)
	var head_pos = sk.get_bone_global_pose(dragon.bone_head_idx).origin
	var chest_pos = sk.get_bone_global_pose(dragon.bone_spine_indices[2]).origin
	print("Head pos: ", head_pos, " Chest pos: ", chest_pos, " Dist: ", head_pos.distance_to(chest_pos))

	# Test 5: Legs in ground pose
	print("\n=== TEST 5: PATAS EN TIERRA / CRUCE DE PATAS ===")
	dragon.ground_pose.prepare(dragon, sk)
	if dragon.ground_pose.limbs.is_empty():
		dragon.ground_pose._configure(sk)
	var rl_pos = dragon.ground_pose.limbs[0].home # Rear Left
	var fr_pos = dragon.ground_pose.limbs[1].home # Front Right
	var rr_pos = dragon.ground_pose.limbs[2].home # Rear Right
	var fl_pos = dragon.ground_pose.limbs[3].home # Front Left
	print("Patas home: RearL=", rl_pos, " RearR=", rr_pos, " FrontL=", fl_pos, " FrontR=", fr_pos)

	print("\n--- FIN DIAGNÓSTICO ---")
	quit(0)
