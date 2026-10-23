@tool
extends SceneTree

func _init():
	var sk = Skeleton3D.new()
	sk.add_bone("root")
	sk.add_bone("child")
	sk.set_bone_parent(1, 0)
	sk.set_bone_rest(0, Transform3D(Basis.IDENTITY, Vector3.ZERO))
	sk.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)))
	sk.reset_bone_poses()
	
	sk.set_bone_pose_rotation(0, Quaternion(Vector3(0, 0, 1), PI / 2.0))
	
	# Let's test how to get the updated child global pose
	print("Method list with 'bone' or 'transform':")
	for m in sk.get_method_list():
		if "pose" in m.name or "bone" in m.name or "transform" in m.name:
			if "update" in m.name or "force" in m.name or "dirty" in m.name or "calc" in m.name:
				print("  ", m.name)
	quit(0)
