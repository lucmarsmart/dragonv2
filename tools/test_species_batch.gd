@tool
extends SceneTree

func _init() -> void:
	print("Testing tree species loading and MultiMesh batching...")
	var species_names = ["oak", "eucalyptus", "birch", "pine", "fir"]
	var total_meshes = 0
	for sp in species_names:
		for v in range(1, 4):
			var p = "res://assets/environment/trees/tree_%s_var%d.res" % [sp, v]
			var m = load(p) as Mesh
			if m:
				total_meshes += 1
				var mm = MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = m
				mm.instance_count = 100
				for i in 100:
					mm.set_instance_transform(i, Transform3D(Basis(), Vector3(i * 2.0, 0, 0)))
				var mmi = MultiMeshInstance3D.new()
				mmi.multimesh = mm
				root.add_child(mmi)
				mmi.free()
			else:
				printerr("Failed to load: ", p)
	print("Successfully verified ", total_meshes, " / 15 species meshes in MultiMesh!")
	quit(0 if total_meshes == 15 else 1)
