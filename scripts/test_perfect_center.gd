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
	var b_rw = skel.find_bone("Bone017_068")
	var b_lw = skel.find_bone("Bone017(mirrored)_092")
	var b_tail = skel.find_bone("Bone008_0154")
	var b_spine = skel.find_bone("Bip001-Spine2_07")
	
	print("--- TESTING MIDPOINT-BASED ALIGNMENT ---")
	for yaw in range(-120, -50, 5):
		raw_scene.rotation_degrees = Vector3(0, float(yaw), 0)
		for f in range(2): await process_frame
		
		var rw_p = skel.global_transform * skel.get_bone_global_pose(b_rw).origin
		var lw_p = skel.global_transform * skel.get_bone_global_pose(b_lw).origin
		var chest_mid = (rw_p + lw_p) * 0.5
		
		var head_p = skel.global_transform * skel.get_bone_global_pose(b_head).origin
		var tail_p = skel.global_transform * skel.get_bone_global_pose(b_tail).origin
		var spine_p = skel.global_transform * skel.get_bone_global_pose(b_spine).origin
		
		# Relative to chest_mid:
		var h_rel = head_p - chest_mid
		var t_rel = tail_p - chest_mid
		var s_rel = spine_p - chest_mid
		
		# Symmetry of wings:
		var rw_rel = rw_p - chest_mid
		var lw_rel = lw_p - chest_mid
		
		print("Yaw %4d | Head rel chest: (X=%+5.2f, Z=%+5.2f) | Tail rel chest: (X=%+5.2f, Z=%+5.2f) | Wings X: +%.2f / -%.2f" % [
			yaw, h_rel.x, h_rel.z, t_rel.x, t_rel.z, rw_rel.x, abs(lw_rel.x)
		])
		
	quit(0)
