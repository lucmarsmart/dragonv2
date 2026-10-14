extends SceneTree

func _init():
	var d = load("res://assets/models/dragon.glb").instantiate()
	var skel: Skeleton3D = null
	for c in d.find_children("*", "Skeleton3D", true, false):
		skel = c
		break
	if skel:
		for i in range(skel.get_bone_count()):
			var bname = skel.get_bone_name(i)
			if "eye" in bname.to_lower() or "head" in bname.to_lower() or "jaw" in bname.to_lower():
				print("Bone ", i, ": ", bname)
				
	# Check materials and textures
	for m: MeshInstance3D in d.find_children("*", "MeshInstance3D", true, false):
		print("Mesh: ", m.name, " parent: ", m.get_parent().name)
	quit(0)
