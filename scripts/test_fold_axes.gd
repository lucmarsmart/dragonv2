@tool
extends SceneTree

func _init():
	root.size = Vector2i(1280, 720)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(20): await process_frame
	for c in scene.get_children():
		if c is CanvasLayer: c.visible = false
		
	var dragon: DragonController = scene.get_node("Dragon")
	var sk: Skeleton3D = dragon.skeleton
	
	# Start with the beautiful symmetric pose from 40.25
	var raw_glb = load("res://assets/models/dragon.glb").instantiate()
	root.add_child(raw_glb)
	var raw_ap: AnimationPlayer = raw_glb.find_child("*AnimationPlayer*", true, false)
	raw_ap.play("Qishilong_fly2")
	raw_ap.seek(40.25, true)
	var raw_sk: Skeleton3D = raw_glb.find_child("*Skeleton3D*", true, false)
	
	# Let's test rotating the shoulder and elbow to tuck back
	# In local bone space, what axis rotates shoulder backward?
	print("Testing local rotation axes...")
	quit(0)
