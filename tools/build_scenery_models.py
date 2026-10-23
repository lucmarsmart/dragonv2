import bpy
import os
import math
from mathutils import Vector

print("=== STARTING FULL SCENERY ASSET PIPELINE ===")

PROJECT_ROOT = r"c:\Proyectos\Dragonv3-original"
TEMP_DIR = os.path.join(os.environ["TEMP"], "scenery_assets")
TEX_DIR = os.path.join(TEMP_DIR, "textures")

OUT_ROCK_DIR = os.path.join(PROJECT_ROOT, "assets", "environment", "rock")
OUT_TREES_DIR = os.path.join(PROJECT_ROOT, "assets", "environment", "trees")
OUT_SIEGE_DIR = os.path.join(PROJECT_ROOT, "assets", "siege", "environment")

os.makedirs(OUT_ROCK_DIR, exist_ok=True)
os.makedirs(OUT_TREES_DIR, exist_ok=True)
os.makedirs(OUT_SIEGE_DIR, exist_ok=True)

def resize_and_save_tex(src_path, dst_path, size=1024):
    if not os.path.exists(src_path):
        return None
    if os.path.exists(dst_path):
        return bpy.data.images.load(dst_path)
    img = bpy.data.images.load(src_path)
    img.scale(size, size)
    img.filepath_raw = dst_path
    img.file_format = "PNG" if dst_path.lower().endswith(".png") else "JPEG"
    img.save()
    print(f"Resized & saved texture: {os.path.basename(dst_path)} ({size}x{size})")
    return img

# -------------------------------------------------------------
# 1. PROCESS BOULDER 01
# -------------------------------------------------------------
print("\n--- Processing Boulder 01 ---")
bpy.ops.wm.open_mainfile(filepath=os.path.join(TEMP_DIR, "boulder_01_4k.blend"))

target_lod = bpy.data.objects.get("boulder_01_LOD0")
for o in list(bpy.data.objects):
    if o != target_lod:
        bpy.data.objects.remove(o, do_unlink=True)

target_lod.name = "BoulderScanned01"
bpy.context.view_layer.objects.active = target_lod

# Decimate to ~2,000 vertices for ultra fast GPU MultiMesh
dec = target_lod.modifiers.new("Decimate", "DECIMATE")
dec.ratio = 0.06 # from 33k down to ~2k
bpy.ops.object.modifier_apply(modifier="Decimate")
print(f"Boulder 01 decimated: {len(target_lod.data.vertices)} vertices, {len(target_lod.data.polygons)} polygons")

b1_diff = os.path.join(TEX_DIR, "boulder_01_diff_4k.jpg")
b1_diff_1k = os.path.join(OUT_ROCK_DIR, "boulder_01_diff_1k.jpg")
b1_diff_img = resize_and_save_tex(b1_diff, b1_diff_1k, 1024)

mat = bpy.data.materials.new("Boulder01_PBR")
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get("Principled BSDF")
if b1_diff_img:
    tex_node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex_node.image = b1_diff_img
    mat.node_tree.links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.92
bsdf.inputs["Metallic"].default_value = 0.0

target_lod.data.materials.clear()
target_lod.data.materials.append(mat)

boulder1_glb = os.path.join(OUT_ROCK_DIR, "boulder_scanned_01.glb")
bpy.ops.export_scene.gltf(filepath=boulder1_glb, export_format='GLB')
print(f"Exported: {boulder1_glb} ({os.path.getsize(boulder1_glb)} bytes)")

# -------------------------------------------------------------
# 2. PROCESS NAMAQUALAND BOULDER 02
# -------------------------------------------------------------
print("\n--- Processing Namaqualand Boulder 02 ---")
bpy.ops.wm.open_mainfile(filepath=os.path.join(TEMP_DIR, "namaqualand_boulder_02_4k.blend"))

target_lod = bpy.data.objects.get("namaqualand_boulder_02_LOD0")
for o in list(bpy.data.objects):
    if o != target_lod:
        bpy.data.objects.remove(o, do_unlink=True)

target_lod.name = "BoulderNamaqualand"
bpy.context.view_layer.objects.active = target_lod

dec = target_lod.modifiers.new("Decimate", "DECIMATE")
dec.ratio = 0.04 # from 49k down to ~2k
bpy.ops.object.modifier_apply(modifier="Decimate")
print(f"Namaqualand boulder decimated: {len(target_lod.data.vertices)} vertices, {len(target_lod.data.polygons)} polygons")

nb_diff = os.path.join(TEX_DIR, "namaqualand_boulder_02_diff_4k.jpg")
nb_diff_1k = os.path.join(OUT_ROCK_DIR, "namaqualand_boulder_diff_1k.jpg")
nb_diff_img = resize_and_save_tex(nb_diff, nb_diff_1k, 1024)

mat = bpy.data.materials.new("NamaqualandBoulder_PBR")
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get("Principled BSDF")
if nb_diff_img:
    tex_node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex_node.image = nb_diff_img
    mat.node_tree.links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.90
bsdf.inputs["Metallic"].default_value = 0.0

target_lod.data.materials.clear()
target_lod.data.materials.append(mat)

boulder_nb_glb = os.path.join(OUT_ROCK_DIR, "boulder_namaqualand.glb")
bpy.ops.export_scene.gltf(filepath=boulder_nb_glb, export_format='GLB')
print(f"Exported: {boulder_nb_glb} ({os.path.getsize(boulder_nb_glb)} bytes)")

