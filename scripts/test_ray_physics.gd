@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for f in range(25): await process_frame
	
	var dragon = scene.get_node("Dragon")
	var space = dragon.get_world_3d().direct_space_state
	
	for y in [150.0, 135.0, 125.0]:
		dragon.global_position = Vector3(0, y, -11.0)
		for f in range(2): await physics_frame
		var ray = PhysicsRayQueryParameters3D.create(dragon.global_position, dragon.global_position + Vector3.DOWN * 60.0)
		ray.exclude = [dragon.get_rid()]
		var hit = space.intersect_ray(ray)
		if hit:
			print("At Y=%.1f -> Hit at %s (dist=%.2f)" % [y, hit.position, dragon.global_position.distance_to(hit.position)])
		else:
			print("At Y=%.1f -> No hit!" % y)
	quit(0)
