@tool
extends SceneTree

func _init() -> void:
	print("Instantiating main game scene for nature capture...")
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)

	var dragon = scene.get_node_or_null("Dragon")
	if dragon:
		scene.remove_child(dragon)
		dragon.queue_free()

	var combat = scene.get_node_or_null("SiegeCombat")
	if combat:
		scene.remove_child(combat)
		combat.queue_free()

	var siege_ui = scene.get_node_or_null("SiegeUI")
	if siege_ui:
		scene.remove_child(siege_ui)
		siege_ui.queue_free()

	var hud = scene.get_node_or_null("HUD")
	if hud:
		scene.remove_child(hud)
		hud.queue_free()

	var cam = scene.get_node_or_null("FlightCamera") as Camera3D
	if not cam:
		cam = Camera3D.new()
		scene.add_child(cam)
	else:
		cam.set_script(null)
	cam.current = true
	cam.fov = 70.0
	cam.far = 4000.0

	var terrain = scene.get_node_or_null("NaturalLandscape")

	for f in range(25):
		await process_frame

	var shots = [
		["valley_nest_framing", Vector3(155.0, 20.0, 120.0), Vector3(300.0, 24.5, 120.0)],
		["distinct_separated_trees", Vector3(125.0, 20.0, 85.0), Vector3(175.0, 22.0, 130.0)],
		["hill_behind_nest", Vector3(365.0, 26.5, 120.0), Vector3(450.0, 28.5, 120.0)],
		["rolling_hills_overview", Vector3(450.0, 48.0, 330.0), Vector3(240.0, 18.0, 60.0)]
	]

	for data in shots:
		var shot_name: String = data[0]
		var eye: Vector3 = data[1]
		var tgt: Vector3 = data[2]
		if terrain:
			var gh: float = terrain.ground_height(eye.x, eye.z)
			eye.y = maxf(eye.y, gh + 3.2)
		cam.position = eye
		cam.look_at(tgt, Vector3.UP)
		for f in range(16):
			await process_frame
		var img = root.get_texture().get_image()
		var out_path = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/9da9056d-a8f0-4a23-8cbd-e7dac712a5ce/nature_%s.png" % shot_name
		if img:
			img.save_png(out_path)
			print("CAPTURED: ", out_path)

	print("ALL_CAPTURES_SUCCESSFUL")
	quit(0)
