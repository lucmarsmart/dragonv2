import bpy
import math
import os

print("--- STARTING PROCEDURAL DRAGON GENERATION ---")

# 1. LIMPIAR LA ESCENA
bpy.ops.wm.read_factory_settings(use_empty=True)

# Configurar unidades a Centímetros (Estándar de Unreal Engine 5)
bpy.context.scene.unit_settings.system = 'METRIC'
bpy.context.scene.unit_settings.scale_length = 0.01

# 2. CREAR MATERIALES BASE PARA UNREAL
def create_mat(name, color, roughness=0.6):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = roughness
    return mat

mat_scales = create_mat("M_Dragon_Scales", (0.55, 0.08, 0.05, 1.0), 0.5) # Rojo oscuro
mat_wings = create_mat("M_Dragon_Wings", (0.85, 0.35, 0.15, 1.0), 0.7) # Membrana naranja/cuero
mat_horns = create_mat("M_Dragon_Horns", (0.15, 0.12, 0.10, 1.0), 0.3) # Cuernos y garras oscuras

parts = []
def add_part(obj, mat):
    obj.data.materials.append(mat)
    parts.append(obj)

# 3. FUNCIÓN PARA CREAR LA COLUMNA, CUELLO Y COLA (Mediante Curva con Grosor Variable)
spine_points = [
    (0, -450, 20, 5),   # Punta de la cola
    (0, -300, 35, 18),  # Cola media
    (0, -150, 75, 38),  # Base de la cola / Cadera
    (0, -30, 115, 68),  # Abdomen
    (0, 70, 135, 82),   # Pecho (parte más ancha)
    (0, 150, 195, 45),  # Base del cuello
    (0, 200, 260, 34),  # Cuello alto
    (0, 255, 275, 40),  # Cabeza (cráneo)
    (0, 325, 255, 20)   # Hocico
]

curve_data = bpy.data.curves.new('SpineCurve', type='CURVE')
curve_data.dimensions = '3D'
curve_data.bevel_depth = 1.0
curve_data.bevel_resolution = 4 # Mantiene estilo Low-Poly limpio

spline = curve_data.splines.new('NURBS')
spline.points.add(len(spine_points) - 1)
for i, (x, y, z, r) in enumerate(spine_points):
    spline.points[i].co = (x, y, z, 1)
    spline.points[i].radius = r

spline.use_endpoint_u = True

spine_obj = bpy.data.objects.new('Dragon_Body', curve_data)
bpy.context.collection.objects.link(spine_obj)
bpy.context.view_layer.objects.active = spine_obj
spine_obj.select_set(True)

bpy.ops.object.convert(target='MESH')
add_part(spine_obj, mat_scales)

# 4. CUERNOS Y CRESTA DORSAL
for side in [-1, 1]:
    bpy.ops.mesh.primitive_cone_add(
        vertices=6, radius1=14, radius2=2, depth=95,
        location=(side * 22, 215, 305),
        rotation=(math.radians(-55), math.radians(side * -20), 0)
    )
    add_part(bpy.context.active_object, mat_horns)

# Púas en el lomo
for i in range(8):
    y_pos = -220 + (i * 55)
    z_pos = 75 + (i * 15) if i < 5 else 150 + ((i - 4) * 35)
    bpy.ops.mesh.primitive_cone_add(
        vertices=4, radius1=8, radius2=1, depth=35,
        location=(0, y_pos, z_pos),
        rotation=(math.radians(-20), 0, 0)
    )
    add_part(bpy.context.active_object, mat_horns)

# 5. PATAS (4 Patas Articuladas)
leg_configs = [
    (55, 65, 80, 28),   # Delantera Derecha
    (-55, 65, 80, 28),  # Delantera Izquierda
    (50, -110, 70, 34), # Trasera Derecha
    (-50, -110, 70, 34) # Trasera Izquierda
]

for lx, ly, lz, rad in leg_configs:
    # Muslo / Pierna
    bpy.ops.mesh.primitive_cone_add(
        vertices=8, radius1=rad*0.65, radius2=rad, depth=130,
        location=(lx, ly, lz - 15),
        rotation=(math.radians(8), 0, 0)
    )
    add_part(bpy.context.active_object, mat_scales)
    # Pie / Garra
    bpy.ops.mesh.primitive_cone_add(
        vertices=6, radius1=rad*0.8, radius2=rad*0.4, depth=45,
        location=(lx, ly + 15, 15),
        rotation=(math.radians(75), 0, 0)
    )
    add_part(bpy.context.active_object, mat_horns)

