@tool
extends SceneTree

func _init() -> void:
	print("--- INSPECTING FIR ---")
	_inspect("res://assets/environment/fir/fir_lod0.glb")
	print("--- INSPECTING PINE ---")
	_inspect("res://assets/environment/pine/pine_lod0.glb")
	quit()

func _inspect(path: String) -> void:
	var res = load(path)
	if not res:
		print("Failed to load ", path)
		return
	var inst = res.instantiate()
	_recurse_node(inst, "")
	inst.free()

func _recurse_node(n: Node, indent: String) -> void:
	print(indent, n.name, " (", n.get_class(), ")")
	if n is MeshInstance3D:
		var m: Mesh = n.mesh
		if m:
			print(indent, "  Mesh: surfaces=", m.get_surface_count())
			for s in m.get_surface_count():
				var mat = m.surface_get_material(s)
				if mat == null:
					mat = n.get_surface_override_material(s)
				print(indent, "    Surface ", s, " mat: ", mat, " class: ", mat.get_class() if mat else "null")
				if mat is StandardMaterial3D:
					print(indent, "      albedo_tex: ", mat.albedo_texture.resource_path if mat.albedo_texture else "null")
					print(indent, "      normal_tex: ", mat.normal_texture.resource_path if mat.normal_texture else "null")
					print(indent, "      rough_tex: ", mat.roughness_texture.resource_path if mat.roughness_texture else "null")
	for c in n.get_children():
		_recurse_node(c, indent + "  ")
