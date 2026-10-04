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
		var min_time = 999999.0
		var max_time = -999999.0
		var changing_tracks = 0
		var key_times = []
		
		# Find tracks that actually change value
		for t in range(anim.get_track_count()):
			var kc = anim.track_get_key_count(t)
			if kc > 1:
				var first_val = anim.track_get_key_value(t, 0)
				var has_change = false
				for k in range(kc):
					var kt = anim.track_get_key_time(t, k)
					var kv = anim.track_get_key_value(t, k)
					if kv != first_val:
						has_change = true
						if kt < min_time: min_time = kt
						if kt > max_time: max_time = kt
				if has_change:
					changing_tracks += 1
		print("Animation '%s': length=%.3fs, changing_tracks=%d, active_range=[%.3f, %.3f]" % [anim_name, anim.length, changing_tracks, min_time, max_time])
		
	quit(0)
