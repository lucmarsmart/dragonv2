@tool
extends SceneTree

func _init() -> void:
	var terrain_script: GDScript = load("res://scripts/terrain.gd")
	var landscape := Node3D.new()
	landscape.name = "Landscape"
	landscape.set_script(terrain_script)
	get_root().add_child(landscape)

	# We can read the internal arrays directly from script instance
	# In terrain.gd, _build_forest() populates the arrays
	var dt = landscape.get_node_or_null("FallenOldGrowthTrunks") as MultiMeshInstance3D
	var sb = landscape.get_node_or_null("ScannedGraniteBoulders_01") as MultiMeshInstance3D
	var nb = landscape.get_node_or_null("NamaqualandMonolithBoulders") as MultiMeshInstance3D

	print("Nodes:")
	print("  dt: ", dt != null, " sb: ", sb != null, " nb: ", nb != null)
	if dt:
		print("  dt vis_end: ", dt.visibility_range_end)
	quit(0)
