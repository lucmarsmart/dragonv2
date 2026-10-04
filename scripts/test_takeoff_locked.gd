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
	env.background_color = Color(0.4, 0.5, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.7)
	env_node.environment = env
	root_node.add_child(env_node)
	
	var raw_scene = load("res://assets/models/dragon.glb").instantiate()
	root_node.add_child(raw_scene)
	raw_scene.position = Vector3(0, 0, 0)
	# In the original simulator: rotation_degrees = Vector3(0, 180, 0)
	raw_scene.rotation_degrees = Vector3(0, 180, 0)
	
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
	
	ap.play("Qishilong_fly2")
	
	var b_pelvis = skel.find_bone("Bip001_03")
	var rest_pelvis_pos = Vector3(32.7745, 356.433, 549.343)
	
	# Camera behind origin
	cam.position = Vector3(0, 5.0, 22.0)
	cam.look_at_from_position(cam.position, Vector3(0, 0, -5.0), Vector3.UP)
	
	# Test takeoff at t = 31.5, 32.0, 32.3, 32.6, 33.0
	var test_times = [31.5, 32.0, 32.3, 32.6, 33.0]
	for idx in range(test_times.size()):
		var t = test_times[idx]
		ap.seek(t, true)
		for f in range(2): await process_frame
		
		# Lock pelvis position to rest pose so it doesn't translate away:
		skel.set_bone_pose_position(b_pelvis, rest_pelvis_pos)
		for f in range(2): await process_frame
		
		var img_path = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/b0204162-bebf-4cb6-b7d8-eda9ec5ebf28/takeoff_locked_%d.png" % idx
		root.get_viewport().get_texture().get_image().save_png(img_path)
		print("Saved takeoff_locked_%d at t=%.2f" % [idx, t])
		
	quit(0)
