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
	sk.force_update_all_bone_transforms()
	print("child global pose after force_update_all_bone_transforms: ", sk.get_bone_global_pose(1).origin)
	quit(0)
