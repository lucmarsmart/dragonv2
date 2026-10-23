@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for f in range(15): await process_frame
	
	var dragon: DragonController = scene.get_node("Dragon")
	var sk: Skeleton3D = dragon.skeleton
	
	# Let's inspect the glide pose rotations for all wing bones
	var ap = dragon.anim_player
	var glide = ap.get_animation("Qishilong_glide")
	print("Glide anim tracks:")
	for t in range(glide.get_track_count()):
		var path = str(glide.track_get_path(t))
		if "Bone017" in path or "Bone018" in path or "Bone026" in path:
			var rot = glide.track_get_key_value(t, 0)
			print("  Track %s: rot=%s" % [path, str(rot)])
	quit(0)
