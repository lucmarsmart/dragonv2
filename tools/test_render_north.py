import bpy
import math

cam = bpy.data.objects["Cam"]
cam.location = (0, 85, 12)
cam.rotation_euler = (math.radians(98), 0, math.radians(180))

bpy.context.scene.render.filepath = r"c:\Proyectos\Dragonv3-original\assets\siege\environment\test_gate_view_north.png"
bpy.ops.render.render(write_still=True)
print("Rendered test_gate_view_north.png")
