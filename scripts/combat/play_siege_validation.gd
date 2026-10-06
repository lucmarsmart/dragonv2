extends SceneTree
## D07 playthrough driver. Reads state; all gameplay changes come from native InputEvents.
## No teleport after Enter, health/grace changes, direct aim/damage calls, or phase writes.
var scene: Node3D
var combat: SiegeCombat
var dragon: DragonController
var breath: DragonBreath
var arena: Node3D
var held: Dictionary = {}
var input_events := 0
var phase_sequence: Array = []
var mode := "approach_landing"
var stage := 0
var rescue_aligned := false
var escape_gate_cleared := false
var frame := 0
var stalled_frames := 0
var trace: FileAccess
var target: Node3D
var waypoint := Vector3.ZERO
var path_distance := 0.0
var max_step := 0.0
var last_position := Vector3.ZERO
var last_phase := -1
var observed_start := false
var snapshots: Array = []
var source_hashes: Dictionary = {}
var failed := ""
var recording := false
var tag := "headless"
var movie_maker := false
var perf_started_us := 0
var perf_previous_us := 0
var perf_previous_group := ""
var perf_capture_interval := false
var perf_groups: Dictionary = {}
var perf_all: Array[float] = []
var perf_clean: Array[float] = []
var perf_warmup_excluded := 0
var perf_capture_excluded := 0
const PERF_WARMUP_US := 5000000
const OUT := "res://docs/validation/v2/"

func _initialize() -> void:
 call_deferred("run")

func measure_process_frame() -> void:
 var now := Time.get_ticks_usec()
 if recording and perf_previous_us > 0 and is_instance_valid(combat):
  var elapsed_ms := float(now-perf_previous_us)/1000.0
  if now-perf_started_us < PERF_WARMUP_US:
   perf_warmup_excluded += 1
  else:
   perf_all.append(elapsed_ms)
   if perf_capture_interval:
    perf_capture_excluded += 1
   else:
    perf_clean.append(elapsed_ms)
    if not perf_groups.has(perf_previous_group):perf_groups[perf_previous_group] = []
    perf_groups[perf_previous_group].append(elapsed_ms)
 perf_capture_interval = false
 perf_previous_us = now
 if is_instance_valid(combat) and is_instance_valid(dragon):
  perf_previous_group = "%s/%s" % [str(combat.phase),"grounded" if dragon.locomotion_state==dragon.LocomotionState.GROUNDED else "air"]

func frame_statistics(values: Array) -> Dictionary:
 if values.is_empty():return {"frames":0,"elapsed_wall_s":0.0,"fps_actual_wall":null,"frame_p95_ms":null}
 var sorted := values.duplicate()
 sorted.sort()
 var total_ms := 0.0
 for value in values:total_ms += float(value)
 return {"frames":values.size(),"elapsed_wall_s":total_ms/1000.0,"fps_actual_wall":float(values.size())*1000.0/total_ms,"frame_p95_ms":sorted[mini(sorted.size()-1,int(ceil(sorted.size()*0.95))-1)]}

func performance_report() -> Dictionary:
 var meaningful := DisplayServer.get_name()!="headless" and not movie_maker
 var groups := {}
 for group in perf_groups:
  var stats := frame_statistics(perf_groups[group])
  stats["reference_budget_met"] = (stats.fps_actual_wall>=60 and stats.frame_p95_ms<=25) if meaningful and stats.frames>=60 else null
  groups[group] = stats
 var clean := frame_statistics(perf_clean)
 return {"valid_runtime_fps_measurement":meaningful,"movie_maker_enabled":movie_maker,"renderer_method":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"viewport":[root.size.x,root.size.y],"vsync_mode":DisplayServer.window_get_vsync_mode() if meaningful else null,"engine_max_fps":Engine.max_fps,"warmup_seconds_wall":5.0,"warmup_frames_excluded":perf_warmup_excluded,"capture_io_intervals_excluded":perf_capture_excluded,"measurement":"Time.get_ticks_usec deltas between process_frame signals; previous-frame phase and grounded state","reference_only":{"fps":60,"frame_p95_ms":25},"reference_budget_met":(clean.fps_actual_wall>=60 and clean.frame_p95_ms<=25) if meaningful and clean.frames>=60 else null,"post_warmup_all_intervals":frame_statistics(perf_all),"post_warmup_without_capture_io":clean,"by_phase_and_locomotion":groups}

