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
	for t in range(anim.get_track_count()):
		var p = str(anim.track_get_path(t))
		if "Bone017(mirrored)_092" in p and anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			wing_track = t
			break
			
	var samples = []
	for t_eval in range(430, 480):
		var t = t_eval / 10.0
		var w_rot = anim.rotation_track_interpolate(wing_track, t)
		samples.append({"t": t, "w": w_rot})
		
	var best_diff = 999.0
	var best_pair = [0.0, 0.0]
	for i in range(samples.size()):
		for j in range(i + 10, samples.size()):
			var dt = samples[j]["t"] - samples[i]["t"]
			if dt >= 1.2 and dt <= 1.8:
				var diff = (samples[i]["w"] as Quaternion).angle_to(samples[j]["w"] as Quaternion)
				if diff < best_diff:
					best_diff = diff
					best_pair = [samples[i]["t"], samples[j]["t"]]
					
	print("Best straight loop around 45s: start=%.2f, end=%.2f, len=%.2f, diff=%.4f" % [
		best_pair[0], best_pair[1], best_pair[1] - best_pair[0], best_diff
	])
	
	quit(0)
