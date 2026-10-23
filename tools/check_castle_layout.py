import bpy

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"assets/siege/environment/castle_citadel.glb")
obj = bpy.data.objects[0]
verts = [v.co for v in obj.data.vertices]

# In Blender, obj was imported: Y is horizontal depth, X is width, Z is height
for side, name in [
    ((lambda v: v.y > 35), '+Y (depth forward)'),
    ((lambda v: v.y < -35), '-Y (depth backward)'),
    ((lambda v: v.x > 35), '+X (right)'),
    ((lambda v: v.x < -35), '-X (left)')
]:
    sub = [v for v in verts if side(v)]
    low_z = [v for v in sub if v.z < 2.0]
    print(f"{name}: total={len(sub)}, low_z={len(low_z)}")

# Also print center of mass / bounding box
coords = [v for v in verts]
print("Min coords:", [min(v[i] for v in coords) for i in range(3)])
print("Max coords:", [max(v[i] for v in coords) for i in range(3)])
