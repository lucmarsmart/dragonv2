@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(5): await process_frame
	
	var dragon = scene.get_node("Dragon")
	var cam = scene.get_node("FlightCamera")
	
	for f in range(20): await process_frame
	
	var forward = -dragon.global_transform.basis.z.normalized()
	var up = dragon.global_transform.basis.y.normalized()
	var saddle = dragon.global_position + (up * 0.5)
	var desired_pos = saddle - (forward * cam.distance) + (up * cam.height)
	
	var space_state = cam.get_world_3d().direct_space_state
	var ray_query = PhysicsRayQueryParameters3D.create(saddle, desired_pos)
	if dragon is CollisionObject3D:
		ray_query.exclude = [dragon.get_rid()]
		
	var hit = space_state.intersect_ray(ray_query)
	print("Ray query from: ", saddle, " to ", desired_pos)
	if hit:
		print("HIT COLLIDER: ", hit.collider, " at ", hit.position)
	else:
		print("NO HIT. Desired distance is unobstructed.")
		
	print("Camera distance: ", cam.distance)
	print("Camera global pos: ", cam.global_position)
	print("Dragon global pos: ", dragon.global_position)
	print("Actual Cam-Dragon distance: ", cam.global_position.distance_to(dragon.global_position))
	
	quit(0)
