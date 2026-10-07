extends SceneTree

func _init():
	print("Testing load of all scripts...")
	assert(load("res://scripts/dragon_controller.gd") != null)
	assert(load("res://scripts/dragon_ground_pose.gd") != null)
	assert(load("res://scripts/dragon_ground_contact.gd") != null)
	assert(load("res://scripts/dragon_wing_contact.gd") != null)
	assert(load("res://scripts/collision_effects.gd") != null)
	print("All scripts compiled cleanly!")
	quit(0)
