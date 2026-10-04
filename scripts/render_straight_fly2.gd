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
	
	var sample_times = [44.0, 44.5, 45.0, 45.5, 46.0]
	for idx in range(sample_times.size()):
		var t = sample_times[idx]
		ap.seek(t, true)
		for f in range(2): await process_frame
		
		var pelvis_world = skel.global_transform * skel.get_bone_global_pose(b_pelvis).origin
		print("t=%.2f: pelvis_world=%s" % [t, pelvis_world])
		
		# Place camera behind the pelvis
		cam.position = pelvis_world + Vector3(0, 5.0, 24.0)
		cam.look_at_from_position(cam.position, pelvis_world + Vector3(0, 0, -10.0), Vector3.UP)
		for f in range(2): await process_frame
		
		var img_path = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/b0204162-bebf-4cb6-b7d8-eda9ec5ebf28/fly2_straight_%d.png" % idx
		root.get_viewport().get_texture().get_image().save_png(img_path)
		print("Saved fly2_straight_%d at t=%.2f" % [idx, t])
		
	quit(0)
