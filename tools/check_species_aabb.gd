@tool
extends SceneTree

func _init() -> void:
	for sp in ["oak", "birch", "eucalyptus", "pine", "fir"]:
		for v in range(1, 4):
			var p = "res://assets/environment/trees/tree_%s_var%d.res" % [sp, v]
			var m = load(p) as ArrayMesh
			if m:
				print(sp, " v", v, " AABB: ", m.get_aabb(), " surfaces: ", m.get_surface_count())
	quit(0)
