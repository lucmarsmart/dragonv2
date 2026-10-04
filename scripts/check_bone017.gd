@tool
extends SceneTree

func _init():
	var d = load("res://assets/models/dragon.glb").instantiate()
	var sk: Skeleton3D = d.find_child("*Skeleton3D*", true, false)
	for b_name in ["Bone017(mirrored)_092", "Bone017_068", "Bone018(mirrored)_096", "Bone018_069"]:
		var idx = sk.find_bone(b_name)
		var p_name = sk.get_bone_name(sk.get_bone_parent(idx)) if idx != -1 and sk.get_bone_parent(idx) != -1 else "NONE"
		print("Bone: %s (idx %d), Parent: %s" % [b_name, idx, p_name])
	quit(0)
