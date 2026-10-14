import unreal

# ==============================================================================
# Script para crear Material Procedural de Escamas en Unreal Engine 5
# Ejecutar dentro de UE5 (Output Log con intérprete Python activado o menú Herramientas)
# ==============================================================================

# 1. Preparar carpeta y crear el Asset de Material en UE5
mat_folder = "/Game/Materiales"
mat_name = "M_Dragon_Scales_Proc"
mat_path = f"{mat_folder}/{mat_name}"

unreal.EditorAssetLibrary.make_directory(mat_folder)
if unreal.EditorAssetLibrary.does_asset_exist(mat_path):
    unreal.EditorAssetLibrary.delete_asset(mat_path)

asset_tools = unreal.AssetToolsHelpers.get_asset_tools()
mat_factory = unreal.MaterialFactoryNew()
mat = asset_tools.create_asset(mat_name, mat_folder, unreal.Material, mat_factory)

mel = unreal.MaterialEditingLibrary

# 2. Crear Nodos Matemáticos en el Grafo del Material
# Coordenadas 3D en espacio absoluto para no depender de UVs
world_pos = mel.create_material_expression(mat, unreal.MaterialExpressionWorldPosition, -800, 0)

# Nodo Noise (Celular / Voronoi para simular patrón de escamas de reptil)
noise = mel.create_material_expression(mat, unreal.MaterialExpressionNoise, -500, 0)
noise.set_editor_property("scale", 0.35)       # Escala de las escamas
noise.set_editor_property("levels", 3)         # Detalle fractal
noise.set_editor_property("output_min", 0.0)
noise.set_editor_property("output_max", 1.0)
mel.connect_material_expressions(world_pos, "", noise, "Position")

# Colores de las escamas (Interpolar entre magma/negro volcánico y rojo escarlata)
col_dark = mel.create_material_expression(mat, unreal.MaterialExpressionConstant3Vector, -500, -250)
col_dark.set_editor_property("constant", unreal.LinearColor(0.04, 0.01, 0.01, 1.0))

col_red = mel.create_material_expression(mat, unreal.MaterialExpressionConstant3Vector, -500, -120)
col_red.set_editor_property("constant", unreal.LinearColor(0.55, 0.05, 0.02, 1.0))

lerp_color = mel.create_material_expression(mat, unreal.MaterialExpressionLinearInterpolate, -200, -150)
mel.connect_material_expressions(col_dark, "", lerp_color, "A")
mel.connect_material_expressions(col_red, "", lerp_color, "B")
mel.connect_material_expressions(noise, "", lerp_color, "Alpha")

# Rugosidad variable (escamas semibrillantes, uniones mates)
lerp_rough = mel.create_material_expression(mat, unreal.MaterialExpressionLinearInterpolate, -200, 150)
lerp_rough.set_editor_property("const_a", 0.85)
lerp_rough.set_editor_property("const_b", 0.35)
mel.connect_material_expressions(noise, "", lerp_rough, "Alpha")

# 3. Conectar al nodo principal del Material y compilar
mel.connect_material_property(lerp_color, "", unreal.MaterialProperty.MP_BASE_COLOR)
mel.connect_material_property(lerp_rough, "", unreal.MaterialProperty.MP_ROUGHNESS)
mel.recompile_material(mat)
unreal.EditorAssetLibrary.save_asset(mat_path)

# 4. Asignar el material a cualquier Actor del Dragón presente en el nivel
actor_sub = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
applied_count = 0
for actor in actor_sub.get_all_level_actors():
    if "dragon" in actor.get_actor_label().lower():
        mesh_comp = actor.get_component_by_class(unreal.MeshComponent)
        if mesh_comp:
            mesh_comp.set_material(0, mat)
            applied_count += 1

unreal.log(f"¡Material procedural '{mat_name}' creado en '{mat_path}'! Asignado a {applied_count} actor(es).")
