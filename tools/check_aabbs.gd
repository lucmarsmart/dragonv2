extends SceneTree

func _initialize() -> void:
	for p in [
		"res://assets/environment/trees/dead_tree_trunk_02.glb",
		"res://assets/environment/rock/boulder_scanned_01.glb",
		"res://assets/environment/rock/boulder_namaqualand.glb"
	]:
		var sc = load(p) as PackedScene
		var inst = sc.instantiate()
		var mi = inst.find_child("*", true, false) as MeshInstance3D
		if mi and mi.mesh:
			var aabb = mi.mesh.get_aabb()
			print(p, " aabb: pos=", aabb.position, " size=", aabb.size)
		inst.free()
	quit(0)
