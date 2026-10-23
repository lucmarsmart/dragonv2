import bpy

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"assets/siege/environment/castle_citadel.glb")
obj = bpy.data.objects[0]
verts = obj.data.vertices

back_verts = [v for v in verts if v.co.y > 40]
print(f"Total verts in back wall region: {len(back_verts)}")
x_buckets = {}
for v in back_verts:
    bx = round(v.co.x / 5.0) * 5
    x_buckets[bx] = x_buckets.get(bx, 0) + 1

print("Back wall X distribution:")
for k in sorted(x_buckets.keys()):
    print(f"  X={k}: {x_buckets[k]} vertices")
