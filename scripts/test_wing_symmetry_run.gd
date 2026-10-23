@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for f in range(30): await process_frame
	
	var dragon: DragonController = scene.get_node("Dragon")
	var sk: Skeleton3D = dragon.skeleton
	
	print("--- TESTING WING SYMMETRY IN VARIOUS STATES ---")
	dragon.has_taken_off = true
	
	for state_name in ["FLYING", "LANDING", "GROUNDED"]:
		if state_name == "FLYING":
			dragon.locomotion_state = dragon.LocomotionState.FLYING
			dragon.wing_fold_blend = 0.0
		elif state_name == "LANDING":
			dragon.locomotion_state = dragon.LocomotionState.LANDING
			dragon.wing_fold_blend = 0.5
		elif state_name == "GROUNDED":
			dragon.locomotion_state = dragon.LocomotionState.GROUNDED
			dragon.wing_fold_blend = 1.0
			
		for f in range(20):
			dragon._physics_process(0.016)
			dragon._process(0.016)
			await process_frame
			
		var b96_p = sk.to_global(sk.get_bone_global_pose(96).origin) - dragon.global_position
		var b97_p = sk.to_global(sk.get_bone_global_pose(97).origin) - dragon.global_position
		var b108_p = sk.to_global(sk.get_bone_global_pose(108).origin) - dragon.global_position
		
		var b120_p = sk.to_global(sk.get_bone_global_pose(120).origin) - dragon.global_position
		var b121_p = sk.to_global(sk.get_bone_global_pose(121).origin) - dragon.global_position
		var b132_p = sk.to_global(sk.get_bone_global_pose(132).origin) - dragon.global_position
		
		# Local to dragon
		var b96_loc = dragon.global_basis.inverse() * b96_p
		var b97_loc = dragon.global_basis.inverse() * b97_p
		var b108_loc = dragon.global_basis.inverse() * b108_p
		
		var b120_loc = dragon.global_basis.inverse() * b120_p
		var b121_loc = dragon.global_basis.inverse() * b121_p
		var b132_loc = dragon.global_basis.inverse() * b132_p
		
		print("\nState: %s (wing_fold_blend=%.2f)" % [state_name, dragon.wing_fold_blend])
		print("  LEFT  Wing: root96=%s, elbow97=%s, tip108=%s" % [str(b96_loc), str(b97_loc), str(b108_loc)])
		print("  RIGHT Wing: root120=%s, elbow121=%s, tip132=%s" % [str(b120_loc), str(b121_loc), str(b132_loc)])
		print("  X-Symmetry check: root: %.2f vs %.2f (diff %.2f), elbow: %.2f vs %.2f (diff %.2f), tip: %.2f vs %.2f (diff %.2f)" % [
			b96_loc.x, -b120_loc.x, abs(b96_loc.x - (-b120_loc.x)),
			b97_loc.x, -b121_loc.x, abs(b97_loc.x - (-b121_loc.x)),
			b108_loc.x, -b132_loc.x, abs(b108_loc.x - (-b132_loc.x))
		])
		print("  Y-Symmetry check: elbow Y diff: %.2f, tip Y diff: %.2f" % [
			abs(b97_loc.y - b121_loc.y), abs(b108_loc.y - b132_loc.y)
		])
		print("  Z-Symmetry check: elbow Z diff: %.2f, tip Z diff: %.2f" % [
			abs(b97_loc.z - b121_loc.z), abs(b108_loc.z - b132_loc.z)
		])
	quit(0)
