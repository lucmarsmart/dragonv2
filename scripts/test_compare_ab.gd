@tool
extends SceneTree

func _init():
	# CASE A: Like test_angles.gd
	var root_A = Node3D.new()
	root.add_child(root_A)
	var raw_A = load("res://assets/models/dragon.glb").instantiate()
	root_A.add_child(raw_A)
	var ap_A: AnimationPlayer = null
	var skel_A: Skeleton3D = null
	var q = [raw_A]
	while q.size() > 0:
		var c = q.pop_front()
		if c is AnimationPlayer: ap_A = c
		if c is Skeleton3D: skel_A = c
		for ch in c.get_children(): q.append(ch)
	raw_A.rotation_degrees = Vector3(0, -28.0, 0)
	ap_A.play("Qishilong_fly2")
	ap_A.seek(34.0, true)
	for f in range(2): await process_frame
	
	var b_head = skel_A.find_bone("Bip001-Head_011")
	var b_pelvis = skel_A.find_bone("Bip001_03")
	var head_A = skel_A.global_transform * skel_A.get_bone_global_pose(b_head).origin
	var pelvis_A = skel_A.global_transform * skel_A.get_bone_global_pose(b_pelvis).origin
	print("CASE A (test_angles.gd at 34s):")
	print("  Pelvis: ", pelvis_A)
	print("  Head:   ", head_A)
	print("  Head - Pelvis: ", head_A - pelvis_A)
	
	# CASE B: Like main.tscn with dragon_controller
	var scene_B = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene_B)
	for f in range(5): await process_frame
	var dragon_B = scene_B.get_node("Dragon")
	var skel_B = dragon_B.get_node("VisualModel/DragonModel").find_child("*Skeleton*", true, false)
	if not skel_B:
		var q2 = [dragon_B]
		while q2.size() > 0:
			var c = q2.pop_front()
			if c is Skeleton3D: skel_B = c
			for ch in c.get_children(): q2.append(ch)
			
	var head_B = skel_B.global_transform * skel_B.get_bone_global_pose(b_head).origin
	var pelvis_B = skel_B.global_transform * skel_B.get_bone_global_pose(b_pelvis).origin
	print("CASE B (main.tscn):")
	print("  Dragon pos: ", dragon_B.global_position)
	print("  Dragon rot: ", dragon_B.rotation_degrees)
	print("  Pelvis:     ", pelvis_B)
	print("  Head:       ", head_B)
	print("  Head - Pelvis: ", head_B - pelvis_B)
	
	quit(0)
