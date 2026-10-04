extends SceneTree

# Verificación: orientación del modelo, vistas de cámara y avance/retroceso.
const OUT = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/0a148249-cdfe-4032-87e0-a6f5bb9f47c4/scratch/"

func _key(code: int, pressed: bool) -> void:
	var e = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)

func _init():
	DirAccess.make_dir_recursive_absolute(OUT)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var dragon = scene.get_node("Dragon")
	var cam = scene.get_node("FlightCamera")
	for f in range(150): await process_frame
	print("--- Estado inicial ---")
	print("dragon forward (-Z global): ", -dragon.global_transform.basis.z)
	var pos0 = dragon.global_position
	for f in range(60): await process_frame
	var moved = dragon.global_position - pos0
	var fwd = -dragon.global_transform.basis.z
	print("Avance en 1s: ", moved, " componente sobre forward: ", moved.dot(fwd))
	
	root.get_viewport().get_texture().get_image().save_png(OUT + "view_back.png")
	cam.set_view(FlightCamera.ViewPreset.FRONT)
	for f in range(70): await process_frame
	root.get_viewport().get_texture().get_image().save_png(OUT + "view_front.png")
	cam.set_view(FlightCamera.ViewPreset.RIGHT)
	for f in range(70): await process_frame
	root.get_viewport().get_texture().get_image().save_png(OUT + "view_right.png")
	cam.set_view(FlightCamera.ViewPreset.BACK)
	for f in range(70): await process_frame
	
	# Retroceso: mantener S
	_key(KEY_S, true)
	for f in range(240): await process_frame
	print("Velocidad con S: ", dragon.current_speed)
	var p1 = dragon.global_position
	for f in range(60): await process_frame
	var back_move = dragon.global_position - p1
	print("Movimiento con S (1s) sobre forward: ", back_move.dot(-dragon.global_transform.basis.z))
	_key(KEY_S, false)
	# Avance: mantener W
	_key(KEY_W, true)
	for f in range(240): await process_frame
	print("Velocidad con W: ", dragon.current_speed)
	_key(KEY_W, false)
	quit(0)
