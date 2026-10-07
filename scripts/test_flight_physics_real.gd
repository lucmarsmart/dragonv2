@tool
extends SceneTree

func _init() -> void:
	print("==================================================")
	print("INICIANDO VERIFICACIÓN DE FÍSICA: COLISIONES Y AGUA")
	print("==================================================")
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)

	var dragon = scene.get_node("Dragon")
	var camera = scene.get_node("FlightCamera")
	var terrain = scene.get_node("NaturalLandscape")

	# Esperar a que la escena y la calibración inicial de orientación finalicen completamente
	for f in range(30):
		await process_frame
	while dragon.calibrating:
		await process_frame

	print("Inicialización y calibración completada con éxito.")
	dragon.manual_input_override = true
	var dt := 1.0 / 60.0

	# =========================================================================
	# FASE 1: Colisión y rebote contra pared rocosa / montaña
	# =========================================================================
	print("\n--- FASE 1: Choque a alta velocidad contra roca / montaña ---")
	var h_wall: float = terrain.ground_height(-700.0, 0.0)
	var h_start: float = terrain.ground_height(-630.0, 0.0)
	print("  Altura de terreno en inicio x=-630: ", h_start)
	print("  Altura de pared rocosa en x=-700: ", h_wall)

	var start_y: float = 192.0 # Altura de vuelo libre que impacta de frente contra la pared de 213m
	dragon.global_position = Vector3(-630.0, start_y, 0.0)
	dragon.target_yaw = deg_to_rad(90.0) # Hacia -X
	dragon.rotation = Vector3(0, deg_to_rad(90.0), 0)
	dragon.target_pitch = 0.0
	dragon.locomotion_state = dragon.LocomotionState.FLYING
	dragon.current_mode = dragon.FlightMode.NORMAL
	dragon.manual_move_input = 1.0
	dragon.current_speed = 35.0
	dragon.velocity = Vector3(-35.0, 0, 0)
	dragon.has_taken_off = true

	var wall_hit := false
	var wall_trauma := 0.0
	var wall_rebound := false
	var initial_x: float = dragon.global_position.x

	var tunneling_detected := false

	for step in range(80):
		dragon._physics_process(dt)
		camera._physics_process(dt)
		await process_frame

		var h_g: float = terrain.ground_height(dragon.global_position.x, dragon.global_position.z)
		if dragon.global_position.y < h_g - 0.2:
			tunneling_detected = true

		if camera.trauma > wall_trauma:
			wall_trauma = camera.trauma
		if dragon.velocity.x > 0.0: # Rebotó hacia +X
			wall_rebound = true
		if dragon.get_slide_collision_count() > 0 or wall_rebound or camera.trauma > 0.05:
			wall_hit = true
		if step % 20 == 0:
			print("  Paso ", step, " | Pos: ", dragon.global_position, " | Vel: ", dragon.velocity, " | Trauma: ", camera.trauma)

	print("FASE 1 COMPLETADA:")
	print("  - Distancia recorrida: ", initial_x - dragon.global_position.x)
	print("  - Impacto detectado: ", wall_hit)
	print("  - Rebote físico (+X velocity): ", wall_rebound)
	print("  - Trauma de impacto en cámara: ", wall_trauma)

	# =========================================================================
	# FASE 2: Penetración y navegación en el agua (Río)
	# =========================================================================
	print("\n--- FASE 2: Picada libre y penetración en el agua (Sin rebotes de trampolín) ---")
	var r_center: float = terrain.river_center(0.0)
	var water_lvl: float = terrain.get_water_level()
	var riverbed_h: float = terrain.ground_height(r_center, 0.0)
	print("  Río centro en x=", r_center, " | Nivel agua = ", water_lvl, " | Fondo del río = ", riverbed_h)

	dragon.global_position = Vector3(r_center, 12.0, 0.0)
	dragon.target_pitch = -deg_to_rad(65.0)
	dragon.target_yaw = 0.0
	dragon.rotation = Vector3(-deg_to_rad(65.0), 0, 0) # Picada hacia el río
	dragon.locomotion_state = dragon.LocomotionState.FLYING
	dragon.current_mode = dragon.FlightMode.DIVE
	dragon.is_diving = true
	dragon.manual_dive = true
	dragon.manual_move_input = 1.0
	dragon.current_speed = 28.0
	dragon.velocity = Vector3(0, -25.0, 5.0)
	dragon.has_taken_off = true

	var water_entered := false
	var min_water_y := 999.0
	var water_trampoline_bounce := false

	for step in range(80):
		dragon._physics_process(dt)
		camera._physics_process(dt)
		await process_frame

		var h_g: float = terrain.ground_height(dragon.global_position.x, dragon.global_position.z)
		if dragon.global_position.y < h_g - 0.2:
			tunneling_detected = true

		var y: float = dragon.global_position.y
		min_water_y = minf(min_water_y, y)
		if y <= water_lvl:
			water_entered = true
		# Un rebote anormal de trampolín impulsaría al dragón hacia arriba a > 5 m/s
		if water_entered and dragon.velocity.y > 5.0:
			water_trampoline_bounce = true
		if step % 20 == 0:
			print("  Paso ", step, " | Y: ", y, " | Vel.y: ", dragon.velocity.y, " | En agua: ", dragon._is_in_water(), " | Picada activa: ", dragon.is_diving)

	print("FASE 2 COMPLETADA:")
	print("  - Dragón atravesó el nivel del agua: ", water_entered)
	print("  - Profundidad mínima alcanzada Y: ", min_water_y, " (Nivel = ", water_lvl, ")")
	print("  - Rebote violento evitado: ", not water_trampoline_bounce)
	print("  - Estado de picada respetado bajo el agua: ", dragon.is_diving)

	# =========================================================================
	# FASE 3: Choque violento contra terreno firme (Crash landing a GROUNDED)
	# =========================================================================
	print("\n--- FASE 3: Choque contra tierra firme (Crash Landing) ---")
	var ground_y: float = terrain.ground_height(300.0, 120.0)
	print("  Altura suelo arena (300, 120): ", ground_y)

	dragon.global_position = Vector3(300.0, ground_y + 18.0, 120.0)
	dragon.target_pitch = -deg_to_rad(55.0)
	dragon.target_yaw = 0.0
	dragon.rotation = Vector3(-deg_to_rad(55.0), 0, 0)
	dragon.locomotion_state = dragon.LocomotionState.FLYING
	dragon.current_mode = dragon.FlightMode.DIVE
	dragon.is_diving = true
	dragon.manual_dive = true
	dragon.manual_move_input = 1.0
	dragon.current_speed = 30.0
	dragon.velocity = Vector3(0, -26.0, 8.0)
	dragon.has_taken_off = true

	var ground_crashed := false
	var ground_trauma := 0.0

	for step in range(40):
		dragon._physics_process(dt)
		camera._physics_process(dt)
		await process_frame

		var h_g: float = terrain.ground_height(dragon.global_position.x, dragon.global_position.z)
		if dragon.global_position.y < h_g - 0.2:
			tunneling_detected = true

		if camera.trauma > ground_trauma:
			ground_trauma = camera.trauma
		if dragon.locomotion_state == dragon.LocomotionState.GROUNDED:
			ground_crashed = true
		if step % 10 == 0 or dragon.locomotion_state == dragon.LocomotionState.GROUNDED:
			print("  Paso ", step, " | y=", dragon.global_position.y, " | vel=", dragon.velocity, " | state=", dragon.locomotion_state, " | cols=", dragon.get_slide_collision_count(), " | cam_trauma=", camera.trauma)

	print("FASE 3 COMPLETADA:")
	print("  - Transición por choque a GROUNDED: ", ground_crashed)
	print("  - Trauma en cámara generado: ", ground_trauma)

	# =========================================================================
	# RESULTADOS GLOBALES
	# =========================================================================
	print("\n==================================================")
	print("RESUMEN DE PRUEBAS DE FÍSICA")
	print("==================================================")
	var p1 = wall_hit and (wall_rebound or wall_trauma > 0.0)
	var p2 = water_entered and not water_trampoline_bounce
	var p3 = ground_crashed or ground_trauma > 0.0
	var p4 = not tunneling_detected

	print("1. Choque contra roca / pared (Inelástico real): ", "PASS" if p1 else "FAIL")
	print("2. Atravesar agua sin rebotes: ", "PASS" if p2 else "FAIL")
	print("3. Choque violento contra tierra (Crash landing): ", "PASS" if p3 else "FAIL")
	print("4. Cero penetración / No atravesar la roca: ", "PASS" if p4 else "FAIL")

	var all_pass = p1 and p2 and p3 and p4
	print("VEREDICTO FINAL: ", "PASS (FÍSICA VALIDADA)" if all_pass else "FAIL")
	quit(0 if all_pass else 1)
