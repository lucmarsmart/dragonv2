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
	
	# Sample Qishilong_down at t=0.0 and t=26.5
	ap.play("Qishilong_down")
	for sample_t in [0.0, 10.0, 26.5, 27.5]:
		ap.seek(sample_t, true)
		for f in range(2): await process_frame
		
		var p_world = skel.global_transform * skel.get_bone_global_pose(b_pelvis).origin
		cam.position = p_world + Vector3(0, 5.0, 25.0)
		cam.look_at_from_position(cam.position, p_world, Vector3.UP)
		for f in range(2): await process_frame
		
		var fname = "c:/Proyectos/Dragon v2/raw_down_t%.1f.png" % sample_t
		root.get_viewport().get_texture().get_image().save_png(fname)
		print("Saved %s" % fname)
		
	quit(0)
