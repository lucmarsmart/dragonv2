@tool
extends Node3D

const BODY_MATERIAL = preload("res://materials/dragon_body_material.tres")
const WING_MATERIAL = preload("res://materials/dragon_wing_material.tres")

var wing_materials: Array[ShaderMaterial] = []

func _ready() -> void:
	apply_materials()

func apply_materials(target_root: Node = null) -> void:
	wing_materials.clear()
	var search_node: Node = target_root if target_root != null else self
	var mesh_nodes: Array[Node] = search_node.find_children("*", "MeshInstance3D", true, false)
	if mesh_nodes.is_empty() and get_parent() != null and target_root == null:
		mesh_nodes = get_parent().find_children("*", "MeshInstance3D", true, false)
	
	for node: Node in mesh_nodes:
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance == null or instance.mesh == null:
			continue
		for surface: int in instance.mesh.get_surface_count():
			var mat: Material = instance.mesh.surface_get_material(surface)
			var std_mat: StandardMaterial3D = mat as StandardMaterial3D
			var res_name: String = ""
			if std_mat != null:
				res_name = std_mat.resource_name
			else:
				res_name = instance.name
			
			if instance.name == "Object_7" or ("body02_Inst" in res_name and not "body02_2" in res_name):
				# ALAS DE DRAGÓN (Object_7): Patagio ámbar vivo, vascularización y SSS solar
				var wing_mat: ShaderMaterial = WING_MATERIAL.duplicate() as ShaderMaterial
				if std_mat != null and std_mat.albedo_texture != null:
					wing_mat.set_shader_parameter("skin_albedo", std_mat.albedo_texture)
				if std_mat != null and std_mat.normal_texture != null:
					wing_mat.set_shader_parameter("skin_normal", std_mat.normal_texture)
				instance.set_surface_override_material(surface, wing_mat)
				wing_materials.append(wing_mat)
				print("Applied WING_MATERIAL to ", instance.name, " (alas translúcidas ámbar)")
			else:
				# CUERPO Y CABEZA (Object_8): Escamas gris carbón/pizarra, placas gulares crema, un solo ojo por lado
				var body_mat: ShaderMaterial = BODY_MATERIAL.duplicate() as ShaderMaterial
				if std_mat != null and std_mat.albedo_texture != null:
					body_mat.set_shader_parameter("skin_albedo", std_mat.albedo_texture)
				if std_mat != null and std_mat.normal_texture != null:
					body_mat.set_shader_parameter("skin_normal", std_mat.normal_texture)
				instance.set_surface_override_material(surface, body_mat)
				print("Applied BODY_MATERIAL to ", instance.name, " (escamas 3D carbón y placas gulares)")

func update_aero_params(wind_speed: float, billow: float, flutter: float) -> void:
	for mat: ShaderMaterial in wing_materials:
		mat.set_shader_parameter("aero_wind_speed", wind_speed)
		mat.set_shader_parameter("aero_billow_amount", billow)
		mat.set_shader_parameter("aero_flutter_intensity", flutter)
