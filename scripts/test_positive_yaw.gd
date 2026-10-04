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
	
	# Camera directly behind at (0, 6, 18) looking straight at (0, 0, -10)
	cam.position = Vector3(0, 6.0, 18.0)
	cam.look_at_from_position(cam.position, Vector3(0, 1.0, -10.0), Vector3.UP)
	
	ap.play("Qishilong_fly2")
	var b_pelvis = skel.find_bone("Bip001_03")
	var b_head = skel.find_bone("Bip001-Head_011")
	var b_tail = skel.find_bone("Bone008_0154")
	
	# Test yaw from 0 to 120 degrees
	var test_yaws = [0.0, 15.0, 30.0, 45.0, 60.0, 70.0, 75.0, 80.0, 85.0, 90.0, 105.0]
	
	for idx in range(test_yaws.size()):
		var yaw = test_yaws[idx]
		visual_root.rotation_degrees = Vector3(0, yaw, 0)
		visual_root.position = Vector3.ZERO
		ap.seek(34.0, true)
		for f in range(2): await process_frame
		
		# Center pelvis
		var pelvis_world = skel.global_transform * skel.get_bone_global_pose(b_pelvis).origin
		visual_root.global_position += (dragon_body.global_position - pelvis_world)
		for f in range(2): await process_frame
		
		var head_world = skel.global_transform * skel.get_bone_global_pose(b_head).origin
		var tail_world = skel.global_transform * skel.get_bone_global_pose(b_tail).origin
		
		var head_rel = head_world - dragon_body.global_position
		var tail_rel = tail_world - dragon_body.global_position
		
		var img_path = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/b0204162-bebf-4cb6-b7d8-eda9ec5ebf28/yaw_pos_%d.png" % idx
		root.get_viewport().get_texture().get_image().save_png(img_path)
		print("Yaw %.1f deg (#%d) -> Head: (X=%.2f, Z=%.2f), Tail: (X=%.2f, Z=%.2f)" % [yaw, idx, head_rel.x, head_rel.z, tail_rel.x, tail_rel.z])
		
	quit(0)
