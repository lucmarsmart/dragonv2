@tool
extends SceneTree

func _init():
	var raw_scene = load("res://assets/models/dragon.glb").instantiate()
	var ap: AnimationPlayer = null
	var q = [raw_scene]
	while q.size() > 0:
		var c = q.pop_front()
		if c is AnimationPlayer: ap = c
		for ch in c.get_children(): q.append(ch)
		
	if ap:
		print("Found AnimationPlayer!")
		var lib = ap.get_animation_library("")
		if lib:
			for anim_name in lib.get_animation_list():
				var anim = lib.get_animation(anim_name)
				print("Anim: %s | Length: %.2fs | Loop: %s | Tracks: %d" % [anim_name, anim.length, anim.loop_mode, anim.get_track_count()])
	else:
		print("No AnimationPlayer found in dragon.glb")
	quit(0)