func key(code: Key, down: bool) -> void:
 if bool(held.get(code,false)) == down:
  return
 held[code] = down
 var e := InputEventKey.new()
 e.keycode = code
 e.physical_keycode = code
 e.pressed = down
 input_events += 1
 Input.parse_input_event(e)

func release_controls() -> void:
 for code in held.keys():
  key(code,false)

func tick() -> void:
 await physics_frame
 await process_frame

func pulse(code: Key) -> void:
 key(code,true)
 await tick()
 key(code,false)

func capture(label: String) -> void:
 if DisplayServer.get_name() == "headless":
  return
 perf_capture_interval = true
 await RenderingServer.frame_post_draw
 var filename := OUT + "playthrough-" + tag + "-%05d-%s.png" % [frame,label]
 root.get_texture().get_image().save_png(filename)
 snapshots.append(filename)

func position_array(p: Vector3) -> Array:
 return [p.x,p.y,p.z]

func sample(event: String = "tick") -> void:
 var slides: Array = []
 for index in dragon.get_slide_collision_count():
  var collision := dragon.get_slide_collision(index)
  slides.append({"collider":str(collision.get_collider().get_path()),"normal":position_array(collision.get_normal()),"position":position_array(collision.get_position())})
 var actors: Array = []
 for enemy in combat.enemies:
  actors.append({"name":enemy.name,"kind":enemy.kind,"position":position_array(enemy.global_position),"health":enemy.health,"dead":enemy.dead,"state":enemy.state})
 var ray_hit := {}
 if is_instance_valid(target):
  var ray := PhysicsRayQueryParameters3D.create(breath.mouth_position,target_center(target),7)
  ray.exclude = [dragon.get_rid()]
  ray_hit = scene.get_world_3d().direct_space_state.intersect_ray(ray)
 var blocker := str(ray_hit.collider.get_path()) if not ray_hit.is_empty() else ""
 var impact_node := instance_from_id(breath.hit_collider_id) if breath.hit_collider_id else null
 var impact_name := str(impact_node.get_path()) if is_instance_valid(impact_node) else ""
 var limb_state: Array = []
 for limb in dragon.ground_pose.limbs:
  limb_state.append({"end":limb.end,"planted":position_array(limb.planted),"start":position_array(limb.start),"finish":position_array(limb.finish),"swinging":limb.swinging,"step_t":limb.step_t,"actual":position_array(limb.actual),"foot_basis_euler":position_array(limb.foot_basis.get_euler())})
 var spine_state: Array = []
 if is_instance_valid(dragon.skeleton):
  for bone in dragon.bone_spine_indices:
   var rotation := dragon.skeleton.get_bone_pose_rotation(bone)
   spine_state.append({"bone":bone,"position":position_array(dragon.skeleton.get_bone_pose_position(bone)),"rotation_quaternion":[rotation.x,rotation.y,rotation.z,rotation.w]})
 var pose := {"body_rotation":position_array(dragon.rotation),"body_target_rotation":[dragon.target_pitch,dragon.target_yaw,dragon.target_roll],"velocity":position_array(dragon.velocity),"ground_blend":dragon.ground_blend,"pose_ground_blend":dragon.ground_pose.pose_blend,"walk_cycle_phase":dragon.walk_cycle_phase,"spine_bones":spine_state,"limbs":limb_state,"head_actual":[dragon.head_aim_yaw,dragon.head_aim_pitch],"head_aim_direction":position_array(dragon.head_aim_direction),"head_rendered_direction":position_array(dragon.head_rendered_direction),"head_pose_blocked":dragon.head_pose_blocked,"pose_turn_blocked":dragon.pose_turn_blocked,"contact_details":dragon.wing_contact.contact_details,"ground_guard_motion":position_array(dragon.ground_guard_motion),"ground_executed_motion":position_array(dragon.ground_executed_motion),"ground_guard_snap_delta":position_array(dragon.ground_guard_snap_delta)}
 var keys: Array = []
 for code in held:
  if held[code]:keys.append(OS.get_keycode_string(code))
 trace.store_line(JSON.stringify({"event":event,"frame":frame,"time":combat.active_time,"phase":combat.phase,"mode":mode,"stage":stage,"position":position_array(dragon.global_position),"mouth":position_array(breath.mouth_position),"direction":position_array(breath.breath_direction),"aim_requested":[dragon.head_requested_yaw,dragon.head_requested_pitch],"locomotion":dragon.locomotion_state,"speed":dragon.current_speed,"health":combat.health,"grace":combat.grace,"fuel":breath.fuel,"fire":breath.is_firing,"fire_hits":combat.fire_hits,"los_blocker":blocker,"impact_blocker":impact_name,"impact_distance":breath.hit_distance,"core_distance":breath.core_distance,"shots":combat.shots_fired,"damages":combat.damage_events,"target":str(target.name) if is_instance_valid(target) else "","waypoint":position_array(waypoint),"keys":keys,"input_w":Input.is_key_pressed(KEY_W),"input_shift":Input.is_key_pressed(KEY_SHIFT),"shoreline_blocked":dragon.shoreline_blocked,"actors":actors,"pose":pose,"slide_collisions":slides,"manual_input_override":dragon.manual_input_override,"wing_predictive_contact":dragon.wing_contact.predictive_contact,"wing_contact_normal":position_array(dragon.wing_contact.contact_normal),"fold_requested":dragon.contact_fold_requested,"fold_blend":dragon.wing_fold_blend}))

