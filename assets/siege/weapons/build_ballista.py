"""Kenney GitHub ballista geometry rebuilt with scanned 2K oak, forged fasteners, ropes, winding drum.
Actual author/licence provenance in docs/assets-siege.md. Blender -b -P this file.
"""
import bpy,math,os
from mathutils import Vector
from pathlib import Path
ROOT=str(Path(__file__).resolve().parents[3]);OUT=ROOT+'/assets/siege/weapons/'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name,color,metal=.0,rough=.7):
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;return m
wood=mat('Weathered_oak_scanned_2K',(.18,.1,.04));n=wood.node_tree.nodes;l=wood.node_tree.links;p=n.get('Principled BSDF')
for f,slot in [('Color','Base Color'),('Roughness','Roughness'),('NormalGL','Normal')]:
 image=bpy.data.images.load(OUT+'textures/Wood060_2K-JPG_'+f+'.jpg');im=n.new('ShaderNodeTexImage');im.image=image
 if f!='Color':image.colorspace_settings.name='Non-Color'
 if f=='NormalGL':normal=n.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.15;l.new(im.outputs['Color'],normal.inputs['Color']);l.new(normal.outputs['Normal'],p.inputs[slot])
 else:l.new(im.outputs['Color'],p.inputs[slot])
steel=mat('Dark_forged_iron',(.11,.12,.13),.92,.45);brass=mat('Worn_brass_axle',(.32,.21,.07),.8,.38);rope=mat('Twisted_hemp',(.24,.19,.12),0,.94)
def empty(name,loc,parent=None):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=loc
 if parent:o.parent=parent
 return o
root=empty('Ballista',(0,0,0));yaw=empty('AimYaw',(0,0,0),root);pitch=empty('AimPitch',(0,0,2.1),yaw);muzzle=empty('Muzzle',(0,3.3,0),pitch)
def finish(o,name,m,parent=yaw,bevel=0):
 o.name=name;o.data.materials.clear();o.data.materials.append(m)
 if o.type=='MESH':
  bpy.context.view_layer.objects.active=o;bpy.ops.object.select_all(action='DESELECT');o.select_set(True)
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  if bevel:
   mod=o.modifiers.new('Worn_edges','BEVEL');mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
  for poly in o.data.polygons:poly.use_smooth=False
  # True scale UVs, end grain and longitudinal fibres rather than palette atlas.
  bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.018);bpy.ops.object.mode_set(mode='OBJECT')
 if parent:
  world=o.matrix_world.copy();o.parent=parent;o.matrix_world=world
 return o
def beam(name,loc,size,m=wood,parent=yaw,bevel=.025):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.scale=size;return finish(o,name,m,parent,bevel)
def cyl(name,a,b,r,m=steel,parent=pitch,verts=20):
 a=Vector(a);b=Vector(b);bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=(b-a).length,location=(a+b)/2);o=bpy.context.object;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return finish(o,name,m,parent,.007)
def curve(name,points,r,m,parent=pitch):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.bevel_depth=r;c.bevel_resolution=2;s=c.splines.new('POLY');s.points.add(len(points)-1)
 for p,co in zip(s.points,points):p.co=(*co,1)
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);c.materials.append(m);world=o.matrix_world.copy();o.parent=parent;o.matrix_world=world;return o
# Import actual GitHub GLB, retain authored structural frame/stock, replace palette shader.
bpy.ops.import_scene.gltf(filepath=OUT+'source/kenney_ballista_github.glb')
original=[o for o in bpy.data.objects if o.type=='MESH']
for o in original:
 if o.name.startswith('arrow') or o.name.startswith('wheel'):bpy.data.objects.remove(o,do_unlink=True);continue
 bpy.context.view_layer.objects.active=o;bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.remove_doubles(threshold=.00001);bpy.ops.object.mode_set(mode='OBJECT')
 # Remove source banners and pennant poles; retain frame and stock meshes.
 import bmesh
 bm=bmesh.new();bm.from_mesh(o.data);seen=set();remove=[]
 for v in bm.verts:
  if v in seen:continue
  comp=[];queue=[v];seen.add(v)
  while queue:
   q=queue.pop();comp.append(q)
   for edge in q.link_edges:
    other=edge.other_vert(q)
    if other not in seen:seen.add(other);queue.append(other)
  if sum(q.co.z for q in comp)/len(comp)>.65:remove.extend(comp)
 bmesh.ops.delete(bm,geom=remove,context='VERTS');bm.to_mesh(o.data);bm.free()
 # Orient original +X launch direction onto Blender +Y = glTF/Godot -Z.
 o.rotation_euler.z=math.pi/2;o.scale=(2.4,2.4,2.4);o.location.z=.9
 finish(o,'Github_Kenney_stock_and_torsion_frame',wood,pitch,.018)
# Stable bolted oak platform + trunnion pedestal.
for x in [-.65,.65]:
 for y in [-.65,.65]:
  beam('Oak_foot', (x,y,.16),(.38,.38,.32),wood,yaw,.035)
  beam('Oak_pedestal_leg',(x,y,.7),(.19,.19,1.1),wood,yaw)
