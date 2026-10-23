@tool
extends SceneTree

func _init() -> void:
	var box := BoxMesh.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = 1
	var t0 := Transform3D(Basis.IDENTITY, Vector3(10, 20, 30))
	mm.set_instance_transform(0, t0)
	print("Buffer size: ", mm.buffer.size())
	print("Buffer floats: ", mm.buffer)
	quit(0)
