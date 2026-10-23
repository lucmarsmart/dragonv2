import bpy
import os

bpy.ops.wm.read_factory_settings(use_empty=True)
castle_dir = os.path.join(os.environ["TEMP"], "castle_inspect", "castle")
castle_obj_path = os.path.join(castle_dir, "castle.obj")

bpy.ops.wm.obj_import(filepath=castle_obj_path)
obj = bpy.data.objects[0]
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.mesh.separate(type='LOOSE')

print(f"Total loose parts in castle.obj: {len(bpy.context.selected_objects)}")
for p in bpy.context.selected_objects:
    dims = [round(d, 2) for d in p.dimensions]
    vcount = len(p.data.vertices)
    print(f"Part: {p.name}, dims={dims}, verts={vcount}, center={[round(c, 2) for c in p.location]}")
