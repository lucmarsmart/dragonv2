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
		
	var anim = ap.get_animation("Qishilong_up")
	var b_pelvis = skel.find_bone("Bip001_03")
	var b_head = skel.find_bone("Bip001-Head_011")
	
	ap.play("Qishilong_up")
	for step in range(16):
		var t = 129.5 + step * 0.1
		ap.seek(t, true)
		for f in range(2): await process_frame
		
		var p_pos = skel.get_bone_global_pose(b_pelvis).origin
		var head_pos = skel.get_bone_global_pose(b_head).origin
		var spine_fwd = (head_pos - p_pos).normalized()
		print("Qishilong_up t=%.2f: head-pelvis dir=%s, pelvis_pos=%s" % [t, spine_fwd, p_pos])
		
	quit(0)
