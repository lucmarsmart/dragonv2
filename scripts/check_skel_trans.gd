@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for f in range(5): await process_frame
	var dragon = scene.get_node("Dragon")
	var skel = dragon.skeleton
	var vm = dragon.visual_root
	var to_vm = vm.global_transform.affine_inverse() * skel.global_transform
	print("Transform from Skeleton to VisualModel: ", to_vm)
	quit(0)
