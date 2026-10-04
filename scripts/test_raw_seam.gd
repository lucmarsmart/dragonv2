@tool
extends SceneTree

func _init():
	var raw_scene = load("res://assets/models/dragon.glb").instantiate()
	root.add_child(raw_scene)
	for f in range(5): await process_frame
	
	var ap: AnimationPlayer = null
	var sk: Skeleton3D = null
	var q = [raw_scene]
	while q.size() > 0:
		var c = q.pop_front()
		if c is AnimationPlayer: ap = c
		if c is Skeleton3D: sk = c
		for ch in c.get_children(): q.append(ch)
		
	var anim_src = ap.get_animation("Qishilong_fly2")
	var b_head = sk.find_bone("Bip001-Head_011")
	var b_tail = sk.find_bone("Bone008_0154")
	var tl = sk.find_bone("Bip001-L-Thigh_0115")
	var tr = sk.find_bone("Bip001-R-Thigh_0130")
	var sp = sk.find_bone("Bip001-Spine2_07")
	
	# Sample directly from anim_src at 33.60 and 36.60
	ap.play("Qishilong_fly2")
	ap.pause()
	
	# Evaluate at 36.60 and 33.60
	ap.seek(36.60, true)
	await process_frame; await process_frame
	var p_h_end = sk.get_bone_global_pose(b_head).origin
	var p_t_end = sk.get_bone_global_pose(b_tail).origin
	var fwd_end = (p_h_end - p_t_end).normalized()
	var yaw_end = atan2(fwd_end.x, -fwd_end.z)
	var core_end = (sk.get_bone_global_pose(tl).origin + sk.get_bone_global_pose(tr).origin + sk.get_bone_global_pose(sp).origin) / 3.0
	
	ap.seek(33.60, true)
	await process_frame; await process_frame
	var p_h_start = sk.get_bone_global_pose(b_head).origin
	var p_t_start = sk.get_bone_global_pose(b_tail).origin
	var fwd_start = (p_h_start - p_t_start).normalized()
	var yaw_start = atan2(fwd_start.x, -fwd_start.z)
	var core_start = (sk.get_bone_global_pose(tl).origin + sk.get_bone_global_pose(tr).origin + sk.get_bone_global_pose(sp).origin) / 3.0
	
	print("RAW SEAM EVALUATION (36.60s vs 33.60s):")
	print("Yaw end: %.2f deg | Yaw start: %.2f deg | Diff: %.2f deg" % [
		rad_to_deg(yaw_end), rad_to_deg(yaw_start), rad_to_deg(yaw_end - yaw_start)
	])
	
	# When yaw is compensated:
	# End pose is rotated by -yaw_end around Y, start pose by -yaw_start around Y
	var rot_end = Transform3D(Basis(Vector3.UP, -yaw_end), -core_end)
	var rot_start = Transform3D(Basis(Vector3.UP, -yaw_start), -core_start)
	
	var head_end_comp = Basis(Vector3.UP, -yaw_end) * (p_h_end - core_end)
	var head_start_comp = Basis(Vector3.UP, -yaw_start) * (p_h_start - core_start)
	
	print("Compensated head pos end: ", head_end_comp)
	print("Compensated head pos start: ", head_start_comp)
	print("Compensated head dist: %.2f units" % (head_end_comp - head_start_comp).length())
	
	quit(0)
