extends SceneTree
var scene: Node3D
var dragon: DragonController
var combat: SiegeCombat
var breath: DragonBreath
var retreat_fire_frames := 0
var retreat_head_angles: Array = []
var maximum_fire_mouth_error_m := 0.0
var maximum_fire_head_error_deg := 0.0
var frames: Array = []
var failures: Array[String] = []
var stages := {}
var maximum_overlap_count := 0
var maximum_prop_overlap_count := 0
var observed_non_grounded_frames := 0
var overlap_diagnostics: Array = []
var maximum_head_step_deg := 0.0
var previous_head := Vector3.FORWARD
var previous_wing_rotations := {}
var maximum_wing_step_deg := 0.0
var skin_probe = preload("res://scripts/dragon_pose_probe.gd").new()
var claw_track := {}
var maximum_stance_slide_m := 0.0
var minimum_skin_terrain_clearance_m := INF
var original_vertices_checked := 0
var skin_poses := {}
var wall_faces := {}
var observation_stage := ""
var observation_index := 0
var observation_remaining := 0
var observation_on := false
var observed_final_frames := 0
var last_final_physics_frame := -1
var capture_requests: Array[String] = []
var source_before := {}
var source_after := {}
var stage_quality := {}
const SOURCE_PATHS := ["res://scripts/combat/test_ground_escape.gd","res://scripts/dragon_controller.gd","res://scripts/dragon_ground_pose.gd","res://scripts/dragon_ground_contact.gd","res://scripts/dragon_wing_contact.gd","res://scripts/dragon_wing_extrema.json","res://scripts/dragon_pose_probe.gd","res://scripts/dragon_head_pose.gd","res://scripts/dragon_breath.gd","res://scripts/dragon_breath_modifier.gd","res://scripts/dragon_skeleton_modifier.gd","res://scripts/terrain.gd","res://scripts/siege_environment.gd","res://scenes/main.tscn","res://project.godot","res://assets/models/dragon.glb","res://assets/models/dragon.glb.import"]
func source_hashes():
 var result:={}
 for path in SOURCE_PATHS:result[path]=FileAccess.get_sha256(path)
 return result
var worst_skin := {}
var worst_stance := {}
func export_skin_pose(label: String):
 var points:PackedVector3Array=skin_probe.coordinates(dragon.skeleton,dragon)
 var packed:Array=[]
 for local in points:
  var point:Vector3=dragon.to_global(local)
  packed.append([point.x,point.y,point.z])
 skin_poses[label]={"vertices":packed,"root":[dragon.global_position.x,dragon.global_position.y,dragon.global_position.z]}
func export_wall(collider: CollisionObject3D, shape_index: int):
 var identity:=str(collider.get_path())+":"+str(shape_index)
 if wall_faces.has(identity):return
 var owner=collider.shape_owner_get_owner(collider.shape_find_owner(shape_index))
 if not owner is CollisionShape3D or not owner.shape is ConcavePolygonShape3D:return
 var packed:Array=[]
 for vertex in owner.shape.get_faces():
  var point:Vector3=owner.to_global(vertex)
  packed.append([point.x,point.y,point.z])
 wall_faces[identity]={"faces":packed}
func stance_detail(limb: Dictionary, sample: Dictionary) -> Dictionary:
 var sk=dragon.skeleton
 var hip:Vector3=sk.to_global(sk.get_bone_global_pose(limb.chain[0]).origin)
 var reach:=0.0
 for index in limb.chain.size():
  var child:int=int(limb.chain[index+1]) if index+1<limb.chain.size() else int(limb.end)
  reach+=sk.to_global(sk.get_bone_global_pose(limb.chain[index]).origin).distance_to(sk.to_global(sk.get_bone_global_pose(child).origin))
 var anchor_error:=Vector3.ZERO
 if not limb.contact_sample.is_empty():anchor_error=limb.probe.point(sk,limb.contact_sample)-limb.contact_anchor
 var rotations:Dictionary={}
 for influence in sample.influence:rotations[str(influence.bone)]=str(sk.get_bone_pose_rotation(influence.bone))
 return {"hip":str(hip),"reach":reach,"target_distance":hip.distance_to(limb.get("previous_primary_target",limb.planted)),"wrist":str(sk.to_global(sk.get_bone_global_pose(limb.end).origin)),"planted":str(limb.planted),"target":str(limb.get("previous_primary_target",limb.planted)),"finish":str(limb.finish),"anchor":str(limb.contact_anchor),"anchor_error_xz":Vector2(anchor_error.x,anchor_error.z).length(),"contact_sample_index":limb.contact_sample.get("index",-1),"digit_local_rotations":rotations,"transition":limb.get("support_transition",false),"limited":limb.get("support_limited",false),"reposition":limb.repositioning,"step_t":limb.step_t,"swing_elapsed":limb.get("swing_elapsed",0),"body_recovering":dragon.wing_contact.body_pose_recovering,"body_blocked":dragon.wing_contact.body_pose_blocked}
