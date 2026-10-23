import bpy
import math

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"assets/siege/environment/castle_citadel.glb")

cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
bpy.context.scene.collection.objects.link(cam)
bpy.context.scene.camera = cam

light_data = bpy.data.lights.new(name="Sun", type='SUN')
light_data.energy = 2.5
light = bpy.data.objects.new(name="Sun", object_data=light_data)
bpy.context.scene.collection.objects.link(light)
light.rotation_euler = (math.radians(45), math.radians(30), 0)

bpy.context.scene.render.resolution_x = 400
bpy.context.scene.render.resolution_y = 250

views = [
    ("front_south", (0, -110, 25), (math.radians(78), 0, 0)),
    ("back_north", (0, 110, 25), (math.radians(78), 0, math.radians(180))),
    ("right_east", (110, 0, 25), (math.radians(78), 0, math.radians(90))),
    ("left_west", (-110, 0, 25), (math.radians(78), 0, math.radians(-90)))
]

for name, loc, rot in views:
    cam.location = loc
    cam.rotation_euler = rot
    bpy.context.scene.render.filepath = rf"c:\Proyectos\Dragonv3-original\assets\siege\environment\castle_citadel_{name}.png"
    bpy.ops.render.render(write_still=True)
    print(f"Rendered {name}")
