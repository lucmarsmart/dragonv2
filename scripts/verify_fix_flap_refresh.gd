@tool
extends SceneTree

func _init():
	print("========================================================")
	print("   VERIFICACIÓN DEL ARREGLO DEL REFRESH TRAS 2º ALETEO   ")
	print("========================================================")
	
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(5): await process_frame
	
	var dragon: DragonController = scene.get_node("Dragon")
	var ap: AnimationPlayer = dragon.anim_player
	var anim: Animation = ap.get_animation("Qishilong_fly2")
	
	# Test 1: Medir discontinuidad de todas las pistas entre t=3.000s y t=0.000s
	print("\n--- TEST 1: CONTINUIDAD DE PISTAS (t=3.00s vs t=0.00s) ---")
	var max_rot_diff = 0.0
	var max_track_name = ""
	for t in range(anim.get_track_count()):
		if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			var q0 = anim.rotation_track_interpolate(t, 0.0)
			var q_end = anim.rotation_track_interpolate(t, anim.length)
			var diff = rad_to_deg(q0.angle_to(q_end))
			if diff > max_rot_diff:
				max_rot_diff = diff
				max_track_name = str(anim.track_get_path(t))
				
	print("Máxima discontinuidad angular en el empalme: %.4f grados" % max_rot_diff)
	if max_rot_diff < 0.1:
		print(">> TEST 1 PASADO CON ÉXITO: El empalme es 100% continuo (error < 0.1°).")
	else:
		printerr(">> TEST 1 FALLÓ: Discontinuidad demasiado alta: %.2f° en %s" % [max_rot_diff, max_track_name])
		quit(1)
		return

	# Test 2: Simulación de vuelo real cruzando el empalme del segundo aleteo
	print("\n--- TEST 2: VUELO REAL FRAME A FRAME ATRAVESANDO EL LOOP ---")
	for f in range(40): await process_frame
	while dragon.calibrating or not dragon.has_taken_off:
		await process_frame
		
	var prev_pos = 0.0
	var prev_yaw = 0.0
	var max_vis_yaw_jump = 0.0
	var wrap_found = false
	var wrap_frame = -1
	
	var wrap_yaw_jump = 0.0
	for f in range(550):
		await process_frame
		var pos = dragon.anim_player.current_animation_position
		var wrapped = pos < prev_pos - 0.1
		var vis_yaw = rad_to_deg(dragon.visual_root.basis.get_euler().y)
		
		var d_yaw = abs(vis_yaw - prev_yaw)
		if d_yaw > 180.0: d_yaw = 360.0 - d_yaw
		
		if f > 25 and d_yaw > max_vis_yaw_jump:
			max_vis_yaw_jump = d_yaw
			
		if wrapped:
			wrap_found = true
			wrap_frame = f
			wrap_yaw_jump = d_yaw
			print("Wrap del ciclo detectado en Frame %d: pos=%.3fs -> pos=%.3fs" % [f, prev_pos, pos])
			print("  -> vis_yaw salto en el wrap: %.3f grados" % d_yaw)
			
		if (pos > 2.95 or pos < 0.05) and f > 25:
			var b_head = dragon.bone_head_idx
			var b_tail = dragon.bone_tail_indices[dragon.bone_tail_indices.size() - 1]
			var skel = dragon.skeleton
			var p_h = skel.global_transform * skel.get_bone_global_pose(b_head).origin
			var p_t = skel.global_transform * skel.get_bone_global_pose(b_tail).origin
			var fwd_local = (dragon.global_transform.basis.inverse() * (p_h - p_t)).normalized()
			var raw_yaw_err = rad_to_deg(atan2(fwd_local.x, -fwd_local.z))
			print("Frame %3d | anim_pos=%.3fs | vis_yaw=%+6.2f | d_yaw=%.3f° | raw_yaw_err=%+6.2f°" % [
				f, pos, vis_yaw, d_yaw, raw_yaw_err
			])
			
		prev_pos = pos
		prev_yaw = vis_yaw
		
	print("\nSalto angular en el wrap: %.3f grados (Umbral: < 0.5°)" % wrap_yaw_jump)
	print("Máximo cambio angular por frame en vuelo natural: %.3f grados (Umbral: < 2.0°)" % max_vis_yaw_jump)
	if wrap_found and wrap_yaw_jump < 0.5 and max_vis_yaw_jump < 2.0:
		print(">> TEST 2 PASADO CON ÉXITO: El wrap tras el segundo aleteo es completamente fluido y continuo.")
		print("========================================================")
		print("       TODAS LAS PRUEBAS COMPLETADAS SATISFACTORIAMENTE  ")
		print("========================================================")
		quit(0)
	else:
		printerr(">> TEST 2 FALLÓ: wrap_found=%s, wrap_yaw_jump=%.3f, max_vis_yaw_jump=%.3f" % [wrap_found, wrap_yaw_jump, max_vis_yaw_jump])
		quit(1)