func track_skin_and_claws():
 var points:PackedVector3Array=skin_probe.coordinates(dragon.skeleton,dragon)
 original_vertices_checked+=points.size()
 if not stage_quality.has(observation_stage):stage_quality[observation_stage]={"frames":0,"minimum_skin_terrain_clearance_m":INF,"maximum_stance_slide_m":0.0}
 var quality:Dictionary=stage_quality[observation_stage]
 quality.frames+=1
 for index in points.size():
  var world:Vector3=dragon.to_global(points[index])
  var clearance:float=world.y-dragon.landscape.ground_height(world.x,world.z)
  quality.minimum_skin_terrain_clearance_m=minf(quality.minimum_skin_terrain_clearance_m,clearance)
  if clearance<minimum_skin_terrain_clearance_m:
   minimum_skin_terrain_clearance_m=clearance
   var ray:=PhysicsRayQueryParameters3D.create(world+Vector3.UP*100,world-Vector3.UP*100,1)
   ray.exclude=[dragon.get_rid()]
   var physical:Dictionary=dragon.get_world_3d().direct_space_state.intersect_ray(ray)
   worst_skin={"stage":observation_stage,"tick":observation_index,"physics_frame":Engine.get_physics_frames(),"process_frame":Engine.get_process_frames(),"sample":str(skin_probe.samples[index]),"world":str(world),"clearance":clearance,"ray":str(physical),"root":str(dragon.global_position),"rotation":str(dragon.rotation),"articulation":dragon.wing_contact.wing_pose_metrics.duplicate(true)}
 for limb in dragon.ground_pose.limbs:
  var end:int=limb.end
  if not claw_track.has(end):
   var chosen:=-1
   var lowest:=INF
   for index in skin_probe.samples.size():
    if int(skin_probe.samples[index].claw)!=end:continue
    var world:Vector3=dragon.to_global(points[index])
    if world.y<lowest:
     lowest=world.y
     chosen=index
   if chosen>=0:claw_track[end]={"index":chosen,"previous":dragon.to_global(points[chosen]),"swing":limb.swinging}
  if not claw_track.has(end):continue
  var tracked:Dictionary=claw_track[end]
  var p:Vector3=dragon.to_global(points[tracked.index])
  var debug_pose:Dictionary=stance_detail(limb,skin_probe.samples[tracked.index]) if OS.get_cmdline_user_args().has("--leg-diagnostic") else {}
  if not limb.swinging and not tracked.swing:
   var slide:float=Vector2(p.x-tracked.previous.x,p.z-tracked.previous.z).length()
   quality.maximum_stance_slide_m=maxf(quality.maximum_stance_slide_m,slide)
   if slide>maximum_stance_slide_m:
    maximum_stance_slide_m=slide
    worst_stance={"stage":observation_stage,"tick":observation_index,"claw":end,"sample":str(skin_probe.samples[tracked.index]),"previous":str(tracked.previous),"point":str(p),"slide":slide,"root":str(dragon.global_position),"rotation":str(dragon.rotation),"articulation":dragon.wing_contact.wing_pose_metrics.duplicate(true)}
    if not debug_pose.is_empty():
     worst_stance.previous_pose=tracked.get("debug_pose",{})
     worst_stance.current_pose=debug_pose
     if slide>.015:print("ESCAPE_STANCE_WORST ",JSON.stringify(worst_stance))
  tracked.previous=p
  tracked.swing=limb.swinging
  tracked.debug_pose=debug_pose
