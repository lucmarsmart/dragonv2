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
	var b_pelvis = skel.find_bone("Bip001_03")
	var b_spine = skel.find_bone("Bip001-Spine2_07")
	var b_head = skel.find_bone("Bip001-Head_011")
	
	for t in [31.5, 32.0, 32.5, 33.0, 34.0, 38.0, 42.0, 45.0, 50.0]:
		ap.seek(t, true)
		for f in range(2): await process_frame
		var g_pelvis = skel.get_bone_global_pose(b_pelvis)
		var eul = g_pelvis.basis.get_euler()
		print("t=%.1f: pelvis basis euler = (pitch=%.1f, yaw=%.1f, roll=%.1f)" % [
			t, rad_to_deg(eul.x), rad_to_deg(eul.y), rad_to_deg(eul.z)
		])
		
	quit(0)
