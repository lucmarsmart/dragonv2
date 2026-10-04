@tool
extends SceneTree

func _init():
	var d = load("res://assets/models/dragon.glb").instantiate()
	var sk: Skeleton3D = d.find_child("*Skeleton3D*", true, false)
	for c in d.get_children():
		print_meshes(c)
	quit(0)

func print_meshes(n: Node):
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		print("MeshInstance3D: %s, skin: %s" % [mi.name, mi.skin != null])
	for ch in n.get_children():
		print_meshes(ch)
