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
	if dt and dt.multimesh:
		print("First 5 Fallen logs transforms:")
		for i in mini(5, dt.multimesh.instance_count):
			var t = dt.multimesh.get_instance_transform(i)
			print("  Log ", i, ": origin=", t.origin)
			
	var sb = landscape.get_node_or_null("ScannedGraniteBoulders_01") as MultiMeshInstance3D
	if sb and sb.multimesh:
		print("First 5 Scanned boulders transforms:")
		for i in mini(5, sb.multimesh.instance_count):
			var t = sb.multimesh.get_instance_transform(i)
			print("  Boulder ", i, ": origin=", t.origin)
			
	landscape.free()
	quit(0)
