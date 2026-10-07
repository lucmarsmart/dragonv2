extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for _i in count:
		await process_frame

func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_texture().get_image()
	if img:
		img.save_png(path)
		print("CAPTURADO: ", path)

func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	# Ocultar HUD para tomas cinematográficas limpias
	var hud = scene.get_node("HUD")
	if hud:
		hud.visible = false
		
	var dragon: DragonController = scene.get_node("Dragon")
	var cam: Camera3D = scene.get_node("FlightCamera")
	cam.script = null # Desacoplar script de seguimiento para control de cámara cinematográfica
	
	dragon.has_taken_off = true
	dragon.manual_input_override = true
	
	await frames(60)
	
	# =========================================================================
	# TOMA 1: DETALLE DE ESCAMAS Y RELIEVE 3D EN EL LOMO Y CABEZA
	# =========================================================================
	dragon.trigger_normal()
	await frames(30)
	var dragon_pos = dragon.global_position
	cam.global_position = dragon_pos + Vector3(2.5, 2.2, 5.5)
	cam.look_at(dragon_pos + Vector3(0.0, 0.8, -0.5), Vector3.UP)
	await frames(15)
	await capture("res://showcase_scales_relief.png")
	
	# =========================================================================
	# TOMA 2: ALAS TRANSLÚCIDAS Y RETROILUMINACIÓN (SSS) HACIA EL SOL
	# =========================================================================
	dragon.trigger_glide()
	await frames(40)
	cam.global_position = dragon_pos + Vector3(-7.5, -1.5, 4.0)
	cam.look_at(dragon_pos + Vector3(-3.0, 1.2, 0.0), Vector3.UP)
	await frames(15)
	await capture("res://showcase_wings_sss.png")
	
	# =========================================================================
	# TOMA 3: VERIFICACIÓN DE PICADA (DIVE) SIN ATRAVESAR EL CUERPO
	# =========================================================================
	dragon.trigger_dive()
	for _f in range(70):
		dragon._physics_process(1.0 / 60.0)
		dragon._process(1.0 / 60.0)
		await process_frame
		
	cam.global_position = dragon.global_position + Vector3(0.0, 6.0, 16.0)
	cam.look_at(dragon.global_position, Vector3.UP)
	await frames(15)
	await capture("res://showcase_dive_clean.png")
	
	# =========================================================================
	# TOMA 4: VERIFICACIÓN DE GIRO Y COLA SIN AUTO-COLISIÓN
	# =========================================================================
	dragon.trigger_normal()
	dragon.manual_turn_input = 1.0 # Giro cerrado a la derecha
	for _f in range(80):
		dragon._physics_process(1.0 / 60.0)
		dragon._process(1.0 / 60.0)
		await process_frame
		
	cam.global_position = dragon.global_position + Vector3(0.0, 5.5, 17.0)
	cam.look_at(dragon.global_position, Vector3.UP)
	await frames(15)
	await capture("res://showcase_turn_clean.png")
	
	print("--- TODAS LAS CAPTURAS CINEMATOGRÁFICAS COMPLETADAS ---")
	scene.queue_free()
	await frames(4)
	quit(0)
