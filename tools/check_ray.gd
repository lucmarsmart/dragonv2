extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	for f in 5:
		await process_frame

	var landscape = main_scene.get_node_or_null("NaturalLandscape")
	var l_pos = landscape.log_transforms[0].origin
	var cam_pos = l_pos + Vector3(3.5, 1.6, 3.5)
	print("l_pos: ", l_pos)
	print("cam_pos: ", cam_pos)
	print("ground_height at l_pos: ", landscape.ground_height(l_pos.x, l_pos.z))
	print("ground_height at cam_pos: ", landscape.ground_height(cam_pos.x, cam_pos.z))

	# Sample 10 points between cam_pos and l_pos
	for i in 11:
		var t = float(i) / 10.0
		var p = cam_pos.lerp(l_pos, t)
		var gh = landscape.ground_height(p.x, p.z)
		print("t=", t, " p.y=", p.y, " ground_height=", gh, " diff(p.y - gh)=", p.y - gh)

	quit(0)
