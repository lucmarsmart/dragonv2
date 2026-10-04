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
	var pelvis_rot_track = -1
	for t in range(anim.get_track_count()):
		if "Bip001_03" in str(anim.track_get_path(t)) and anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			pelvis_rot_track = t
			break
			
	for time in [46.10, 46.50, 47.00, 47.50]:
		var q_val = anim.rotation_track_interpolate(pelvis_rot_track, time)
		var eul = q_val.get_euler()
		print("t=%.2f: q=%s euler=(%.2f, %.2f, %.2f)" % [time, q_val, rad_to_deg(eul.x), rad_to_deg(eul.y), rad_to_deg(eul.z)])
		
	var q_start = anim.rotation_track_interpolate(pelvis_rot_track, 46.10)
	var q_end = anim.rotation_track_interpolate(pelvis_rot_track, 47.50)
	print("Pelvis rot angle diff between start and end: %.4f rad (%.2f deg)" % [
		q_start.angle_to(q_end), rad_to_deg(q_start.angle_to(q_end))
	])
	quit(0)
