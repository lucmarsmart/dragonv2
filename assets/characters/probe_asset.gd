extends SceneTree
func _initialize():call_deferred('probe')
func probe():
 var doc=GLTFDocument.new();var state=GLTFState.new();doc.append_from_file(OS.get_cmdline_user_args()[0],state)
 var model=doc.generate_scene(state);root.add_child(model);await process_frame
 var meshes=model.find_children('*','MeshInstance3D',true,false)
 var bounds=AABB();var first=true
 for m in meshes:
  var a=m.global_transform*m.get_aabb()
  bounds=a if first else bounds.merge(a);first=false
 print('REST_AABB:',bounds)
 var skeletons=model.find_children('*','Skeleton3D',true,false)
 if skeletons.size()>0:
  var skeleton=skeletons[0];print('BONES:',skeleton.get_bone_count())
  var players=model.find_children('*','AnimationPlayer',true,false)
  var ap=players[0]
  for clip in ['idle','walk_loop','sword_attack','death']:
   ap.play(clip);var duration=ap.get_animation(clip).length;var low=100.;var high=-100.
   for frame in range(21):
    ap.seek(duration*frame/20.,true);ap.pause();skeleton.force_update_all_bone_transforms()
    for m in meshes:
     if m.skin==null:continue
     var sk=m.get_node(m.skeleton)
     var matrices=[]
     for b in range(m.skin.get_bind_count()):
      var idx=m.skin.get_bind_bone(b)
      if idx<0:idx=sk.find_bone(m.skin.get_bind_name(b))
      matrices.append(sk.global_transform*sk.get_bone_global_pose(idx)*m.skin.get_bind_pose(b))
     for surface in range(m.mesh.get_surface_count()):
      var arr=m.mesh.surface_get_arrays(surface);var verts=arr[Mesh.ARRAY_VERTEX];var ids=arr[Mesh.ARRAY_BONES];var weights=arr[Mesh.ARRAY_WEIGHTS]
      for i in range(verts.size()):
       var p=Vector3.ZERO
       for k in range(4):p+=(matrices[ids[i*4+k]]*verts[i])*weights[i*4+k]
       low=min(low,p.y);high=max(high,p.y)
   print('CLIP_HEIGHT:',clip,':',low,':',high)
 quit()