func overlapping_hulls(mask: int = 3) -> Array[int]:
 var overlaps: Array[int] = []
 var query := PhysicsShapeQueryParameters3D.new()
 query.transform=dragon.global_transform
 query.exclude=[dragon.get_rid()]
 query.margin=0
 query.collision_mask=mask
 var space:=dragon.get_world_3d().direct_space_state
 for index in dragon.wing_contact.hulls.size():
  query.shape=dragon.wing_contact.hulls[index]
  if query.shape.points.size()>=4 and not space.intersect_shape(query,1).is_empty():overlaps.append(index)
 return overlaps
func check(ok: bool, label: String):
 print("PASS " if ok else "FAIL ",label)
 if not ok: failures.append(label)
func _initialize(): call_deferred("run")
func ticks(n: int):
 for _i in n:
  await physics_frame
  await process_frame
func key(code: Key, pressed: bool):
 var event := InputEventKey.new()
 event.keycode = code
 event.physical_keycode = code
 event.pressed = pressed
 Input.parse_input_event(event)
func capture(label: String):
 if not "--capture-ground-escape" in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/validation/v2/ground-escape-"+label+".png")
func mouse(relative: Vector2):
 var event:=InputEventMouseMotion.new()
 event.relative=relative
 event.screen_relative=relative
 event.position=Vector2(640,360)
 event.global_position=event.position
 Input.parse_input_event(event)
func observe_final():
 if not observation_on or last_final_physics_frame==Engine.get_physics_frames():return
 last_final_physics_frame=Engine.get_physics_frames()
 observed_final_frames+=1
 if dragon.locomotion_state!=dragon.LocomotionState.GROUNDED:observed_non_grounded_frames+=1
 var label:=observation_stage
 var index:=observation_index
 track_skin_and_claws()
 for bone in dragon.skeleton.get_bone_count():
  var ancestor:=bone
  while ancestor>=0 and ancestor not in [96,120]:ancestor=dragon.skeleton.get_bone_parent(ancestor)
  if ancestor<0:continue
  var actual:Quaternion=(dragon.skeleton.global_basis*dragon.skeleton.get_bone_global_pose(bone).basis).orthonormalized().get_rotation_quaternion()
  if previous_wing_rotations.has(bone):maximum_wing_step_deg=maxf(maximum_wing_step_deg,rad_to_deg(actual.angle_to(previous_wing_rotations[bone])))
  previous_wing_rotations[bone]=actual
 var overlapping: Array = overlapping_hulls()
 maximum_overlap_count = maxi(maximum_overlap_count,overlapping.size())
 maximum_prop_overlap_count=maxi(maximum_prop_overlap_count,overlapping_hulls(2).size())
 if not overlapping.is_empty() and index % 30 == 0:
  var details: Array = []
  for hull_index in overlapping:
   var query := PhysicsShapeQueryParameters3D.new()
   query.shape=dragon.wing_contact.hulls[hull_index]
   query.transform=dragon.global_transform
   query.collision_mask=3
   query.exclude=[dragon.get_rid()]
   query.margin=0
   var depth:=0.0
   var pairs:PackedVector3Array=dragon.get_world_3d().direct_space_state.collide_shape(query,4)
   for pair in range(0,pairs.size(),2): depth=maxf(depth,pairs[pair].distance_to(pairs[pair+1]))
   var colliders: Array=[]
   for hit in dragon.get_world_3d().direct_space_state.intersect_shape(query,4):
    colliders.append(str(hit.collider.get_path()))
    if (hit.collider.collision_layer&2)!=0:export_wall(hit.collider,int(hit.shape))
   details.append({"hull":hull_index,"depth":depth,"colliders":colliders})
  if label=="forward" and index in [90,180]:export_skin_pose(label+str(index))
  overlap_diagnostics.append({"stage":label,"frame":index,"overlaps":details})
  print("ESCAPE_FINAL_OVERLAP ",label," frame=",index," ",details)
 if label=="reverse":
  if breath.is_firing and Input.is_key_pressed(KEY_S) and dragon.head_aim_active:retreat_fire_frames+=1
  maximum_fire_mouth_error_m=maxf(maximum_fire_mouth_error_m,breath.mouth_position.distance_to(breath.rendered_oral_center+breath.breath_direction*.08))
  maximum_fire_head_error_deg=maxf(maximum_fire_head_error_deg,rad_to_deg(breath.breath_direction.angle_to(dragon.head_rendered_direction)))
  if index in [75,175]:
   var head_relative:Vector3=dragon.global_basis.inverse()*breath.breath_direction
   retreat_head_angles.append(rad_to_deg(atan2(-head_relative.x,-head_relative.z)))
   capture_requests.append("retreat-aim-plus15" if index==75 else "retreat-aim-minus15")
 maximum_head_step_deg = maxf(maximum_head_step_deg,rad_to_deg(previous_head.angle_to(dragon.head_rendered_direction)))
 previous_head=dragon.head_rendered_direction
 if index % 30 == 0:
  frames.append({"stage":label,"frame":index,"position":str(dragon.global_position),"velocity":str(dragon.velocity),"details":dragon.wing_contact.contact_details.duplicate(true),"yaw":dragon.rotation.y,"turn_blocked":dragon.pose_turn_blocked})

 if observation_remaining>0:
  observation_remaining-=1
  observation_index+=1
  if observation_remaining==0:export_skin_pose(label)
