extends SceneTree

func _init():
	var d = load("res://assets/models/dragon.glb").instantiate()
	for m: MeshInstance3D in d.find_children("*", "MeshInstance3D", true, false):
		var mesh: ArrayMesh = m.mesh
		print("Mesh: ", m.name, " surfaces: ", mesh.get_surface_count())
		var arrays = mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		print("  verts: ", verts.size(), " uvs: ", uvs.size())
		
		# Find min/max bounds in local space
		var min_p = Vector3(999,999,999)
		var max_p = Vector3(-999,-999,-999)
		for v in verts:
			min_p = min_p.min(v)
			max_p = max_p.max(v)
		print("  bounds: min=", min_p, " max=", max_p)
		
		# Check ventral vertices (lower Y, underbelly)
		var ventral_count = 0
		for i in range(verts.size()):
			if verts[i].y < min_p.y + (max_p.y - min_p.y) * 0.35 and normals[i].y < -0.1:
				ventral_count += 1
		print("  ventral vertices: ", ventral_count)
	quit(0)
