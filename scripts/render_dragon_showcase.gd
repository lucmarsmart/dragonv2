extends SceneTree

func _init():
	var root_node = Node3D.new()
	root.add_child(root_node)
	
	# Directional sun from front-top-right
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 50, 0)
	light.light_energy = 1.35
	light.shadow_enabled = true
	root_node.add_child(light)
	
	# Sky & Environment
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.22, 0.25, 0.28)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.40, 0.42, 0.46)
	env_node.environment = env
	root_node.add_child(env_node)
	
	# Instantiate dragon
	var dragon_scene = load("res://assets/models/dragon.glb").instantiate()
	root_node.add_child(dragon_scene)
	
	# Attach and apply surface materials
	var mat_script = load("res://scripts/dragon_surface_materials.gd").new()
	dragon_scene.add_child(mat_script)
	mat_script.apply_materials(dragon_scene)
	
	var ap: AnimationPlayer = null
	var skel: Skeleton3D = null
	var q = [dragon_scene]
	while q.size() > 0:
		var c = q.pop_front()
		if c is AnimationPlayer: ap = c
		if c is Skeleton3D: skel = c
		for ch in c.get_children(): q.append(ch)
	
	# Look for animation
	if ap and ap.has_animation("Qishilong_fly2"):
		ap.play("Qishilong_fly2")
		ap.seek(0.5, true)
	
	var cam = Camera3D.new()
	root_node.add_child(cam)
	cam.current = true
	cam.fov = 42.0
	
	for f in range(6): await process_frame
	
	# 1. Close-up of dorsal scales and osteoderms
	cam.position = Vector3(1.2, 2.8, 3.8)
	cam.look_at(Vector3(0.0, 1.8, 0.8), Vector3.UP)
	for f in range(4): await process_frame
	root.get_viewport().get_texture().get_image().save_png("c:/Proyectos/Dragon v2/showcase_scales_v2.png")
	print("Saved showcase_scales_v2.png")
	
	# 2. Ventral throat, gular plates and head
	cam.position = Vector3(1.8, 1.4, 2.8)
	cam.look_at(Vector3(0.2, 2.0, 1.2), Vector3.UP)
	for f in range(4): await process_frame
	root.get_viewport().get_texture().get_image().save_png("c:/Proyectos/Dragon v2/showcase_throat_v2.png")
	print("Saved showcase_throat_v2.png")
	
	# 3. Wings with backlight SSS and vascular veins
	light.rotation_degrees = Vector3(15, -130, 0) # Sol detrás de las alas
	cam.position = Vector3(-4.0, 3.2, 4.2)
	cam.look_at(Vector3(-2.2, 2.4, 0.2), Vector3.UP)
	for f in range(4): await process_frame
	root.get_viewport().get_texture().get_image().save_png("c:/Proyectos/Dragon v2/showcase_wings_v2.png")
	print("Saved showcase_wings_v2.png")
	
	# 4. Heroic full body profile
	light.rotation_degrees = Vector3(-35, 40, 0)
	cam.position = Vector3(7.2, 3.2, 8.0)
	cam.look_at(Vector3(0.0, 1.4, 0.0), Vector3.UP)
	for f in range(4): await process_frame
	root.get_viewport().get_texture().get_image().save_png("c:/Proyectos/Dragon v2/showcase_heroic_v2.png")
	print("Saved showcase_heroic_v2.png")
	
	quit(0)
