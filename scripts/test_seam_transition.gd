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
	var b_spine = dragon.bone_spine_indices[dragon.bone_spine_indices.size() - 1]
	
	dragon.has_taken_off = true
	ap.play("Qishilong_fly2")
	
	print("--- TESTING SEAM TRANSITION WITH STABILIZER ---")
	# Simulate approaching seam: 2.80, 2.85, 2.90, 2.95, 0.00, 0.05, 0.10
	var test_times = [2.70, 2.80, 2.90, 2.98, 0.00, 0.05, 0.15, 0.30]
	var prev_head_pos = Vector3.ZERO
	var prev_fwd = Vector3.ZERO
	
	for t in test_times:
		ap.seek(t, true)
		dragon._process(0.016)
		
		# Measure body forward before compensation
		var p_h = skel.global_transform * skel.get_bone_global_pose(b_head).origin
		var p_t = skel.global_transform * skel.get_bone_global_pose(b_tail).origin
		var fwd_world = (p_h - p_t).normalized()
		var char_fwd = -dragon.global_transform.basis.z.normalized()
		var raw_yaw_err = wrapf(atan2(fwd_world.x, -fwd_world.z) - atan2(char_fwd.x, -char_fwd.z), -PI, PI)
		
		# Apply stabilizer
		dragon.visual_root.basis = Basis(Vector3.UP, raw_yaw_err) * dragon.visual_root.basis
		var anchor_world = dragon._body_core_world()
		var target_center = dragon.global_position + Vector3(0, -0.3, 0)
		dragon.visual_root.global_position += (target_center - anchor_world)
		
		# Measure after stabilizer
		p_h = skel.global_transform * skel.get_bone_global_pose(b_head).origin
		p_t = skel.global_transform * skel.get_bone_global_pose(b_tail).origin
		fwd_world = (p_h - p_t).normalized()
		var post_yaw_err = rad_to_deg(wrapf(atan2(fwd_world.x, -fwd_world.z) - atan2(char_fwd.x, -char_fwd.z), -PI, PI))
		
		var delta_head = (p_h - prev_head_pos).length() if prev_head_pos != Vector3.ZERO else 0.0
		var delta_angle = rad_to_deg(fwd_world.angle_to(prev_fwd)) if prev_fwd != Vector3.ZERO else 0.0
		prev_head_pos = p_h
		prev_fwd = fwd_world
		
		print("t=%.2f | post_yaw_err=%+.2f deg | head_pos=%s | d_head=%.3fm d_angle=%.2f deg" % [
			t, post_yaw_err, p_h - dragon.global_position, delta_head, delta_angle
		])
		
	quit(0)
