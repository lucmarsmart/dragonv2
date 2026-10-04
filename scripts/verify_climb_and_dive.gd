@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(15): await process_frame
	
	var dragon = scene.get_node("Dragon")
	var cam = scene.get_node("FlightCamera")
	var skel: Skeleton3D = dragon.skeleton
	var ap: AnimationPlayer = dragon.anim_player
	var b_head = dragon.bone_head_idx
	var b_pel = dragon.bone_pelvis
	
	dragon.has_taken_off = true
	print("\n=======================================================")
	print("--- INICIANDO VERIFICACIÓN DE SUBIDA (CLIMB) Y PICADA (DIVE) ---")
	print("=======================================================")
	
	# 1. Warm-up en vuelo normal
	dragon.trigger_normal()
	for f in range(30):
		dragon._physics_process(1.0 / 60.0)
		dragon._process(1.0 / 60.0)
		cam._physics_process(1.0 / 60.0)
		await process_frame
		
	var start_y = dragon.global_position.y
	print("Altitud inicial: %.1f m" % start_y)
	
	# 2. PRUEBA DE SUBIDA (CLIMB)
	print("\n[TEST 1] Activando MODO SUBIDA (CLIMB)...")
	dragon.trigger_climb()
	var climb_frames = 90 # 1.5 segundos
	var max_vy_climb = 0.0
	
	for f in range(climb_frames):
		dragon._physics_process(1.0 / 60.0)
		dragon._process(1.0 / 60.0)
		cam._physics_process(1.0 / 60.0)
		await process_frame
		if dragon.velocity.y > max_vy_climb:
			max_vy_climb = dragon.velocity.y
			
	var climb_alt_gain = dragon.global_position.y - start_y
	print("  -> Altitud ganada en 1.5s: +%.1f m" % climb_alt_gain)
	print("  -> Tasa de ascenso máxima (Vy): %.1f m/s" % max_vy_climb)
	print("  -> Modo activo: %s, Blend de subida: %.2f" % [dragon.FlightMode.keys()[dragon.current_mode], dragon.climb_blend])
	assert(climb_alt_gain > 15.0, "La subida debe ganar altitud significativa (+15m en 1.5s)")
	assert(max_vy_climb >= 12.0, "La tasa de ascenso máxima debe ser >= 12 m/s")
	
	var img_climb = root.get_viewport().get_texture().get_image()
	if img_climb:
		img_climb.save_png("c:/Proyectos/Dragon v2/verify_climb.png")
		print("  -> Captura guardada: verify_climb.png")
		
	# 3. PRUEBA DE PICADA (DIVE)
	print("\n[TEST 2] Activando MODO PICADA (DIVE)...")
	dragon.toggle_dive()
	var dive_frames = 80
	var max_speed_dive = 0.0
	var max_angular_dev = 0.0
	
	for f in range(dive_frames):
		dragon._physics_process(1.0 / 60.0)
		dragon._process(1.0 / 60.0)
		cam._physics_process(1.0 / 60.0)
		await process_frame
		
		var spd_kmh = dragon.current_speed * 3.6
		if spd_kmh > max_speed_dive:
			max_speed_dive = spd_kmh
			
		# Verificar alineación del esqueleto (cabeza a pelvis) respecto a la orientación del CharacterBody3D
		var h_pos = skel.global_transform * skel.get_bone_global_pose(b_head).origin
		var p_pos = skel.global_transform * skel.get_bone_global_pose(b_pel).origin
		var spine_fwd = (h_pos - p_pos).normalized()
		var char_fwd = -dragon.global_transform.basis.z.normalized()
		var dev = rad_to_deg(spine_fwd.angle_to(char_fwd))
		if dev > max_angular_dev:
			max_angular_dev = dev
			
	print("  -> Velocidad máxima en picada: %.1f km/h" % max_speed_dive)
	print("  -> Desviación angular máxima de columna en picada: %.2f°" % max_angular_dev)
	print("  -> Blend de plegado alar en picada: %.2f" % dragon.dive_fold_blend)
	print("  -> Animación activa: %s" % ap.current_animation)
	var img_dive = root.get_viewport().get_texture().get_image()
	if img_dive:
		img_dive.save_png("c:/Proyectos/Dragon v2/verify_dive.png")
		print("  -> Captura guardada: verify_dive.png")
		
	assert(max_speed_dive >= 120.0, "La picada debe acelerar a más de 120 km/h")
	assert(ap.current_animation == "Qishilong_glide", "La picada debe usar la base limpia Qishilong_glide!")
		
	# 4. PRUEBA DE PULL-OUT (Transición Picada -> Planeo)
	print("\n[TEST 3] Transición PULL-OUT (Salir de picada a planeo)...")
	dragon.toggle_dive() # Apaga dive
	dragon.toggle_glide()
	for f in range(40):
		dragon._physics_process(1.0 / 60.0)
		dragon._process(1.0 / 60.0)
		cam._physics_process(1.0 / 60.0)
		await process_frame
		
	print("  -> Modo tras pull-out: %s" % dragon.FlightMode.keys()[dragon.current_mode])
	print("  -> Velocidad mantenida tras pull-out: %.1f km/h" % (dragon.current_speed * 3.6))
	print("  -> Blend de plegado: %.2f (desplegado a planeo)" % dragon.dive_fold_blend)
	assert(dragon.dive_fold_blend < 0.2, "Las alas deben desplegarse limpiamente tras soltar la picada")
	
	print("\n=======================================================")
	print(">>> TODAS LAS VERIFICACIONES COMPLETADAS CON ÉXITO! <<<")
	print("=======================================================")
	quit(0)
