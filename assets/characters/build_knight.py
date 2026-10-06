"""Convert public Github piacenti mesh + author's original 2K maps; rig and clips authored locally.
Run Blender -b /tmp/dragon-blender/armor.blend -P assets/characters/build_knight.py.
"""
import bpy,math,json,os
from mathutils import Vector
from pathlib import Path
ROOT=str(Path(__file__).resolve().parents[2])
# Keep original packed 2K texture maps. Import actual Github mesh.
for o in list(bpy.data.objects): bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=ROOT+'/assets/characters/source/piacenti_github_armor.gltf')
meshes=[o for o in bpy.data.objects if o.type=='MESH']
for o in list(bpy.data.objects):
 if o.type!='MESH':bpy.data.objects.remove(o,do_unlink=True)
for o in meshes:
 bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);o.select_set(False)
points=[v.co for o in meshes for v in o.data.vertices]; low=min(v.z for v in points);high=max(v.z for v in points); fac=1.9/(high-low)
for o in meshes:
 for v in o.data.vertices:v.co=(v.co-Vector((0,0,low)))*fac
m=bpy.data.materials.new('Tempered_steel_PBR_2K');m.use_nodes=True;nodes=m.node_tree.nodes;links=m.node_tree.links;p=nodes.get('Principled BSDF')
for name,slot in [('armor_default_color.png','Base Color'),('armor_default_metalness.png','Metallic'),('armor_default_rough.png','Roughness')]:
 image=bpy.data.images[name];im=nodes.new('ShaderNodeTexImage');im.image=image
 if slot!='Base Color':image.colorspace_settings.name='Non-Color'
 links.new(im.outputs['Color'],p.inputs[slot])
im=nodes.new('ShaderNodeTexImage');im.image=bpy.data.images['armor_default_nmap.png'];im.image.colorspace_settings.name='Non-Color';no=nodes.new('ShaderNodeNormalMap');links.new(im.outputs['Color'],no.inputs['Color']);links.new(no.outputs['Normal'],p.inputs['Normal'])
for o in meshes:o.data.materials.clear();o.data.materials.append(m)
# Anatomical rig calibrated against normalized armour rest pose.
bones={'Pelvis':((0,0,0.87),(0,0,1.02),None),'Spine':((0,0,1.02),(0,0,1.32),'Pelvis'),'Chest':((0,0,1.32),(0,0,1.55),'Spine'),'Neck':((0,0,1.55),(0,0,1.66),'Chest'),'Head':((0,0,1.66),(0,0,1.86),'Neck')}
for side,sign in [('Right',-1),('Left',1)]:
 bones.update({f'{side}UpperArm':((sign*.25,0,1.51),(sign*.44,-.025,1.3),'Chest'),f'{side}ForeArm':((sign*.44,-.025,1.3),(sign*.61,-.06,1.14),f'{side}UpperArm'),f'{side}Hand':((sign*.61,-.06,1.14),(sign*.69,-.07,1.09),f'{side}ForeArm'),f'{side}Thigh':((sign*.16,0,.89),(sign*.17,.01,.5),'Pelvis'),f'{side}Shin':((sign*.17,.01,.5),(sign*.17,0,.12),f'{side}Thigh'),f'{side}Foot':((sign*.17,0,.12),(sign*.17,-.16,.05),f'{side}Shin')})
arm=bpy.data.armatures.new('KnightSkeleton');rig=bpy.data.objects.new('KnightRig',arm);bpy.context.collection.objects.link(rig);bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
for name,(head,tail,parent) in bones.items():
 b=arm.edit_bones.new(name);b.head=head;b.tail=tail
 if parent:b.parent=arm.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
def dist(p,a,b):
 a=Vector(a);ab=Vector(b)-a;t=max(0,min(1,(p-a).dot(ab)/ab.length_squared));return (p-a-t*ab).length
