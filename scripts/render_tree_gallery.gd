@tool
extends SceneTree

func _init() -> void:
	print("Rendering Next-Gen Tree Bark & Form Gallery...")
	
	var root_node = Node3D.new()
	root.add_child(root_node)
	
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, -40, 0)
	sun.light_color = Color(1.0, 0.96, 0.91)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	root_node.add_child(sun)
	
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.75, 0.88)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.58, 0.64)
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env_node.environment = env
	root_node.add_child(env_node)
	
	var ground = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(100, 100)
	ground.mesh = plane_mesh
	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.24, 0.34, 0.20)
	ground_mat.roughness = 0.92
	ground.material_override = ground_mat
	root_node.add_child(ground)
	
	var species_list = [
		{"name": "oak", "x": -32.0},
		{"name": "eucalyptus", "x": -16.0},
		{"name": "birch", "x": 0.0},
		{"name": "pine", "x": 16.0},
		{"name": "fir", "x": 32.0}
	]
	
	for sp in species_list:
		var mesh_path = "res://assets/environment/trees/tree_%s_var1.res" % sp["name"]
		var mesh = load(mesh_path) as Mesh
		if mesh:
			var inst = MeshInstance3D.new()
			inst.name = sp["name"]
			inst.mesh = mesh
			inst.position = Vector3(sp["x"], 0, 0)
			root_node.add_child(inst)
			print("Placed tree ", sp["name"], " at x=", sp["x"])
			
	var cam = Camera3D.new()
	cam.position = Vector3(0, 12.0, 48.0)
	root_node.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 9.0, 0), Vector3.UP)
	cam.fov = 65.0
	cam.current = true
	
	for f in range(20):
		await process_frame
		
	var viewport = root.get_viewport()
	var img = viewport.get_texture().get_image()
	var out_dir = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/a53d2dc3-e34f-480b-b77b-efaadb2bef9c"
	if img:
		img.save_png("%s/nextgen_gallery_overview.png" % out_dir)
		print("Saved nextgen_gallery_overview.png")
		
	# High-detail Full Tree Shots (Bark + Canopy Architecture)
	var closeups = [
		{"name": "oak", "target": Vector3(-32.0, 7.0, 0), "cam_pos": Vector3(-32.0, 6.5, 14.0)},
		{"name": "eucalyptus", "target": Vector3(-16.0, 9.0, 0), "cam_pos": Vector3(-16.0, 8.5, 15.0)},
		{"name": "birch", "target": Vector3(0.0, 8.0, 0), "cam_pos": Vector3(0.0, 7.5, 13.0)},
		{"name": "pine", "target": Vector3(16.0, 8.0, 0), "cam_pos": Vector3(16.0, 7.5, 14.5)},
		{"name": "fir", "target": Vector3(32.0, 10.0, 0), "cam_pos": Vector3(32.0, 9.5, 17.5)}
	]
	
	for cu in closeups:
		cam.position = cu["cam_pos"]
		cam.look_at_from_position(cam.position, cu["target"], Vector3.UP)
		for f in range(6):
			await process_frame
		var cu_img = viewport.get_texture().get_image()
		if cu_img:
			var path = "%s/nextgen_bark_%s.png" % [out_dir, cu["name"]]
			cu_img.save_png(path)
			print("Saved %s" % path)
			
	quit(0)
