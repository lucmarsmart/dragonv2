@tool
extends SceneTree

func _init() -> void:
	var terrain_script: GDScript = load("res://scripts/terrain.gd")
	var landscape := Node3D.new()
	landscape.name = "Landscape"
	landscape.set_script(terrain_script)
	get_root().add_child(landscape)
	
	for pos in [
		Vector2(180, 110),
		Vector2(200, 120),
		Vector2(160, 80),
		Vector2(300, 120),
		Vector2(300, 180),
		Vector2(32, 15)
	]:
		var h = landscape.ground_height(pos.x, pos.y)
		print("Coord (", pos.x, ", ", pos.y, ") -> ground_height = ", h)
	landscape.free()
	quit(0)
