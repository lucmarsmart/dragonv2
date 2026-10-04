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
	var b_head = sk.find_bone("Bip001-Head_011")
	var b_tail = sk.find_bone("Bone008_0154")
	ap.play("Qishilong_fly2")
	ap.pause()
	
	var t = 33.60
	print("--- RAW ANIMATION YAW (without slerp) ---")
	while t <= 36.65:
		ap.seek(t, true)
		await process_frame
		await process_frame
		var p_h = sk.get_bone_global_pose(b_head).origin
		var p_t = sk.get_bone_global_pose(b_tail).origin
		var fwd = (p_h - p_t).normalized()
		var yaw = rad_to_deg(atan2(fwd.x, -fwd.z))
		print("t=%.2f -> raw yaw=%+6.2f deg" % [t, yaw])
		t += 0.05
	quit(0)
