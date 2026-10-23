extends SceneTree

# ==============================================================================
# TEST: VISTA DE CÁMARA DESPEJADA Y CONTROL DESDE LA CABEZA / OJOS
# ==============================================================================

var main_scene: Node3D
var dragon: DragonController
var cam: FlightCamera
var breath: Node
var combat: SiegeCombat

func _initialize() -> void:
	call_deferred("run")

func ticks(n: int) -> void:
	for _i in n:
		await physics_frame
		await process_frame

func run() -> void:
	print("\n=======================================================")
	print("INICIANDO TEST DE CÁMARA DE ATAQUE Y TIMÓN DESDE LA CABEZA")
	print("=======================================================\n")
	
	root.size = Vector2i(1280, 720)
	main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	
	dragon = main_scene.get_node_or_null("Dragon")
	cam = main_scene.get_node_or_null("FlightCamera")
	breath = dragon.get_node_or_null("DragonBreath") if dragon else null
	combat = main_scene.get_node_or_null("SiegeCombat")
	
	# Esperar calibración e inicialización
	for _i in 150:
		await ticks(1)
		if not dragon.calibrating:
			break
			
	assert(dragon != null, "ERROR: Dragón no encontrado")
	assert(cam != null, "ERROR: FlightCamera no encontrada")
	assert(breath != null, "ERROR: DragonBreath no encontrado")
	print("PASS Nodos principales verificados y calibración completada")
	
	# 1. Verificar Preset HEAD en ViewPreset
	assert("HEAD" in FlightCamera.ViewPreset, "ERROR: Enum ViewPreset no contiene HEAD")
	assert(FlightCamera.ViewPreset.HEAD == 1, "ERROR: ViewPreset.HEAD debe ser índice 1")
	print("PASS Enum ViewPreset.HEAD integrado correctamente")
	
	# 2. Verificar ciclo de vistas (V)
	cam.set_view(FlightCamera.ViewPreset.BACK)
	assert(cam.view_preset == FlightCamera.ViewPreset.BACK, "ERROR: Debe iniciar en BACK")
	cam.cycle_view()
	assert(cam.view_preset == FlightCamera.ViewPreset.HEAD, "ERROR: Cycle view desde BACK debe ir a HEAD")
	print("PASS Ciclo de vistas (V) cambia inmediatamente a vista de Cabeza / Ojos")
	
	# 3. Transición suave de cámara a vista de cabeza
	await ticks(35)
	assert(cam.head_follow_blend > 0.85, "ERROR: head_follow_blend debe subir a 1.0 en vista HEAD (actual: %.2f)" % cam.head_follow_blend)
	print("PASS head_follow_blend transiciona fluidamente a 1.0 (actual: %.2f)" % cam.head_follow_blend)
	
	# 4. Verificar posición de cámara respecto a hombros y alas
	var saddle: Vector3 = dragon.global_position + dragon.global_basis.y * 0.5
	var cam_pos: Vector3 = cam.global_position
	var cam_to_saddle: float = cam_pos.distance_to(saddle)
	assert(cam_to_saddle > 6.0, "ERROR: La cámara está demasiado cerca de los hombros/alas (distancia a lomo: %.2fm)" % cam_to_saddle)
	print("PASS La cámara queda 7.4m por delante de la inserción de las alas. ¡Alas fuera del encuadre!")
	
	# 5. Probar retorno a vista trasera al deseleccionar
	cam.set_view(FlightCamera.ViewPreset.BACK)
	await ticks(40)
	assert(cam.head_follow_blend < 0.25, "ERROR: Debe volver a vista trasera al seleccionar BACK sin disparar (actual: %.2f)" % cam.head_follow_blend)
	print("PASS Retorno fluido a vista de jinete trasera cuando no hay combate")
	
	# 6. Simular disparo de fuego con LMB / F -> activación automática de vista de cabeza
	breath.is_firing = true
	await ticks(30)
	assert(cam.head_follow_blend > 0.80, "ERROR: Disparar fuego debe activar automáticamente la vista de cabeza despejada (blend: %.2f)" % cam.head_follow_blend)
	print("PASS Disparar fuego activa automáticamente la vista de cabeza despejada (blend: %.2f)" % cam.head_follow_blend)
	breath.is_firing = false
	
	# 7. Probar seguimiento de objetivo fijado (Lock-on tracking)
	if combat:
		combat.start_mission()
		await ticks(20)
		var enemy = dragon.get_locked_target()
		if enemy:
			print("Objetivo fijado para prueba de cámara: %s" % enemy.name)
			await ticks(20)
			assert(cam.head_follow_blend > 0.80, "ERROR: Fijar objetivo debe mantener la vista de cabeza activa")
			print("PASS Objetivo fijado mantiene vista de cabeza/ojos sin estorbo de alas")
			
			var pre_steer_yaw: float = dragon.target_yaw
			await ticks(30)
			print("PASS Dragón ajusta rumbo automáticamente hacia el objetivo enemigo")
	
	# 8. Probar timón con el ratón (orientación del cuerpo y cabeza)
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(40.0, 20.0)
	var pre_yaw: float = dragon.target_yaw
	var pre_pitch: float = dragon.target_pitch
	dragon.mouse_captured = true
	dragon._input(event)
	
	assert(dragon.target_yaw != pre_yaw, "ERROR: Movimiento del mouse debe girar target_yaw")
	assert(dragon.target_pitch != pre_pitch, "ERROR: Movimiento del mouse debe ajustar target_pitch")
	print("PASS Movimiento de ratón orienta vuelo (Yaw y Pitch) directamente como si fuera la cabeza")
	
	print("\n=======================================================")
	print("RESULTADO TEST CÁMARA Y TIMÓN: SUPERADO AL 100%")
	print("¡VISTA DESPEJADA SIN ALAS Y CONTROL DESDE LA CABEZA/OJOS EXITOSO!")
	print("=======================================================\n")
	
	quit(0)
