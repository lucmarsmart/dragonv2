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
	env.background_color = Color(0.6, 0.7, 0.8)
	env_node.environment = env
	root_node.add_child(env_node)
	
	var raw_scene = load("res://assets/models/dragon.glb").instantiate()
	root_node.add_child(raw_scene)
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
	cam.far = 1000.0
	
	var b_pelvis = skel.find_bone("Bip001_03")
	
	# Test: t=45.3s in Qishilong_fly2 (Glide candidate)
	ap.play("Qishilong_fly2")
	ap.seek(45.3, true)
	for f in range(2): await process_frame
	
	var p_world = skel.global_transform * skel.get_bone_global_pose(b_pelvis).origin
	cam.position = p_world + Vector3(0, 4.0, 18.0)
	cam.look_at_from_position(cam.position, p_world + Vector3(0, 0, -10.0), Vector3.UP)
	for f in range(2): await process_frame
	
	root.get_viewport().get_texture().get_image().save_png("test_glide_45_3.png")
	print("Saved test_glide_45_3.png")
	
	# Also test Turn Left at 127.8s
	ap.play("Qishilong_turnleft")
	ap.seek(127.8, true)
	for f in range(2): await process_frame
	p_world = skel.global_transform * skel.get_bone_global_pose(b_pelvis).origin
	cam.position = p_world + Vector3(0, 4.0, 18.0)
	cam.look_at_from_position(cam.position, p_world + Vector3(0, 0, -10.0), Vector3.UP)
	for f in range(2): await process_frame
	root.get_viewport().get_texture().get_image().save_png("test_turnleft_127_8.png")
	print("Saved test_turnleft_127_8.png")
	
	quit(0)
