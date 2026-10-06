extends SceneTree
var failures: Array[String] = []
func _initialize(): call_deferred("run_checks")
func check(condition: bool, message: String):
	if not condition:
		failures.append(message)
		push_error(message)
func run_checks():
	var scene=Node3D.new()
	root.add_child(scene)
	var terrain=load("res://assets/models/terrain.glb").instantiate()
	terrain.set_script(load("res://scripts/terrain.gd"))
	scene.add_child(terrain)
	await physics_frame
	await physics_frame
	check(terrain.is_in_group("landscape"), "LANDSCAPE group missing")
	check(terrain.get_node_or_null("SafetyWorldFloor") == null, "Invisible safety floor remains")
	check(terrain.is_water_at(Vector3(0, 0, 0)), "River center is not water")
	check(not terrain.is_water_at(Vector3(180, 100, 120)), "Dry hill incorrectly water")
	var landing: Vector3=terrain.find_landing_site(Vector3(0, 120, 0))
	check(not terrain.is_water_at(landing), "Landing site is submerged")
	var space=terrain.get_world_3d().direct_space_state
	for p in [Vector3(180, 0, 120), Vector3(110, 0, 0), Vector3(1200, 0, 120), Vector3(2100, 0, 700)]:
		var query=PhysicsRayQueryParameters3D.create(p + Vector3.UP*1000, p - Vector3.UP*1000)
		var hit=space.intersect_ray(query)
		check(not hit.is_empty(), "Visible terrain/coast/ridge has no collision at " + str(p))
		if not hit.is_empty():
			check(hit.normal.y > 0.0, "Collider faces downward at " + str(p))
	print("ENVIRONMENT CHECKS: ", failures.size(), " failures; dry landing ", landing)
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
