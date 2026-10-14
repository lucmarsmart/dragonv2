@tool
extends SceneTree

func _init() -> void:
	var root_node = Node3D.new()
	root.add_child(root_node)

	var env = WorldEnvironment.new()
	var env_res = Environment.new()
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.54, 0.88)
	sky_mat.sky_horizon_color = Color(0.68, 0.76, 0.86)
	sky_mat.ground_bottom_color = Color(0.18, 0.22, 0.16)
	sky_mat.ground_horizon_color = Color(0.55, 0.65, 0.6)
	sky.sky_material = sky_mat
	env_res.background_mode = Environment.BG_SKY
	env_res.sky = sky
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env_res.ambient_light_sky_contribution = 0.6
	env_res.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = env_res
	root_node.add_child(env)

	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	light.light_color = Color(1.0, 0.96, 0.9)
	light.light_energy = 1.2
	light.shadow_enabled = false
	root_node.add_child(light)

	var terrain_script = load("res://scripts/terrain.gd")
	var terrain = Node3D.new()
	terrain.set_script(terrain_script)
	root_node.add_child(terrain)

	var fort_script = load("res://scripts/siege_environment.gd")
	var fort = Node3D.new()
	fort.set_script(fort_script)
	root_node.add_child(fort)

	var cam = Camera3D.new()
	cam.current = true
	cam.fov = 70.0
	cam.far = 4000.0
	root_node.add_child(cam)

	for f in range(25):
		await process_frame

	var shots = [
		["nature_valley_nest_framing", Vector3(300.0, 25.5, 230.0), Vector3(300.0, 24.5, 80.0)],
		["nature_distinct_separated_trees", Vector3(135.0, 22.0, 80.0), Vector3(205.0, 24.0, 120.0)],
		["nature_hill_behind_nest", Vector3(300.0, 25.5, 82.0), Vector3(300.0, 36.0, 0.0)],
		["nature_rolling_hills_overview", Vector3(440.0, 50.0, 320.0), Vector3(240.0, 20.0, 70.0)]
	]

	for data in shots:
		var shot_name: String = data[0]
		var eye: Vector3 = data[1]
		var tgt: Vector3 = data[2]
		var gh: float = terrain.ground_height(eye.x, eye.z)
		eye.y = maxf(eye.y, gh + 2.8)
		cam.position = eye
		cam.look_at(tgt, Vector3.UP)
		for f in range(8):
			await process_frame
		var img = root.get_texture().get_image()
		var out_path = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/9da9056d-a8f0-4a23-8cbd-e7dac712a5ce/%s.png" % shot_name
		if img:
			img.save_png(out_path)
			print("CAPTURED: ", out_path)

	print("ALL_VIEWS_CAPTURED_SUCCESSFULLY")
	quit()
