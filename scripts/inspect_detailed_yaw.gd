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
	
	var dt = 0.05
	var t = 0.0
	print("--- DETAILED YAW PROFILE ACROSS CYCLE ---")
	while t <= 3.01:
		ap.seek(t, true)
		dragon._process(dt)
		var p_h = skel.global_transform * skel.get_bone_global_pose(b_head).origin
		var p_t = skel.global_transform * skel.get_bone_global_pose(b_tail).origin
		var fwd = (p_h - p_t).normalized()
		var char_fwd = -dragon.global_transform.basis.z.normalized()
		var yaw_deg = rad_to_deg(wrapf(atan2(fwd.x, -fwd.z) - atan2(char_fwd.x, -char_fwd.z), -PI, PI))
		print("t=%0.2f -> yaw=%+6.2f deg" % [t, yaw_deg])
		t += dt
	quit(0)
