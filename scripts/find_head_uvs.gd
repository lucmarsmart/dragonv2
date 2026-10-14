extends SceneTree

func _init():
	var d = load("res://assets/models/dragon.glb").instantiate()
	var skel: Skeleton3D = null
	for c in d.find_children("*", "Skeleton3D", true, false):
		skel = c
		break
		
	var head_idx = skel.find_bone("Bip001-Head_011")
	var m: MeshInstance3D = skel.get_node("Object_7")
	var mesh: ArrayMesh = m.mesh
	var arrays = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	
	var head_uvs: Array[Vector2] = []
	for i in range(verts.size()):
		# Each vertex has 4 bone indices and 4 weights
		for w in range(4):
			if bones[i * 4 + w] == head_idx and weights[i * 4 + w] > 0.3:
				head_uvs.append(uvs[i])
				break
				
	var min_uv = Vector2(1,1)
	var max_uv = Vector2(0,0)
	for uv in head_uvs:
		min_uv = min_uv.min(uv)
		max_uv = max_uv.max(uv)
		
	print("Head vertices count: ", head_uvs.size())
	print("Head UV bounds: min=", min_uv, " max=", max_uv)
	
	# Save head UV bounding box to json
	var f = FileAccess.open("head_uv_bounds.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"min_u": min_uv.x, "min_v": min_uv.y,
		"max_u": max_uv.x, "max_v": max_uv.y,
		"uvs": head_uvs.map(func(v): return [v.x, v.y])
	}))
	quit(0)
