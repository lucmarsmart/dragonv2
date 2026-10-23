extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)

	for f in 10:
		await process_frame

	var landscape = main_scene.get_node_or_null("NaturalLandscape")
	if not landscape:
		print("No NaturalLandscape")
		quit(1)
		return

	var dt = landscape.get_node_or_null("FallenOldGrowthTrunks") as MultiMeshInstance3D
	var sb = landscape.get_node_or_null("ScannedGraniteBoulders_01") as MultiMeshInstance3D
	var nb = landscape.get_node_or_null("NamaqualandMonolithBoulders") as MultiMeshInstance3D

	print("dt: ", dt, " visible: ", dt.visible if dt else false)
	if dt:
		print("  multimesh: ", dt.multimesh)
		print("  mesh: ", dt.multimesh.mesh if dt.multimesh else null)
		print("  instance_count: ", dt.multimesh.instance_count if dt.multimesh else 0)
		print("  visibility_range_end: ", dt.visibility_range_end)

	print("sb: ", sb, " visible: ", sb.visible if sb else false)
	if sb:
		print("  multimesh: ", sb.multimesh)
		print("  mesh: ", sb.multimesh.mesh if sb.multimesh else null)
		print("  instance_count: ", sb.multimesh.instance_count if sb.multimesh else 0)
		print("  visibility_range_end: ", sb.visibility_range_end)

	print("log_transforms count: ", landscape.log_transforms.size())
	for i in min(3, landscape.log_transforms.size()):
		var t = landscape.log_transforms[i]
		print("log[", i, "] = origin: ", t.origin, " scale: ", t.basis.get_scale())

	print("boulder_transforms count: ", landscape.boulder_transforms.size())
	for i in min(3, landscape.boulder_transforms.size()):
		var t = landscape.boulder_transforms[i]
		print("boulder[", i, "] = origin: ", t.origin, " scale: ", t.basis.get_scale())

	quit(0)