func stage(label: String, code: Key, n: int):
 var start := dragon.global_position
 var yaw := dragon.rotation.y
 if label=="reverse":
  key(KEY_T,true)
  await ticks(1)
  key(KEY_T,false)
  key(KEY_F,true)
  mouse(Vector2(-deg_to_rad(15.0)/dragon.mouse_sensitivity,0))
 key(code,true)
 observation_stage=label
 observation_index=0
 observation_remaining=n
 var switched:=false
 while observation_remaining>0:
  if label=="reverse" and observation_index>=80 and not switched:
   mouse(Vector2(deg_to_rad(30.0)/dragon.mouse_sensitivity,0))
   switched=true
  await ticks(1)
  while not capture_requests.is_empty():await capture(capture_requests.pop_front())
 key(code,false)
 if label=="reverse":key(KEY_F,false)
 await ticks(5)
 stages[label]={"horizontal_distance_m":Vector2(dragon.global_position.x-start.x,dragon.global_position.z-start.z).length(),"yaw_delta_deg":rad_to_deg(wrapf(dragon.rotation.y-yaw,-PI,PI))}
 await capture(label)
 print("ESCAPE ",label," motion=",dragon.global_position-start," yaw=",rad_to_deg(wrapf(dragon.rotation.y-yaw,-PI,PI))," details=",dragon.wing_contact.contact_details)
