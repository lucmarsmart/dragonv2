extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var dragon = scene.get_node("Dragon")
	for f in range(60): await process_frame
	var sk: Skeleton3D = dragon.skeleton
	var names = ["Bip001_03", "Bip001-Spine2_07", "Bip001-Head_011", "Bone008_0154", "Bone001_0147", "Bip001-L-Thigh_0115", "Bip001-R-Thigh_0130", "Bip001-L-Foot_0118", "Bip001-L-UpperArm_038", "Bip001-R-UpperArm_053"]
	for step in range(6):
		print("== t=%.2f anim=%.2f" % [step * 0.5, dragon.anim_player.current_animation_position])
		for n in names:
			var i = sk.find_bone(n)
			if i == -1:
				print(n, " missing")
				continue
			var wp = sk.global_transform * sk.get_bone_global_pose(i).origin
			var lp = dragon.global_transform.affine_inverse() * wp
			print("%-24s local(x right, y up, z back)= %s" % [n, lp.snapped(Vector3(0.01, 0.01, 0.01))])
		for f in range(30): await process_frame
	quit(0)
