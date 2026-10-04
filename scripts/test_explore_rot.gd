@tool
extends SceneTree

func _init():
	var root_node = Node3D.new()
	root.add_child(root_node)
	
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	root_node.add_child(light)
	
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.35, 0.55, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.7)
	env_node.environment = env
	root_node.add_child(env_node)
	
	var dragon_body = Node3D.new()
	root_node.add_child(dragon_body)
	
	var visual_root = Node3D.new()
	dragon_body.add_child(visual_root)
	
	var raw_scene = load("res://assets/models/dragon.glb").instantiate()
	visual_root.add_child(raw_scene)
	
	var ap: AnimationPlayer = null
	var skel: Skeleton3D = null
	var q = [raw_scene]
	while q.size() > 0:
		var c = q.pop_front()
		if c is AnimationPlayer: ap = c
		if c is Skeleton3D: skel = c
		for ch in c.get_children(): q.append(ch)
		
	var cam = Camera3D.new()
	root_node.add_child(cam)
	cam.current = true
	cam.far = 2000.0
	
	# Camera straight behind dragon at distance 16, height 5
	cam.position = Vector3(0, 5.0, 16.0)
	cam.look_at_from_position(cam.position, Vector3(0, 2.0, -10.0), Vector3.UP)
	
	ap.play("Qishilong_fly2")
	var b_pelvis = skel.find_bone("Bip001_03")
	var b_head = skel.find_bone("Bip001-Head_011")
	var b_tail = skel.find_bone("Bone008_0154")
	
	# Test yaw from -60 to -120 in 5 deg steps
	var test_yaws = [-60.0, -65.0, -70.0, -75.0, -80.0, -85.0, -90.0, -95.0, -100.0, -105.0, -110.0, -115.0, -120.0]
	
	for idx in range(test_yaws.size()):
		var yaw = test_yaws[idx]
		visual_root.rotation_degrees = Vector3(0, yaw, 0)
		visual_root.position = Vector3.ZERO
		ap.seek(34.0, true)
		for f in range(2): await process_frame
		
		# Center pelvis at dragon_body
		var pelvis_world = skel.global_transform * skel.get_bone_global_pose(b_pelvis).origin
		visual_root.global_position += (dragon_body.global_position - pelvis_world)
		for f in range(2): await process_frame
		
		var head_world = skel.global_transform * skel.get_bone_global_pose(b_head).origin
		var tail_world = skel.global_transform * skel.get_bone_global_pose(b_tail).origin
		
		var head_x = head_world.x - dragon_body.global_position.x
		var tail_x = tail_world.x - dragon_body.global_position.x
		
		var img_path = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/b0204162-bebf-4cb6-b7d8-eda9ec5ebf28/yaw_fine_%d.png" % idx
		root.get_viewport().get_texture().get_image().save_png(img_path)
		print("Yaw %.1f deg (#%d) -> Head X=%.3f, Tail X=%.3f" % [yaw, idx, head_x, tail_x])
		
	quit(0)
