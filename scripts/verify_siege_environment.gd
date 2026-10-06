extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var terrain = load("res://assets/models/terrain.glb").instantiate()
	terrain.set_script(load("res://scripts/terrain.gd"))
	world.add_child(terrain)
	var siege = load("res://scripts/siege_environment.gd").new()
	world.add_child(siege)
	await physics_frame
	await physics_frame
	_check(siege.knight_spawn_points.size() == 8, "eight knight spawns")
	_check(siege.turret_spawn_points.size() == 3, "three turret spawns")
	var maximum_error := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed=4187
	for i in 180:
		var p := Vector3(rng.randf_range(-850,850),0,rng.randf_range(-850,850))
		if absf(p.x-300)<110 and absf(p.z-120)<100:
			continue
		var hit: Dictionary = terrain.ground_surface(p)
		_check(not hit.is_empty(), "ground ray %s" % p)
		if not hit.is_empty():
			maximum_error=maxf(maximum_error,absf(hit.position.y-terrain.ground_height(p.x,p.z)))
	_check(maximum_error < 0.005, "triangular height matches physical surface")
	for p in siege.knight_spawn_points:
		var hit: Dictionary = terrain.ground_surface(p)
		_check(not hit.is_empty() and absf(hit.position.y-p.y)<0.005,"knight grounded %s" % p)
	for p in siege.turret_spawn_points:
		var hit: Dictionary = terrain.ground_surface(p)
		_check(not hit.is_empty() and absf(hit.position.y-p.y)<0.005,"ballista grounded %s" % p)
	var gate: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(300,27,235), Vector3(300,27,160), 2))
	_check(gate.is_empty(), "gate approach clear")
	var wall: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(205,27,130),Vector3(245,27,130),2))
	_check(not wall.is_empty(),"physical wall blocks line of sight")
	var ridge: Dictionary = terrain.ground_surface(Vector3(1450,0,-1600))
	_check(not ridge.is_empty(), "mountain upper face supports ground ray")
	for x in [294.0,296.0,298.0,300.0,302.0,304.0,306.0]:
		var rescue_access: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,27.5,108),Vector3(x,27.5,89),2))
		_check(rescue_access.is_empty(), "rescue approach clear x=%s" % x)
	siege.liberate_nest()
	_check(not siege.get_node("CaptiveIronChains").visible, "liberation removes chains")
	siege.reset_nest()
	_check(siege.get_node("CaptiveIronChains").visible, "retry restores captivity")
	var report := {"checks": "terrain-triangles,8-knights,3-platforms,gate,wall,mountain,nest-access,nest-release,nest-reset", "maximum_terrain_height_error_m":maximum_error,"failures":failures}
	FileAccess.open("res://docs/validation/v2/environment-physics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ENVIRONMENT_VERIFY ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
func _check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
