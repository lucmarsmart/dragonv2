import bpy
import math

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"assets/siege/environment/castle_citadel.glb")
obj = bpy.data.objects[0]
verts = obj.data.vertices

# Let's check average Z for vertices in 4 quadrant directions
# In gltf imported to blender:
# X is width (-57 to +53), Y is depth (-51 to +52), Z is height (0 to 30)
for name, cond in [
    ("North (+Y)", lambda v: v.co.y > 25),
    ("South (-Y)", lambda v: v.co.y < -25),
    ("East (+X)", lambda v: v.co.x > 25),
    ("West (-X)", lambda v: v.co.x < -25)
]:
    sub = [v for v in verts if cond(v)]
    low_z = [v for v in sub if v.co.z < 1.0]
    mid_z = [v for v in sub if 5.0 < v.co.z < 15.0]
    high_z = [v for v in sub if v.co.z > 20.0]
    print(f"Side {name}: total={len(sub)}, ground={len(low_z)}, mid_walls={len(mid_z)}, high_towers={len(high_z)}")
