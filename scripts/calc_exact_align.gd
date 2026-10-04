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
	var b_spine = skel.find_bone("Bip001-Spine2_07")
	
	var p_pos = skel.get_bone_global_pose(b_pelvis).origin
	var h_pos = skel.get_bone_global_pose(b_head).origin
	var s_pos = skel.get_bone_global_pose(b_spine).origin
	
	var fwd = (h_pos - p_pos).normalized()
	var mid = (s_pos - p_pos)
	var up = (mid - fwd * mid.dot(fwd)).normalized()
	var right = fwd.cross(up).normalized()
	
	print("Dragon local basis in fly2 at 34.0:")
	print("  fwd (head direction): ", fwd)
	print("  up (dorsal direction): ", up)
	print("  right: ", right)
	
	# We want dragon's fwd to point to -Z (Vector3.FORWARD)
	# and dragon's up to point to +Y (Vector3.UP)
	# Target basis:
	# basis.x = Vector3.RIGHT (1, 0, 0)
	# basis.y = Vector3.UP (0, 1, 0)
	# basis.z = Vector3.BACK (0, 0, 1)
	
	# If raw dragon has basis M_dragon = Basis(right, up, -fwd)
	# We want M_align * M_dragon = Basis.IDENTITY
	# So M_align = M_dragon.inverse()!
	var m_dragon = Basis(right, up, -fwd)
	var m_align = m_dragon.inverse()
	
	print("Required align basis rotation_degrees: ", m_align.get_euler() * (180.0 / PI))
	
	# Test this alignment:
	var aligned_fwd = m_align * fwd
	var aligned_up = m_align * up
	print("Resulting aligned_fwd: ", aligned_fwd)
	print("Resulting aligned_up: ", aligned_up)
	
	quit(0)
