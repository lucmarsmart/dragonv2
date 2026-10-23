@tool
extends SceneTree

func _init() -> void:
	for p in [
		"res://assets/environment/rock/boulder_scanned_01.glb",
		"res://assets/environment/rock/boulder_namaqualand.glb",
		"res://assets/environment/trees/dead_tree_trunk_02.glb",
		"res://assets/siege/environment/castle_citadel.glb"
	]:
		var sc: PackedScene = load(p)
		if not sc:
			print("FAIL: ", p)
			continue
		var inst = sc.instantiate()
		print("--- Asset: ", p, " ---")
		for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D"):
			print("  Node: ", mi.name)
			if mi.mesh:
				print("    Mesh surfaces: ", mi.mesh.get_surface_count(), " AABB: ", mi.mesh.get_aabb())
				for s in mi.mesh.get_surface_count():
					var mat = mi.get_surface_override_material(s)
					if not mat:
						mat = mi.mesh.surface_get_material(s)
					print("    Surface ", s, " mat: ", mat, " class: ", mat.get_class() if mat else "none")
		inst.free()
	quit(0)
