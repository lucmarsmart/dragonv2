extends SceneTree

var scene: Node3D
var dragon: DragonController
var cam: Camera3D

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for _i in count:
		await process_frame
		await physics_frame

func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_texture().get_image()
	if img:
		img.save_png(path)
		print("CAPTURADO: ", path)

func run() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	# Ocultar todos los paneles de UI para ver limpiamente al dragón
	var hud = scene.get_node_or_null("HUD")
	if hud: hud.visible = false
	var siege_ui = scene.get_node_or_null("SiegeUI")
	if siege_ui: siege_ui.visible = false
	
	dragon = scene.get_node("Dragon")
	cam = scene.get_node("FlightCamera")
	
	dragon.has_taken_off = true
	dragon.manual_input_override = true
	
	# Warmup
	await frames(40)
		
	# 1. VUELO NORMAL (Observar relieve de escamas y nuevo aspecto vivo)
	dragon.trigger_normal()
	await frames(45)
	await capture("res://ingame_flight_normal.png")
	
	# 2. PLANEO (GLIDE)
	dragon.toggle_glide()
	await frames(45)
	await capture("res://ingame_flight_glide.png")
	
	# 3. PICADA (DIVE) - Verificar que las alas y patas NO atraviesan el cuerpo
	dragon.toggle_dive()
	await frames(50)
	await capture("res://ingame_flight_dive.png")
	dragon.toggle_dive() # Salir de picada
	
	# 4. GIRO (TURN) - Verificar que la cola se arquea con gracia y NO penetra el cuerpo
	dragon.trigger_normal()
	dragon.manual_turn_input = 1.0
	await frames(50)
	await capture("res://ingame_flight_turn.png")
	
	scene.queue_free()
	await frames(4)
	quit(0)
