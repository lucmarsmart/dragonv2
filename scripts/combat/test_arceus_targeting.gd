extends SceneTree

# ==============================================================================
# TEST DE VALIDACIÓN: SISTEMA DE FIJACIÓN DE OBJETIVO (ESTILO LEYENDAS ARCEUS)
# ==============================================================================

var scene: Node3D
var combat: SiegeCombat
var dragon: DragonController
var breath: DragonBreath
var hud: CanvasLayer
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func ticks(n: int) -> void:
	for _i in n:
		await physics_frame
		await process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures.append(message)

func key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)

func pulse(code: Key) -> void:
	key(code, true)
	await ticks(1)
	key(code, false)
	await ticks(2)

func run() -> void:
	root.size = Vector2i(1280, 720)
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	combat = scene.get_node("SiegeCombat")
	dragon = scene.get_node("Dragon")
	breath = dragon.get_node("DragonBreath")
	hud = scene.get_node("HUD")
	
	# Esperar calibración e inicialización
	for _i in 300:
		await ticks(1)
		if combat.initialized:
			break
	
	check(combat.initialized, "Combate inicializado con éxito")
	check(dragon.lock_on_enabled, "Sistema de fijación de objetivo está habilitado")
	
	# Iniciar asedio
	combat.start_mission()
	await ticks(10)
	check(combat.is_running(), "Misión en curso")
	
	# Posicionar al dragón a 30m de una ballista con vista frontal clara
	var ballista: CharacterBody3D = combat.enemies[0]
	dragon.global_position = ballista.global_position + Vector3(0, 4, 30)
	dragon.rotation = Vector3.ZERO
	dragon.target_yaw = 0
	dragon.target_pitch = 0
	dragon.target_roll = 0
	dragon.velocity = Vector3.ZERO
	
	await ticks(15)
	
	# 1. Comprobar que fija automáticamente a la ballista más cercana
	var locked = dragon.get_locked_target()
	check(locked == ballista, "La mira se fija automáticamente en la ballista más cercana")
	check(dragon.lock_on_distance > 10.0 and dragon.lock_on_distance < 36.0, "Distancia de fijación calculada correctamente (~30m)")
	
	# 2. Comprobar que la cabeza del dragón apunta hacia la ballista
	var target_center: Vector3 = dragon._get_target_aim_point(ballista)
	var dir_to_target: Vector3 = (target_center - breath.mouth_position).normalized()
	check(breath.breath_direction.dot(dir_to_target) > 0.85, "La cabeza y dirección del soplo siguen al objetivo fijado")
	
	# 3. Comprobar retícula Arceus en HUD
	var reticle = hud.get_node_or_null("ArceusReticle")
	check(reticle != null, "Nodo ArceusReticle activo en el HUD")
	check(reticle.visible, "Retícula visible en modo combate")
	check(reticle.is_locked, "Retícula reporta estado FIJADO (is_locked = true)")
	
	# 4. Probar cambio de objetivo con TAB / cycle_locked_target()
	var previous_target = locked
	dragon.cycle_locked_target()
	await ticks(5)
	# Si hay otro enemigo en rango, cambia; o mantiene si es único en 65m
	print("Objetivo tras TAB: ", dragon.get_locked_target().name if dragon.get_locked_target() else "Ninguno")
	check(dragon.get_locked_target() != null, "TAB mantiene o cicla objetivo válido")
	
	# 5. Probar que al alejarse (> 68m) la mira se desengancha ("hasta que este se aleja")
	dragon.global_position = ballista.global_position + Vector3(0, 10, 85) # 85m de distancia
	await ticks(15)
	check(dragon.get_locked_target() == null, "La mira se desengancha al alejarse del enemigo (>68m)")
	check(not reticle.is_locked, "Retícula vuelve a modo libre al alejarse el objetivo")
	
	# 6. Regresar a rango cercano y probar daño certero
	dragon.global_position = ballista.global_position + Vector3(0, 3, 20)
	await ticks(15)
	check(dragon.get_locked_target() == ballista, "Re-fija automáticamente al volver a entrar en rango")
	
	var hp_before: float = ballista.health
	breath.manual_override = true
	breath.manual_fire = true
	await ticks(45)
	breath.manual_fire = false
	breath.manual_override = false
	
	check(ballista.health < hp_before, "El fuego daña efectivamente al objetivo fijado gracias al seguimiento")
	
	print("\n=======================================================")
	print("RESULTADO TEST ARCEUS TARGETING: %d/%d superados" % [checks - failures.size(), checks])
	if failures.is_empty():
		print("¡TODAS LAS PRUEBAS DE MODO BATALLA Y FIJACIÓN PASARON CON ÉXITO!")
	else:
		print("FALLOS: ", failures)
	print("=======================================================\n")
	
	quit(0 if failures.is_empty() else 1)
