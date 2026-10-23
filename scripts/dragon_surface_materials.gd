@tool
extends Node3D

const BODY_MATERIAL = preload("res://materials/dragon_body_material.tres")
const WING_MATERIAL = preload("res://materials/dragon_wing_material.tres")

const SYRAX_ALBEDO_PATH = "res://assets/models/bipedal_dragon/textures/T_Syrax_Master_Albedo.png"
const SYRAX_NORMAL_PATH = "res://assets/models/bipedal_dragon/textures/T_Syrax_Master_Normal.png"
const SYRAX_ROUGHNESS_PATH = "res://assets/models/bipedal_dragon/textures/T_Syrax_Master_Roughness.png"

static var _texture_cache: Dictionary = {}

var wing_materials: Array[ShaderMaterial] = []

func _ready() -> void:
	apply_materials()

static func _load_texture_safe(res_path: String) -> Texture2D:
	if res_path.is_empty():
		return null
	if _texture_cache.has(res_path):
		return _texture_cache[res_path]
	
	var tex: Texture2D = null
	
	# 1) Intento vía ResourceLoader si el recurso está importado
	if ResourceLoader.exists(res_path):
		var res: Resource = ResourceLoader.load(res_path)
		if res is Texture2D:
			tex = res as Texture2D
	
	# 2) Fallback infalible directo desde archivo en disco (evita fallos de parseo/importación)
	if tex == null:
		var global_path: String = ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(global_path):
			var img: Image = Image.load_from_file(global_path)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	
	if tex != null:
		_texture_cache[res_path] = tex
	else:
		push_warning("DragonSurfaceMaterials: No se pudo cargar textura: " + res_path)
	
	return tex

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
			
			if instance.name == "SK_Wyvern_Biped" or "Syrax" in res_name or "wyvern" in instance.name.to_lower():
				# WYVERN BIPEDAL DRAGON (Syrax):
				# StandardMaterial3D PBR fiel al atlas anatómico 4K (Dorso obsidiana, vientre marfil, alas, cuernos y garras)
				# Cull disabled para visibilidad de doble cara en alas.
				var wyvern_mat: StandardMaterial3D = null
				if std_mat != null:
					wyvern_mat = std_mat.duplicate() as StandardMaterial3D
				else:
					wyvern_mat = StandardMaterial3D.new()
				
				wyvern_mat.resource_name = "M_Syrax_Master"
				wyvern_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				wyvern_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				wyvern_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
				
				var alb: Texture2D = _load_texture_safe(SYRAX_ALBEDO_PATH)
				if alb != null:
					wyvern_mat.albedo_texture = alb
				elif std_mat != null and std_mat.albedo_texture != null:
					wyvern_mat.albedo_texture = std_mat.albedo_texture
				
				var nrm: Texture2D = _load_texture_safe(SYRAX_NORMAL_PATH)
				if nrm != null:
					wyvern_mat.normal_enabled = true
					wyvern_mat.normal_texture = nrm
				elif std_mat != null and std_mat.normal_texture != null:
					wyvern_mat.normal_enabled = true
					wyvern_mat.normal_texture = std_mat.normal_texture
				
				var rgh: Texture2D = _load_texture_safe(SYRAX_ROUGHNESS_PATH)
				if rgh != null:
					wyvern_mat.roughness_texture = rgh
					wyvern_mat.roughness = 1.0
				elif std_mat != null and std_mat.roughness_texture != null:
					wyvern_mat.roughness_texture = std_mat.roughness_texture
					wyvern_mat.roughness = 1.0
				else:
					wyvern_mat.roughness = 0.55
				
				wyvern_mat.metallic = 0.0
				wyvern_mat.metallic_specular = 0.35
				
				instance.set_surface_override_material(surface, wyvern_mat)
				print("Applied StandardMaterial3D with Syrax PBR textures to ", instance.name)
			elif instance.name == "Object_7" or ("body02_Inst" in res_name and not "body02_2" in res_name):
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

