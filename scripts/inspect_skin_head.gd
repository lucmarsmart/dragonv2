extends SceneTree

func _init():
	var d = load("res://assets/models/dragon.glb").instantiate()
	var skel: Skeleton3D = null
	for c in d.find_children("*", "Skeleton3D", true, false):
		skel = c
		break
		
	var head_skel_idx = skel.find_bone("Bip001-Head_011")
	var m: MeshInstance3D = skel.get_node("Object_7")
	var skin: Skin = m.skin
	print("Head skel idx: ", head_skel_idx)
	print("Skin bind count: ", skin.get_bind_count() if skin else "no skin")
	
	var head_skin_idx = -1
	if skin:
		for i in range(skin.get_bind_count()):
			if skin.get_bind_bone(i) == head_skel_idx:
				head_skin_idx = i
				print("Head skin idx: ", i, " name: ", skin.get_bind_name(i))
				break
				
	var mesh: ArrayMesh = m.mesh
	var arrays = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	
	var target_bone = head_skin_idx if head_skin_idx != -1 else head_skel_idx
	var head_uvs: Array[Vector2] = []
	for i in range(verts.size()):
		for w in range(4):
			if bones[i * 4 + w] == target_bone and weights[i * 4 + w] > 0.1:
				head_uvs.append(uvs[i])
				break
				
	print("Found head verts: ", head_uvs.size())
	if head_uvs.size() > 0:
		var min_u = 1.0
		var max_u = 0.0
		var min_v = 1.0
		var max_v = 0.0
		for uv in head_uvs:
			min_u = minf(min_u, uv.x)
			max_u = maxf(max_u, uv.x)
			min_v = minf(min_v, uv.y)
			max_v = maxf(max_v, uv.y)
		print("Head UV box: U=[%.3f, %.3f], V=[%.3f, %.3f]" % [min_u, max_u, min_v, max_v])
	quit(0)
