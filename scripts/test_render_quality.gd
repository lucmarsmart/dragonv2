extends SceneTree
var scene: Node3D
var failures: Array[String] = []
var metrics := {}
func _initialize() -> void:
	call_deferred("run")
func frames(count: int) -> void:
	for _i in count:
		await process_frame
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)
func snapshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/validation/" + name + ".png")
func run() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await frames(240)
	metrics.fps_after_warmup = Performance.get_monitor(Performance.TIME_FPS)
	metrics.draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	metrics.primitives = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	metrics.physics_ms = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000
	var dragon := scene.get_node("Dragon")
	dragon.set_physics_process(false)
	await snapshot("10-desktop")
	var hud := scene.get_node("HUD")
	hud.controls_panel.visible = true
	await frames(2)
	await snapshot("11-desktop-help")
	for size in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = size
		await frames(10)
		var viewport := Rect2(Vector2.ZERO,Vector2(size))
		for b: Button in hud.buttons.get_children():
			check(viewport.encloses(b.get_global_rect()) and b.size.y >= 44, "Visible >=44px button at " + str(size) + ": " + b.name)
			b.grab_focus()
			await frames(1)
			check(b.has_focus() and b.get_theme_stylebox("focus") != null, "Keyboard focus visible: " + b.name)
		check(viewport.encloses(hud.controls_panel.get_global_rect()), "Help panel fits " + str(size))
		check(hud.action_bar.get_global_rect().end.y < hud.speed_label.get_global_rect().position.y, "Action bar does not overlap telemetry " + str(size))
		await snapshot("12-ui-%dx%d" % [size.x,size.y])
	metrics.failures = failures
	var report := FileAccess.open("res://docs/validation/render-quality.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(metrics,"  "))
	print("RENDER QUALITY ",JSON.stringify(metrics))
	scene.queue_free()
	await frames(4)
	quit(0 if failures.is_empty() else 1)
