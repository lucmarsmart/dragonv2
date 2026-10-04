@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for f in range(25): await process_frame
	
	var dragon = scene.get_node("Dragon")
	var space = dragon.get_world_3d().direct_space_state
	var ray = PhysicsRayQueryParameters3D.create(Vector3(0, 500, 0), Vector3(0, -100, 0))
	var hit = space.intersect_ray(ray)
	if hit:
		print("Terrain directly below origin: Y = %.2f, normal = %s" % [hit.position.y, hit.normal])
	else:
		print("No terrain found directly below origin!")
	quit(0)
