@tool
extends SceneTree

func _init():
	root.size = Vector2i(1280, 720)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(15): await process_frame
	
	for c in scene.get_children():
		if c is CanvasLayer: c.visible = false
	
	var dragon: DragonController = scene.get_node("Dragon")
	var sk: Skeleton3D = dragon.skeleton
	var ap: AnimationPlayer = dragon.anim_player
	
	# Load the full raw fly2 animation from dragon.glb
	var raw_glb = load("res://assets/models/dragon.glb").instantiate()
	var raw_ap: AnimationPlayer = raw_glb.find_child("*AnimationPlayer*", true, false)
	var raw_fly2 = raw_ap.get_animation("Qishilong_fly2")
	
	print("Finding frames with minimum wingspan in raw Qishilong_fly2...")
	var min_span = 9999.0
	var best_t = 0.0
	
	# Sample every 0.1s across raw_fly2
	for step in range(int(raw_fly2.length * 10)):
		var t = float(step) * 0.1
		# Track bone 108 and 132 rotations
		# We can check the distance between tips
		pass
		
	# Let's inspect t from 36.0 to 40.0
	for step in range(50):
		var t = 36.0 + float(step) * 0.1
		# let's seek raw_ap
		raw_ap.play("Qishilong_fly2")
		raw_ap.seek(t, true)
		var raw_sk: Skeleton3D = raw_glb.find_child("*Skeleton3D*", true, false)
		var p108 = raw_sk.get_bone_global_pose(108).origin
		var p132 = raw_sk.get_bone_global_pose(132).origin
		var span = p108.distance_to(p132)
		if span < min_span:
			min_span = span
			best_t = t
			
	print("Best raw time with minimum span: t=%.2fs (span=%.2f)" % [best_t, min_span])
	quit(0)
