extends SceneTree

func ticks(count: int):
	for i in range(count):
		await physics_frame
		await process_frame

func _init():
	run.call_deferred()

func run():
	print("=======================================================")
	print("VERIFICACIÓN DE MARCHA BIOMECÁNICA (VIDEO DE REFERENCIA)")
	print("=======================================================")
	
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	# Wait for scene initialization & calibration (80 ticks)
	await ticks(80)
	
	var d = scene.get_node("Dragon")
	
	# Crear plano de apoyo firme para caminar
	var plane = StaticBody3D.new()
	plane.position = Vector3(180, 250, 120)
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(400, 2, 400)
	col.shape = box
	plane.add_child(col)
	scene.add_child(plane)
	
	d.has_taken_off = true
	d.global_position = Vector3(180, 252.0, 120)
	d.rotation = Vector3.ZERO
	d.target_pitch = 0.0
	d.target_roll = 0.0
	d.target_yaw = 0.0
	d.velocity = Vector3(0, -3, 0)
	d.locomotion_state = d.LocomotionState.GROUNDED
	d.ground_blend = 1.0
	d.manual_input_override = true
	d.manual_move_input = 1.0
	
	# Dejar que aterrice y asiente las patas en el plano
	for i in range(30):
		await physics_frame
		await process_frame
		
	d.locomotion_state = d.LocomotionState.GROUNDED
	d.ground_blend = 1.0
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
	var limb_phases := []
	
	for limb in d.ground_pose.limbs:
		limb_phases.append(limb.phase)
		
	print("Fases configuradas de las 4 extremidades: ", limb_phases)
	print("Orden: [0]=LH:%.2f, [1]=RF:%.2f, [2]=RH:%.2f, [3]=LF:%.2f" % [limb_phases[0], limb_phases[1], limb_phases[2], limb_phases[3]])
	
	# Secuencia lateral: LH (0.0) -> LF (0.25) -> RH (0.50) -> RF (0.75)
	assert(absf(limb_phases[0] - 0.00) < 0.01, "LH debe ser fase 0.0")
	assert(absf(limb_phases[3] - 0.25) < 0.01, "LF debe ser fase 0.25")
	assert(absf(limb_phases[2] - 0.50) < 0.01, "RH debe ser fase 0.50")
	assert(absf(limb_phases[1] - 0.75) < 0.01, "RF debe ser fase 0.75")
	print("Secuencia lateral cuadrúpeda verificada correctamente.")
	
	var initial_phase = d.walk_cycle_phase
	var pos_start = d.position
	
	for frame in range(120):
		await physics_frame
		await process_frame
		
		# Medir rotaciones articulares biomecánicas
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
				
	var distance_walked = pos_start.distance_to(d.position)
	print("\n--- RESULTADOS DE LA SIMULACIÓN DE MARCHA ---")
	print("Distancia avanzada caminando: %.2f m" % distance_walked)
	print("Fase de ciclo avanzada: de %.2f a %.2f (delta: %.2f rad)" % [initial_phase, d.walk_cycle_phase, d.walk_cycle_phase - initial_phase])
	print("Oscilación angular máxima de Pelvis: %.2f grados" % rad_to_deg(max_pel_yaw))
	print("Ondulación en S de Columna Dorsal: %.2f grados" % rad_to_deg(max_spine_yaw))
	print("Ondulación inercial de Cola: %.2f grados" % rad_to_deg(max_tail_yaw))
	print("Frames de elevación/balanceo (LH, RF, RH, LF): ", limb_swings)
	
	assert(distance_walked > 1.0, "El dragón debe avanzar caminando")
	assert(max_pel_yaw > deg_to_rad(1.0), "La pelvis debe oscilar en Yaw/Roll siguiendo la transferencia de peso")
	assert(max_spine_yaw > deg_to_rad(1.0), "La columna debe ondular en contra-fase en 'S'")
	assert(max_tail_yaw > deg_to_rad(1.0), "La cola debe propagar la onda armónica de la marcha")
	
	print("\n¡TODAS LAS PRUEBAS BIOMECÁNICAS PASARON EXITOSAMENTE!")
	print("=======================================================")
	quit(0)
