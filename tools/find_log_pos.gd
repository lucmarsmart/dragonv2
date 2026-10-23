@tool
extends SceneTree

func _init() -> void:
	_run()

func _run() -> void:
	var terrain_script: GDScript = load("res://scripts/terrain.gd")
	var landscape := Node3D.new()
	landscape.name = "Landscape"
	landscape.set_script(terrain_script)
	get_root().add_child(landscape)

	await process_frame
	await process_frame

	var dt = landscape.get_node_or_null("FallenOldGrowthTrunks") as MultiMeshInstance3D
	var sb = landscape.get_node_or_null("ScannedGraniteBoulders_01") as MultiMeshInstance3D
	var nb = landscape.get_node_or_null("NamaqualandMonolithBoulders") as MultiMeshInstance3D

	# Since get_instance_transform isn't readable in headless, let's find them from the script's internal logic
	# Let's see the first log position by printing during placement
	print("Checking done")
	landscape.free()
	quit(0)
