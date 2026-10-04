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
	
	print("--- SCANNING Qishilong_fly2 TIMELINE (0 to 68s) ---")
	ap.play("Qishilong_fly2")
	
	for s in range(0, 680, 5): # every 0.5s
		var t = s / 10.0
		ap.seek(t, true)
		for f in range(2): await process_frame
		
		var p_pos = skel.get_bone_global_pose(b_pelvis).origin
		var h_pos = skel.get_bone_global_pose(b_head).origin
		var spine = (h_pos - p_pos).normalized()
		var yaw = rad_to_deg(atan2(spine.x, spine.z))
		var horiz = sqrt(spine.x * spine.x + spine.z * spine.z)
		var pitch = rad_to_deg(atan2(spine.y, horiz))
		
		# Print key checkpoints
		if (t >= 31.0 and t <= 36.0) or (t >= 50.0 and t <= 68.0) or (abs(yaw) < 15.0 and t > 32.0):
			print("t=%4.1f: yaw=%6.1f deg, pitch=%5.1f deg, pelvis_pos=%s" % [t, yaw, pitch, p_pos])
			
	quit(0)
