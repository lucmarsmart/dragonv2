extends SceneTree

func _initialize() -> void:
	for p in ["res://assets/environment/trees/dead_tree_trunk_02.glb", "res://assets/environment/rock/boulder_scanned_01.glb", "res://assets/environment/rock/boulder_namaqualand.glb"]:
		print("Checking ", p)
		var sc = load(p) as PackedScene
		if not sc:
			print("Failed to load scene")
			continue
		var inst = sc.instantiate()
		print("Instantiated root: ", inst.name, " (", inst.get_class(), ")")
		_print_tree(inst, "  ")
		var mi = inst.find_child("*", true, false) as MeshInstance3D
		print("find_child MeshInstance3D: ", mi)
		if mi and mi.mesh:
			print("  mesh: ", mi.mesh.get_class(), " surfaces: ", mi.mesh.get_surface_count())
			for s in mi.mesh.get_surface_count():
				print("    surface ", s, " mat: ", mi.mesh.surface_get_material(s))
				print("    override mat: ", mi.get_surface_override_material(s))
		inst.free()
	quit(0)

func _print_tree(node: Node, indent: String) -> void:
	for c in node.get_children():
		print(indent, c.name, " (", c.get_class(), ")")
		_print_tree(c, indent + "  ")
