@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for f in range(5): await process_frame
	
	var dragon = scene.get_node("Dragon")
	var ap = dragon.anim_player
	var anim_down = ap.get_animation("Qishilong_down")
	print("Qishilong_down length: ", anim_down.length)
	
	dragon.has_taken_off = true
	ap.play("Qishilong_down")
	
	var skel = dragon.skeleton
	var b_head = dragon.bone_head_idx
	var b_tail = dragon.bone_tail_indices[dragon.bone_tail_indices.size() - 1]
	
	var times = [0.0, 0.5, 1.0, 1.5, anim_down.length - 0.05, anim_down.length]
	for t in times:
		ap.seek(t, true)
		var p_h = skel.global_transform * skel.get_bone_global_pose(b_head).origin
		var p_t = skel.global_transform * skel.get_bone_global_pose(b_tail).origin
		var fwd = (p_h - p_t).normalized()
		var char_fwd = -dragon.global_transform.basis.z.normalized()
		var yaw_err = rad_to_deg(wrapf(atan2(fwd.x, -fwd.z) - atan2(char_fwd.x, -char_fwd.z), -PI, PI))
		print("Down t=%.2f | Yaw err=%+.2f deg" % [t, yaw_err])
	quit(0)
