extends SceneTree
# Captura la cámara real de juego durante una secuencia de vuelo con entradas reales:
# crucero, viraje cerrado, trepada, picada y planeo. Requiere renderer real (sin --headless).
# Uso: tools/godot.sh --path . --script res://scripts/capture_flight_feel.gd -- --out=/ruta/carpeta --tag=antes

const SEQUENCE := [
	{"name": "crucero", "seconds": 3.0, "move": 0.0, "turn": 0.0},
	{"name": "viraje", "seconds": 3.0, "move": 0.0, "turn": 1.0},
	{"name": "trepada", "seconds": 3.0, "move": 1.0, "turn": 0.0, "climb": true},
	{"name": "picada", "seconds": 2.5, "move": 0.0, "turn": 0.0, "dive": true},
	{"name": "planeo", "seconds": 3.0, "move": 0.0, "turn": -0.6, "glide": true},
]

func _initialize() -> void:
	call_deferred("run")

func _arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.split("=", true, 1)[1]
	return fallback

func run() -> void:
	root.size = Vector2i(1280, 720)
	var out := _arg("out", ProjectSettings.globalize_path("res://artifacts/flight-feel"))
	var tag := _arg("tag", "captura")
	DirAccess.make_dir_recursive_absolute(out)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for _i in 120:
		await process_frame
	var dragon = scene.get_node("Dragon")
	dragon.global_position = Vector3(180.0, 190.0, 120.0)
	dragon.has_taken_off = true
	dragon.manual_input_override = true
	var log_lines: Array[String] = []
	for step in SEQUENCE:
		dragon.manual_move_input = step.move
		dragon.manual_turn_input = step.turn
		dragon.manual_climb = step.get("climb", false)
		dragon.manual_dive = step.get("dive", false)
		dragon.glide_mode_active = step.get("glide", false)
		var t := 0.0
		var shots := 0
		while t < step.seconds:
			await physics_frame
			t += 1.0 / float(Engine.physics_ticks_per_second)
			if t >= (float(shots) + 1.0) * step.seconds / 3.0 - 0.001 and shots < 3:
				await process_frame
				shots += 1
				var img := root.get_viewport().get_texture().get_image()
				img.save_png("%s/%s_%s_%d.png" % [out, tag, step.name, shots])
				log_lines.append("%s %d v=%.1f vy=%.1f alt=%.1f pitch=%.1f roll=%.1f" % [step.name, shots, dragon.current_speed, dragon.velocity.y, dragon.global_position.y, rad_to_deg(dragon.rotation.x), rad_to_deg(dragon.rotation.z)])
	var f := FileAccess.open("%s/%s_log.txt" % [out, tag], FileAccess.WRITE)
	f.store_string("\n".join(log_lines))
	print("\n".join(log_lines))
	quit(0)
