@tool
extends SceneTree

func _init() -> void:
	var fir_scene = load("res://assets/environment/fir/fir_lod0.glb") as PackedScene
	var fir_inst = fir_scene.instantiate()
	var fir_mi = fir_inst.find_child("*", true, false) as MeshInstance3D
	if fir_mi and fir_mi.mesh:
		print("FIR LOD0 AABB: ", fir_mi.mesh.get_aabb())
	fir_inst.free()

	var pine_scene = load("res://assets/environment/pine/pine_lod0.glb") as PackedScene
	var pine_inst = pine_scene.instantiate()
	var pine_mi = pine_inst.find_child("*", true, false) as MeshInstance3D
	if pine_mi and pine_mi.mesh:
		print("PINE LOD0 AABB: ", pine_mi.mesh.get_aabb())
	pine_inst.free()

	quit(0)
