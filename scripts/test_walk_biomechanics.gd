@tool
extends SceneTree

func _init():
	print("--- INICIANDO TEST DE BIOMECÁNICA DE MARCHA (LATERAL SEQUENCE & SPINE S-CURVE) ---")
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(25): await process_frame
	
	var dragon = scene.get_node("Dragon")
	dragon.has_taken_off = true
	dragon.locomotion_state = dragon.LocomotionState.GROUNDED
	dragon.ground_blend = 1.0
	dragon.manual_input_override = true
	dragon.manual_move_input = 1.0
	
	var sk: Skeleton3D = dragon.skeleton
	var b_pelvis = dragon.bone_pelvis
	var b_spine = dragon.bone_spine_indices[1] if dragon.bone_spine_indices.size() > 1 else -1
	var b_tail = dragon.bone_tail_indices[3] if dragon.bone_tail_indices.size() > 3 else -1
	
	var initial_pelvis_rot = sk.get_bone_pose_rotation(b_pelvis)
	var max_pelvis_diff := 0.0
	var max_spine_diff := 0.0
	var max_tail_diff := 0.0
	
	# Initialize ground pose limbs
	dragon.ground_pose.apply(dragon, sk)
	
	var limb_swings = [0, 0, 0, 0]
	var limb_phases = []
	for limb in dragon.ground_pose.limbs:
		limb_phases.append(limb.phase)
		
	print("Configuración de fases de extremidades: ", limb_phases)
	# Verificar que el orden de fases sea LH(0.0), LF(0.25), RH(0.50), RF(0.75)
	assert(abs(limb_phases[0] - 0.0) < 0.01, "LH debe ser fase 0.0")
	assert(abs(limb_phases[3] - 0.25) < 0.01, "LF debe ser fase 0.25")
	assert(abs(limb_phases[2] - 0.50) < 0.01, "RH debe ser fase 0.50")
	assert(abs(limb_phases[1] - 0.75) < 0.01, "RF debe ser fase 0.75")
	print("Secuencia lateral LH -> LF -> RH -> RF verificada con éxito.")
	
	# Simular 180 ticks de caminata
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
			
		for i in range(dragon.ground_pose.limbs.size()):
			if dragon.ground_pose.limbs[i].swinging:
				limb_swings[i] += 1
				
	print("Resultados de simulación de marcha:")
	print("- Oscilación angular máxima de pelvis: %.2f deg" % rad_to_deg(max_pelvis_diff))
	print("- Curvatura ondulatoria de columna (S-curve): %.2f deg" % rad_to_deg(max_spine_diff))
	print("- Cuadros en fase de balanceo por pata: LH=%d, RF=%d, RH=%d, LF=%d" % [limb_swings[0], limb_swings[1], limb_swings[2], limb_swings[3]])
	
	assert(max_pelvis_diff > deg_to_rad(1.0), "La pelvis debe oscilar orgánicamente durante la marcha")
	assert(limb_swings[0] > 0 and limb_swings[1] > 0 and limb_swings[2] > 0 and limb_swings[3] > 0, "Todas las 4 extremidades deben completar pasos")
	print("TODAS LAS PRUEBAS DE BIOMECÁNICA DE MARCHA SUPERADAS CON ÉXITO.")
	quit(0)
