@tool
extends SceneTree

func _init():
	print("\n=======================================================")
	print("--- TEST DE DAÑO DE FUEGO A BALLISTAS (AIRE Y TIERRA) ---")
	print("=======================================================")
	
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(30): await process_frame
	
	var combat: SiegeCombat = scene.get_node("SiegeCombat")
	var dragon: DragonController = scene.get_node("Dragon")
	var breath: DragonBreath = dragon.get_node("DragonBreath")
	
	combat.phase = combat.Phase.DEFENSES
	
	# Buscar ballistas (turrets)
	var turrets = []
	for e in combat.enemies:
		if e.kind == "turret":
			turrets.append(e)
			
	print("Ballistas encontradas: %d" % turrets.size())
	assert(turrets.size() > 0, "No se encontraron ballistas en el combate")
	
	# -------------------------------------------------------------
	# 1. TEST DE FUEGO EN TIERRA (GROUNDED) CONTRA BALLISTA 0
	# -------------------------------------------------------------
	print("\n[1] Probando fuego desde TIERRA (GROUNDED) contra Ballista...")
	var t0 = turrets[0]
	var initial_hp = t0.health
	print("  -> HP inicial de Ballista: %.1f" % initial_hp)
	
	# Posicionar dragón en tierra frente a la ballesta
	var t0_pos: Vector3 = t0.global_position
	dragon.global_position = t0_pos + Vector3(0, 0, 15) # 15m de distancia en el suelo
	dragon.locomotion_state = dragon.LocomotionState.GROUNDED
	dragon.velocity = Vector3.ZERO
	dragon.current_speed = 0.0
	for f in range(5):
		dragon._physics_process(0.033)
		await process_frame
	if breath.has_method("_update_mouth"):
		breath._update_mouth()
	
	# Apuntar cabeza/boca hacia el centro de la ballesta
	var dir_to_turret = (t0_pos + Vector3(0, 1.2, 0) - breath.mouth_position).normalized()
	breath.breath_direction = dir_to_turret
	breath.manual_override = true
	breath.manual_fire = true
	
	for f in range(40):
		breath._physics_process(0.033)
		combat._physics_process(0.033)
		await process_frame
		
	var hp_after_ground = t0.health
	var damage_ground = initial_hp - hp_after_ground
	print("  -> HP de Ballista tras fuego terrestre: %.1f (Daño recibido: %.1f)" % [hp_after_ground, damage_ground])
	assert(damage_ground > 10.0, "ERROR: La ballista NO recibió daño de fuego desde tierra!")
	print("  -> ¡ÉXITO: La ballista recibe daño correctamente desde tierra!")
	
	# -------------------------------------------------------------
	# 2. TEST DE FUEGO DESDE EL AIRE (AIRBORNE) CONTRA BALLISTA 1
	# -------------------------------------------------------------
	if turrets.size() > 1:
		print("\n[2] Probando fuego desde el AIRE (AIRBORNE) contra Ballista...")
		var t1 = turrets[1]
		var initial_hp1 = t1.health
		var t1_pos: Vector3 = t1.global_position
		
		# Dragón en vuelo a 10m de altura y 15m de distancia
		dragon.global_position = t1_pos + Vector3(0, 10, 15)
		dragon.locomotion_state = dragon.LocomotionState.FLYING
		dragon.velocity = Vector3(0, 0, -5)
		for f in range(5):
			dragon._physics_process(0.033)
			await process_frame
		if breath.has_method("_update_mouth"):
			breath._update_mouth()
		
		var dir_to_t1 = (t1_pos + Vector3(0, 1.2, 0) - breath.mouth_position).normalized()
		breath.breath_direction = dir_to_t1
		breath.manual_override = true
		breath.manual_fire = true
		
		for f in range(40):
			breath._physics_process(0.033)
			combat._physics_process(0.033)
			await process_frame
			
		var damage_air = initial_hp1 - t1.health
		print("  -> HP de Ballista tras fuego aéreo: %.1f (Daño recibido: %.1f)" % [t1.health, damage_air])
		assert(damage_air > 10.0, "ERROR: La ballista NO recibió daño de fuego desde el aire!")
		print("  -> ¡ÉXITO: La ballista recibe daño correctamente desde el aire!")
		
	breath.manual_fire = false
	print("\n=======================================================")
	print(">>> ¡TODAS LAS PRUEBAS DE DAÑO A BALLISTAS PASARON EXITOSAMENTE! <<<")
	print("=======================================================\n")
	quit(0)
