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
	env.background_color = Color(0.5, 0.6, 0.7)
	env_node.environment = env
	root_node.add_child(env_node)
	
	var raw_scene = load("res://assets/models/dragon.glb").instantiate()
	root_node.add_child(raw_scene)
	raw_scene.position = Vector3(0, 0, 0)
	
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
	cam.position = Vector3(0, 4, 18)
	cam.look_at(Vector3(0, 1, 0), Vector3.UP)
	
	var clips = {
		"up": {"anim": "Qishilong_up", "range": Vector2(129.5, 131.0)},
		"turnleft": {"anim": "Qishilong_turnleft", "range": Vector2(127.433, 128.417)},
		"turnright": {"anim": "Qishilong_turnright", "range": Vector2(128.467, 129.458)},
		"down": {"anim": "Qishilong_down", "range": Vector2(26.1, 27.875)}
	}
	
	var b_pelvis = skel.find_bone("Bip001_03")
	
	for clip_name in clips:
		var info = clips[clip_name]
		ap.play(info["anim"])
		var start_t = info["range"].x
		var end_t = info["range"].y
		print("\n=== Clip: %s (anim %s from %.3f to %.3f, duration=%.3f) ===" % [
			clip_name, info["anim"], start_t, end_t, end_t - start_t
		])
		
		# Sample 5 frames across the clip
		for i in range(5):
			var t = lerp(start_t, end_t, float(i) / 4.0)
			ap.seek(t, true)
			for f in range(2): await process_frame
			
			var p_pos = skel.get_bone_global_pose(b_pelvis).origin
			var p_rot = skel.get_bone_global_pose(b_pelvis).basis.get_euler()
			print("  t=%.3f: pelvis_pos=%s, pelvis_euler_deg=%s" % [
				t, p_pos.snapped(Vector3(0.1, 0.1, 0.1)),
				Vector3(rad_to_deg(p_rot.x), rad_to_deg(p_rot.y), rad_to_deg(p_rot.z)).snapped(Vector3(0.1, 0.1, 0.1))
			])
			
	quit(0)
