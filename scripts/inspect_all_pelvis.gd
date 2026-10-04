@tool
extends SceneTree

func _init():
	var raw_scene = load("res://assets/models/dragon.glb").instantiate()
	root.add_child(raw_scene)
	
	var ap: AnimationPlayer = null
	var q = [raw_scene]
	while q.size() > 0:
		var c = q.pop_front()
		if c is AnimationPlayer: ap = c
		for ch in c.get_children(): q.append(ch)
		
	for anim_name in ap.get_animation_list():
		var anim = ap.get_animation(anim_name)
		# Check pelvis position at t = 0, 1, 2, 5, 10, 20...
		var pelvis_t = -1
		for t in range(anim.get_track_count()):
			if "Bip001_03" in str(anim.track_get_path(t)) and anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
				pelvis_t = t
				break
		if pelvis_t != -1:
			var k0 = anim.track_get_key_value(pelvis_t, 0)
			var kend = anim.track_get_key_value(pelvis_t, anim.track_get_key_count(pelvis_t) - 1)
			print("Anim %s: len=%.2f, pelvis start=%s, pelvis end=%s" % [anim_name, anim.length, k0, kend])
		else:
			print("Anim %s: no pelvis track" % anim_name)
			
	quit(0)
