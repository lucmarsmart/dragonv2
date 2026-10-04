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
		print("Anim: '%s', length: %.3f, tracks: %d" % [anim_name, anim.length, anim.get_track_count()])
		
	quit(0)
