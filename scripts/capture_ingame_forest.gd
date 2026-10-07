@tool
extends SceneTree

# Direct photographic capture of the game's actual botanical landscape
func _init() -> void:
	print("Loading actual game landscape & botanical forest...")
	var root_node = Node3D.new()
	root.add_child(root_node)
	
	# Match main.tscn environment & lighting exactly
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.54, 0.88)
	sky_mat.sky_horizon_color = Color(0.68, 0.76, 0.86)
	sky_mat.ground_bottom_color = Color(0.18, 0.22, 0.16)
	sky_mat.ground_horizon_color = Color(0.55, 0.65, 0.60)
	var sky = Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.65, 0.72, 0.80)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_node.environment = env
	root_node.add_child(env_node)
	
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_color = Color(1.0, 0.96, 0.90)
	sun.light_energy = 1.3
	sun.shadow_enabled = false # Shadows off on sun to avoid Intel HD 620 TDR
	root_node.add_child(sun)
	
	# Load the actual terrain model + script from main.tscn
	var terrain_scene = load("res://assets/models/terrain.glb") as PackedScene
	var terrain_node = terrain_scene.instantiate()
	var terrain_script = load("res://scripts/terrain.gd")
	terrain_node.set_script(terrain_script)
	root_node.add_child(terrain_node)
	
	print("NaturalLandscape added, waiting for forest generation...")
	for f in range(25):
		await process_frame
		
	var viewport = root.get_viewport()
	var out_dir = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/a53d2dc3-e34f-480b-b77b-efaadb2bef9c"
	
	var inspect_cam = Camera3D.new()
	inspect_cam.fov = 68.0
	inspect_cam.current = true
	root_node.add_child(inspect_cam)
	
	var views = [
		{
			"id": "birch_river_grove",
			"pos": Vector3(-40.0, 16.0, -120.0),
			"look_at": Vector3(-75.0, 10.0, -200.0),
			"desc": "Silver Birch grove along the river with luminous white trunks"
		},
		{
			"id": "ancient_oak_valley",
			"pos": Vector3(80.0, 32.0, 240.0),
			"look_at": Vector3(150.0, 16.0, 160.0),
			"desc": "Ancient Oak forest in the valley with sprawling mushroom crowns"
		},
		{
			"id": "stone_pine_ridge",
			"pos": Vector3(-180.0, 68.0, 180.0),
			"look_at": Vector3(-250.0, 52.0, 110.0),
			"desc": "Mediterranean Stone Pine forest on rocky ridges with umbrella canopies"
		},
		{
			"id": "panoramic_mixed_world",
			"pos": Vector3(120.0, 95.0, -50.0),
			"look_at": Vector3(-80.0, 30.0, -150.0),
			"desc": "Panoramic high flight showing diverse species coexisting across the valley"
		}
	]
	
	for v in views:
		inspect_cam.position = v["pos"]
		inspect_cam.look_at_from_position(v["pos"], v["look_at"], Vector3.UP)
		for f in range(8):
			await process_frame
			
		var img = viewport.get_texture().get_image()
		if img:
			var filename = "%s/ingame_%s.png" % [out_dir, v["id"]]
			img.save_png(filename)
			print("Saved %s (%s)" % [filename, v["desc"]])
			
	print("All in-game botanical captures completed successfully!")
	quit(0)
