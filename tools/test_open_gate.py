import bpy
import os
import math
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
castle_dir = os.path.join(os.environ["TEMP"], "castle_inspect", "castle")
castle_obj_path = os.path.join(castle_dir, "castle.obj")

bpy.ops.wm.obj_import(filepath=castle_obj_path)
obj = bpy.data.objects[0]
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.mesh.separate(type='LOOSE')

parts_to_keep = []
for p in bpy.context.selected_objects:
    if max(p.dimensions) > 10000:
        continue
    name = p.name
    if "." in name:
        try:
            num = int(name.split(".")[-1])
            if 30 <= num <= 75:
                continue
        except:
            pass
    parts_to_keep.append(p)

bpy.ops.object.select_all(action='DESELECT')
for p in parts_to_keep:
    p.select_set(True)
bpy.context.view_layer.objects.active = parts_to_keep[0]
bpy.ops.object.join()

castle = bpy.context.active_object
castle.name = "MedievalCastleCitadel"

castle.rotation_euler.x = math.radians(90.0)
castle.rotation_euler.z = math.radians(90.0)
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

# Assign material
textures_dir = os.path.join(castle_dir, "Users", "cem", "Desktop", "shutter", "castle")
stone_tex = os.path.join(textures_dir, "BrickOldRounded0134_2_M.jpg")
mat = bpy.data.materials.new("CastleCitadel_PBR")
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get("Principled BSDF")
if os.path.exists(stone_tex):
    img = bpy.data.images.load(stone_tex)
    tex_node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex_node.image = img
    mat.node_tree.links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.88
castle.data.materials.clear()
castle.data.materials.append(mat)

# Setup camera looking at -Y from y = -80 (the front approach)
cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
bpy.context.scene.collection.objects.link(cam)
bpy.context.scene.camera = cam

cam.location = (0, -85, 12)
cam.rotation_euler = (math.radians(82), 0, 0)

light_data = bpy.data.lights.new(name="Sun", type='SUN')
light_data.energy = 2.5
light = bpy.data.objects.new(name="Sun", object_data=light_data)
bpy.context.scene.collection.objects.link(light)
light.rotation_euler = (math.radians(45), math.radians(30), 0)

bpy.context.scene.render.resolution_x = 480
bpy.context.scene.render.resolution_y = 270
bpy.context.scene.render.filepath = r"c:\Proyectos\Dragonv3-original\assets\siege\environment\test_gate_view_south.png"
bpy.ops.render.render(write_still=True)
print("Rendered test_gate_view_south.png")
