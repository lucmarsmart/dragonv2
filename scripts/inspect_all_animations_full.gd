@tool
extends SceneTree

func _init():
	var raw_scene = load("res://assets/models/dragon.glb").instantiate()
	root.add_child(raw_scene)
	
	var ap: AnimationPlayer = null
	var skel: Skeleton3D = null
	var q = [raw_scene]
	while q.size() > 0:
		var c = q.pop_front()
		if c is AnimationPlayer: ap = c
		if c is Skeleton3D: skel = c
		for ch in c.get_children(): q.append(ch)
		
	var anim_names = ap.get_animation_list()
	print("--- INSPECTING ALL ANIMATIONS IN DRAGON.GLB ---")
	
	var b_pelvis = skel.find_bone("Bip001_03")
	var b_head = skel.find_bone("Bip001-Head_011")
	var b_l_wing = skel.find_bone("Bip001-L-UpperArm_038")
	var b_r_wing = skel.find_bone("Bip001-R-UpperArm_053")
	
	for anim_name in anim_names:
		var anim = ap.get_animation(anim_name)
		print("\n==========================================")
		print("Animation: %s, Length: %.3fs, Tracks: %d" % [anim_name, anim.length, anim.get_track_count()])
		
		# Sample every 5 seconds or across the animation to see pelvis movement and wing movement
		var num_samples = int(anim.length / 5.0) + 1
		for s in range(min(num_samples, 20)):
			var t = float(s) * (anim.length / float(min(num_samples, 20) - 1)) if num_samples > 1 else 0.0
			ap.play(anim_name)
			ap.seek(t, true)
			for f in range(2): await process_frame
			
			var p_pos = skel.get_bone_global_pose(b_pelvis).origin
			var h_pos = skel.get_bone_global_pose(b_head).origin
			var fwd = (h_pos - p_pos).normalized()
			print("  t=%6.2fs: PelvisPos=%s, SpineFwd=%s" % [t, p_pos.snapped(Vector3(0.1, 0.1, 0.1)), fwd.snapped(Vector3(0.01, 0.01, 0.01))])
			
	quit(0)
