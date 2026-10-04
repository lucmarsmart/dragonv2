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
	var b_head = skel.find_bone("Bip001-Head_011")
	var b_l_wing = skel.find_bone("Bip001-L-UpperArm_038")
	var b_r_wing = skel.find_bone("Bip001-R-UpperArm_053")
	
	print("--- SCANNING Qishilong_up (Length: %.2fs) ---" % ap.get_animation("Qishilong_up").length)
	ap.play("Qishilong_up")
	
	for s in range(0, 131, 5):
		var t = float(s)
		ap.seek(t, true)
		for f in range(2): await process_frame
		
		var p_world = skel.global_transform * skel.get_bone_global_pose(b_pelvis).origin
		var h_world = skel.global_transform * skel.get_bone_global_pose(b_head).origin
		var lw_world = skel.global_transform * skel.get_bone_global_pose(b_l_wing).origin
		var rw_world = skel.global_transform * skel.get_bone_global_pose(b_r_wing).origin
		
		var fwd = (h_world - p_world).normalized()
		var wing_span = (rw_world - lw_world).length()
		var wing_height = (lw_world.y + rw_world.y) * 0.5 - p_world.y
		
		print("t=%3.0fs: PelvisPos=%s | SpineFwd=%s | Pitch=%.1f deg | WingH=%.1f" % [
			t, p_world.snapped(Vector3(1,1,1)), fwd.snapped(Vector3(0.01,0.01,0.01)), rad_to_deg(asin(fwd.y)), wing_height
		])
		
	quit(0)
