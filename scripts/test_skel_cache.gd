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
	
	print("Before rotation:")
	print("  root global pose: ", sk.get_bone_global_pose(0).origin)
	print("  child global pose: ", sk.get_bone_global_pose(1).origin)
	
	# Rotate root 90 deg around Z
	sk.set_bone_pose_rotation(0, Quaternion(Vector3(0, 0, 1), PI / 2.0))
	
	print("Immediately after set_bone_pose_rotation(0):")
	print("  child global pose: ", sk.get_bone_global_pose(1).origin)
	
	sk.force_update_bone_child_transform(0)
	print("After force_update_bone_child_transform(0):")
	print("  child global pose: ", sk.get_bone_global_pose(1).origin)
	quit(0)
