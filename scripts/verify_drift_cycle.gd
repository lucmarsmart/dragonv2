@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for f in range(25): await process_frame
	
	var dragon = scene.get_node("Dragon")
	var skel = dragon.skeleton
	var ap = dragon.anim_player
	var b_head = dragon.bone_head_idx
	var b_tail = dragon.bone_tail_indices[dragon.bone_tail_indices.size() - 1]
	
	dragon.has_taken_off = true
	ap.play("Qishilong_fly2")
	
	print("--- VERIFYING COMPLETE CYCLE DRIFT ---")
	var t = 0.0
	var max_err = 0.0
	while t <= 3.00:
		ap.seek(t, true)
		for f in range(2): await process_frame
		dragon._process(0.016)
		
		var p_h = skel.global_transform * skel.get_bone_global_pose(b_head).origin
		var p_t = skel.global_transform * skel.get_bone_global_pose(b_tail).origin
		var fwd_world = (p_h - p_t).normalized()
		var char_fwd = -dragon.global_transform.basis.z.normalized()
		var angle_yaw = rad_to_deg(wrapf(atan2(fwd_world.x, -fwd_world.z) - atan2(char_fwd.x, -char_fwd.z), -PI, PI))
		max_err = max(max_err, abs(angle_yaw))
		if fmod(round(t * 100) / 100.0, 0.2) < 0.01:
			print("t=%.2f -> yaw drift = %+0.3f deg" % [t, angle_yaw])
		t += 0.05
		
	print("MAX ABSOLUTE YAW DRIFT OVER ENTIRE 3-SECOND CYCLE: %.3f deg" % max_err)
	quit(0)
