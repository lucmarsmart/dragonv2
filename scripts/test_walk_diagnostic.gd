extends SceneTree

func ticks(count: int):
	for i in range(count):
		await physics_frame
		await process_frame

func _init():
	run.call_deferred()

func run():
	print("--- TEST REAL DE ATERRIZAJE Y MARCHA CUADRÚPEDA ---")
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	# Warm up scene
	await ticks(60)
	
	var d = scene.get_node("Dragon")
	
	# Crear plano en altura limpia
	var plane = StaticBody3D.new()
	plane.position = Vector3(180, 250, 120)
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(300, 1, 300)
	col.shape = box
	plane.add_child(col)
	scene.add_child(plane)
	
	# Posicionar en planeo de aterrizaje hacia el plano
	d.has_taken_off = true
	d.manual_input_override = true
	d.global_position = Vector3(180, 260, 120)
	d.rotation = Vector3.ZERO
	d.target_pitch = 0.0
	d.target_roll = 0.0
	d.target_yaw = 0.0
	d.velocity = Vector3(0, -3, 0)
	d.current_speed = 0.0
	d.locomotion_state = d.LocomotionState.LANDING
	
	print("Aterrizando sobre la plataforma...")
	for i in range(260):
		await physics_frame
		await process_frame
		if d.locomotion_state == d.LocomotionState.GROUNDED and d.ground_blend >= 0.99:
			print("Aterrizaje completado en tick ", i, "! Altitud: ", d.position.y)
			break
			
	print("Estado final de aterrizaje: ", d.locomotion_state, " ground_blend: ", d.ground_blend)
	
	var pos_start = d.position
	d.manual_move_input = 1.0
	
	var sk: Skeleton3D = d.skeleton
	var b_pelvis = d.bone_pelvis
	var b_spine = d.bone_spine_indices[1] if d.bone_spine_indices.size() > 1 else -1
	var b_tail = d.bone_tail_indices[3] if d.bone_tail_indices.size() > 3 else -1
	var init_pel_rot = sk.get_bone_pose_rotation(b_pelvis)
	
	var max_pel_yaw := 0.0
	var max_spine_yaw := 0.0
	var max_tail_yaw := 0.0
	var limb_swings := [0, 0, 0, 0]
	var initial_phase = d.walk_cycle_phase
	
	var speed_samples := []
	var heave_samples := []
	
	print("Iniciando caminata (120 frames)...")
	for i in range(120):
		await physics_frame
		await process_frame
		
		speed_samples.append(d.current_speed)
		heave_samples.append(d.position.y)
		
		var p_rot = sk.get_bone_pose_rotation(b_pelvis)
		max_pel_yaw = maxf(max_pel_yaw, init_pel_rot.angle_to(p_rot))
		
		if b_spine != -1:
			var s_rot = sk.get_bone_pose_rotation(b_spine)
			max_spine_yaw = maxf(max_spine_yaw, s_rot.angle_to(Quaternion.IDENTITY))
			
		if b_tail != -1:
			var t_rot = sk.get_bone_pose_rotation(b_tail)
			max_tail_yaw = maxf(max_tail_yaw, t_rot.angle_to(Quaternion.IDENTITY))
			
		for j in range(d.ground_pose.limbs.size()):
			if d.ground_pose.limbs[j].swinging:
				limb_swings[j] += 1
				
		if i % 30 == 0:
			print("Frame %d: speed=%.2f pos=%s phase=%.2f swings=%s" % [i, d.current_speed, d.position, d.walk_cycle_phase, limb_swings])
			
	var pos_end = d.position
	var distance_walked = pos_start.distance_to(pos_end)
	
	print("\n================ MÉTRICAS DE CAMINATA ================")
	print("Distancia total avanzada: %.2f m" % distance_walked)
	print("Velocidad promedio: %.2f m/s" % (distance_walked / 2.0))
	print("Fase de marcha avanzada: de %.2f a %.2f (delta: %.2f rad)" % [initial_phase, d.walk_cycle_phase, d.walk_cycle_phase - initial_phase])
	print("Oscilación angular de Pelvis: %.2f deg" % rad_to_deg(max_pel_yaw))
	print("Ondulación en S de Columna: %.2f deg" % rad_to_deg(max_spine_yaw))
	print("Ondulación armónica de Cola: %.2f deg" % rad_to_deg(max_tail_yaw))
	print("Pasos por extremidad (LH, RF, RH, LF): ", limb_swings)
	print("======================================================")
	quit(0)
