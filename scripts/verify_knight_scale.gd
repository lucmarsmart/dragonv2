@tool
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- VERIFYING KNIGHT SCALE ---")
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for i in 10:
		await process_frame
		await physics_frame
	
	var combat = scene.get_node("SiegeCombat")
	if not combat:
		print("FAIL: SiegeCombat not found")
		quit(1)
		return
		
	var knights: Array = []
	var captains: Array = []
	for enemy in combat.enemies:
		if enemy.kind == "knight":
			knights.append(enemy)
		elif enemy.kind == "captain":
			captains.append(enemy)
			
	print("Found %d knights and %d captains" % [knights.size(), captains.size()])
	
	var knight = knights[0]
	var captain = captains[0]
	
	print("Knight scale: ", knight.knight_scale, " visual scale: ", knight.visual.scale)
	print("Captain scale: ", captain.knight_scale, " visual scale: ", captain.visual.scale)
	
	assert(is_equal_approx(knight.knight_scale, 2.0), "Knight scale should be 2.0")
	assert(is_equal_approx(captain.knight_scale, 2.4), "Captain scale should be 2.4")
	assert(knight.visual.scale.is_equal_approx(Vector3(2.0, 2.0, 2.0)), "Knight visual scale match")
	assert(captain.visual.scale.is_equal_approx(Vector3(2.4, 2.4, 2.4)), "Captain visual scale match")
	
	var knight_cols = knight.find_children("*", "CollisionShape3D", false, false)
	var captain_cols = captain.find_children("*", "CollisionShape3D", false, false)
	assert(knight_cols.size() > 0, "Knight must have collision shape")
	assert(captain_cols.size() > 0, "Captain must have collision shape")
	
	var knight_shape: CapsuleShape3D = knight_cols[0].shape
	var captain_shape: CapsuleShape3D = captain_cols[0].shape
	print("Knight capsule height: ", knight_shape.height, " radius: ", knight_shape.radius)
	print("Captain capsule height: ", captain_shape.height, " radius: ", captain_shape.radius)
	
	assert(is_equal_approx(knight_shape.height, 1.9 * 2.0), "Knight shape height")
	assert(is_equal_approx(captain_shape.height, 1.9 * 2.4), "Captain shape height")
	assert(is_equal_approx(knight_shape.radius, 0.42 * 2.0), "Knight shape radius")
	assert(is_equal_approx(captain_shape.radius, 0.42 * 2.4), "Captain shape radius")
	
	print("SUCCESS: ALL KNIGHT SCALE CHECKS PASSED PERFECTLY!")
	scene.queue_free()
	quit(0)