# Each armour limb uses anatomical nearest segment with joint blending, shield and sword rigid to hands.
for o in meshes:
 o.name='Longsword' if len(o.data.vertices)<1000 else 'ArmouredKnight'
 for name in bones:o.vertex_groups.new(name=name)
 for v in o.data.vertices:
  x,y,z=v.co;sgn='Left' if x>0 else 'Right'
  if o.name=='Longsword':weights=[('RightHand',1.)]
  elif x>.55 and y<-.15:weights=[('LeftHand',1.)]
  else:
   if z<.95:candidates=[sgn+'Thigh',sgn+'Shin',sgn+'Foot','Pelvis']
   elif abs(x)>.28:candidates=[sgn+'UpperArm',sgn+'ForeArm',sgn+'Hand','Chest']
   else:candidates=['Pelvis','Spine','Chest','Neck','Head']
   ds=sorted((dist(v.co,bones[n][0],bones[n][1]),n) for n in candidates)
   # Small smooth region at anatomical joints, rigid armour away from joints.
   if ds[1][0]-ds[0][0]<.018:
    w=max(.6,min(.92,.5+(ds[1][0]-ds[0][0])/.036));weights=[(ds[0][1],w),(ds[1][1],1-w)]
   else:weights=[(ds[0][1],1.)]
  for n,w in weights:o.vertex_groups[n].add([v.index],w,'REPLACE')
 mod=o.modifiers.new('ArmourRig','ARMATURE');mod.object=rig;o.parent=rig
# Original authored animation clips; all motion baked into exported GLB.
rig.animation_data_create();fps=30;bpy.context.scene.render.fps=fps
for name,duration in [('idle',2.),('walk_loop',1.15),('sword_attack',1.15),('hit_chest',.45),('death',1.8)]:
 action=bpy.data.actions.new(name);rig.animation_data.action=action;count=round(duration*fps)
 for frame in range(count+1):
  t=frame/count
  for pb in rig.pose.bones:pb.rotation_mode='XYZ';pb.rotation_euler=(0,0,0);pb.location=(0,0,0)
  rig.pose.bones['Chest'].rotation_euler.x=.012*math.sin(t*math.tau)
  rig.pose.bones['Head'].rotation_euler.z=.025*math.sin(t*math.tau)
  if name=='walk_loop':
   phase=t*math.tau
   for side,offset in [('Right',0),('Left',math.pi)]:
    a=phase+offset;s=math.sin(a);rig.pose.bones[side+'Thigh'].rotation_euler.x=.34*s;rig.pose.bones[side+'Shin'].rotation_euler.x=-.32*max(0,-s);rig.pose.bones[side+'Foot'].rotation_euler.x=-.16*s
    rig.pose.bones[side+'UpperArm'].rotation_euler.x=-.12*s
   rig.pose.bones['Pelvis'].location.y=.017*(1-math.cos(phase*2));rig.pose.bones['Chest'].rotation_euler.y=.025*math.sin(phase)
  elif name=='sword_attack':
   anticipation=math.sin(min(t/.36,1)*math.pi/2);strike=max(0,min(1,(t-.36)/.3));recover=max(0,min(1,(t-.72)/.28));armangle=(-1.05*anticipation+1.65*strike)*(1-recover)
   rig.pose.bones['RightUpperArm'].rotation_euler.x=armangle;rig.pose.bones['RightForeArm'].rotation_euler.x=-.45*math.sin(t*math.pi);rig.pose.bones['Chest'].rotation_euler.y=.16*math.sin(t*math.tau)
  elif name=='hit_chest':rig.pose.bones['Chest'].rotation_euler.x=.24*math.sin(t*math.pi)
  elif name=='death':
   progress=min(1,max(0,(t-.15)/.7));rig.pose.bones['Pelvis'].rotation_euler.x=-1.45*progress;rig.pose.bones['Pelvis'].location.y=-.72*progress;rig.pose.bones['RightShin'].rotation_euler.x=-.5*progress;rig.pose.bones['LeftShin'].rotation_euler.x=-.3*progress;rig.pose.bones['RightHand'].rotation_euler.z=-.9*progress
   # Evaluate visible skinned mesh: put fallen armour on the floor, never below it.
   bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
   minz=min((o.evaluated_get(deps).matrix_world@v.co).z for o in meshes for v in o.evaluated_get(deps).data.vertices)
   if minz<0:rig.pose.bones['Pelvis'].location.y-=minz
  for pb in rig.pose.bones:pb.keyframe_insert(data_path='rotation_euler',frame=frame);pb.keyframe_insert(data_path='location',frame=frame)
 track=rig.animation_data.nla_tracks.new();track.name=name;strip=track.strips.new(name,0,action)
rig.animation_data.action=None
for pb in rig.pose.bones:pb.rotation_euler=(0,0,0);pb.location=(0,0,0)
bpy.context.scene.frame_set(0)
root=bpy.data.objects.new('Knight',None);bpy.context.collection.objects.link(root);rig.parent=root;root.rotation_euler.z=math.pi
bpy.ops.export_scene.gltf(filepath=ROOT+'/assets/characters/knight.glb',export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS')
print('KNIGHT_READY',len(bones),[(o.name,len(o.data.vertices)) for o in meshes])
