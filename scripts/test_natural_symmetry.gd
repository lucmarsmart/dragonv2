@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for f in range(15): await process_frame
	
	var dragon: DragonController = scene.get_node("Dragon")
	var sk: Skeleton3D = dragon.skeleton
	
	# Let's inspect the bones when we aim them backward (+Z)
	dragon.has_taken_off = true
	dragon.locomotion_state = dragon.LocomotionState.GROUNDED
	dragon.wing_fold_blend = 1.0
	dragon.ground_blend = 1.0
	
	# Test aiming with positive Z (posterior fold)
	print("Testing bone positions...")
	var b108_p = dragon.global_basis.inverse() * (sk.to_global(sk.get_bone_global_pose(108).origin) - dragon.global_position)
	var b132_p = dragon.global_basis.inverse() * (sk.to_global(sk.get_bone_global_pose(132).origin) - dragon.global_position)
	print("Initial 108(L)=%s, 132(R)=%s" % [str(b108_p), str(b132_p)])
	
	quit(0)
