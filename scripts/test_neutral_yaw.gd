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
	
	# Chase camera behind dragon
	cam.position = Vector3(0, 5.0, 22.0)
	cam.look_at_from_position(cam.position, Vector3(0, 0, 0), Vector3.UP)
	
	var b_pelvis = skel.find_bone("Bip001_03")
	var b_head = skel.find_bone("Bip001-Head_011")
	
	ap.play("Qishilong_fly2")
	
	# Sample at t = 34.0, 34.3, 34.6, 35.0
	var sample_times = [34.0, 34.3, 34.6, 35.0]
	for idx in range(sample_times.size()):
		var t = sample_times[idx]
		ap.seek(t, true)
		for f in range(2): await process_frame
		
		# Lock pelvis position to rest pose in local space
		var rest_pelvis_pos = Vector3(32.7745, 356.433, 549.343)
		skel.set_bone_pose_position(b_pelvis, rest_pelvis_pos)
		
		# What is the spine direction now?
		var p_world = skel.global_transform * skel.get_bone_global_pose(b_pelvis).origin
		var h_world = skel.global_transform * skel.get_bone_global_pose(b_head).origin
		var spine_world = (h_world - p_world).normalized()
		var spine_yaw = atan2(spine_world.x, -spine_world.z)
		print("t=%.2f: spine_world=%s, yaw=%.1f deg" % [t, spine_world, rad_to_deg(spine_yaw)])
		
		# If we rotate the pelvis by -spine_yaw around UP:
		var cur_pelvis_rot = skel.get_bone_pose_rotation(b_pelvis)
		# UP in skeleton space:
		var skel_up = (skel.global_transform.basis.inverse() * Vector3.UP).normalized()
		var corr_rot = Quaternion(skel_up, -spine_yaw)
		skel.set_bone_pose_rotation(b_pelvis, corr_rot * cur_pelvis_rot)
		for f in range(2): await process_frame
		
		var p_after = skel.global_transform * skel.get_bone_global_pose(b_pelvis).origin
		var h_after = skel.global_transform * skel.get_bone_global_pose(b_head).origin
		var spine_after = (h_after - p_after).normalized()
		print("After yaw alignment: spine_world=%s" % [spine_after])
		
		var img_path = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/b0204162-bebf-4cb6-b7d8-eda9ec5ebf28/neutral_fly2_%d.png" % idx
		root.get_viewport().get_texture().get_image().save_png(img_path)
		print("Saved neutral_fly2_%d" % idx)
		
	quit(0)
