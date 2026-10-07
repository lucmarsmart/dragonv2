extends SceneTree

func ticks(count: int):
	for i in range(count):
		await physics_frame
		await process_frame

func _init():
	run.call_deferred()

func run():
	print("--- TEST DE EVALUACIÓN CRÍTICA DE MARCHA ---")
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	# Wait for scene initialization & calibration (80 frames)
	await ticks(80)
	
	var dragon = scene.get_node("Dragon")
	dragon.has_taken_off = true
	dragon.locomotion_state = dragon.LocomotionState.GROUNDED
	dragon.ground_blend = 1.0
	dragon.manual_input_override = true
	dragon.manual_move_input = 1.0
	
	dragon.global_position = Vector3(300.0, 24.5, 200.0)
	dragon.rotation = Vector3.ZERO
	print("Dragon placed in flat fortress courtyard at pos: ", dragon.global_position)
	
	var sk: Skeleton3D = dragon.skeleton
	var b_pelvis = dragon.bone_pelvis
	var b_spine = dragon.bone_spine_indices[1] if dragon.bone_spine_indices.size() > 1 else -1
	var b_tail = dragon.bone_tail_indices[3] if dragon.bone_tail_indices.size() > 3 else -1
	
	dragon.ground_pose.apply(dragon, sk)
	
	var initial_pelvis_rot = sk.get_bone_pose_rotation(b_pelvis)
	var max_pelvis_diff := 0.0
	var max_spine_diff := 0.0
	var max_tail_diff := 0.0
	var limb_swings := [0, 0, 0, 0]
	var limb_phases := []
	for limb in dragon.ground_pose.limbs:
		limb_phases.append(limb.phase)
		
	print("Limb phases: ", limb_phases)
	var pos_start = dragon.global_position
	var initial_phase = dragon.walk_cycle_phase
	
	# Simulate 180 ticks
	for t in range(180):
		dragon._physics_process(1.0 / 60.0)
		dragon._process(1.0 / 60.0)
		await process_frame
		
		var cur_pelvis_rot = sk.get_bone_pose_rotation(b_pelvis)
		var p_diff = initial_pelvis_rot.angle_to(cur_pelvis_rot)
		max_pelvis_diff = maxf(max_pelvis_diff, p_diff)
		
		if b_spine != -1:
			var s_rot = sk.get_bone_pose_rotation(b_spine)
			max_spine_diff = maxf(max_spine_diff, s_rot.angle_to(Quaternion.IDENTITY))
			
		if b_tail != -1:
			var t_rot = sk.get_bone_pose_rotation(b_tail)
			max_tail_diff = maxf(max_tail_diff, t_rot.angle_to(Quaternion.IDENTITY))
			
		for i in range(dragon.ground_pose.limbs.size()):
			if dragon.ground_pose.limbs[i].swinging:
				limb_swings[i] += 1
				
		if t % 30 == 0:
			print("Tick %d: pos=%s speed=%.2f phase=%.2f vel=%s on_floor=%s swings=%s" % [
				t, dragon.global_position, dragon.current_speed, dragon.walk_cycle_phase, dragon.velocity, dragon.is_on_floor(), limb_swings
			])
			
	var pos_end = dragon.global_position
	var dist = pos_start.distance_to(pos_end)
	print("\n--- RESULTADOS DETALLADOS DE EVALUACIÓN ---")
	print("Distancia total recorrida: %.3f m" % dist)
	print("Fase de ciclo inicial: %.2f rad, final: %.2f rad (delta: %.2f rad)" % [initial_phase, dragon.walk_cycle_phase, dragon.walk_cycle_phase - initial_phase])
	print("Oscilación angular de Pelvis: %.2f grados" % rad_to_deg(max_pelvis_diff))
	print("Curvatura ondulatoria de Columna (S-curve): %.2f grados" % rad_to_deg(max_spine_diff))
	print("Ondulación inercial de Cola: %.2f grados" % rad_to_deg(max_tail_diff))
	print("Frames de balanceo por extremidad (LH, RF, RH, LF): %s" % str(limb_swings))
	print("Posición inicial: %s -> final: %s" % [pos_start, pos_end])
	print("------------------------------------------")
	quit(0)
