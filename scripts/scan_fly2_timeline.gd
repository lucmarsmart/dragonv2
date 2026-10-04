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
		
	var b_pelvis = skel.find_bone("Bip001_03")
	var b_head = skel.find_bone("Bip001-Head_011")
	var b_l_wing = skel.find_bone("Bip001-L-UpperArm_038")
	var b_r_wing = skel.find_bone("Bip001-R-UpperArm_053")
	
	print("--- SCANNING Qishilong_fly2 (0s to 68s) ---")
	ap.play("Qishilong_fly2")
	
	for s in range(0, 69, 2):
		var t = float(s)
		ap.seek(t, true)
		for f in range(2): await process_frame
		
		var p_world = skel.global_transform * skel.get_bone_global_pose(b_pelvis).origin
		var h_world = skel.global_transform * skel.get_bone_global_pose(b_head).origin
		var lw_world = skel.global_transform * skel.get_bone_global_pose(b_l_wing).origin
		var rw_world = skel.global_transform * skel.get_bone_global_pose(b_r_wing).origin
		
		var fwd = (h_world - p_world).normalized()
		var wing_height = (lw_world.y + rw_world.y) * 0.5 - p_world.y
		
		print("t=%4.1fs: SpineFwd=%s | Pitch=%5.1f° | WingH=%5.1f" % [
			t, fwd.snapped(Vector3(0.01,0.01,0.01)), rad_to_deg(asin(fwd.y)), wing_height
		])
		
	quit(0)
