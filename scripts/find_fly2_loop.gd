@tool
extends SceneTree

# Test extracting a clean flight loop from Qishilong_fly2
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
	
	# Let's check wing bone (Bone017(mirrored)_092) and pelvis rotation across 33.0 to 45.0
	# to find two times where wing and pelvis rotation match closely for a seamless loop!
	var wing_track = -1
	var pelvis_rot_track = -1
	for t in range(anim.get_track_count()):
		var p = str(anim.track_get_path(t))
		if "Bone017(mirrored)_092" in p and anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			wing_track = t
		if "Bip001_03" in p and anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			pelvis_rot_track = t
			
	print("wing_track=%d, pelvis_rot_track=%d" % [wing_track, pelvis_rot_track])
	
	# Check wing angles at each peak/trough between 33.0 and 42.0
	var samples = []
	for t_eval in range(330, 420):
		var t = t_eval / 10.0
		var w_rot = anim.rotation_track_interpolate(wing_track, t)
		var p_rot = anim.rotation_track_interpolate(pelvis_rot_track, t)
		samples.append({"t": t, "w": w_rot, "p": p_rot})
		
	print("Finding best loop candidates...")
	var best_diff = 999.0
	var best_pair = [0.0, 0.0]
	for i in range(samples.size()):
		for j in range(i + 12, samples.size()): # at least 1.2s apart
			var dt = samples[j]["t"] - samples[i]["t"]
			if dt >= 1.3 and dt <= 2.2:
				var w_diff = (samples[i]["w"] as Quaternion).angle_to(samples[j]["w"] as Quaternion)
				var p_diff = (samples[i]["p"] as Quaternion).angle_to(samples[j]["p"] as Quaternion)
				var total_diff = w_diff * 2.0 + p_diff
				if total_diff < best_diff:
					best_diff = total_diff
					best_pair = [samples[i]["t"], samples[j]["t"]]
					
	print("Best loop in Qishilong_fly2: start=%.2f, end=%.2f, len=%.2f, diff=%.4f" % [
		best_pair[0], best_pair[1], best_pair[1] - best_pair[0], best_diff
	])
	
	quit(0)
