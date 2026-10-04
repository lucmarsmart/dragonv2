@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for f in range(25): await process_frame
	
	var dragon = scene.get_node("Dragon")
	var skel: Skeleton3D = dragon.skeleton
	var ap: AnimationPlayer = dragon.anim_player
	var b_head = dragon.bone_head_idx
	var b_pel = dragon.bone_pelvis
	
	print("--- TEST ORIENTATION IN NORMAL FLIGHT (Qishilong_fly2) ---")
	dragon.has_taken_off = true
	ap.play("Qishilong_fly2")
	ap.seek(0.5, true)
	for f in range(2): await process_frame
	dragon._process(0.016)
	
	var h_norm = skel.global_transform * skel.get_bone_global_pose(b_head).origin
	var p_norm = skel.global_transform * skel.get_bone_global_pose(b_pel).origin
	var fwd_norm = (h_norm - p_norm).normalized()
	var char_fwd = -dragon.global_transform.basis.z.normalized()
	print("Normal flight: Character forward = ", char_fwd, " | Spine forward (head - pelvis) = ", fwd_norm)
	
	print("\n--- TEST ORIENTATION IN DIVE (Qishilong_down) ---")
	dragon.toggle_dive()
	ap.play("Qishilong_down")
	ap.seek(0.5, true)
	for f in range(2): await process_frame
	dragon._process(0.016)
	
	var h_dive = skel.global_transform * skel.get_bone_global_pose(b_head).origin
	var p_dive = skel.global_transform * skel.get_bone_global_pose(b_pel).origin
	var fwd_dive = (h_dive - p_dive).normalized()
	print("Dive mode: Character forward = ", char_fwd, " | Spine forward (head - pelvis) = ", fwd_dive)
	
	var angle_diff = rad_to_deg(char_fwd.angle_to(fwd_dive))
	print("Angular deviation between Character forward and Dragon spine in Dive: %.2f degrees!" % angle_diff)
	
	quit(0)
