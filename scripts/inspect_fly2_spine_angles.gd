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
	
	ap.play("Qishilong_fly2")
	for t_int in range(330, 420, 10):
		var t = t_int / 10.0
		ap.seek(t, true)
		for f in range(2): await process_frame
		
		var p_pos = skel.get_bone_global_pose(b_pelvis).origin
		var head_pos = skel.get_bone_global_pose(b_head).origin
		var spine = (head_pos - p_pos).normalized()
		var yaw = rad_to_deg(atan2(spine.x, spine.z))
		var horiz = sqrt(spine.x * spine.x + spine.z * spine.z)
		var pitch = rad_to_deg(atan2(spine.y, horiz))
		print("t=%.1f: spine=%s yaw=%.1f deg pitch=%.1f deg" % [t, spine, yaw, pitch])
		
	quit(0)
