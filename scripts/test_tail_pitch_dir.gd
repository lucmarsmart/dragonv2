@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for f in range(25): await process_frame
	
	var dragon = scene.get_node("Dragon")
	var skel: Skeleton3D = dragon.skeleton
	var b_tail_first = dragon.bone_tail_indices[0]
	var b_tail_last = dragon.bone_tail_indices[dragon.bone_tail_indices.size() - 1]
	
	print("Tail pitch axis for first tail bone: ", dragon.bone_pitch_axes[b_tail_first])
	
	# Sample tail tip position with 0 pitch
	var tip_pos_0 = skel.global_transform * skel.get_bone_global_pose(b_tail_last).origin
	
	# Apply negative tail pitch like climb does (-0.3 rad)
	for b in dragon.bone_tail_indices:
		var q = Quaternion(dragon.bone_pitch_axes[b], -0.3)
		skel.set_bone_pose_rotation(b, q * skel.get_bone_pose_rotation(b))
	
	for f in range(2): await process_frame
	var tip_pos_neg = skel.global_transform * skel.get_bone_global_pose(b_tail_last).origin
	
	print("Tail tip Y at pitch=0: %.3f" % tip_pos_0.y)
	print("Tail tip Y at pitch=-0.3: %.3f" % tip_pos_neg.y)
	if tip_pos_neg.y > tip_pos_0.y:
		print("-> WARNING: Negative tail pitch raises the tail UP! (Inverted from desired counterweight)")
	else:
		print("-> OK: Negative tail pitch lowers the tail DOWN.")
		
	quit(0)
