@tool
extends SceneTree

func _init():
	root.size = Vector2i(1280, 720)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(20): await process_frame
	for c in scene.get_children():
		if c is CanvasLayer: c.visible = false
		
	var dragon: DragonController = scene.get_node("Dragon")
	var sk: Skeleton3D = dragon.skeleton
	
	# Test t_glide = 40.25 in glide animation
	var ap = dragon.anim_player
	var raw_glb = load("res://assets/models/dragon.glb").instantiate()
	root.add_child(raw_glb)
	var raw_ap: AnimationPlayer = raw_glb.find_child("*AnimationPlayer*", true, false)
	raw_ap.play("Qishilong_fly2")
	raw_ap.seek(40.25, true)
	var raw_sk: Skeleton3D = raw_glb.find_child("*Skeleton3D*", true, false)
	
	for b in range(raw_sk.get_bone_count()):
		sk.set_bone_pose_rotation(b, raw_sk.get_bone_pose_rotation(b))
	sk.force_update_all_bone_transforms()
	
	dragon.global_position = Vector3(300, 24, 120)
	
	# Check symmetry of 40.25:
	var p96 = dragon.global_basis.inverse() * (sk.to_global(sk.get_bone_global_pose(96).origin) - dragon.global_position)
	var p120 = dragon.global_basis.inverse() * (sk.to_global(sk.get_bone_global_pose(120).origin) - dragon.global_position)
	var p108 = dragon.global_basis.inverse() * (sk.to_global(sk.get_bone_global_pose(108).origin) - dragon.global_position)
	var p132 = dragon.global_basis.inverse() * (sk.to_global(sk.get_bone_global_pose(132).origin) - dragon.global_position)
	
	print("Glide at 40.25:")
	print("  Root 96=%s, 120=%s (X diff=%.2f, Y diff=%.2f, Z diff=%.2f)" % [str(p96), str(p120), abs(p96.x + p120.x), abs(p96.y - p120.y), abs(p96.z - p120.z)])
	print("  Tip 108=%s, 132=%s (X diff=%.2f, Y diff=%.2f, Z diff=%.2f)" % [str(p108), str(p132), abs(p108.x + p132.x), abs(p108.y - p132.y), abs(p108.z - p132.z)])
	
	quit(0)
