extends SceneTree
const Probe = preload("res://scripts/dragon_pose_probe.gd")
func _initialize() -> void: call_deferred("run")
func key(code: Key, down: bool) -> void:
 var e := InputEventKey.new()
 e.keycode = code
 e.physical_keycode = code
 e.pressed = down
 Input.parse_input_event(e)
func run() -> void:
 var scene = load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 for i in 100: await process_frame
 key(KEY_ENTER,true)
 await process_frame
 key(KEY_ENTER,false)
 var dragon = scene.get_node("Dragon")
 dragon.global_position = Vector3(292.63,27.5,106.13)
 dragon.rotation = Vector3(0,-.58,0)
 dragon.target_yaw = -.58
 dragon.target_pitch = 0
 dragon.target_roll = 0
 dragon.locomotion_state = dragon.LocomotionState.GROUNDED
 dragon.has_taken_off = true
 dragon.velocity = Vector3.ZERO
 dragon.current_speed = 0
 key(KEY_T,true)
 await process_frame
 key(KEY_T,false)
 print("DIAGNOSTIC ONLY: positioned real scene at pre-rescue trace; not a mission acceptance run")
 Probe.costs = {}
 var start := Time.get_ticks_usec()
 for i in 240:
  var target := Vector3(300,44,90)
  var diff: Vector3 = target-dragon.global_position
  var yaw: float = wrapf(atan2(-diff.x,-diff.z)-dragon.rotation.y,-PI,PI)
  var pitch: float = asin(diff.normalized().y)
  var mouse := InputEventMouseMotion.new()
  mouse.relative = Vector2((dragon.head_requested_yaw-yaw)/dragon.mouse_sensitivity,(dragon.head_requested_pitch-pitch)/dragon.mouse_sensitivity).limit_length(120)
  Input.parse_input_event(mouse)
  key(KEY_W,i<180)
  await physics_frame
  await process_frame
  if i%30==0:
   print("RESCUE_PROFILE ",JSON.stringify({"frame":i,"elapsed_us":Time.get_ticks_usec()-start,"position":str(dragon.global_position),"blocked":dragon.head_pose_blocked,"costs":Probe.costs}))
   Probe.costs = {}
 key(KEY_W,false)
 quit()
