extends SceneTree
# Mide tiempos de cuadro reales en vuelo de crucero con viraje suave (renderer real, sin --headless).
# Variantes: -- --off=sdfgi,ssil,volfog,ssao,shadows,msaa  (desactiva efectos para aislar su costo)
# Uso: tools/godot.sh --path . --script res://scripts/benchmark_flight.gd -- --seconds=12 --off=sdfgi

func _initialize() -> void:
	call_deferred("run")

func _arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.split("=", true, 1)[1]
	return fallback

func run() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.get_node("SiegeUI").free()
	scene.get_node("SiegeCombat").free()
	root.add_child(scene)
	var env: Environment = scene.get_node("WorldEnvironment").environment
	var off := _arg("off", "").split(",", false)
	if "sdfgi" in off: env.sdfgi_enabled = false
	if "ssil" in off: env.ssil_enabled = false
	if "ssao" in off: env.ssao_enabled = false
	if "volfog" in off: env.volumetric_fog_enabled = false
	if "shadows" in off: scene.get_node("DirectionalLight3D").shadow_enabled = false
	if "msaa" in off: root.msaa_3d = Viewport.MSAA_DISABLED
	for _i in 120:
		await process_frame
	var dragon = scene.get_node("Dragon")
	dragon.global_position = Vector3(180.0, 160.0, 120.0)
	dragon.has_taken_off = true
	dragon.manual_input_override = true
	dragon.manual_turn_input = 0.35
	for _i in 90:
		await process_frame
	var seconds := float(_arg("seconds", "12"))
	var frames: Array[float] = []
	var start := Time.get_ticks_usec()
	var previous := start
	while Time.get_ticks_usec() - start < int(seconds * 1000000.0):
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append(float(now - previous) / 1000.0)
		previous = now
	frames.sort()
	var total := 0.0
	for f in frames:
		total += f
	var n := frames.size()
	var over_33 := frames.filter(func(f): return f > 33.4).size()
	print("BENCH off=%s frames=%d avg_ms=%.1f fps=%.1f p50=%.1f p95=%.1f p99=%.1f max=%.1f over33ms=%.1f%%" % [",".join(off), n, total / n, 1000.0 * n / total, frames[n / 2], frames[int(n * 0.95)], frames[int(n * 0.99)], frames[-1], 100.0 * over_33 / n])
	quit(0)