func aim_at(p: Vector3) -> void:
 var local := dragon.global_basis.inverse() * (p-breath.mouth_position).normalized()
 var yaw := clampf(atan2(-local.x,-local.z),-PI/4,PI/4)
 var pitch := clampf(asin(clampf(local.y,-1,1)),-PI/6,PI/6)
 var mouse := InputEventMouseMotion.new()
 mouse.relative = Vector2((dragon.head_requested_yaw-yaw)/dragon.mouse_sensitivity,(dragon.head_requested_pitch-pitch)/dragon.mouse_sensitivity).limit_length(120)
 input_events += 1
 Input.parse_input_event(mouse)

func walk_to(p: Vector3, stop_distance: float = 3.0) -> bool:
 waypoint = p
 var offset := p-dragon.global_position
 offset.y = 0
 var wanted_yaw := atan2(-offset.x,-offset.z)
 var turn_error := wrapf(wanted_yaw-dragon.target_yaw,-PI,PI)
 key(KEY_A,turn_error > 0.028)
 key(KEY_D,turn_error < -0.028)
 var actual_error := wrapf(wanted_yaw-dragon.rotation.y,-PI,PI)
 var reached := offset.length() < stop_distance
 key(KEY_W,not reached and absf(actual_error) < 0.4)
 key(KEY_S,false)
 key(KEY_SHIFT,not reached and absf(actual_error)<0.2 and offset.length()>12)
 return reached

func live_turret(index: int) -> Node3D:
 for enemy in combat.enemies:
  if enemy.name == "Ballista_%d" % index:
   return enemy
 return null

func target_center(enemy: Node3D) -> Vector3:
 return enemy.global_position + Vector3.UP * (1.8 if enemy.kind == "turret" else 1.0)

func attack_target(enemy: Node3D) -> void:
 target = enemy
 var center := target_center(enemy)
 aim_at(center)
 var direction := (center-breath.mouth_position).normalized()
 var distance := center.distance_to(breath.mouth_position)
 var aim_error := breath.breath_direction.angle_to(direction)
 key(KEY_F,distance < 25.0 and aim_error < deg_to_rad(7) and breath.fuel > 0.0)

