@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for f in range(5): await process_frame
	
	var dragon = scene.get_node("Dragon")
	var skel = dragon.skeleton
	var b_lf = dragon.bone_l_foot
	var b_rf = dragon.bone_r_foot
	var b_pel = dragon.bone_pelvis
	
	dragon.has_taken_off = true
	dragon.anim_player.play("Qishilong_fly2")
	dragon.anim_player.seek(0.5, true)
	for f in range(3): await process_frame
	dragon._process(0.016)
	
	var p_lf = skel.global_transform * skel.get_bone_global_pose(b_lf).origin - dragon.global_position
	var p_rf = skel.global_transform * skel.get_bone_global_pose(b_rf).origin - dragon.global_position
	var p_pel = skel.global_transform * skel.get_bone_global_pose(b_pel).origin - dragon.global_position
	
	print("Left foot local to Dragon: ", p_lf)
	print("Right foot local to Dragon: ", p_rf)
	print("Pelvis local to Dragon: ", p_pel)
	quit(0)
