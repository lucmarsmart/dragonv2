@tool
extends SceneTree

func _init() -> void:
	var yaw := 0.75
	var dir := Vector3(cos(yaw), 0.0, sin(yaw))
	var p1 := Vector3(10.0, 5.0, 10.0)
	var p2 := Vector3(14.0, 5.8, 13.0)
	var tangent := (p2 - p1).normalized()
	var normal := Vector3.UP
	var side := tangent.cross(normal).normalized()
	var up := side.cross(tangent).normalized()
	var b := Basis(tangent, up, side).scaled(Vector3.ONE * 1.2)
	print("Basis determinant: ", b.determinant())
	print("Basis valid: ", not is_nan(b.determinant()))
	quit(0)
