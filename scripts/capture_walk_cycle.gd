extends SceneTree
# Captura la marcha terrestre cuadro a cuadro (lateral, 3/4 y cámara de juego) con entradas reales.
# Requiere renderer real. Uso: tools/godot.sh --path . --script res://scripts/capture_walk_cycle.gd -- --out=/ruta --tag=antes

func _initialize() -> void:
	call_deferred("run")

func _arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.split("=", true, 1)[1]
	return fallback

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	root.size = Vector2i(960, 540)
	# Sin foco y siempre visible: no roba el teclado y macOS no congela la ventana tapada.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	var out := _arg("out", ProjectSettings.globalize_path("res://artifacts/walk-cycle"))
	var tag := _arg("tag", "marcha")
	DirAccess.make_dir_recursive_absolute(out)
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.get_node("SiegeUI").free()
	scene.get_node("SiegeCombat").free()
	root.add_child(scene)
	var d = scene.get_node("Dragon")
	for _f in 120:
		await process_frame
	# Terreno real: primer punto seco y transitable del corredor que usa la prueba de aceptación.
	var landscape = get_first_node_in_group("landscape")
	var spot := Vector3(300, 0, 170)
	for candidate in [Vector3(300, 0, 170), Vector3(280, 0, 160), Vector3(300, 0, 120), Vector3(320, 0, 170)]:
		var support: Dictionary = landscape.ground_surface(candidate)
		if not support.is_empty() and not landscape.is_water_at(candidate):
			spot = support.position
			break
	d.global_position = spot + Vector3.UP * 3.5
	d.velocity = Vector3(0, -2, 0)
	d.has_taken_off = true
	d.current_speed = 0
	d.locomotion_state = d.LocomotionState.LANDING
	d.rotation = Vector3.ZERO
	d.target_pitch = 0
	d.target_yaw = 0
	d.target_roll = 0
	d.manual_input_override = true
	d.landing_target_active = false
	var game_cam = scene.get_node("FlightCamera")
	var hud = scene.get_node("HUD")
	hud.visible = false
	for _f in 200:
		await physics_frame
	print("ATERRIZAJE state=%d ground_blend=%.2f y=%.2f" % [d.locomotion_state, d.ground_blend, d.global_position.y])
	var side := Camera3D.new()
	scene.add_child(side)
	var log_lines: Array[String] = []
	# Marcha, luego carrera: 24 cuadros laterales cada 0,1 s y 6 de la cámara de juego.
	for phase in [{"name": "paso", "sprint": false}, {"name": "carrera", "sprint": true}]:
		d.manual_move_input = 1.0
		d.manual_sprint = phase.sprint
		for _f in 60:
			await physics_frame
		for i in 24:
			for _f in 6:
				await physics_frame
			var right: Vector3 = d.global_basis.x
			side.global_position = d.global_position + right * 24.0 + Vector3.UP * 2.5
			side.look_at(d.global_position + Vector3(0, -1, 0))
			side.current = true
			await _shot("%s/%s_%s_lado_%02d.png" % [out, tag, phase.name, i])
			print("%s %02d state=%d speed=%.2f moved=%.2f phase=%.2f" % [phase.name, i, d.locomotion_state, d.current_speed, d.ground_motion_speed, d.walk_cycle_phase])
			log_lines.append("%s %02d speed=%.2f moved=%.2f phase=%.2f errors=%s" % [phase.name, i, d.current_speed, d.ground_motion_speed, d.walk_cycle_phase, str(d.ground_pose.debug_errors)])
		game_cam.current = true
		for i in 6:
			for _f in 10:
				await physics_frame
			await _shot("%s/%s_%s_juego_%02d.png" % [out, tag, phase.name, i])
	var f := FileAccess.open("%s/%s_log.txt" % [out, tag], FileAccess.WRITE)
	f.store_string("\n".join(log_lines))
	print("\n".join(log_lines))
	quit(0)