func run():
 source_before=source_hashes()
 scene = load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 dragon = scene.get_node("Dragon")
 combat = scene.get_node("SiegeCombat")
 breath=dragon.get_node("DragonBreath")
 await ticks(150)
 key(KEY_ENTER,true)
 await ticks(2)
 key(KEY_ENTER,false)
 # Fixture position only: all observation uses the real keyboard/controller.
 for actor in combat.enemies: actor.set_physics_process(false)
 combat.grace = 1000
 var args := OS.get_cmdline_user_args()
 var x := 215.0
 var z := 205.0
 for arg in args:
  if arg.begins_with("--x="): x = float(arg.trim_prefix("--x="))
  if arg.begins_with("--z="): z = float(arg.trim_prefix("--z="))
 for scan_z in [150.0,175.0,190.0,195.0,200.0,205.0,210.0,220.0,235.0]:
  print("ESCAPE_TERRAIN z=",scan_z," heights=",[dragon.landscape.ground_height(185,scan_z),dragon.landscape.ground_height(200,scan_z),dragon.landscape.ground_height(215,scan_z),dragon.landscape.ground_height(225,scan_z)])
 dragon.global_position = Vector3(x,dragon.landscape.ground_height(x,z)+4.0,z)
 dragon.rotation = Vector3.ZERO
 dragon.target_yaw=0
 dragon.target_pitch=0
 dragon.target_roll=0
 dragon.ground_blend=1
 dragon.wing_fold_blend=1
 dragon.locomotion_state = dragon.LocomotionState.GROUNDED
 dragon.current_speed=0
 dragon.velocity=Vector3.ZERO
 dragon.ground_pose.reset()
 dragon.manual_input_override=false
 await ticks(120)
 for index in dragon.wing_contact.hulls.size():
  var q := PhysicsShapeQueryParameters3D.new()
  q.shape=dragon.wing_contact.hulls[index]
  q.transform=dragon.global_transform
  q.collision_mask=3
  q.exclude=[dragon.get_rid()]
  q.margin=0
  for hit in dragon.get_world_3d().direct_space_state.intersect_shape(q,10):
   print("ESCAPE_OVERLAP hull=",index," collider=",hit.collider.get_path()," shape=",hit.shape," pairs=",dragon.get_world_3d().direct_space_state.collide_shape(q,4))
 var ray := PhysicsRayQueryParameters3D.create(dragon.global_position+Vector3.UP*2+Vector3.LEFT*25,dragon.global_position+Vector3.UP*2+Vector3.RIGHT*25,3)
 ray.exclude=[dragon.get_rid()]
 print("ESCAPE_CORRIDOR west_to_east=",dragon.get_world_3d().direct_space_state.intersect_ray(ray))
 ray.from=dragon.global_position+Vector3.UP*2+Vector3.RIGHT*25
 ray.to=dragon.global_position+Vector3.UP*2+Vector3.LEFT*25
 print("ESCAPE_CORRIDOR east_to_west=",dragon.get_world_3d().direct_space_state.intersect_ray(ray))
 check(dragon.locomotion_state==dragon.LocomotionState.GROUNDED and not dragon.manual_input_override and overlapping_hulls().is_empty(),"Fixture starts grounded with every actual hull clear; observed actions use Input WASD")
 await capture("start")
 print("ESCAPE_START ",dragon.global_position," state=",dragon.locomotion_state," contact=",dragon.wing_contact.contact_details)
 skin_probe.configure(dragon,dragon.skeleton,1)
 var final_modifier:SkeletonModifier3D
 for child in dragon.skeleton.get_children():
  if child is SkeletonModifier3D:final_modifier=child
 final_modifier.modification_processed.connect(observe_final)
 observation_on=true
 previous_head=dragon.head_rendered_direction
 await stage("forward",KEY_W,300)
 await stage("reverse",KEY_S,180)
 await stage("left",KEY_A,120)
 await stage("right",KEY_D,240)
 await stage("left_return",KEY_A,120)
 await stage("forward_after_turn",KEY_W,60)
 await stage("reverse_after_turn",KEY_S,120)
 observation_on=false
 source_after=source_hashes()
 check(source_before==source_after,"Relevant runtime, Skin asset and input driver sources remain unchanged during the observed run")
 check(stages.forward.horizontal_distance_m>1.0,"Real W approaches the actual fortress wall from a clear grounded start")
 check(stages.reverse.horizontal_distance_m>5.0,"Actual S withdraws more than 5m after contact; no teleport or manual override")
 check(absf(stages.right.yaw_delta_deg)>30.0 and absf(stages.left_return.yaw_delta_deg)>30.0,"Actual D and A both turn the dragon after retreat")
 check(stages.reverse_after_turn.horizontal_distance_m>2.0,"Actual S still withdraws more than 2m after both turn directions; no residual-contact deadlock")
 check(maximum_prop_overlap_count==0,"All 18 final rendered hulls stay outside real obstacle surfaces in every observed frame")
 check(observed_non_grounded_frames==0,"Real WASD controls remain grounded throughout every observed frame")
 check(observed_final_frames>=1140 and original_vertices_checked==observed_final_frames*25603 and minimum_skin_terrain_clearance_m>=-.05,"Every original skinned vertex is checked each observed frame against actual terrain, within existing 5cm limit")
 check(maximum_stance_slide_m<=.015,"Original claw stance remains locked within existing 1.5cm limit")
 check(retreat_fire_frames>=160,"Retreat, independent mouse aim and actual F fire coexist for at least 160 observed frames")
 check(retreat_head_angles.size()==2 and absf(retreat_head_angles[0]-15.0)<3.0 and absf(retreat_head_angles[1]+15.0)<3.0,"Free neck tracks two mouse targets +15/-15 degrees during retreat")
 check(maximum_fire_mouth_error_m<.001 and maximum_fire_head_error_deg<.1,"Final flame oral origin and direction follow the rendered free neck after wing recovery")
 check(maximum_wing_step_deg<=5.0,"Both final wing branches stay continuous within 5 degrees per observed frame")
 check(maximum_head_step_deg<=5.0,"Head direction stays continuous within 5 degrees per observed frame")
 print("ESCAPE_METRICS ",JSON.stringify({"stages":stages,"source_sha256_before":source_before,"source_sha256_after":source_after,"sources_unchanged":source_before==source_after,"stage_quality":stage_quality,"observed_final_frames":observed_final_frames,"worst_skin":worst_skin,"worst_stance":worst_stance,"original_vertices_checked":original_vertices_checked,"minimum_skin_terrain_clearance_m":minimum_skin_terrain_clearance_m,"maximum_stance_slide_m":maximum_stance_slide_m,"retreat_fire_frames":retreat_fire_frames,"retreat_head_angles":retreat_head_angles,"maximum_fire_mouth_error_m":maximum_fire_mouth_error_m,"maximum_fire_head_error_deg":maximum_fire_head_error_deg,"maximum_overlap_count":maximum_overlap_count,"maximum_prop_overlap_count":maximum_prop_overlap_count,"observed_non_grounded_frames":observed_non_grounded_frames,"maximum_head_step_deg":maximum_head_step_deg,"maximum_wing_step_deg":maximum_wing_step_deg,"articulation":dragon.wing_contact.wing_pose_metrics.duplicate(true)}))
 var file := FileAccess.open("res://docs/validation/v2/ground-escape-trace.json",FileAccess.WRITE)
 var skin_file:=FileAccess.open("res://docs/validation/v2/ground-escape-skin.json",FileAccess.WRITE)
 skin_file.store_string(JSON.stringify({"poses":skin_poses,"walls":wall_faces,"sample_count":skin_probe.samples.size()}))
 file.store_string(JSON.stringify({"stages":stages,"source_sha256_before":source_before,"source_sha256_after":source_after,"sources_unchanged":source_before==source_after,"stage_quality":stage_quality,"observed_final_frames":observed_final_frames,"worst_skin":worst_skin,"worst_stance":worst_stance,"original_vertices_checked":original_vertices_checked,"minimum_skin_terrain_clearance_m":minimum_skin_terrain_clearance_m,"maximum_stance_slide_m":maximum_stance_slide_m,"retreat_fire_frames":retreat_fire_frames,"retreat_head_angles":retreat_head_angles,"maximum_fire_mouth_error_m":maximum_fire_mouth_error_m,"maximum_fire_head_error_deg":maximum_fire_head_error_deg,"frames":frames,"overlap_diagnostics":overlap_diagnostics,"maximum_overlap_count":maximum_overlap_count,"maximum_prop_overlap_count":maximum_prop_overlap_count,"observed_non_grounded_frames":observed_non_grounded_frames,"maximum_head_step_deg":maximum_head_step_deg,"maximum_wing_step_deg":maximum_wing_step_deg,"articulation":dragon.wing_contact.wing_pose_metrics.duplicate(true),"failures":failures}," "))
 var csv:=FileAccess.open("res://docs/validation/v2/ground-escape-metrics.csv",FileAccess.WRITE)
 csv.store_csv_line(PackedStringArray(["stage","distance_m","yaw_deg","final_skin_frames","minimum_skin_terrain_clearance_m","maximum_original_claw_stance_slide_m","controller_sha256","ground_pose_sha256","wing_contact_sha256","wing_selection_sha256"]))
 for label in stages:
  var quality:Dictionary=stage_quality[label]
  csv.store_csv_line(PackedStringArray([label,str(stages[label].horizontal_distance_m),str(stages[label].yaw_delta_deg),str(quality.frames),str(quality.minimum_skin_terrain_clearance_m),str(quality.maximum_stance_slide_m),source_before["res://scripts/dragon_controller.gd"],source_before["res://scripts/dragon_ground_pose.gd"],source_before["res://scripts/dragon_wing_contact.gd"],source_before["res://scripts/dragon_wing_extrema.json"]]))
 quit(0 if failures.is_empty() else 1)
