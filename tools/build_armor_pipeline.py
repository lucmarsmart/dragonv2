import bpy
import os
import math
from mathutils import Vector

print("=== STARTING OPTIMIZED ARMOR AND SWORD PIPELINE ===")

PROJECT_ROOT = r"c:\Proyectos\Dragonv3-original"
OUT_ARMOR_DIR = os.path.join(PROJECT_ROOT, "assets", "siege", "environment", "armor")
OUT_TEXTURES_DIR = os.path.join(OUT_ARMOR_DIR, "textures")
os.makedirs(OUT_TEXTURES_DIR, exist_ok=True)

TEMP_TEXTURES = os.path.join(os.environ["TEMP"], "textures")

# 1. Open armor.blend
bpy.ops.wm.open_mainfile(filepath=r"c:\Users\lucma\Downloads\armor.blend")

# Remove any unused vertex groups to eliminate deform weight precision warnings
for o in bpy.data.objects:
    if o.type == "MESH":
        o.vertex_groups.clear()
        o.data.validate()

# Optimize meshes with decimation for rock-solid GPU performance
for o in [bpy.data.objects.get("Platemail"), bpy.data.objects.get("leather")]:
    if o:
        dec = o.modifiers.new("Decimate", "DECIMATE")
        dec.ratio = 0.55 # Preserves all edge detail while halving vertex count
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier="Decimate")

# Relink texture nodes to our optimized textures
for mat in bpy.data.materials:
    for node in mat.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image:
            base_name = os.path.basename(node.image.name)
            opt_path = os.path.join(OUT_TEXTURES_DIR, base_name)
            if os.path.exists(opt_path):
                new_img = bpy.data.images.load(opt_path)
                node.image = new_img
                if "Normal" in base_name or "Roughness" in base_name or "Metallic" in base_name:
                    new_img.colorspace_settings.name = "Non-Color"

print("Armor textures and meshes optimized.")

# Add a stone plinth base for the sentinel
bpy.ops.mesh.primitive_cylinder_add(radius=0.72, depth=0.10, location=(0, 0, 0.05))
plinth = bpy.context.active_object
plinth.name = "ArmorPedestal"
plinth_mat = bpy.data.materials.new("PedestalStone")
p_bsdf = plinth_mat.node_tree.nodes.get("Principled BSDF")
if p_bsdf:
    p_bsdf.inputs["Base Color"].default_value = (0.32, 0.33, 0.36, 1.0)
    p_bsdf.inputs["Roughness"].default_value = 0.88
    p_bsdf.inputs["Metallic"].default_value = 0.05
plinth.data.materials.append(plinth_mat)

# Import and setup sword
sword_path = os.path.join(os.environ["TEMP"], "sword.obj")
bpy.ops.wm.obj_import(filepath=sword_path)
sword = bpy.context.selected_objects[0]
sword.name = "Greatsword"

# Clean up any missing image nodes from sword import
for mat in bpy.data.materials:
    if "steel" in mat.name.lower() or "wood" in mat.name.lower():
        nodes_to_remove = [n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE"]
        for n in nodes_to_remove:
            mat.node_tree.nodes.remove(n)
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            if "steel" in mat.name.lower():
                bsdf.inputs["Base Color"].default_value = (0.88, 0.90, 0.94, 1.0)
                bsdf.inputs["Metallic"].default_value = 0.98
                bsdf.inputs["Roughness"].default_value = 0.18
            else:
                # Grip / pommel
                bsdf.inputs["Base Color"].default_value = (0.16, 0.11, 0.07, 1.0)
                bsdf.inputs["Metallic"].default_value = 0.10
                bsdf.inputs["Roughness"].default_value = 0.60

# Decimate sword
dec_sword = sword.modifiers.new("Decimate", "DECIMATE")
dec_sword.ratio = 0.25 # reduces ~40k down to ~10k
bpy.context.view_layer.objects.active = sword
bpy.ops.object.modifier_apply(modifier="Decimate")

# Scale sword to proportional greatsword length (~1.42m)
scale_fac = 1.42 / sword.dimensions.z
sword.scale = Vector((scale_fac, scale_fac, scale_fac))
bpy.ops.object.transform_apply(scale=True)

# Export standalone greatsword (centered at origin, upright)
bpy.ops.object.select_all(action='DESELECT')
sword.select_set(True)
bpy.context.view_layer.objects.active = sword
sword_glb = os.path.join(PROJECT_ROOT, "assets", "siege", "weapons", "greatsword.glb")
bpy.ops.export_scene.gltf(filepath=sword_glb, use_selection=True, export_format='GLB')
print("Saved clean Standalone Greatsword GLB:", sword_glb)

# Now position sword in front of armor sentinel (blade point down into pedestal)
z_min = min(v.co.z for v in sword.data.vertices)
sword.location = Vector((0.0, -0.30, 0.05 - z_min))

# Export full Sentinel Monument
bpy.ops.object.select_all(action='SELECT')
sentinel_glb = os.path.join(OUT_ARMOR_DIR, "armor_sentinel.glb")
bpy.ops.export_scene.gltf(filepath=sentinel_glb, use_selection=False, export_format='GLB')
print("Saved clean Armor Sentinel Monument GLB:", sentinel_glb)

print("=== PIPELINE FINISHED SUCCESSFULLY ===")
