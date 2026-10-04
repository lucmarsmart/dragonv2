@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for f in range(5): await process_frame
	
	var terrain = scene.get_node("NaturalLandscape")
	print("Terrain global_transform: ", terrain.global_transform)
	
	# Find static bodies and collision shapes
	var q = [terrain]
	while q.size() > 0:
		var c = q.pop_front()
		if c is StaticBody3D:
			print("StaticBody3D: ", c.name, " transform: ", c.global_transform)
			for ch in c.get_children():
				if ch is CollisionShape3D:
					print("  CollisionShape3D shape: ", ch.shape, " pos: ", ch.position)
		for ch in c.get_children(): q.append(ch)
		
	# Ray from high up directly down at (0, 0)
	var space = terrain.get_world_3d().direct_space_state
	for x in [-50, 0, 50]:
		for z in [-50, 0, 50]:
			var ray = PhysicsRayQueryParameters3D.create(Vector3(x, 1000, z), Vector3(x, -500, z))
			var hit = space.intersect_ray(ray)
			if hit:
				print("Ray at (%d, %d) hit at: %s" % [x, z, hit.position])
			else:
				print("Ray at (%d, %d) MISS!" % [x, z])
	quit(0)