# 6. ALAS EN POSE T (Con estructura ósea y membrana)
for side in [-1, 1]:
    # Hueso principal del ala (Borde de ataque)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=9, depth=380,
        location=(side * 220, 60, 175),
        rotation=(0, math.radians(side * 82), math.radians(side * -10))
    )
    add_part(bpy.context.active_object, mat_scales)
    
    # Membrana del ala (Geometría explícita para exportación limpia)
    mesh = bpy.data.meshes.new(f"Wing_Membrane_{side}")
    obj = bpy.data.objects.new(f"Wing_Membrane_{side}", mesh)
    bpy.context.collection.objects.link(obj)
    verts = [
        (side * 45, 80, 150),    # 0: Hombro delantero
        (side * 210, 100, 185),  # 1: Codo del ala
        (side * 410, 50, 195),   # 2: Punta exterior del ala
        (side * 330, -90, 140),  # 3: Punta del dedo externo
        (side * 195, -120, 125), # 4: Punta del dedo medio
        (side * 55, -80, 120)    # 5: Unión trasera al torso
    ]
    faces = [(0, 1, 4, 5), (1, 2, 3, 4)]
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    
    # Dar un pequeño grosor a la membrana para que se vea de ambos lados en UE5
    solid = obj.modifiers.new(name="Solidify", type='SOLIDIFY')
    solid.thickness = 4.0
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier="Solidify")
    add_part(obj, mat_wings)

# 7. UNIR TODA LA MALLA EN UN SOLO OBJETO
bpy.ops.object.select_all(action='DESELECT')
for p in parts:
    p.select_set(True)

bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()

dragon_mesh = bpy.context.active_object
dragon_mesh.name = "SK_Procedural_Dragon"

# Colocar pivote en el origen (0,0,0) a nivel del suelo
bpy.context.scene.cursor.location = (0, 0, 0)
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')

# 8. CREAR ESQUELETO (ARMATURE) COMPATIBLE CON UNREAL ENGINE 5
bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
armature = bpy.context.active_object
armature.name = "Armature_Dragon"
edit_bones = armature.data.edit_bones

# Configurar hueso Root en (0,0,0) - Requisito clave de UE5
root_bone = edit_bones[0]
root_bone.name = "root"
root_bone.head = (0, 0, 0)
root_bone.tail = (0, 0, 50)

def add_bone(name, head, tail, parent):
    b = edit_bones.new(name)
    b.head = head
    b.tail = tail
    b.parent = parent
    return b

pelvis = add_bone("pelvis", (0, -60, 110), (0, 40, 130), root_bone)
spine = add_bone("spine_01", (0, 40, 130), (0, 130, 160), pelvis)
neck = add_bone("neck_01", (0, 130, 160), (0, 230, 265), spine)
head = add_bone("head", (0, 230, 265), (0, 330, 255), neck)
tail1 = add_bone("tail_01", (0, -60, 110), (0, -240, 60), pelvis)
tail2 = add_bone("tail_02", (0, -240, 60), (0, -450, 20), tail1)
wing_l = add_bone("wing_L", (-45, 60, 150), (-400, 40, 190), spine)
wing_r = add_bone("wing_R", (45, 60, 150), (400, 40, 190), spine)

bpy.ops.object.mode_set(mode='OBJECT')

# Emparentar Malla al Esqueleto con Pesos Automáticos (Skinning)
bpy.ops.object.select_all(action='DESELECT')
dragon_mesh.select_set(True)
armature.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.object.parent_set(type='ARMATURE_AUTO')

# 9. EXPORTAR AUTOMÁTICAMENTE A .FBX CON CONFIGURACIÓN DE UNREAL ENGINE 5
desktop = os.path.join(os.path.expanduser("~"), "Desktop")
export_path = os.path.join(desktop, "Dragon_UE5.fbx")

# Asegurar selección correcta para el exportador
bpy.ops.object.select_all(action='DESELECT')
dragon_mesh.select_set(True)
armature.select_set(True)

bpy.ops.export_scene.fbx(
    filepath=export_path,
    use_selection=True,
    object_types={'ARMATURE', 'MESH'},
    axis_forward='-Y',
    axis_up='Z',
    mesh_smooth_type='FACE',
    add_leaf_bones=False
)

print(f"¡ÉXITO! Tu Dragón listo para UE5 se ha guardado en: {export_path}")
