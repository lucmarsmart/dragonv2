extends "res://scripts/test_dragon_anatomy.gd"

# Front view of the flat landing regression; runtime and assertions unchanged.
func record() -> void:
	super.record()
	if is_instance_valid(camera) and is_instance_valid(dragon):
		var heading := Basis(Vector3.UP, dragon.rotation.y)
		camera.global_position = dragon.global_position + heading * Vector3(0, 9, -30)
		camera.look_at(dragon.global_position + Vector3.DOWN)
