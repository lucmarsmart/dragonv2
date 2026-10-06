extends SceneTree
var camera: Camera3D
func _initialize():
 var scene=Node3D.new(); root.add_child(scene)
 var doc=GLTFDocument.new(); var state=GLTFState.new()
 var input=OS.get_cmdline_user_args()[0]
 var error=doc.append_from_file(input,state)
 print('GLTF_ERROR:',error)
 var model=doc.generate_scene(state);scene.add_child(model)
 model.rotation.y=0.35
 for mesh in model.find_children('*','MeshInstance3D',true,false):
  for i in range(mesh.mesh.get_surface_count()):
   var m=mesh.mesh.surface_get_material(i)
   if m is BaseMaterial3D:
    m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    for slot in [BaseMaterial3D.TEXTURE_ALBEDO,BaseMaterial3D.TEXTURE_NORMAL,BaseMaterial3D.TEXTURE_METALLIC,BaseMaterial3D.TEXTURE_ROUGHNESS]:
     var tx=m.get_texture(slot)
     if tx!=null:
      var im=tx.get_image();im.generate_mipmaps();m.set_texture(slot,ImageTexture.create_from_image(im))
 var env=WorldEnvironment.new();var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color(0.12,0.15,0.19);e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color(0.6,0.65,0.75);e.ambient_light_energy=0.65;e.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.environment=e;scene.add_child(env)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,150,0);light.light_energy=2.3;light.shadow_enabled=true;scene.add_child(light)
 camera=Camera3D.new();scene.add_child(camera);camera.position=Vector3(-2.8,1.4,-4.4);camera.look_at_from_position(camera.position,Vector3(0,1.0,0));camera.fov=35
 var a=model.find_children('*','AnimationPlayer',true,false)
 if not a.is_empty(): print('ANIMATIONS:',a[0].get_animation_list());a[0].play('idle')
 root.size=Vector2i(900,900)
 call_deferred('capture')
func capture():
 for i in range(12): await process_frame
 var args=OS.get_cmdline_user_args()
 if args.size()>2:
  var a=root.find_children('*','AnimationPlayer',true,false)
  if not a.is_empty():a[0].play(args[1]);a[0].seek(float(args[2]),true);a[0].pause()
  for i in range(3):await process_frame
 var img=root.get_texture().get_image();img.save_png(args[3] if args.size()>3 else '/tmp/siege_asset_preview.png')
 quit()