func control() -> void:
 if mode == "approach_landing":
  key(KEY_F,false)
  if dragon.locomotion_state == dragon.LocomotionState.GROUNDED:
   mode = "enter_gate"
   sample("grounded")
  return
 if mode == "enter_gate":
  key(KEY_F,false)
  if walk_to(Vector3(300,24,150),5):
   mode = "turrets"
   stage = 0
  return
 if mode == "turrets":
  var order := [2,1,0]
  if stage >= order.size():
   mode = "captain"
   return
  var enemy: Node3D = live_turret(order[stage])
  if enemy.dead:
   sample("turret_destroyed")
   stage += 1
   return
  # Southern firing approach, clear of the plinth and beyond the dragon's snout.
  var stations := [Vector3(330,24,150),Vector3(330,24,114),Vector3(271,24,110)]
  var station: Vector3 = stations[stage]
  var reached := walk_to(station,2.0)
  if reached:
   var off := target_center(enemy)-dragon.global_position
   var yaw := atan2(-off.x,-off.z)
   var err := wrapf(yaw-dragon.target_yaw,-PI,PI)
   key(KEY_A,err>0.025)
   key(KEY_D,err < -0.025)
  attack_target(enemy)
  return
 if mode == "captain":
  target = null
  for enemy in combat.enemies:
   if enemy.kind == "captain" and not enemy.dead:
    target = enemy
    break
  if not is_instance_valid(target):
   mode = "rescue"
   return
  # Face and backpedal with native S before the long snout passes through a charging foe.
  var delta := target.global_position-dragon.global_position
  delta.y = 0
  var yaw := atan2(-delta.x,-delta.z)
  var err := wrapf(yaw-dragon.target_yaw,-PI,PI)
  var facing := absf(wrapf(yaw-dragon.rotation.y,-PI,PI))<0.4
  key(KEY_A,err>0.028)
  key(KEY_D,err < -0.028)
  key(KEY_W,facing and delta.length()>23)
  key(KEY_S,facing and delta.length()<18)
  key(KEY_SHIFT,false)
  attack_target(target)
  return
 if mode == "rescue":
  key(KEY_F,false)
  aim_at(arena.rescue_point+Vector3.UP*20)
  if not rescue_aligned:
   if walk_to(arena.rescue_point+Vector3(0,0,23),3):rescue_aligned = true
  else:
   walk_to(arena.rescue_point,8)
  key(KEY_E,dragon.global_position.distance_to(arena.rescue_point)<11.9)
  if combat.phase == combat.Phase.ESCAPE:
   key(KEY_E,false)
   mode = "escape_retreat"
  return
 if mode == "escape_retreat":
  key(KEY_F,false)
  key(KEY_W,false)
  key(KEY_A,false)
  key(KEY_D,false)
  key(KEY_SHIFT,dragon.global_position.z<106)
  key(KEY_S,dragon.global_position.z<106)
  if dragon.global_position.z>=106:mode = "escape"
  return
 if mode == "escape":
  key(KEY_F,false)
  aim_at(waypoint+Vector3.UP*15)
  if not escape_gate_cleared:
   if walk_to(Vector3(300,24,202),3):escape_gate_cleared = true
  else:
   walk_to(arena.escape_point,10)

