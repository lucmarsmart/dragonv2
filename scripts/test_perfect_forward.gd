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
	
	# Camera behind the dragon: distance 20m, height 5m, looking forward into -Z
	cam.position = Vector3(0, 5.0, 20.0)
	cam.look_at_from_position(cam.position, Vector3(0, 0, -10.0), Vector3.UP)
	
	# Take the 1.50s wing flap cycle from 34.0 to 35.5 in Qishilong_fly2
	var src_anim = ap.get_animation("Qishilong_fly2")
	var new_anim = Animation.new()
	var loop_len = 1.50
	new_anim.length = loop_len
	new_anim.loop_mode = Animation.LOOP_LINEAR
	
	var rest_pelvis_pos = Vector3(32.7745, 356.433, 549.343)
	# At t=31.5 (straight ahead, level flight), pelvis rotation is:
	var straight_pelvis_rot = Quaternion(0.504518, 0.50452, -0.495438, 0.495442)
	
	# Pelvis rotation track in source
	var pelvis_rot_track = -1
	for t in range(src_anim.get_track_count()):
		var p = str(src_anim.track_get_path(t))
		if "Bip001_03" in p and src_anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			pelvis_rot_track = t
			break
			
	# Get the baseline pelvis rotation at t=34.0
	var base_pelvis_rot_at_34 = src_anim.rotation_track_interpolate(pelvis_rot_track, 34.0)
	
	for t in range(src_anim.get_track_count()):
		var track_type = src_anim.track_get_type(t)
		var track_path = str(src_anim.track_get_path(t))
		var is_pelvis = "Bip001_03" in track_path
		
		var new_t = new_anim.add_track(track_type)
		new_anim.track_set_path(new_t, NodePath(track_path))
		new_anim.track_set_interpolation_type(new_t, Animation.INTERPOLATION_CUBIC)
		
		if is_pelvis and track_type == Animation.TYPE_POSITION_3D:
			new_anim.track_insert_key(new_t, 0.0, rest_pelvis_pos)
			new_anim.track_insert_key(new_t, loop_len, rest_pelvis_pos)
		elif is_pelvis and track_type == Animation.TYPE_ROTATION_3D:
			# For pelvis rotation: keep the local pitch and roll bobbing of the wing flaps,
			# but relative to the straight_pelvis_rot (facing straight forward)!
			var first_val = null
			for k in range(src_anim.track_get_key_count(t)):
				var kt = src_anim.track_get_key_time(t, k)
				if kt >= 34.0 - 0.01 and kt <= 35.5 + 0.01:
					var cur_rot = src_anim.track_get_key_value(t, k) as Quaternion
					# Delta rotation relative to 34.0:
					var delta_q = cur_rot * base_pelvis_rot_at_34.inverse()
					# Apply delta to straight forward pelvis orientation:
					var val = delta_q * straight_pelvis_rot
					var new_time = clamp(kt - 34.0, 0.0, loop_len)
					if first_val == null: first_val = val
					
					if new_time > loop_len - 0.15 and first_val != null:
						var blend_factor = (new_time - (loop_len - 0.15)) / 0.15
						val = val.slerp(first_val, blend_factor)
					new_anim.track_insert_key(new_t, new_time, val)
			if first_val != null and new_anim.track_get_key_count(new_t) > 1:
				new_anim.track_insert_key(new_t, loop_len, first_val)
		else:
			# All other body bones (wings, legs, tail, head, spine) keep their full original animation!
			var first_val = null
			for k in range(src_anim.track_get_key_count(t)):
				var kt = src_anim.track_get_key_time(t, k)
				if kt >= 34.0 - 0.01 and kt <= 35.5 + 0.01:
					var val = src_anim.track_get_key_value(t, k)
					var new_time = clamp(kt - 34.0, 0.0, loop_len)
					if first_val == null: first_val = val
					
					if new_time > loop_len - 0.15 and first_val != null:
						var blend_factor = (new_time - (loop_len - 0.15)) / 0.15
						if track_type == Animation.TYPE_ROTATION_3D:
							val = (val as Quaternion).slerp(first_val as Quaternion, blend_factor)
						elif track_type == Animation.TYPE_POSITION_3D:
							val = (val as Vector3).lerp(first_val as Vector3, blend_factor)
							
					new_anim.track_insert_key(new_t, new_time, val)
			if first_val != null and new_anim.track_get_key_count(new_t) > 1:
				new_anim.track_insert_key(new_t, loop_len, first_val)
				
	var lib = ap.get_animation_library("")
	lib.add_animation("fly_perfect_forward", new_anim)
	ap.play("fly_perfect_forward")
	
	# Sample frames across the flap cycle
	var sample_times = [0.0, 0.35, 0.75, 1.15, 1.49]
	for idx in range(sample_times.size()):
		var time = sample_times[idx]
		ap.seek(time, true)
		for f in range(2): await process_frame
		
		var img_path = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/b0204162-bebf-4cb6-b7d8-eda9ec5ebf28/perfect_forward_%d.png" % idx
		root.get_viewport().get_texture().get_image().save_png(img_path)
		print("Saved perfect_forward_%d at t=%.2f" % [idx, time])
		
	quit(0)
