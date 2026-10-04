@tool
extends SceneTree

const DragonSkeletonModifier = preload("res://scripts/dragon_skeleton_modifier.gd")

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for f in range(25): await process_frame
	
	var dragon = scene.get_node("Dragon")
	var skel = dragon.skeleton
	
	# Instantiate modifier
	var mod = DragonSkeletonModifier.new()
	mod.name = "TestModifier"
	mod.dragon = dragon
	skel.add_child(mod)
	
	print("Modifier successfully added to skeleton!")
	for f in range(5): await process_frame
	print("Frames processed without crashing!")
	quit(0)