# -------------------------------------------------------------
# 3. PROCESS DEAD TREE TRUNK 02
# -------------------------------------------------------------
print("\n--- Processing Dead Tree Trunk 02 ---")
bpy.ops.wm.open_mainfile(filepath=os.path.join(TEMP_DIR, "dead_tree_trunk_02_4k.blend"))

target_lod = bpy.data.objects.get("dead_tree_trunk_02_LOD0")
for o in list(bpy.data.objects):
    if o != target_lod:
        bpy.data.objects.remove(o, do_unlink=True)

target_lod.name = "DeadTreeTrunk02"
bpy.context.view_layer.objects.active = target_lod

dec = target_lod.modifiers.new("Decimate", "DECIMATE")
dec.ratio = 0.05 # from 41k down to ~2k
bpy.ops.object.modifier_apply(modifier="Decimate")
print(f"Dead tree trunk decimated: {len(target_lod.data.vertices)} vertices, {len(target_lod.data.polygons)} polygons")

dt_diff = os.path.join(TEX_DIR, "dead_tree_trunk_02_diff_4k.jpg")
dt_diff_1k = os.path.join(OUT_TREES_DIR, "dead_tree_trunk_diff_1k.jpg")
dt_diff_img = resize_and_save_tex(dt_diff, dt_diff_1k, 1024)

mat = bpy.data.materials.new("DeadTreeTrunk_PBR")
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get("Principled BSDF")
if dt_diff_img:
    tex_node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex_node.image = dt_diff_img
    mat.node_tree.links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.88
bsdf.inputs["Metallic"].default_value = 0.02

target_lod.data.materials.clear()
target_lod.data.materials.append(mat)

trunk_glb = os.path.join(OUT_TREES_DIR, "dead_tree_trunk_02.glb")
bpy.ops.export_scene.gltf(filepath=trunk_glb, export_format='GLB')
print(f"Exported: {trunk_glb} ({os.path.getsize(trunk_glb)} bytes)")

# -------------------------------------------------------------
# 4. PROCESS CASTLE CITADEL
# -------------------------------------------------------------
print("\n--- Processing Castle Citadel ---")
bpy.ops.wm.read_factory_settings(use_empty=True)
castle_dir = os.path.join(os.environ["TEMP"], "castle_inspect", "castle")
castle_obj_path = os.path.join(castle_dir, "castle.obj")

bpy.ops.wm.obj_import(filepath=castle_obj_path)
castle_obj = bpy.data.objects[0]

bpy.context.view_layer.objects.active = castle_obj
castle_obj.select_set(True)
bpy.ops.mesh.separate(type='LOOSE')

parts_to_keep = []
ground_plane = None
for p in bpy.context.selected_objects:
    if max(p.dimensions) > 10000:
        ground_plane = p
        continue
    # Drop closed door panels and metal studs (.030 to .075) to leave portal archway open
    name = p.name
    if "." in name:
        try:
            num = int(name.split(".")[-1])
            if 30 <= num <= 75:
                continue
        except:
            pass
    parts_to_keep.append(p)

if ground_plane:
    bpy.data.objects.remove(ground_plane, do_unlink=True)

bpy.ops.object.select_all(action='DESELECT')
for p in parts_to_keep:
    p.select_set(True)
bpy.context.view_layer.objects.active = parts_to_keep[0]
bpy.ops.object.join()

castle = bpy.context.active_object
castle.name = "MedievalCastleCitadel"

# Delete all other objects in the scene so ONLY MedievalCastleCitadel is exported
for o in list(bpy.data.objects):
    if o != castle:
        bpy.data.objects.remove(o, do_unlink=True)

castle.rotation_euler.x = math.radians(90.0)
bpy.ops.object.transform_apply(rotation=True)

z_min = min(v.co.z for v in castle.data.vertices)
for v in castle.data.vertices:
    v.co.z -= z_min

x_min = min(v.co.x for v in castle.data.vertices); x_max = max(v.co.x for v in castle.data.vertices)
y_min = min(v.co.y for v in castle.data.vertices); y_max = max(v.co.y for v in castle.data.vertices)
x_mid = (x_min + x_max) * 0.5
y_mid = (y_min + y_max) * 0.5
for v in castle.data.vertices:
    v.co.x -= x_mid
    v.co.y -= y_mid

scale_factor = 110.0 / castle.dimensions.x
castle.scale = Vector((scale_factor, scale_factor, scale_factor))
bpy.ops.object.transform_apply(scale=True)

textures_dir = os.path.join(castle_dir, "Users", "cem", "Desktop", "shutter", "castle")
stone_tex = os.path.join(textures_dir, "BrickOldRounded0134_2_M.jpg")
stone_tex_1k = os.path.join(OUT_SIEGE_DIR, "castle_stone_diff_1k.jpg")
stone_img = resize_and_save_tex(stone_tex, stone_tex_1k, 1024)

mat = bpy.data.materials.new("CastleCitadel_PBR")
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get("Principled BSDF")
if stone_img:
    tex_node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex_node.image = stone_img
    mat.node_tree.links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.88
bsdf.inputs["Metallic"].default_value = 0.04

castle.data.materials.clear()
castle.data.materials.append(mat)

castle_glb = os.path.join(OUT_SIEGE_DIR, "castle_citadel.glb")
bpy.ops.export_scene.gltf(filepath=castle_glb, export_format='GLB')
print(f"Exported: {castle_glb} ({os.path.getsize(castle_glb)} bytes)")

print("\n=== ALL SCENERY ASSETS BUILT SUCCESSFULLY ===")
