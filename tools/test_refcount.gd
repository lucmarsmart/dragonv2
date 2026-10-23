@tool
extends SceneTree

func _init() -> void:
	var path := "res://assets/environment/rock/boulder_scanned_01.glb"
	var sc := load(path) as PackedScene
	var inst := sc.instantiate()
	var mi := inst.find_child("*", true, false) as MeshInstance3D
	var mesh: Mesh = mi.mesh
	inst.free()
	print("Mesh after free: ", mesh, " surfaces: ", mesh.get_surface_count())
	quit(0)
