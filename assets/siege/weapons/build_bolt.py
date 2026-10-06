import bpy,math
from pathlib import Path
ROOT=str(Path(__file__).resolve().parents[3]);P='/tmp/dragon-blender/bolt/ballista_bolt/'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.ops.wm.obj_import(filepath=P+'bolt.obj')
m=bpy.data.materials.new('Kutejnikov_Bolt_PBR_2K');m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;bs=n.get('Principled BSDF')
for f,slot in [('Base_Color','Base Color'),('Metallic','Metallic'),('Roughness','Roughness'),('Normal_OpenGL','Normal')]:
 im=n.new('ShaderNodeTexImage');im.image=bpy.data.images.load(P+'DefaultMaterial_'+f+'.png')
 if f!='Base_Color':im.image.colorspace_settings.name='Non-Color'
 if slot=='Normal':nm=n.new('ShaderNodeNormalMap');l.new(im.outputs['Color'],nm.inputs['Color']);l.new(nm.outputs['Normal'],bs.inputs[slot])
 else:l.new(im.outputs['Color'],bs.inputs[slot])
for o in bpy.data.objects:
 if o.type=='MESH':
  for v in o.data.vertices:v.co*=1.8/1518.49536
  # Author's long axis BlenderZ: move onto Blender+Y, exported glTF−Z.
  o.rotation_euler.x=-math.pi/2;o.data.materials.clear();o.data.materials.append(m)
bpy.ops.export_scene.gltf(filepath=ROOT+'/assets/siege/weapons/bolt.glb',export_format='GLB',export_yup=True)
