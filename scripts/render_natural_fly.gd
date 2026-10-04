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
	
	var raw_scene = load("res://assets/models/dragon.glb").instantiate()
	root_node.add_child(raw_scene)
	raw_scene.position = Vector3(0, 0, 0)
	raw_scene.rotation_degrees = Vector3(-38.0, -83.0, 0.0)
	
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
	
	# Extract loop [34.0, 35.5] from Qishilong_fly2
	var src_anim = ap.get_animation("Qishilong_fly2")
	var new_anim = Animation.new()
	new_anim.length = 1.50
	new_anim.loop_mode = Animation.LOOP_LINEAR
	
	var rest_pelvis_pos = Vector3(32.7745, 356.433, 549.343)
	
	for t in range(src_anim.get_track_count()):
		var track_type = src_anim.track_get_type(t)
		var track_path = str(src_anim.track_get_path(t))
		var is_pelvis = "Bip001_03" in track_path
		
		var new_t = new_anim.add_track(track_type)
		new_anim.track_set_path(new_t, NodePath(track_path))
		new_anim.track_set_interpolation_type(new_t, Animation.INTERPOLATION_CUBIC)
		
		if is_pelvis and track_type == Animation.TYPE_POSITION_3D:
			new_anim.track_insert_key(new_t, 0.0, rest_pelvis_pos)
			new_anim.track_insert_key(new_t, 1.50, rest_pelvis_pos)
		else:
			var first_val = null
			for k in range(src_anim.track_get_key_count(t)):
				var kt = src_anim.track_get_key_time(t, k)
				if kt >= 34.0 - 0.01 and kt <= 35.5 + 0.01:
					var val = src_anim.track_get_key_value(t, k)
					var new_time = clamp(kt - 34.0, 0.0, 1.50)
					if first_val == null: first_val = val
					
					if new_time > 1.35 and first_val != null:
						var blend_factor = (new_time - 1.35) / 0.15
						if track_type == Animation.TYPE_ROTATION_3D:
							val = (val as Quaternion).slerp(first_val as Quaternion, blend_factor)
						elif track_type == Animation.TYPE_POSITION_3D:
							val = (val as Vector3).lerp(first_val as Vector3, blend_factor)
							
					new_anim.track_insert_key(new_t, new_time, val)
					
			if first_val != null and new_anim.track_get_key_count(new_t) > 1:
				new_anim.track_insert_key(new_t, 1.50, first_val)
				
	var lib = ap.get_animation_library("")
	lib.add_animation("fly_natural_cycle", new_anim)
	ap.play("fly_natural_cycle")
	
	# Camera behind the dragon: distance 22m, height 4.5m
	cam.position = Vector3(0, 4.5, 22.0)
	cam.look_at_from_position(cam.position, Vector3(0, 0, -10.0), Vector3.UP)
	
	# Sample at 0.0s, 0.35s, 0.75s, 1.15s, 1.50s (full cycle)
	var times = [0.0, 0.35, 0.75, 1.15, 1.49]
	for idx in range(times.size()):
		var t = times[idx]
		ap.seek(t, true)
		for f in range(2): await process_frame
		
		var img_path = "C:/Users/Lucas Marsiglia/.gemini/antigravity/brain/b0204162-bebf-4cb6-b7d8-eda9ec5ebf28/natural_fly_%d.png" % idx
		root.get_viewport().get_texture().get_image().save_png(img_path)
		print("Saved natural_fly_%d at t=%.2f" % [idx, t])
		
	quit(0)
