@tool
extends SceneTree

func _init():
	var d = load("res://scenes/main.tscn").instantiate()
	root.add_child(d)
	var dragon = d.get_node("Dragon")
	var sk: Skeleton3D = dragon.skeleton
	var vm: Node3D = dragon.visual_root
	print("Dragon global_basis: ", dragon.global_basis)
	print("VisualModel basis: ", vm.basis)
	print("Skel global_basis: ", sk.global_basis)
	var b_head = dragon.bone_head_idx
	var b_pelvis = dragon.bone_pelvis
	print("Head world pos: ", sk.to_global(sk.get_bone_global_pose(b_head).origin) - dragon.global_position)
	print("Pelvis world pos: ", sk.to_global(sk.get_bone_global_pose(b_pelvis).origin) - dragon.global_position)
	for b in [96, 97, 104, 108, 120, 121, 128, 132]:
		var g_pos = sk.to_global(sk.get_bone_global_pose(b).origin) - dragon.global_position
		print("Bone %d (%s) world pos relative to dragon: %s" % [b, sk.get_bone_name(b), str(g_pos)])
	quit(0)
