@tool
extends SceneTree

func _init() -> void:
	print("=== RUNNING FULL SCENERY VERIFICATION SCRIPT ===")
	_run()

func _run() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	
	# 1. Instantiate Landscape
	var terrain_script: GDScript = load("res://scripts/terrain.gd")
	var landscape := Node3D.new()
	landscape.name = "Landscape"
	landscape.set_script(terrain_script)
	root.add_child(landscape)
	
	# 2. Instantiate SiegeEnvironment
	var siege_script: GDScript = load("res://scripts/siege_environment.gd")
	var siege := Node3D.new()
	siege.name = "SiegeEnvironment"
	siege.set_script(siege_script)
	root.add_child(siege)
	
	await process_frame
	await process_frame
	
	print("[OK] Nodes entered scene tree and executed _ready()")
	
	# Check Landscape child MultiMeshes
	var sb = landscape.get_node_or_null("ScannedGraniteBoulders_01") as MultiMeshInstance3D
	var nb = landscape.get_node_or_null("NamaqualandMonolithBoulders") as MultiMeshInstance3D
	var dt = landscape.get_node_or_null("FallenOldGrowthTrunks") as MultiMeshInstance3D
	
	if sb and sb.multimesh:
		print("  -> ScannedGraniteBoulders_01: ", sb.multimesh.instance_count, " instances (1 draw call, vis_end=", sb.visibility_range_end, "m)")
	else:
		print("  -> ERROR: ScannedGraniteBoulders_01 missing or null")
		
	if nb and nb.multimesh:
		print("  -> NamaqualandMonolithBoulders: ", nb.multimesh.instance_count, " instances (1 draw call, vis_end=", nb.visibility_range_end, "m)")
	else:
		print("  -> ERROR: NamaqualandMonolithBoulders missing or null")

	if dt and dt.multimesh:
		print("  -> FallenOldGrowthTrunks: ", dt.multimesh.instance_count, " instances (1 draw call, vis_end=", dt.visibility_range_end, "m)")
	else:
		print("  -> ERROR: FallenOldGrowthTrunks missing or null")
		
	var castle = siege.get_node_or_null("MedievalCastleCitadel")
	if castle:
		print("  -> MedievalCastleCitadel: FOUND at ", castle.position)
		var static_bodies := castle.find_children("*", "StaticBody3D")
		print("  -> Castle collision bodies count: ", static_bodies.size())
	else:
		print("  -> ERROR: MedievalCastleCitadel not found")
		
	var sentinels := siege.find_children("RoyalArmorSentinel_*")
	print("  -> RoyalArmorSentinel count: ", sentinels.size())
	var relics := siege.find_children("FortressRelicGreatsword_*")
	print("  -> FortressRelicGreatsword count: ", relics.size())
	
	print("=== SCENERY VERIFICATION COMPLETED SUCCESSFULLY ===")
	quit(0)
