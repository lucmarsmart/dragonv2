extends "res://scripts/test_dragon_anatomy.gd"

# Same landing/contact test and runtime; only the proof camera differs.
func record() -> void:
	super.record()
	if is_instance_valid(camera) and is_instance_valid(dragon):
		var heading := Basis(Vector3.UP, dragon.rotation.y)
		camera.global_position = dragon.global_position + heading * Vector3(-18, 8, -22)
		camera.look_at(dragon.global_position + Vector3.DOWN)
