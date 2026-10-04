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
	
	print("--- BONE REST & GLOBAL POSES AT 34.0s (NO VISUAL ROOT ROTATION) ---")
	var bones = [
		"Bip001_03",
		"Bip001-Spine_05",
		"Bip001-Spine1_06",
		"Bip001-Spine2_07",
		"Bip001-Neck_08",
		"Bip001-Head_011",
		"Bone001_0147",
		"Bone004_0150",
		"Bone008_0154",
		"Bone017_068",
		"Bone017(mirrored)_092"
	]
	
	var pelvis_idx = skel.find_bone("Bip001_03")
	var pelvis_p = skel.get_bone_global_pose(pelvis_idx).origin
	
	for bname in bones:
		var idx = skel.find_bone(bname)
		if idx != -1:
			var p = skel.get_bone_global_pose(idx).origin
			var rel = p - pelvis_p
			print("%-25s: X=%.2f, Y=%.2f, Z=%.2f" % [bname, rel.x, rel.y, rel.z])
			
	quit(0)
