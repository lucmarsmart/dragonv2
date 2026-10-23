@tool
extends SceneTree

func _init() -> void:
	var path := "res://assets/siege/environment/castle_citadel.glb"
	var scene: PackedScene = load(path)
	if not scene:
		print("ERROR: could not load ", path)
		quit(1)
		return
	var inst := scene.instantiate() as Node3D
	print("Loaded scene: ", inst.name)
	for child in inst.find_children("*", "MeshInstance3D"):
		var mi := child as MeshInstance3D
		var aabb := mi.get_aabb()
		print("Mesh: ", mi.name, " AABB pos=", aabb.position, " size=", aabb.size)
		if mi.mesh:
			print("Faces count: ", mi.mesh.get_faces().size() / 3)
	inst.free()
	quit(0)
