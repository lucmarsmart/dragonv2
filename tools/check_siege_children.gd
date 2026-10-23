@tool
extends SceneTree

func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var terrain_script: GDScript = load("res://scripts/terrain.gd")
	var landscape := Node3D.new()
	landscape.name = "Landscape"
	landscape.set_script(terrain_script)
	root.add_child(landscape)
	var siege_script: GDScript = load("res://scripts/siege_environment.gd")
	var siege := Node3D.new()
	siege.name = "SiegeEnvironment"
	siege.set_script(siege_script)
	root.add_child(siege)
	
	await process_frame
	await process_frame
	
	print("Children of SiegeEnvironment:")
	for c in siege.get_children():
		print(" - ", c.name, " (class: ", c.get_class(), ")")
	quit(0)
