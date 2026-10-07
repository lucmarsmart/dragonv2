@tool
extends SceneTree

func _init():
	var root_node = Node3D.new()
	root.add_child(root_node)
	
	# Iluminación cinematográfica natural (sol directo + luz ambiental de cielo)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 40, 0)
	sun.light_color = Color(1.0, 0.96, 0.90)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	root_node.add_child(sun)
	
	var rim_light = DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(130, -140, 0)
	rim_light.light_color = Color(0.65, 0.80, 1.0)
	rim_light.light_energy = 0.5
	root_node.add_child(rim_light)
	
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.35, 0.45, 0.55)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.40, 0.48, 0.56)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env_node.environment = env
	root_node.add_child(env_node)
	
	var dragon_model = load("res://assets/models/dragon.glb").instantiate()
	root_node.add_child(dragon_model)
	dragon_model.rotation_degrees = Vector3(0, 180, 0)
	
	# Aplicar el gestor de materiales con los shaders de relieve y SSS
	var skin_script = load("res://scripts/dragon_surface_materials.gd").new()
	dragon_model.add_child(skin_script)
	skin_script._ready()
	
	var ap: AnimationPlayer = null
	var skel: Skeleton3D = null
	var q = [dragon_model]
	while q.size() > 0:
		var c = q.pop_front()
		if c is AnimationPlayer: ap = c
		if c is Skeleton3D: skel = c
		for ch in c.get_children(): q.append(ch)
		
	var cam = Camera3D.new()
	root_node.add_child(cam)
	cam.current = true
	cam.far = 1000.0
	
	var b_pelvis = skel.find_bone("Bip001_03")
	var b_head = skel.find_bone("Bip001-Head_011")
	
	# -------------------------------------------------------------------------
	# TOMA 1: PRIMER PLANO DEL CUERPO Y RELIEVE DE ESCAMAS (LOMO Y CABEZA)
	# -------------------------------------------------------------------------
	ap.play("Qishilong_fly2")
	ap.seek(34.8, true) # Pose de planeo con alas extendidas
	for f in range(4): await process_frame
	
	var p_head = skel.global_transform * skel.get_bone_global_pose(b_head).origin
	var p_pelvis = skel.global_transform * skel.get_bone_global_pose(b_pelvis).origin
	var p_spine = (p_head + p_pelvis) * 0.5
	
	cam.position = p_spine + Vector3(2.5, 2.2, 5.0)
	cam.look_at_from_position(cam.position, p_spine + Vector3(0.0, 0.5, -0.5), Vector3.UP)
	for f in range(4): await process_frame
	
	root.get_viewport().get_texture().get_image().save_png("showcase_scales_relief.png")
	print("Guardado showcase_scales_relief.png")
	
	# -------------------------------------------------------------------------
	# TOMA 2: PRIMER PLANO DE LA CABEZA, FAUCES Y PLACAS VENTRALES
	# -------------------------------------------------------------------------
	cam.position = p_head + Vector3(1.8, 0.4, -2.8)
	cam.look_at_from_position(cam.position, p_head + Vector3(0.0, 0.1, 0.2), Vector3.UP)
	for f in range(4): await process_frame
	
	root.get_viewport().get_texture().get_image().save_png("showcase_head_detail.png")
	print("Guardado showcase_head_detail.png")
	
	# -------------------------------------------------------------------------
	# TOMA 3: ALAS TRANSLÚCIDAS CON RETROILUMINACIÓN (SSS)
	# -------------------------------------------------------------------------
	cam.position = p_pelvis + Vector3(-5.5, -0.8, 3.2)
	cam.look_at_from_position(cam.position, p_pelvis + Vector3(-3.0, 1.2, -1.0), Vector3.UP)
	for f in range(4): await process_frame
	
	root.get_viewport().get_texture().get_image().save_png("showcase_wings_sss.png")
	print("Guardado showcase_wings_sss.png")
	
	# -------------------------------------------------------------------------
	# TOMA 4: VISTA COMPLETA DEL DRAGÓN MAJESTUOSO EN VUELO
	# -------------------------------------------------------------------------
	cam.position = p_pelvis + Vector3(0.0, 4.0, 16.0)
	cam.look_at_from_position(cam.position, p_spine, Vector3.UP)
	for f in range(4): await process_frame
	
	root.get_viewport().get_texture().get_image().save_png("showcase_full_flight.png")
	print("Guardado showcase_full_flight.png")
	
	quit(0)
