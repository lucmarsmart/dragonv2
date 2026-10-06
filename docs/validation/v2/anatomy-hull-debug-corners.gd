extends SceneTree
func _initialize() -> void:
 var data = JSON.parse_string(FileAccess.get_file_as_string("res://docs/validation/v2/anatomy-affine-neck_support.json"))
 for group in data.groups:
  if group.full.size()<2000: continue
  var pts := PackedVector3Array()
  for p in group.full: pts.append(Vector3(p[0],p[1],p[2]))
  var shape := ConvexPolygonShape3D.new()
  shape.points = pts
  var mesh := shape.get_debug_mesh()
  var corners: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  var worst := 0.0
  for c in corners:
   var nearest := INF
   for p in pts: nearest = minf(nearest,c.distance_to(p))
   worst = maxf(worst,nearest)
  print("HULL ",pts.size()," corners ",corners.size()," worst ",worst," first ",corners[0]," surfaces ",mesh.get_surface_count())
 quit()
