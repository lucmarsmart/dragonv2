@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for f in range(5): await process_frame
	
	var dragon = scene.get_node("Dragon")
	var ap = dragon.anim_player
	var lib = ap.get_animation_library("")
	var raw = load("res://assets/models/dragon.glb").instantiate()
	root.add_child(raw)
	var raw_ap: AnimationPlayer = null
	var q = [raw]
	while q.size() > 0:
		var c = q.pop_front()
		if c is AnimationPlayer: raw_ap = c
		for ch in c.get_children(): q.append(ch)
		
	var orig_fly2 = raw_ap.get_animation("Qishilong_fly2")
	var r = Vector2(33.600, 36.600)
	var loop_len = r.y - r.x
	var new_anim = Animation.new()
	new_anim.length = loop_len
	new_anim.loop_mode = Animation.LOOP_LINEAR
	
	var rest_pelvis_pos = Vector3(32.7745, 356.433, 549.343)
	for t in range(orig_fly2.get_track_count()):
		var track_type = orig_fly2.track_get_type(t)
		var track_path = str(orig_fly2.track_get_path(t))
		var is_pelvis = "Bip001_03" in track_path
		var new_t = new_anim.add_track(track_type)
		new_anim.track_set_path(new_t, NodePath(track_path))
		new_anim.track_set_interpolation_type(new_t, Animation.INTERPOLATION_CUBIC)
		
		if is_pelvis and track_type == Animation.TYPE_POSITION_3D:
			new_anim.track_insert_key(new_t, 0.0, rest_pelvis_pos)
			new_anim.track_insert_key(new_t, loop_len, rest_pelvis_pos)
		else:
			for k in range(orig_fly2.track_get_key_count(t)):
				var kt = orig_fly2.track_get_key_time(t, k)
				if kt >= r.x - 0.005 and kt <= r.y + 0.005:
					var val = orig_fly2.track_get_key_value(t, k)
					var new_t_pos = clamp(kt - r.x, 0.0, loop_len)
					new_anim.track_insert_key(new_t, new_t_pos, val)
					
	lib.remove_animation("Qishilong_fly2")
	lib.add_animation("Qishilong_fly2", new_anim)
	
	dragon.has_taken_off = true
	ap.play("Qishilong_fly2")
	
	var skel = dragon.skeleton
	var b_head = dragon.bone_head_idx
	var b_tail = dragon.bone_tail_indices[dragon.bone_tail_indices.size() - 1]
	var b_wing_l = dragon.bone_l_wing_mid
	var b_wing_r = dragon.bone_r_wing_mid
	
	for t in [2.95, 2.99, 0.00, 0.05]:
		ap.seek(t, true)
		dragon._process(0.016)
		
		var p_h = skel.global_transform * skel.get_bone_global_pose(b_head).origin
		var p_t = skel.global_transform * skel.get_bone_global_pose(b_tail).origin
		var fwd_world = (p_h - p_t).normalized()
		var char_fwd = -dragon.global_transform.basis.z.normalized()
		var raw_yaw_err = wrapf(atan2(fwd_world.x, -fwd_world.z) - atan2(char_fwd.x, -char_fwd.z), -PI, PI)
		
		dragon.visual_root.basis = Basis(Vector3.UP, raw_yaw_err) * dragon.visual_root.basis
		var anchor_world = dragon._body_core_world()
		var target_center = dragon.global_position + Vector3(0, -0.3, 0)
		dragon.visual_root.global_position += (target_center - anchor_world)
		
		var p_wl = skel.global_transform * skel.get_bone_global_pose(b_wing_l).origin - dragon.global_position
		var p_wr = skel.global_transform * skel.get_bone_global_pose(b_wing_r).origin - dragon.global_position
		var p_tl = skel.global_transform * skel.get_bone_global_pose(b_tail).origin - dragon.global_position
		print("t=%.2f | WingL=%s | WingR=%s | Tail=%s" % [t, p_wl, p_wr, p_tl])
		
	quit(0)
