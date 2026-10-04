@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for f in range(25): await process_frame
	
	var dragon = scene.get_node("Dragon")
	var skel = dragon.skeleton
	var ap = dragon.anim_player
	var b_head = skel.find_bone("Bip001-Head_011")
	var b_tail = skel.find_bone("Bone008_0154")
	var b_thigh_l = dragon.bone_l_thigh
	var b_thigh_r = dragon.bone_r_thigh
	
	dragon.has_taken_off = true
	ap.play("Qishilong_fly2")
	
	print("--- TEST STABILIZER SIMULATION ---")
	var dt = 0.05
	var t = 0.0
	var smoothed_yaw_corr = 0.0
	
	while t <= 3.01:
		ap.seek(t, true)
		
		# 1. Update dragon _process base
		dragon._process(dt)
		
		# 2. Measure raw body forward in dragon space
		var p_h = skel.global_transform * skel.get_bone_global_pose(b_head).origin
		var p_t = skel.global_transform * skel.get_bone_global_pose(b_tail).origin
		var fwd_world = (p_h - p_t).normalized()
		var char_fwd = -dragon.global_transform.basis.z.normalized()
		var raw_yaw_err = atan2(fwd_world.x, -fwd_world.z) - atan2(char_fwd.x, -char_fwd.z)
		raw_yaw_err = wrapf(raw_yaw_err, -PI, PI)
		
		# If we apply Basis.from_euler(Vector3(0, -raw_yaw_err, 0)) to visual_root.transform.basis:
		# Let's see: visual_root is a child of Dragon.
		# A rotation around Y in Dragon's space means multiplying from the left:
		# visual_root.basis = Basis(Vector3.UP, -raw_yaw_err) * visual_root.basis
		var corrected_basis = Basis(Vector3.UP, raw_yaw_err) * dragon.visual_root.basis
		dragon.visual_root.basis = corrected_basis
		
		# Recalculate anchor
		var anchor_world = dragon._body_core_world()
		var target_center = dragon.global_position + Vector3(0, -0.3, 0)
		dragon.visual_root.global_position += (target_center - anchor_world)
		
		# Measure again!
		p_h = skel.global_transform * skel.get_bone_global_pose(b_head).origin
		p_t = skel.global_transform * skel.get_bone_global_pose(b_tail).origin
		fwd_world = (p_h - p_t).normalized()
		var after_yaw_err = rad_to_deg(wrapf(atan2(fwd_world.x, -fwd_world.z) - atan2(char_fwd.x, -char_fwd.z), -PI, PI))
		
		if fmod(round(t * 100) / 100.0, 0.2) < 0.01:
			print("t=%.2f | raw_yaw=%+.2f deg | after_comp=%+.2f deg" % [t, rad_to_deg(raw_yaw_err), after_yaw_err])
			
		t += dt
		
	quit(0)
