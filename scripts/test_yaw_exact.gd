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
		
	ap.play("Qishilong_fly2")
	ap.seek(34.0, true)
	for f in range(2): await process_frame
	
	var b_pelvis = skel.find_bone("Bip001_03")
	var b_head = skel.find_bone("Bip001-Head_011")
	var b_spine2 = skel.find_bone("Bip001-Spine2_07")
	var b_tail = skel.find_bone("Bone008_0154")
	var b_rw = skel.find_bone("Bone017_068")
	var b_lw = skel.find_bone("Bone017(mirrored)_092")
	
	print("--- VERIFYING EXACT YAWS AROUND -83.0 DEGREES ---")
	for yaw in [-80.0, -81.0, -82.0, -83.0, -84.0, -85.0]:
		raw_scene.rotation_degrees = Vector3(0, yaw, 0)
		for f in range(2): await process_frame
		
		var p_p = skel.global_transform * skel.get_bone_global_pose(b_pelvis).origin
		var p_h = skel.global_transform * skel.get_bone_global_pose(b_head).origin - p_p
		var p_s = skel.global_transform * skel.get_bone_global_pose(b_spine2).origin - p_p
		var p_t = skel.global_transform * skel.get_bone_global_pose(b_tail).origin - p_p
		var p_rw = skel.global_transform * skel.get_bone_global_pose(b_rw).origin - p_p
		var p_lw = skel.global_transform * skel.get_bone_global_pose(b_lw).origin - p_p
		
		print("Yaw %5.1f | Head: (X=%+5.2f, Z=%+5.2f) | Spine2: (X=%+5.2f, Z=%+5.2f) | Tail: (X=%+5.2f, Z=%+5.2f) | RW.X=%+5.2f, LW.X=%+5.2f" % [
			yaw, p_h.x, p_h.z, p_s.x, p_s.z, p_t.x, p_t.z, p_rw.x, p_lw.x
		])
		
	quit(0)
