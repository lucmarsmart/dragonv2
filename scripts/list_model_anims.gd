@tool
extends SceneTree

func _init():
	var d = load("res://assets/models/dragon.glb").instantiate()
	var ap: AnimationPlayer = d.find_child("*AnimationPlayer*", true, false)
	for a in ap.get_animation_list():
		var anim = ap.get_animation(a)
		print("Animation: %s, length: %.2f" % [a, anim.length])
	quit(0)
