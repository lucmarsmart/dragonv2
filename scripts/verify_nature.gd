extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("STARTING NATURE VERIFICATION...")
	var world := Node3D.new()
	root.add_child(world)

	var terrain = load("res://assets/models/terrain.glb").instantiate()
	terrain.set_script(load("res://scripts/terrain.gd"))
	world.add_child(terrain)

	var trees_count: int = terrain._tree_transforms.size()
	print("VERIFY: Total tree count = ", trees_count)

	var forest_nodes_count: int = terrain._forest_nodes.size()
	print("VERIFY: Total forest MultiMesh LOD nodes = ", forest_nodes_count, " (expected 64)")

	# Check uniqueness of trees
	var unique_scales := {}
	var unique_pos := {}
	var trees_near_stream := 0
	for t in terrain._tree_transforms:
		var skey = "%.4f,%.4f,%.4f" % [t.basis.get_scale().x, t.basis.get_scale().y, t.basis.get_scale().z]
		var pkey = "%.2f,%.2f" % [t.origin.x, t.origin.z]
		unique_scales[skey] = true
		unique_pos[pkey] = true
		if t.origin.z >= -200.0 and t.origin.z <= 300.0:
			var d_str = absf(t.origin.x - terrain.stream_west_center(t.origin.z))
			if d_str >= 16.0 and d_str <= 45.0:
				trees_near_stream += 1
	print("VERIFY: Unique tree scales = ", unique_scales.size(), " / ", trees_count)
	print("VERIFY: Unique tree positions = ", unique_pos.size(), " / ", trees_count)
	print("VERIFY: Trees bordering west stream (16m-45m) = ", trees_near_stream)

	# Check lake position, depth and gentle shore slope (Foto 4)
	var lake_gh = terrain.ground_height(-520, -280)
	print("VERIFY: Lake center ground height = ", lake_gh, " (water level is ", terrain.get_water_level(), ")")
	var is_lake_water = terrain.is_water_at(Vector3(-520, lake_gh, -280))
	print("VERIFY: is_water_at lake = ", is_lake_water)
	var lake_shore_h = terrain.ground_height(-520 + 95, -280)
	var lake_bank_slope = (terrain.ground_height(-520 + 105, -280) - terrain.ground_height(-520 + 85, -280)) / 20.0
	print("VERIFY: Lake shore height at 95m = ", lake_shore_h, ", slope = ", lake_bank_slope)

	# Check west stream and gentle bank slope (Fotos 2 & 3 y Video)
	var sx = terrain.stream_west_center(50)
	var stream_gh = terrain.ground_height(sx, 50)
	print("VERIFY: West Stream at z=50 (x=", sx, ") ground height = ", stream_gh)
	var is_stream_water = terrain.is_water_at(Vector3(sx, stream_gh, 50))
	print("VERIFY: is_water_at west stream = ", is_stream_water)
	var stream_bank_slope = (terrain.ground_height(sx + 20, 50) - terrain.ground_height(sx + 5, 50)) / 15.0
	print("VERIFY: West stream bank slope (5m to 20m) = ", stream_bank_slope)

	# Check east stream
	var ex = terrain.stream_east_center(-50)
	var stream_e_gh = terrain.ground_height(ex, -50)
	print("VERIFY: East Stream at z=-50 (x=", ex, ") ground height = ", stream_e_gh)
	var is_east_stream_water = terrain.is_water_at(Vector3(ex, stream_e_gh, -50))
	print("VERIFY: is_east_stream_water = ", is_east_stream_water)

	# Check rolling hills elevation (Foto 1)
	var hill_h = terrain.ground_height(-600, 450)
	print("VERIFY: Rolling hill ground height at (-600, 450) = ", hill_h)

	# Check arena protection
	var arena_h = terrain.ground_height(300, 120)
	print("VERIFY: Arena center ground height = ", arena_h, " (expected 24.0)")

	var passed = trees_count > 8000 and forest_nodes_count == 64 and is_lake_water and is_stream_water and is_east_stream_water and absf(arena_h - 24.0) < 0.01 and lake_bank_slope < 0.40 and stream_bank_slope < 0.45 and trees_near_stream > 30
	print("ALL CHECKS PASSED: ", passed)

	quit(0 if passed else 1)
