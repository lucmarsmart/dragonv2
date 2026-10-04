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
		var min_time = 99999.0
		var max_time = -99999.0
		var total_keys = 0
		for t in range(anim.get_track_count()):
			var kc = anim.track_get_key_count(t)
			total_keys += kc
			if kc > 0:
				min_time = min(min_time, anim.track_get_key_time(t, 0))
				max_time = max(max_time, anim.track_get_key_time(t, kc - 1))
		print("Anim '%s': len=%.3f, min_key_time=%.3f, max_key_time=%.3f, total_keys=%d" % [anim_name, anim.length, min_time, max_time, total_keys])
		
	quit(0)
