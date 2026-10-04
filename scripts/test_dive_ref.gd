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
	var b_pel = dragon.bone_pelvis
	var b_tail = dragon.bone_tail_indices[dragon.bone_tail_indices.size() - 1]
	
	dragon.has_taken_off = true
	dragon.toggle_dive()
	ap.play("Qishilong_down")
	
	var anim_down = ap.get_animation("Qishilong_down")
	var t = 0.0
	var max_err_tail = 0.0
	var max_err_pel = 0.0
	while t <= anim_down.length:
		ap.seek(t, true)
		for f in range(2): await process_frame
		dragon._process(0.016)
		
		var p_h = skel.global_transform * skel.get_bone_global_pose(b_head).origin
		var p_t = skel.global_transform * skel.get_bone_global_pose(b_tail).origin
		var p_p = skel.global_transform * skel.get_bone_global_pose(b_pel).origin
		var char_fwd = -dragon.global_transform.basis.z.normalized()
		
		var fwd_t = (p_h - p_t).normalized()
		var err_t = abs(rad_to_deg(wrapf(atan2(fwd_t.x, -fwd_t.z) - atan2(char_fwd.x, -char_fwd.z), -PI, PI)))
		max_err_tail = max(max_err_tail, err_t)
		
		var fwd_p = (p_h - p_p).normalized()
		var err_p = abs(rad_to_deg(wrapf(atan2(fwd_p.x, -fwd_p.z) - atan2(char_fwd.x, -char_fwd.z), -PI, PI)))
		max_err_pel = max(max_err_pel, err_p)
		
		t += 0.05
		
	print("Max err using head-tail: %.2f deg | Max err using head-pelvis: %.2f deg" % [max_err_tail, max_err_pel])
	quit(0)
