@tool
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- VERIFYING KNIGHT SCALE ---")
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for i in 5:
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
	
	if knights.is_empty() or captains.is_empty():
		print("FAIL: Missing enemies")
		quit(1)
		return
		
	var knight = knights[0]
	var captain = captains[0]
	
	print("Knight scale: ", knight.knight_scale, " visual scale: ", knight.visual.scale)
	print("Captain scale: ", captain.knight_scale, " visual scale: ", captain.visual.scale)
	
	assert(is_equal_approx(knight.knight_scale, 2.0), "Knight scale should be 2.0")
	assert(is_equal_approx(captain.knight_scale, 2.4), "Captain scale should be 2.4")
	assert(knight.visual.scale.is_equal_approx(Vector3(2.0, 2.0, 2.0)), "Knight visual scale match")
	assert(captain.visual.scale.is_equal_approx(Vector3(2.4, 2.4, 2.4)), "Captain visual scale match")
	
	var knight_col = knight.find_child("CollisionShape3D", true, false)
	var captain_col = captain.find_child("CollisionShape3D", true, false)
	print("Knight shape height: ", knight_col.shape.height, " radius: ", knight_col.shape.radius)
	print("Captain shape height: ", captain_col.shape.height, " radius: ", captain_col.shape.radius)
	
	assert(is_equal_approx(knight_col.shape.height, 1.9 * 2.0), "Knight shape height")
	assert(is_equal_approx(captain_col.shape.height, 1.9 * 2.4), "Captain shape height")
	
	print("ALL CHECKS PASSED: Knights and Captain are properly scaled!")
	scene.queue_free()
	quit(0)
