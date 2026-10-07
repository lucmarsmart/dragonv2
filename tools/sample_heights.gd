extends SceneTree

func _init():
	var terrain = load("res://assets/models/terrain.glb").instantiate()
	terrain.set_script(load("res://scripts/terrain.gd"))
	root.add_child(terrain)
	print("--- TERRAIN ELEVATION SAMPLES ---")
	for z in [-700, -500, -300, -100, 100, 300, 500, 700]:
		var line = "z=%4d | " % z
		for x in [-700, -500, -300, -100, 0, 100, 300, 500, 700]:
			line += "x=%4d: %5.1fm | " % [x, terrain.ground_height(x, z)]
		print(line)
	quit(0)
