extends SceneTree

func _init():
	var root_node = Node3D.new()
	root.add_child(root_node)
	
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 45, 0)
	light.light_energy = 1.3
	root_node.add_child(light)
	
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.22, 0.25)
	env_node.environment = env
	root_node.add_child(env_node)
	
	var dragon_scene = load("res://assets/models/dragon.glb").instantiate()
	root_node.add_child(dragon_scene)
	
	var mat_script = load("res://scripts/dragon_surface_materials.gd").new()
	dragon_scene.add_child(mat_script)
	mat_script.apply_materials(dragon_scene)
	
	var skel: Skeleton3D = null
	for c in dragon_scene.find_children("*", "Skeleton3D", true, false):
		skel = c
		break
		
	var b_head = skel.find_bone("Bip001-Head_011")
	var head_pos = skel.global_transform * skel.get_bone_global_pose(b_head).origin
	print("Head pos: ", head_pos)
	
	var cam = Camera3D.new()
	root_node.add_child(cam)
	cam.current = true
	cam.fov = 30.0
	
	for f in range(5): await process_frame
	
	# Lateral side view of the head
	cam.position = head_pos + Vector3(2.5, 0.2, 0.8)
	cam.look_at(head_pos, Vector3.UP)
	for f in range(3): await process_frame
	root.get_viewport().get_texture().get_image().save_png("c:/Proyectos/Dragon v2/head_side.png")
	print("Saved head_side.png")
	
	# Front three-quarter view of the head
	cam.position = head_pos + Vector3(1.8, 0.6, 2.2)
	cam.look_at(head_pos + Vector3(0, 0, 0.5), Vector3.UP)
	for f in range(3): await process_frame
	root.get_viewport().get_texture().get_image().save_png("c:/Proyectos/Dragon v2/head_three_quarter.png")
	print("Saved head_three_quarter.png")
	
	quit(0)
