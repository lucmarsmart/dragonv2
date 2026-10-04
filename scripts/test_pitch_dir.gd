@tool
extends SceneTree

func _init():
	var b_pos = Basis.from_euler(Vector3(deg_to_rad(26.0), 0, 0))
	var b_neg = Basis.from_euler(Vector3(-deg_to_rad(26.0), 0, 0))
	print("pitch=+26: -b.z = ", -b_pos.z, " (y component: ", (-b_pos.z).y, ")")
	print("pitch=-26: -b.z = ", -b_neg.z, " (y component: ", (-b_neg.z).y, ")")
	quit(0)
