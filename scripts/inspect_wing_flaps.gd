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
	var l_wing_track = -1
	for t in range(anim.get_track_count()):
		var p = str(anim.track_get_path(t))
		if "Bone017(mirrored)_092" in p and anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			l_wing_track = t
			break
			
	print("L_wing_track: ", l_wing_track)
	if l_wing_track != -1:
		for k in range(anim.track_get_key_count(l_wing_track)):
			var kt = anim.track_get_key_time(l_wing_track, k)
			if kt >= 31.5 and kt <= 40.0:
				var rot = anim.track_get_key_value(l_wing_track, k) as Quaternion
				var euler = rot.get_euler()
				print("t=%.3f wing_euler = (%.2f, %.2f, %.2f)" % [kt, rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z)])
				
	quit(0)
