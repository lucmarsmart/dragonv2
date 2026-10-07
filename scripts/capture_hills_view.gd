extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for i in range(15):
		await process_frame
		
	# Hide UI overlay
	var ui = scene.get_node_or_null("SiegeUI")
	if ui and "overlay" in ui and ui.overlay:
		ui.overlay.visible = false
	var hud = scene.get_node_or_null("HUD")
	if hud:
		hud.visible = false
	var combat = scene.get_node_or_null("SiegeCombat")
	if combat and "ui" in combat and combat.ui and "overlay" in combat.ui:
		combat.ui.overlay.visible = false
		
	for i in range(5):
		await process_frame
		
	var vp = root.get_viewport()
	var img = vp.get_texture().get_image()
	var path = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/0549d9c2-5e5f-4a4e-9bb9-ed9a5260b0ea/hills_view_clean.png"
	if img:
		img.save_png(path)
		print("Saved hills_view_clean.png to: ", path)
	quit(0)
