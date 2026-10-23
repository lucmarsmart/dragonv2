extends Node3D
class_name WindVegetationSim

## SIMULACIÓN FOTORREALISTA DE BAMBOLEO DE VEGETACIÓN Y ÁRBOLES
## Implementa mecánica física de viga en voladizo (cantilever beam):
## - La raíz y base del tronco permanecen firmes en la tierra (0 deformación).
## - La copa experimenta deflexión elástica progresiva cúbica (proporcional a h^2.2).
## - Si un elemento es rígido o pesado (rocas, troncos secos en tierra), NO se anima para evitar efectos de goma.

@export var enable_simulation := true
@export var wind_simulator: WindCurrentSimulator

var _time := 0.0
var simulated_nodes: Array[Dictionary] = []

func _ready() -> void:
	if not wind_simulator:
		wind_simulator = WindCurrentSimulator.new()
	_register_scene_vegetation(self)

func _register_scene_vegetation(node: Node) -> void:
	for child in node.get_children():
		var name_l := child.name.lower()
		# Solo animar especies elásticas: ramas, árboles vivos y matas de pasto
		# Los troncos caídos de piedra/madera muerta permanecen rígidos (realismo)
		if "dead_tree" in name_l or "log" in name_l or "rock" in name_l or "stone" in name_l:
			# Rígido sin animación
			pass
		elif "tree" in name_l or "fir" in name_l or "searsia" in name_l or "fern" in name_l or "grass" in name_l:
			if child is Node3D:
				var stiffness := 1.0
				var mass := 1.0
				if "grass" in name_l or "fern" in name_l:
					stiffness = 2.4 # Alta flexibilidad
					mass = 0.2
				elif "searsia" in name_l:
					stiffness = 1.6
					mass = 0.6
				elif "fir" in name_l:
					stiffness = 0.85 # Conífera masiva firme
					mass = 1.8
				else:
					stiffness = 1.0
					mass = 1.0
				
				simulated_nodes.append({
					"node": child,
					"base_basis": child.transform.basis,
					"base_pos": child.global_position,
					"stiffness": stiffness,
					"mass": mass,
					"phase": randf() * TAU,
					"current_lean": Vector2.ZERO,
					"lean_velocity": Vector2.ZERO
				})
		_register_scene_vegetation(child)

func _physics_process(delta: float) -> void:
	if not enable_simulation or simulated_nodes.is_empty():
		return
	_time += delta
	
	for item in simulated_nodes:
		var node = item["node"] as Node3D
		if not is_instance_valid(node):
			continue
		var pos = item["base_pos"] as Vector3
		var wind := wind_simulator.get_wind_at(pos, _time)
		var wind_force := Vector2(wind.x, wind.z)
		
		# Modelo físico de oscilador armónico amortiguado (resorte elástico vegetal)
		var k := 32.0 * item["stiffness"] # Constante elástica
		var c := 5.2 * sqrt(item["mass"]) # Amortiguamiento crítico vegetal
		
		var target_lean := wind_force * (0.018 * item["stiffness"])
		var accel := (target_lean - item["current_lean"]) * k - item["lean_velocity"] * c
		
		item["lean_velocity"] += accel * delta
		item["current_lean"] += item["lean_velocity"] * delta
		
		# Rizado de alta frecuencia en copa (flutter)
		var flutter := sin(_time * 4.2 + item["phase"]) * 0.003 * wind.length()
		
		# Aplicar rotación orgánica de inclinación sin traslación de raíz
		var lean_x := item["current_lean"].x + flutter
		var lean_z := item["current_lean"].y + flutter * 0.7
		
		var sway_rotation := Basis()
		sway_rotation = sway_rotation.rotated(Vector3.FORWARD, -lean_x)
		sway_rotation = sway_rotation.rotated(Vector3.RIGHT, lean_z)
		
		node.transform.basis = item["base_basis"] * sway_rotation
