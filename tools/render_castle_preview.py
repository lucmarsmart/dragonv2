import bpy
import math

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"assets/siege/environment/castle_citadel.glb")

# Setup top-down camera
cam_data = bpy.data.cameras.new("TopCam")
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 130.0
cam = bpy.data.objects.new("TopCam", cam_data)
bpy.context.scene.collection.objects.link(cam)
bpy.context.scene.camera = cam

cam.location = (0, 0, 80)
cam.rotation_euler = (0, 0, 0)

# Setup sun
light_data = bpy.data.lights.new(name="Sun", type='SUN')
light_data.energy = 2.5
light = bpy.data.objects.new(name="Sun", object_data=light_data)
bpy.context.scene.collection.objects.link(light)
light.rotation_euler = (math.radians(45), math.radians(30), 0)

bpy.context.scene.render.resolution_x = 512
bpy.context.scene.render.resolution_y = 512
bpy.context.scene.render.filepath = r"assets/siege/environment/castle_citadel_topdown.png"
bpy.ops.render.render(write_still=True)
print("Rendered castle topdown preview!")
