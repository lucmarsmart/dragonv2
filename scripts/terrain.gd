extends Node3D

# ==============================================================================
# GESTOR DE TERRENO Y COLISIONES FÍSICAS
# Genera colisiones trimesh precisas para todas las montañas y valles
# ==============================================================================

func _ready() -> void:
	_setup_terrain_collisions(self)
	_setup_world_boundaries()

func _setup_terrain_collisions(node: Node) -> void:
	if node is MeshInstance3D:
		var has_col = false
		for child in node.get_children():
			if child is StaticBody3D:
				has_col = true
				break
		if not has_col:
			node.create_trimesh_collision()
			print("Colisión física trimesh generada con éxito para terreno: ", node.name)
			
	for child in node.get_children():
		_setup_terrain_collisions(child)

func _setup_world_boundaries() -> void:
	# Plano límite inferior de seguridad a nivel del lecho del valle (Y = 0)
	# para evitar caídas al vacío infinito en los bordes del mapa
	var floor_body = StaticBody3D.new()
	floor_body.name = "SafetyWorldFloor"
	var col_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(6000.0, 10.0, 6000.0)
	col_shape.shape = box
	col_shape.position = Vector3(0, -5.0, 0)
	floor_body.add_child(col_shape)
	add_child(floor_body)
	print("Límite inferior del mundo (SafetyWorldFloor 6000x6000m) activado.")
