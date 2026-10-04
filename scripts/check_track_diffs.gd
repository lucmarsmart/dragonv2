@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for f in range(15): await process_frame
	
	var dragon = scene.get_node("Dragon")
	var skel = dragon.skeleton
	var ap = dragon.anim_player
	
	# Let's inspect the tracks of Qishilong_fly2 in anim_player
	var anim = ap.get_animation("Qishilong_fly2")
	print("Track count: ", anim.get_track_count(), " Length: ", anim.length)
	
	# For each track, measure difference between value at t=2.70 and t=0.00, and t=2.99 and t=0.00
	var max_diff = 0.0
	var sum_diff = 0.0
	var count = 0
	for t in range(anim.get_track_count()):
		if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			var q0 = anim.rotation_track_interpolate(t, 0.0)
			var q_end = anim.rotation_track_interpolate(t, 2.75) # before the 0.20s slerp!
			var diff = rad_to_deg(q0.angle_to(q_end))
			if diff > max_diff:
				max_diff = diff
			sum_diff += diff
			count += 1
			if diff > 25.0:
				print("Track %s diff at 2.75s: %.2f deg" % [anim.track_get_path(t), diff])
				
	print("At t=2.75s before slerp: Mean rot diff=%.2f deg, Max rot diff=%.2f deg" % [sum_diff / count, max_diff])
	quit(0)