func run() -> void:
 root.size = Vector2i(1280,720)
 movie_maker = bool(Engine.call("is_movie_maker_enabled")) if Engine.has_method("is_movie_maker_enabled") else OS.get_cmdline_args().has("--write-movie")
 tag = "headless" if DisplayServer.get_name()=="headless" else ("metal" if movie_maker else "native")
 if DisplayServer.get_name()!="headless" and not movie_maker:
  DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 process_frame.connect(measure_process_frame)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 trace = FileAccess.open(OUT+"playthrough-"+tag+".jsonl",FileAccess.WRITE)
 for source in ["project.godot","scenes/main.tscn","scripts/terrain.gd","scripts/siege_environment.gd","scripts/dragon_controller.gd","scripts/dragon_skeleton_modifier.gd","scripts/dragon_ground_pose.gd","scripts/dragon_ground_contact.gd","scripts/dragon_head_pose.gd","scripts/dragon_pose_probe.gd","scripts/dragon_wing_contact.gd","scripts/dragon_breath.gd","scripts/dragon_breath_modifier.gd","scripts/combat/siege_combat.gd","scripts/combat/siege_enemy.gd","scripts/combat/siege_projectile.gd","scripts/combat/siege_ui.gd","scripts/dragon_wing_extrema.json","scripts/dragon_affine_support.json","scripts/combat/play_siege_validation.gd","shaders/terrain.gdshader","shaders/foliage.gdshader","shaders/landscape_sky.gdshader","shaders/landscape_water.gdshader","shaders/dragon_wing.gdshader","shaders/flame.gdshader","shaders/smoke.gdshader","shaders/siege_egg.gdshader"]:
  source_hashes[source] = FileAccess.get_sha256("res://"+source)
 scene = load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 combat = scene.get_node("SiegeCombat")
 dragon = scene.get_node("Dragon")
 breath = dragon.get_node("DragonBreath")
 arena = scene.get_node("SiegeEnvironment")
 for i in range(360):
  await tick()
  if combat.initialized:break
 if not combat.initialized:
  failed = "mission_initialization_timeout"
  finish()
  return
 await capture("briefing")
 await pulse(KEY_ENTER)
 observed_start = combat.phase == combat.Phase.DEFENSES
 last_position = dragon.global_position
 await pulse(KEY_T)
 await pulse(KEY_L)
 perf_started_us = Time.get_ticks_usec()
 perf_previous_us = perf_started_us
 recording = true
 for i in range(60*210):
  frame = i
  if combat.phase in [combat.Phase.VICTORY,combat.Phase.DEFEAT]:break
  control()
  await tick()
  var step := last_position.distance_to(dragon.global_position)
  path_distance += step
  max_step = maxf(max_step,step)
  last_position = dragon.global_position
  if combat.phase != last_phase:
   last_phase = combat.phase
   phase_sequence.append(last_phase)
   sample("phase_changed")
   await capture("phase_%d" % last_phase)
  if frame % 120 == 0:
   sample()
   print("PLAYTRACE t=",snapped(combat.active_time,.01)," mode=",mode," pos=",dragon.global_position," hp=",combat.health," turrets=",combat.turrets_destroyed," firehits=",combat.fire_hits," aim=",dragon.head_requested_yaw,",",dragon.head_requested_pitch)
  if frame % 600 == 0:await capture("sequence")
  if mode in ["enter_gate","rescue","escape"] and Input.is_key_pressed(KEY_W) and step<0.001:
   stalled_frames += 1
  else:
   stalled_frames = 0
  if stalled_frames > 300:
   failed = "ground_movement_blocked_5s"
   sample("blocked_collision")
   break
  if step > 3.0:
   failed = "movement_discontinuity_above_3m"
   break
 release_controls()
 if failed.is_empty() and combat.phase != combat.Phase.VICTORY:
  failed = "normal_gameplay_defeat" if combat.phase == combat.Phase.DEFEAT else "mission_timeout"
 sample("finished")
 await capture("victory" if failed.is_empty() else "blocked")
 finish()

func finish() -> void:
 var changed_sources: Array = []
 for source in source_hashes:
  if FileAccess.get_sha256("res://"+source) != source_hashes[source]:changed_sources.append(source)
 var report := {"pass":failed.is_empty(),"input_events":input_events,"phase_sequence":phase_sequence,"shots_fired":combat.shots_fired if combat else 0,"damage_events":combat.damage_events if combat else 0,"fire_hits":combat.fire_hits if combat else 0,"turrets_destroyed":combat.turrets_destroyed if combat else 0,"captain_dead":combat.captain_dead if combat else false,"failure":failed,"start_via_enter":observed_start,"phase":combat.phase if combat else -1,"health":combat.health if combat else 0,"time":combat.active_time if combat else 0,"path_distance_m":path_distance,"max_physics_step_m":max_step,"teleports_after_start":0,"damage_api_calls":0,"runtime_state_overrides":0,"input_method":"Input.parse_input_event: Enter, T, L, W/A/S/D/Shift/E/F and mouse head-aim motion","snapshots":snapshots,"renderer":DisplayServer.get_name(),"runtime_sources_sha256":source_hashes,"runtime_sources_unchanged_at_finish":changed_sources.is_empty(),"source_files_changed_during_run":changed_sources,"performance":performance_report()}
 FileAccess.open(OUT+"playthrough-"+tag+"-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 if trace:trace.close()
 print("PLAYTHROUGH_RESULT ",JSON.stringify(report))
 recording = false
 if scene:scene.free()
 quit(0 if failed.is_empty() else 1)
