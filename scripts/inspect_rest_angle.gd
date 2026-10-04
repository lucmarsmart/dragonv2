@tool
extends SceneTree

func _init():
	var raw_scene = load("res://assets/models/dragon.glb").instantiate()
	root.add_child(raw_scene)
	
	var skel: Skeleton3D = null
	var q = [raw_scene]
	while q.size() > 0:
		var c = q.pop_front()
		if c is Skeleton3D: skel = c
		for ch in c.get_children(): q.append(ch)
		
	var b_pelvis = skel.find_bone("Bip001_03")
	var b_head = skel.find_bone("Bip001-Head_011")
	var p0 = skel.get_bone_rest(b_pelvis).origin
	var h0 = skel.get_bone_rest(b_head).origin
	
	# Global rest pose
	var gp_pelvis = skel.get_bone_global_rest(b_pelvis).origin
	var gp_head = skel.get_bone_global_rest(b_head).origin
	var rest_spine = (gp_head - gp_pelvis).normalized()
	print("Rest spine direction: ", rest_spine)
	
	# Yaw angle in horizontal plane (X-Z)
	var yaw_angle = atan2(rest_spine.x, rest_spine.z)
	print("Rest spine yaw angle: %.2f deg" % rad_to_deg(yaw_angle))
	
	# Pitch angle
	var horiz_len = sqrt(rest_spine.x * rest_spine.x + rest_spine.z * rest_spine.z)
	var pitch_angle = atan2(rest_spine.y, horiz_len)
	print("Rest spine pitch angle: %.2f deg" % rad_to_deg(pitch_angle))
	
	quit(0)
