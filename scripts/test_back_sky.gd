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
	dragon_body.position = Vector3(0, 0, 0)
	
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
	
	# Chase camera: 18m behind, 5m high
	cam.position = Vector3(0, 5.0, 18.0)
	cam.look_at_from_position(cam.position, Vector3(0, 0, -10.0), Vector3.UP)
	
	ap.play("Qishilong_fly2")
	var b_pelvis = skel.find_bone("Bip001_03")
	
	# Test roll variations: roll = 180, pitch = 180, etc.
	# Current was: yaw = 180, pitch = 0, roll = 0
	# What happens with roll = 180? (pitch=0, yaw=180, roll=180)
	# Or pitch = 180, yaw = 0?
	var test_rotations = [
		Vector3(0, 180, 180),   # Roll 180
		Vector3(180, 180, 0),   # Pitch 180
		Vector3(0, 0, 180),     # Yaw 0, Roll 180
		Vector3(180, 0, 0)      # Pitch 180, Yaw 0
	]
	
	for idx in range(test_rotations.size()):
		var rot = test_rotations[idx]
		visual_root.rotation_degrees = rot
		ap.seek(34.0, true)
		for f in range(2): await process_frame
		
		# Center pelvis
		var pelvis_world = skel.global_transform * skel.get_bone_global_pose(b_pelvis).origin
		visual_root.global_position += (dragon_body.global_position - pelvis_world)
		for f in range(2): await process_frame
		
		var img_path = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/b0204162-bebf-4cb6-b7d8-eda9ec5ebf28/test_back_sky_%d.png" % idx
		root.get_viewport().get_texture().get_image().save_png(img_path)
		print("Saved test_back_sky_%d with rot=%s" % [idx, rot])
		
	quit(0)
