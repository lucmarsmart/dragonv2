extends SceneTree

var world: Node3D
var camera: Camera3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	world = Node3D.new()
	root.add_child(world)
	
	var env_node = WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	env_node.environment = Environment.new()
	env_node.environment.background_mode = Environment.BG_SKY
	world.add_child(env_node)
	
	var sun = DirectionalLight3D.new()
	sun.name = "DirectionalLight3D"
	sun.rotation = Vector3(-0.7, 0.8, 0.0)
	world.add_child(sun)
	
	var terrain = load("res://assets/models/terrain.glb").instantiate()
	terrain.set_script(load("res://scripts/terrain.gd"))
	world.add_child(terrain)
	
	var siege = load("res://scripts/siege_environment.gd").new()
	world.add_child(siege)
	
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.far = 5000.0
	world.add_child(camera)
	camera.current = true

	var shots = [
		["valley_nest_framed", Vector3(160.0, terrain.ground_height(160.0, 120.0) + 4.0, 120.0), Vector3(300.0, terrain.ground_height(300.0, 120.0) + 3.0, 120.0)],
		["distinct_separated_trees", Vector3(130.0, terrain.ground_height(130.0, 100.0) + 3.5, 100.0), Vector3(175.0, terrain.ground_height(175.0, 140.0) + 6.0, 140.0)],
		["gentle_rolling_hills", Vector3(-120.0, terrain.ground_height(-120.0, 100.0) + 12.0, 100.0), Vector3(0.0, terrain.ground_height(0.0, 0.0) + 5.0, 0.0)],
		["hill_behind_nest", Vector3(385.0, 38.0, 160.0), Vector3(440.0, 28.0, 120.0)]
	]

	for data in shots:
		var shot_name: String = data[0]
		var eye: Vector3 = data[1]
		var tgt: Vector3 = data[2]
		var gh: float = terrain.ground_height(eye.x, eye.z)
		eye.y = maxf(eye.y, gh + 2.5)
		camera.position = eye
		camera.look_at(tgt, Vector3.UP)
		terrain._update_forest_lods()
		for i in 12:
			await process_frame
		var img = root.get_texture().get_image()
		var out_path = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/9da9056d-a8f0-4a23-8cbd-e7dac712a5ce/nature_%s.png" % shot_name
		if img:
			img.save_png(out_path)
			print("NATURE_CAPTURE_SAVED: ", out_path)

	print("ALL_NATURE_CAPTURES_COMPLETED")
	quit(0)
