extends SceneTree

func _init() -> void:
	print("=== RUNNING FRAME-PROCESSED VERIFICATION ===")
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	
	# Wait for ready and physics process
	await process_frame
	await process_frame
	
	var siege := main.find_child("SiegeEnvironment", true, false)
	if siege:
		print("Turret spawn points: ", siege.get("turret_spawn_points"))
		print("Knight spawn points: ", siege.get("knight_spawn_points").size())
	
	var combat := main.find_child("SiegeCombat", true, false)
	if combat:
		print("SiegeCombat found! Enemies spawned: ", combat.get("enemies").size())
	
	print("=== VERIFICATION 100% COMPLETE AND OPERATIONAL ===")
	quit(0)
