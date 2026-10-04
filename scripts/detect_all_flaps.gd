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
	
	ap.play("Qishilong_fly2")
	
	var dt = 0.05
	var total_steps = int((68.0 - 31.6) / dt)
	var records = []
	
	for s in range(total_steps):
		var t = 31.6 + s * dt
		ap.seek(t, true)
		for f in range(2): await process_frame
		
		var p_pose = skel.get_bone_global_pose(b_pelvis)
		var lw_pose = skel.get_bone_global_pose(b_lw)
		var rw_pose = skel.get_bone_global_pose(b_rw)
		var h_pose = skel.get_bone_global_pose(b_head)
		
		# Wing height relative to pelvis
		var w_height = ((lw_pose.origin.y + rw_pose.origin.y) * 0.5) - p_pose.origin.y
		# Wing roll / bank: rw y minus lw y
		var w_bank = rw_pose.origin.y - lw_pose.origin.y
		# Spine direction
		var fwd = (h_pose.origin - p_pose.origin).normalized()
		var pitch = rad_to_deg(asin(clamp(fwd.y, -1.0, 1.0)))
		
		records.append({"t": t, "w_h": w_height, "bank": w_bank, "pitch": pitch, "p_pos": p_pose.origin})
		
	print("--- FLAP PEAKS & TROUGHS IN Qishilong_fly2 ---")
	for i in range(2, records.size() - 2):
		var cur = records[i]["w_h"]
		var prev = records[i-1]["w_h"]
		var next = records[i+1]["w_h"]
		if cur > prev and cur > next and cur > records[i-2]["w_h"] and cur > records[i+2]["w_h"]:
			if cur - records[max(0, i-10)]["w_h"] > 20.0 or cur - records[min(records.size()-1, i+10)]["w_h"] > 20.0:
				print("WING PEAK (UP) at t=%.2fs (height=%.1f, pitch=%.1f, bank=%.1f)" % [records[i]["t"], cur, records[i]["pitch"], records[i]["bank"]])
		if cur < prev and cur < next and cur < records[i-2]["w_h"] and cur < records[i+2]["w_h"]:
			if records[max(0, i-10)]["w_h"] - cur > 20.0 or records[min(records.size()-1, i+10)]["w_h"] - cur > 20.0:
				print("WING TROUGH (DOWN) at t=%.2fs (height=%.1f, pitch=%.1f, bank=%.1f)" % [records[i]["t"], cur, records[i]["pitch"], records[i]["bank"]])
				
	quit(0)
