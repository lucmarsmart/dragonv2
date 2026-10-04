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
	print("Qishilong_fly2 length: ", anim.length)
	print("Track count: ", anim.get_track_count())
	
	# Find root / pelvis track
	var pelvis_track = -1
	for t in range(anim.get_track_count()):
		var p = str(anim.track_get_path(t))
		if "Bip001_03" in p or "Root" in p or "Pelvis" in p:
			print("Found track: ", p, " type: ", anim.track_get_type(t), " keys: ", anim.track_get_key_count(t))
			if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and "Bip001_03" in p:
				pelvis_track = t
				
	# Let's inspect pelvis translation over time from 31.0 to 45.0
	if pelvis_track != -1:
		for k in range(anim.track_get_key_count(pelvis_track)):
			var kt = anim.track_get_key_time(pelvis_track, k)
			if kt >= 31.0 and kt <= 42.0:
				print("t=%.3f pelvis pos = %s" % [kt, anim.track_get_key_value(pelvis_track, k)])
				
	quit(0)
