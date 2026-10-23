@tool
extends SceneTree

func _init():
	var glb = load("res://assets/models/dragon.glb").instantiate()
	root.add_child(glb)
	for f in range(5): await process_frame
	
	var ap: AnimationPlayer = glb.find_child("*AnimationPlayer*", true, false)
	var sk: Skeleton3D = glb.find_child("*Skeleton3D*", true, false)
	var anim = ap.get_animation("Qishilong_fly2")
	
	var b_root96 = 96
	var b_tip108 = 108
	var b_root120 = 120
	var b_tip132 = 132
	
	var best_t = -1.0
	var best_err = 999999.0
	var candidates = []
	
	# Sample every 0.05 seconds
	var steps = int(anim.length / 0.05)
	for s in range(steps):
		var t = float(s) * 0.05
		ap.play("Qishilong_fly2")
		ap.seek(t, true)
		
		var p96 = sk.get_bone_global_pose(b_root96).origin
		var p120 = sk.get_bone_global_pose(b_root120).origin
		var p108 = sk.get_bone_global_pose(b_tip108).origin
		var p132 = sk.get_bone_global_pose(b_tip132).origin
		
		# In glb local space:
		# Z is lateral (left/right)
		# Y is forward/back
		# X is vertical
		var span = p108.distance_to(p132)
		if span < 3000.0: # require open wings
			continue
			
		var y_diff = abs(p108.y - p132.y)
		var x_diff = abs(p108.x - p132.x)
		var z_sym = abs((p108.z - p96.z) + (p132.z - p120.z)) # should be opposite
		
		var err = y_diff + x_diff + z_sym
		if err < 350.0:
			candidates.append({"t": t, "err": err, "span": span, "x_diff": x_diff, "y_diff": y_diff})
			if err < best_err:
				best_err = err
				best_t = t
				
	print("Found %d candidate symmetrical frames!" % candidates.size())
	candidates.sort_custom(func(a, b): return a.err < b.err)
	for i in range(min(10, candidates.size())):
		var c = candidates[i]
		print("  t=%.2fs: err=%.2f, span=%.2f, x_diff=%.2f, y_diff=%.2f" % [c.t, c.err, c.span, c.x_diff, c.y_diff])
	quit(0)
