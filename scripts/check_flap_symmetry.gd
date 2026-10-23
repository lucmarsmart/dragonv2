@tool
extends SceneTree

func _init():
	var glb = load("res://assets/models/dragon.glb").instantiate()
	root.add_child(glb)
	for f in range(5): await process_frame
	
	var ap: AnimationPlayer = glb.find_child("*AnimationPlayer*", true, false)
	var sk: Skeleton3D = glb.find_child("*Skeleton3D*", true, false)
	
	for s in range(30):
		var t = 33.6 + float(s) * 0.1
		ap.play("Qishilong_fly2")
		ap.seek(t, true)
		var p96 = sk.get_bone_global_pose(96).origin
		var p120 = sk.get_bone_global_pose(120).origin
		var p108 = sk.get_bone_global_pose(108).origin
		var p132 = sk.get_bone_global_pose(132).origin
		var y_diff = abs(p108.y - p132.y)
		var x_diff = abs(p108.x - p132.x)
		var span = p108.distance_to(p132)
		print("t=%.2fs: span=%.1f, x_diff=%.1f, y_diff=%.1f" % [t, span, x_diff, y_diff])
	quit(0)
