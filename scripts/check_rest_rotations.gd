@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for f in range(10): await process_frame
	
	var dragon: DragonController = scene.get_node("Dragon")
	var sk: Skeleton3D = dragon.skeleton
	var ap: AnimationPlayer = dragon.anim_player
	
	var anim: Animation = ap.get_animation("Qishilong_fly2")
	print("Anim length: ", anim.length)
	
	# Find tracks for left and right wing
	for b_idx in [96, 97, 104, 108, 120, 121, 128, 132]:
		var b_name = sk.get_bone_name(b_idx)
		print("\nBone %d: %s (rest rot: %s, rest pos: %s)" % [
			b_idx, b_name, str(sk.get_bone_rest(b_idx).basis.get_rotation_quaternion()), str(sk.get_bone_rest(b_idx).origin)
		])
		
	quit(0)
