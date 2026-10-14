@tool
extends SceneTree

func _init() -> void:
	var pine_scene = load("res://assets/environment/pine/pine_lod0.glb") as PackedScene
	var inst_p = pine_scene.instantiate()
	var mi_p = inst_p.find_child("*", true, false) as MeshInstance3D
	if mi_p and mi_p.mesh:
		print("Pine AABB: ", mi_p.mesh.get_aabb())
	inst_p.free()

	var fir_scene = load("res://assets/environment/fir/fir_lod0.glb") as PackedScene
	var inst_f = fir_scene.instantiate()
	var mi_f = inst_f.find_child("*", true, false) as MeshInstance3D
	if mi_f and mi_f.mesh:
		print("Fir AABB: ", mi_f.mesh.get_aabb())
	inst_f.free()

	quit(0)
