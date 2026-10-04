@tool
extends SceneTree

func _init():
	print("=================================================================")
	print("       VERIFICACIÓN COMPLETA DE BIOMECÁNICA NATURAL DE VUELO     ")
	print("=================================================================")
	
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	
	var dragon = main_scene.get_node("Dragon")
	if not dragon:
		print("ERROR: Dragon node not found!")
		quit(1)
		return
		
	# Wait for _ready and initial setup
	for f in range(10):
		await process_frame
		
	print("\n--- 1. VERIFICACIÓN DE BIBLIOTECA DE ANIMACIONES ---")
	var ap: AnimationPlayer = dragon.anim_player
	var anims = ap.get_animation_list()
	print("Animaciones disponibles en AnimationPlayer:", anims)
	
	assert(ap.has_animation("Qishilong_fly2"), "Falta Qishilong_fly2!")
	assert(ap.has_animation("Qishilong_glide"), "Falta Qishilong_glide!")
	print("-> Verificación de animaciones: EXITOSA (Qishilong_fly2 y Qishilong_glide presentes)")
	
	print("\n--- 2. VERIFICACIÓN DEL MODO NORMAL ---")
	dragon.manual_input_override = true
	dragon.has_taken_off = true
	dragon.trigger_normal()
	for f in range(15):
		dragon._physics_process(0.016)
		dragon._process(0.016)
		await process_frame
		
	print("Modo actual: %s (esperado NORMAL)" % dragon.current_mode)
	print("Animación reproduciéndose: %s, velocidad alar: %.2f" % [ap.current_animation, ap.speed_scale])
	assert(dragon.current_mode == dragon.FlightMode.NORMAL, "Error: no está en NORMAL")
	assert(ap.current_animation == "Qishilong_fly2", "Error: no está reproduciendo Qishilong_fly2")
	print("-> Modo NORMAL: VERIFICADO")
	
	print("\n--- 3. VERIFICACIÓN DEL MODO PLANEO (GLIDE) ---")
	dragon.toggle_glide()
	for f in range(25):
		dragon._physics_process(0.016)
		dragon._process(0.016)
		await process_frame
		
	print("Modo actual: %s (esperado GLIDE)" % dragon.current_mode)
	print("Animación reproduciéndose: %s (esperado Qishilong_glide)" % ap.current_animation)
	print("¿Está aleteando? %s (esperado false)" % dragon.is_flapping)
	assert(dragon.current_mode == dragon.FlightMode.GLIDE, "Error: no está en GLIDE")
	assert(ap.current_animation == "Qishilong_glide", "Error: no está reproduciendo Qishilong_glide")
	assert(dragon.is_flapping == false, "Error: en planeo NO debe aletear continuamente")
	print("-> Modo GLIDE (Alas extendidas horizontales, sin aleteo parásito): VERIFICADO")
	
	print("\n--- 4. VERIFICACIÓN DEL MODO TREPADA (CLIMB) ---")
	dragon.trigger_climb()
	for f in range(20):
		dragon._physics_process(0.016)
		dragon._process(0.016)
		await process_frame
		
	print("Modo actual: %s (esperado CLIMB)" % dragon.current_mode)
	print("Pitch objetivo: %.1f deg, Animación: %s, Cadencia: %.2f" % [
		rad_to_deg(dragon.target_pitch), ap.current_animation, ap.speed_scale
	])
	assert(dragon.current_mode == dragon.FlightMode.CLIMB, "Error: no está en CLIMB")
	assert(dragon.is_flapping == true, "Error: en CLIMB debe aletear con potencia")
	print("-> Modo CLIMB (Trepada activa y potente): VERIFICADO")
	
	print("\n--- 5. VERIFICACIÓN DE VIRAJES COORDINADOS Y ASIMETRÍA ALAR ---")
	dragon.trigger_normal()
	dragon.manual_turn_input = 1.0 # Giro a la izquierda
	for f in range(30):
		dragon._physics_process(0.016)
		dragon._process(0.016)
		await process_frame
		
	print("Viraje a la izquierda: TurnRate=%.3f, TargetRoll=%.1f deg" % [
		dragon.smoothed_turn_rate, rad_to_deg(dragon.target_roll)
	])
	assert(dragon.smoothed_turn_rate > 0.1, "Error: la tasa de giro debe ser positiva hacia la izquierda")
	assert(dragon.target_roll > 0.05, "Error: debe alabear hacia el interior de la curva")
	print("-> Virajes coordinados (Alabeo y tasa centrípeta fluida): VERIFICADOS")
	
	print("\n--- 6. VERIFICACIÓN DE ESTABILIDAD DEL MODELO VISUAL (CERO JITTER) ---")
	var prev_basis = dragon.visual_root.basis
	var jitter_detected = false
	for f in range(30):
		dragon._physics_process(0.016)
		dragon._process(0.016)
		await process_frame
		var cur_basis = dragon.visual_root.basis
		# Check if basis had unnatural instant snapping
		var diff = (cur_basis.get_euler() - prev_basis.get_euler()).length()
		if diff > 0.8:
			jitter_detected = true
			print("Alerta: jitter detectado, diff=%.4f" % diff)
		prev_basis = cur_basis
		
	assert(not jitter_detected, "Error: se detectó jitter en visual_root")
	print("-> Estabilidad visual y continuidad angular: VERIFICADA (Cero jitter/fricción)")
	
	print("\n=================================================================")
	print("       ¡TODAS LAS PRUEBAS BIOMECÁNICAS PASARON CON ÉXITO!        ")
	print("=================================================================")
	quit(0)
