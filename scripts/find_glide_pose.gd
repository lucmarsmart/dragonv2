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
		
	var anim = ap.get_animation("Qishilong_fly2")
	var b_pelvis = skel.find_bone("Bip001_03")
	var b_lw = skel.find_bone("Bip001-L-UpperArm_038")
	var b_rw = skel.find_bone("Bip001-R-UpperArm_053")
	var b_head = skel.find_bone("Bip001-Head_011")
	var b_tail = skel.find_bone("Bone008_0154")
	
	ap.play("Qishilong_fly2")
	
	# Let's search from 31.6 to 68.0 in steps of 0.05s
	# We want: wings wide, wing height near pelvis level, symmetric bank (< 5 deg), spine pitch between -5 and 5 deg
	print("--- SEARCHING FOR GLIDE POSE CANDIDATES IN Qishilong_fly2 ---")
	var best_glide = []
	for s in range(int((68.0 - 31.6) / 0.05)):
		var t = 31.6 + s * 0.05
		ap.seek(t, true)
		for f in range(2): await process_frame
		
		var p_pose = skel.get_bone_global_pose(b_pelvis)
		var lw_pose = skel.get_bone_global_pose(b_lw)
		var rw_pose = skel.get_bone_global_pose(b_rw)
		var h_pose = skel.get_bone_global_pose(b_head)
		
		var w_height = ((lw_pose.origin.y + rw_pose.origin.y) * 0.5) - p_pose.origin.y
		var w_span = (rw_pose.origin - lw_pose.origin).length()
		var bank = abs(rw_pose.origin.y - lw_pose.origin.y)
		var fwd = (h_pose.origin - p_pose.origin).normalized()
		var pitch = rad_to_deg(asin(clamp(fwd.y, -1.0, 1.0)))
		
		if abs(w_height) < 25.0 and bank < 15.0 and abs(pitch) < 15.0:
			best_glide.append({"t": t, "w_h": w_height, "span": w_span, "bank": bank, "pitch": pitch})
			
	best_glide.sort_custom(func(a, b): return (abs(a["w_h"]) + a["bank"] + abs(a["pitch"])) < (abs(b["w_h"]) + b["bank"] + abs(b["pitch"])))
	
	for i in range(min(10, best_glide.size())):
		var g = best_glide[i]
		print("Candidate %d: t=%.3fs, WingH=%.1f, Bank=%.1f, Pitch=%.1f, Span=%.1f" % [i, g["t"], g["w_h"], g["bank"], g["pitch"], g["span"]])
		
	quit(0)