for y in [-.65,.65]:beam('Lower_crossbrace',(0,y,.3),(1.55,.2,.2),wood,yaw)
beam('Rotating_oak_table',(0,0,1.12),(1.65,1.8,.24),wood,yaw,.045)
cyl('Yaw_bearing',(0,0,.93),(0,0,1.32),.32,steel,yaw,32)
# More articulated real mechanism than source silhouette: torsion bundles, laminated limbs, taut bowstring.
for sign in [-1,1]:
 x=sign*.84
 cyl('Torsion_socket',(x,.93,1.75),(x,.93,2.57),.19,steel,pitch,24)
 for j in range(9):
  a=j*math.tau/9;cyl('Hemp_torsion_bundle',(x+.11*math.cos(a),.93+.11*math.sin(a),1.76),(x+.11*math.cos(a+.65),.93+.11*math.sin(a+.65),2.56),.027,rope)
 # Curved laminations with forged ferrules and end hooks.
 pts=[(sign*(.85+1.5*t),.95-.5*t*t,2.13+.09*math.sin(t*math.pi)) for t in [i/20 for i in range(21)]]
 for layer in [-.05,0,.05]:curve('Laminated_bow_limb',[(x,y,z+layer) for x,y,z in pts],.057,wood)
 for t in [.0,.35,.65,.95]:
  x=sign*(.85+1.5*t);y=.95-.5*t*t;z=2.13+.09*math.sin(t*math.pi);beam('Limb_iron_band',(x,y,z),(.105,.24,.27),steel,pitch,.012)
 curve('Drawn_bowstring',[(sign*2.35,.45,2.13),(0,-.9,2.15)],.025,rope)
 for i in range(13):
  y=-1.05+i*.22;cyl('Bolt_rack_pin',(sign*.24,y,2.16),(sign*.24,y,2.27),.022,steel)
beam('Bolt_guide_trough',(0,.65,2.07),(.26,4.8,.16),wood,pitch,.022)
for x in [-.14,.14]:beam('Iron_bolt_rail',(x,.65,2.16),(.025,4.8,.08),steel,pitch,.005)
cyl('Pitch_trunnion',(-.98,0,2.1),(.98,0,2.1),.105,brass,pitch,24)
cyl('Winding_drum',(-.48,-1.2,2.05),(.48,-1.2,2.05),.14,wood,pitch,24)
for k in range(36):
 x=-.4+k*.023;pts=[(x,-1.2+.155*math.cos(a),2.05+.155*math.sin(a)) for a in [i*math.tau/20 for i in range(21)]];curve('Wound_tension_rope',pts,.012,rope)
for sign in [-1,1]:
 cyl('Crank_axle',(sign*.48,-1.2,2.05),(sign*.74,-1.2,2.05),.042,steel)
 cyl('Crank_arm',(sign*.74,-1.2,2.05),(sign*.74,-1.2,2.45),.036,steel)
 cyl('Crank_handle',(sign*.74,-1.2,2.45),(sign*1.03,-1.2,2.45),.055,wood)
 for y in [-1.4,-.8,0,.7,1.3]:
  beam('Stock_strap',(sign*.25,y,2.09),(.035,.16,.31),steel,pitch,.012)
  for z in [2.02,2.17]:cyl('Forged_rivet',(sign*.26,y,z),(sign*.29,y,z),.032,brass,pitch,12)
# Low-angle side braces retain stability and give readable silhouette.
for x in [-.62,.62]:cyl('Pitch_support_brace',(x,-.58,1.22),(x,0,2.06),.08,steel,yaw)
# Arrow visible on its guide; independent detailed asset built separately below.
cyl('Loaded_oak_bolt',(0,-.9,2.23),(0,2.75,2.23),.041,wood,pitch,16)
bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=.105,radius2=0,depth=.42,location=(0,2.96,2.23));o=bpy.context.object;o.rotation_euler.x=-math.pi/2;finish(o,'Forged_bodkin_head',steel,pitch,.006)
for x in [-.075,.075]:beam('Bolt_fletching',(x,-.65,2.24),(.014,.38,.18),wood,pitch,.005)
# Merge static geometry by pivot/material to keep seven draw surfaces rather than 158.
for o in list(bpy.data.objects):
 if o.type=='CURVE':
  bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
groups={}
for o in bpy.data.objects:
 if o.type=='MESH':groups.setdefault((o.parent.name if o.parent else '',o.data.materials[0].name),[]).append(o)
for (pn,mn),obs in groups.items():
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();obs[0].name=pn+'_'+mn
bpy.ops.export_scene.gltf(filepath=OUT+'ballista.glb',export_format='GLB',export_yup=True,export_apply=True)
import struct,json
pth=OUT+'ballista.glb';raw=open(pth,'rb').read();jn=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+jn]);binary=raw[20+jn:]
for ma in doc['materials']:
 if ma['name']=='Weathered_oak_scanned_2K':ma['pbrMetallicRoughness']['baseColorFactor']=[.5,.44,.38,1]
j=json.dumps(doc,separators=(',',':')).encode();j+=b' '*((-len(j))%4);open(pth,'wb').write(struct.pack('<III',0x46546c67,2,20+len(j)+len(binary))+struct.pack('<II',len(j),0x4e4f534a)+j+binary)
print('BALLISTA_READY',len([o for o in bpy.data.objects if o.type in ['MESH','CURVE']]))
