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
	var wing_track = -1
	var pelvis_rot_track = -1
	for t in range(anim.get_track_count()):
		var p = str(anim.track_get_path(t))
		if "Bone017(mirrored)_092" in p and anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			wing_track = t
		if "Bip001_03" in p and anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			pelvis_rot_track = t
			
	var samples = []
	for t_eval in range(320, 670, 1): # step 0.1s
		var t = t_eval / 10.0
		var w_rot = anim.rotation_track_interpolate(wing_track, t)
		var p_rot = anim.rotation_track_interpolate(pelvis_rot_track, t)
		samples.append({"t": t, "w": w_rot, "p": p_rot})
		
	print("Searching entire Qishilong_fly2 for best matching loop...")
	var matches = []
	for i in range(samples.size()):
		for j in range(i + 10, samples.size()):
			var dt = samples[j]["t"] - samples[i]["t"]
			if dt >= 1.2 and dt <= 2.2:
				var w_diff = (samples[i]["w"] as Quaternion).angle_to(samples[j]["w"] as Quaternion)
				var p_diff = (samples[i]["p"] as Quaternion).angle_to(samples[j]["p"] as Quaternion)
				if w_diff < 0.25 and p_diff < 0.25:
					matches.append({"start": samples[i]["t"], "end": samples[j]["t"], "len": dt, "w_diff": w_diff, "p_diff": p_diff, "total": w_diff + p_diff})
					
	matches.sort_custom(func(a, b): return a["total"] < b["total"])
	
	print("Top 5 loop matches in Qishilong_fly2:")
	for idx in range(min(5, matches.size())):
		var m = matches[idx]
		print("  [%d] start=%.2f, end=%.2f, len=%.2f, w_diff=%.3f, p_diff=%.3f (deg: w=%.1f, p=%.1f)" % [
			idx, m["start"], m["end"], m["len"], m["w_diff"], m["p_diff"],
			rad_to_deg(m["w_diff"]), rad_to_deg(m["p_diff"])
		])
		
	quit(0)
