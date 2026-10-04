@tool
extends SceneTree

func _init():
	var d = load("res://assets/models/dragon.glb").instantiate()
	var sk: Skeleton3D = d.find_child("*Skeleton3D*", true, false)
	
	print("--- LEFT ARM/WING BONES ---")
	var b = sk.find_bone("Bip001-L-Clavicle_037")
	print_bone_tree(sk, b, 0)
	
	quit(0)

func print_bone_tree(sk: Skeleton3D, b_idx: int, depth: int):
	if b_idx == -1: return
	var indent = "  ".repeat(depth)
	print("%s- [%d] %s" % [indent, b_idx, sk.get_bone_name(b_idx)])
	for i in range(sk.get_bone_count()):
		if sk.get_bone_parent(i) == b_idx:
			print_bone_tree(sk, i, depth + 1)
