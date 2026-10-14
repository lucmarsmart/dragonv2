@tool
extends SceneTree

func _init() -> void:
	var sh = load("res://shaders/terrain.gdshader")
	if sh == null:
		print("SHADER LOAD FAILED!")
	else:
		print("SHADER LOADED OK: ", sh)
		var mat = ShaderMaterial.new()
		mat.shader = sh
		print("MATERIAL CREATED OK")
	quit()
