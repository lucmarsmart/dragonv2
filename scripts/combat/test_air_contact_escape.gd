extends SceneTree

var scene:Node3D
var dragon:DragonController
var failures:Array[String]=[]
var checks:=0
var rows:Array=[]
var observed:=false
var phase:=""
var maximum_actual_overlaps:=0
var last_frame:=-1
var sources:={}
const PATHS:=["scripts/combat/test_air_contact_escape.gd","scripts/dragon_controller.gd","scripts/dragon_wing_contact.gd","scripts/dragon_ground_contact.gd","scripts/dragon_ground_pose.gd","scripts/dragon_skeleton_modifier.gd","scripts/dragon_head_pose.gd","scripts/dragon_wing_extrema.json","scenes/main.tscn","project.godot"]
func _initialize():call_deferred("run")
func ticks(n:int):
 for _i in n:
  await physics_frame
  await process_frame
func key(code:Key,pressed:bool):
 var e:=InputEventKey.new()
 e.keycode=code
 e.physical_keycode=code
 e.pressed=pressed
 Input.parse_input_event(e)
func check(ok:bool,label:String):
 checks+=1
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func final_pose():
 if not observed or last_frame==Engine.get_physics_frames():return
 last_frame=Engine.get_physics_frames()
 var q:=PhysicsShapeQueryParameters3D.new()
 q.transform=dragon.global_transform
 q.collision_mask=3
 q.margin=0
 q.exclude=[dragon.get_rid()]
 var overlaps:Array=[]
 for i in dragon.wing_contact.hulls.size():
  q.shape=dragon.wing_contact.hulls[i]
  if q.shape.points.size()>=4 and not dragon.get_world_3d().direct_space_state.intersect_shape(q,1).is_empty():overlaps.append(i)
 maximum_actual_overlaps=maxi(maximum_actual_overlaps,overlaps.size())
 rows.append({"phase":phase,"position":str(dragon.global_position),"velocity":str(dragon.velocity),"speed":dragon.current_speed,"state":dragon.locomotion_state,"actual_hull_overlaps":overlaps,"contacts":dragon.wing_contact.contact_details.duplicate(true),"space":Input.is_key_pressed(KEY_SPACE),"yaw":dragon.rotation.y,"pitch":dragon.rotation.x})
func run():
 for path in PATHS:sources[path]=FileAccess.get_sha256("res://"+path)
 scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 dragon=scene.get_node("Dragon")
 await ticks(150)
 key(KEY_ENTER,true)
 await ticks(1)
 key(KEY_ENTER,false)
 # One legal initial air fixture, followed only by production keyboard input.
 dragon.global_position=Vector3(0,300,0)
 dragon.rotation=Vector3.ZERO
 dragon.target_yaw=0
 dragon.target_pitch=0
 dragon.target_roll=0
 dragon.velocity=Vector3(0,0,-26)
 dragon.current_speed=26
 dragon.has_taken_off=true
 dragon.locomotion_state=dragon.LocomotionState.FLYING
 var wall:=StaticBody3D.new()
 wall.name="AirEscapeCalibrationCliff"
 wall.collision_layer=2
 var shape:=CollisionShape3D.new()
 var box:=BoxShape3D.new()
 box.size=Vector3(100,200,2)
 shape.shape=box
 wall.add_child(shape)
 scene.add_child(wall)
 wall.global_position=Vector3(0,300,-30)
 await ticks(5)
 var final_modifier:SkeletonModifier3D
 for child in dragon.skeleton.get_children():
  if child is SkeletonModifier3D:final_modifier=child
 final_modifier.modification_processed.connect(final_pose)
 phase="approach"
 observed=true
 key(KEY_W,true)
 await ticks(360)
 key(KEY_W,false)
 check(dragon.wing_contact.predictive_contact and dragon.current_speed<2,"W approaches a physical cliff and stops through production flight collision")
 var stopped:=dragon.global_position
 phase="climb_escape"
 key(KEY_SPACE,true)
 await ticks(180)
 check(dragon.global_position.y-stopped.y>5,"Actual SPACE climbs at least5m out of a stopped flight contact")
 var climb_height:=dragon.global_position.y-stopped.y
 phase="turn_escape"
 key(KEY_A,true)
 await ticks(180)
 key(KEY_A,false)
 key(KEY_SPACE,false)
 await ticks(120)
 observed=false
 check(dragon.global_position.distance_to(stopped)>10 and dragon.current_speed>2,"Actual turning and climb regain travel after cliff contact")
 check(maximum_actual_overlaps==0,"All18 final original skin enclosures remain outside actual physical surfaces")
 check(not dragon.manual_input_override,"Air escape uses real keyboard with no input override")
 var frozen:=true
 for path in PATHS:frozen=frozen and sources[path]==FileAccess.get_sha256("res://"+path)
 check(frozen,"Air contact runtime and driver sources remain frozen")
 FileAccess.open("res://docs/validation/v2/air-contact-escape.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"pass":failures.is_empty(),"climb_height_m":climb_height,"maximum_actual_overlaps":maximum_actual_overlaps,"sources_sha256":sources,"rows":rows,"teleports_after_initial_fixture":0,"scope":"Actual Input/production flight and all18 final hulls against a physical vertical cliff fixture; finite escape case, no terrain universality or native FPS claim"},"  "))
 print("AIR_CONTACT_ESCAPE_RESULT ",checks-failures.size(),"/",checks," failures=",failures)
 quit(0 if failures.is_empty() else 1)
