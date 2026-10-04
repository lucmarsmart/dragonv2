@tool
extends SceneTree

func _init():
	print("\n=======================================================")
	print("--- TEST DE VERIFICACIÓN COMPLETO: VUELO, ATERRIZAJE Y CAMINATA ---")
	print("=======================================================")
	
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for f in range(25): await process_frame
	
	var dragon: DragonController = scene.get_node("Dragon")
	var skel = dragon.skeleton
	var ap = dragon.anim_player
	var b_head = dragon.bone_head_idx
	var b_tail = dragon.bone_tail_indices[dragon.bone_tail_indices.size() - 1]
	
	# -------------------------------------------------------------------------
	# 1. VERIFICAR DERIVA DE VUELO (FLIGHT DRIFT)
	# -------------------------------------------------------------------------
	print("\n[1] Verificando deriva de vuelo en ciclo completo (3.0s)...")
	dragon.has_taken_off = true
	ap.play("Qishilong_fly2")
	var max_drift = 0.0
	for step in range(30):
		var t = step * 0.1
		ap.seek(t, true)
		for f in range(2): await process_frame
		dragon._process(0.016)
		
		var p_h = skel.global_transform * skel.get_bone_global_pose(b_head).origin
		var p_t = skel.global_transform * skel.get_bone_global_pose(b_tail).origin
		var fwd = (p_h - p_t).normalized()
		var char_fwd = -dragon.global_transform.basis.z.normalized()
		var yaw_err = abs(rad_to_deg(wrapf(atan2(fwd.x, -fwd.z) - atan2(char_fwd.x, -char_fwd.z), -PI, PI)))
		max_drift = max(max_drift, yaw_err)
		
	print("  -> Deriva máxima en vuelo: %.3f grados (Éxito si < 3.0°)" % max_drift)
	assert(max_drift < 3.0, "Fallo: la deriva en vuelo supera 3°")
	
	# -------------------------------------------------------------------------
	# 2. VERIFICAR ATERRIZAJE (LANDING)
	# -------------------------------------------------------------------------
	print("\n[2] Verificando maniobra de aterrizaje (trigger_landing)...")
	# Posicionar al dragón a 10 metros sobre el suelo (terreno en Y=0)
	dragon.global_position = Vector3(0, 10, -50)
	dragon.velocity = Vector3(0, 0, -5)
	dragon.trigger_landing()
	print("  -> Estado tras trigger_landing: %s" % dragon.LocomotionState.keys()[dragon.locomotion_state])
	assert(dragon.locomotion_state == dragon.LocomotionState.LANDING)
	
	# Simular física hasta tocar tierra
	var landed = false
	for sim_step in range(150):
		dragon._physics_process(0.05)
		dragon._process(0.05)
		await process_frame
		if sim_step % 10 == 0:
			print("    step %d: pos=%s vel=%s ground_prox=%.2f is_floor=%s" % [
				sim_step, dragon.global_position, dragon.velocity, dragon.ground_proximity, dragon.is_on_floor()
			])
		if dragon.locomotion_state == dragon.LocomotionState.GROUNDED:
			landed = true
			print("  -> Contacto con el suelo alcanzado en el paso %d. Posición Y: %.2f" % [sim_step, dragon.global_position.y])
			break
			
	assert(landed, "Fallo: el dragón no completó el aterrizaje hacia GROUNDED")
	print("  -> Estado actual: %s | En suelo: %s" % [
		dragon.LocomotionState.keys()[dragon.locomotion_state],
		dragon.is_on_floor()
	])
	
	# -------------------------------------------------------------------------
	# 3. VERIFICAR CAMINATA EN TIERRA (GROUND WALKING)
	# -------------------------------------------------------------------------
	print("\n[3] Verificando caminata en tierra (movimiento y cinemática)...")
	for f in range(10):
		dragon._physics_process(0.033)
		dragon._process(0.033)
		await process_frame
		
	var initial_pos = dragon.global_position
	dragon.walk_forward()
	
	for walk_step in range(60):
		dragon._physics_process(0.033)
		dragon._process(0.033)
		await process_frame
		
	var walked_dist = (dragon.global_position - initial_pos).length()
	print("  -> Distancia caminada: %.2f metros" % walked_dist)
	print("  -> Plegado de alas (wing_fold_blend): %.2f" % dragon.wing_fold_blend)
	print("  -> Blend de tierra (ground_blend): %.2f" % dragon.ground_blend)
	print("  -> Fase de ciclo de patas (walk_cycle_phase): %.2f rad" % dragon.walk_cycle_phase)
	
	assert(walked_dist > 5.0, "Fallo: el dragón no avanzó caminando")
	assert(dragon.wing_fold_blend > 0.7, "Fallo: las alas no se plegaron en tierra")
	assert(dragon.ground_blend > 0.8, "Fallo: el blend de tierra no se activó")
	dragon.stop_walking()
	
	# -------------------------------------------------------------------------
	# 4. VERIFICAR DESPEGUE (TAKING_OFF -> FLYING)
	# -------------------------------------------------------------------------
	print("\n[4] Verificando despegue hacia vuelo libre (trigger_takeoff)...")
	dragon.trigger_takeoff()
	print("  -> Estado tras trigger_takeoff: %s" % dragon.LocomotionState.keys()[dragon.locomotion_state])
	assert(dragon.locomotion_state == dragon.LocomotionState.TAKING_OFF)
	
	var back_in_flight = false
	for to_step in range(60):
		dragon._physics_process(0.033)
		dragon._process(0.033)
		await process_frame
		if dragon.locomotion_state == dragon.LocomotionState.FLYING:
			back_in_flight = true
			print("  -> Vuelo libre alcanzado en el paso %d. Altitud: %.2fm, Velocidad: %.2fm/s" % [
				to_step, dragon.global_position.y, dragon.current_speed
			])
			break
			
	assert(back_in_flight, "Fallo: el dragón no completó la transición de vuelta a FLYING")
	print("\n=======================================================")
	print(">>> ¡TODAS LAS PRUEBAS DE VUELO, ATERRIZAJE Y CAMINATA PASARON EXITOSAMENTE! <<<")
	print("=======================================================\n")
	quit(0)
