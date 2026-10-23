import bpy

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"assets/siege/environment/castle_citadel.glb")
obj = bpy.data.objects[0]
verts = obj.data.vertices

center_verts = [v for v in verts if 0 < v.co.x < 50 and -15 < v.co.y < 15]
print("Center-ish verts in line of sight:", len(center_verts))
if center_verts:
    for v in center_verts[:10]:
        print("  co:", v.co)
