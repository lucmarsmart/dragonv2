@tool
extends SceneTree

func _init():
	var raw = load("res://assets/models/dragon.glb").instantiate()
	root.add_child(raw)
	var ap: AnimationPlayer = null
	var sk: Skeleton3D = null
	var q = [raw]
	while q.size() > 0:
		var c = q.pop_front()
		if c is AnimationPlayer: ap = c
		if c is Skeleton3D: sk = c
		for ch in c.get_children(): q.append(ch)
		
	var anim = ap.get_animation("Qishilong_fly2")
	var l_wing = sk.find_bone("Bone017(mirrored)_092")
	var r_wing = sk.find_bone("Bone017_068")
	var l_mid = sk.find_bone("Bone018(mirrored)_096")
	var r_mid = sk.find_bone("Bone018_069")
	
	for t in [33.60, 36.60]:
		ap.play("Qishilong_fly2")
		ap.seek(t, true)
		print("t=%.2f | L-Wing rot=%s | R-Wing rot=%s" % [
			t,
			sk.get_bone_pose_rotation(l_wing).get_euler(),
			sk.get_bone_pose_rotation(r_wing).get_euler()
		])
	quit(0)
