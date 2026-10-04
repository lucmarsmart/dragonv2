@tool
extends SceneTree

func _init():
	var raw_scene = load("res://assets/models/dragon.glb").instantiate()
	root.add_child(raw_scene)
	
	var ap: AnimationPlayer = null
	var skel: Skeleton3D = null
	var q = [raw_scene]
	while q.size() > 0:
		var c = q.pop_front()
		if c is AnimationPlayer: ap = c
		if c is Skeleton3D: skel = c
		for ch in c.get_children(): q.append(ch)
		
	var anim = ap.get_animation("Qishilong_fly2")
	var b_pelvis = skel.find_bone("Bip001_03")
	var b_head = skel.find_bone("Bip001-Head_011")
	var b_l_wing = skel.find_bone("Bip001-L-UpperArm_038")
	var b_r_wing = skel.find_bone("Bip001-R-UpperArm_053")
	
	print("--- SCANNING Qishilong_fly2 FROM 31.6s TO 68.2s ---")
	ap.play("Qishilong_fly2")
	
	var prev_pelvis = Vector3.ZERO
	for step in range(37):
		var t = 31.6 + step * 1.0
		if t > 68.208: break
		ap.seek(t, true)
		for f in range(2): await process_frame
		
		var p_pos = skel.get_bone_global_pose(b_pelvis).origin
		var h_pos = skel.get_bone_global_pose(b_head).origin
		var lw_pos = skel.get_bone_global_pose(b_l_wing).origin
		var rw_pos = skel.get_bone_global_pose(b_r_wing).origin
		var fwd = (h_pos - p_pos).normalized()
		var wing_vec = (rw_pos - lw_pos).normalized()
		var wing_span = (rw_pos - lw_pos).length()
		var wing_height = (lw_pos.y + rw_pos.y) * 0.5 - p_pos.y
		
		var delta_pos = p_pos - prev_pelvis if step > 0 else Vector3.ZERO
		prev_pelvis = p_pos
		
		print("t=%5.1fs: PelvisPos=%s | Delta=%s | SpineFwd=%s | WingH=%.1f" % [
			t, p_pos.snapped(Vector3(1, 1, 1)), delta_pos.snapped(Vector3(1, 1, 1)), fwd.snapped(Vector3(0.01, 0.01, 0.01)), wing_height
		])
		
	quit(0)
