@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for f in range(15): await process_frame
	
	var dragon: DragonController = scene.get_node("Dragon")
	var sk: Skeleton3D = dragon.skeleton
	
	print("--- TESTING NATURAL WING FOLD POSE ---")
	dragon.has_taken_off = true
	dragon.locomotion_state = dragon.LocomotionState.GROUNDED
	dragon.wing_fold_blend = 1.0
	dragon.ground_blend = 1.0
	
	for f in range(30):
		dragon._physics_process(0.016)
		dragon._process(0.016)
		await process_frame
		
	var b108_p = dragon.global_basis.inverse() * (sk.to_global(sk.get_bone_global_pose(108).origin) - dragon.global_position)
	var b132_p = dragon.global_basis.inverse() * (sk.to_global(sk.get_bone_global_pose(132).origin) - dragon.global_position)
	print("Current tips in GROUNDED: 108(L)=%s, 132(R)=%s" % [str(b108_p), str(b132_p)])
	
	quit(0)
