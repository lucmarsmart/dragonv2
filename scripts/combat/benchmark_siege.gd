extends SceneTree
var samples: Array[float] = []
func _initialize(): call_deferred("run")
func run():
 root.size=Vector2i(1280,720)
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 Engine.max_fps=0
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 for _i in 180: await process_frame
 var combat=scene.get_node("SiegeCombat")
 var dragon=scene.get_node("Dragon")
 combat.start_mission()
 # A continuous turn keeps the live target around the fortress and evades bolts.
 dragon.manual_input_override=true
 dragon.manual_turn_input=0.65
 var start=Time.get_ticks_usec()
 while Time.get_ticks_usec()-start<5000000: await process_frame
 var previous=Time.get_ticks_usec()
 start=previous
 var running_frames:=0
 var fire_frames:=0
 var firing:=false
 var draws:=0.0
 while Time.get_ticks_usec()-start<60000000:
  await process_frame
  var now=Time.get_ticks_usec()
  var next_fire=fmod(float(now-start)/1000000.0,4.0)<0.8
  if next_fire!=firing:
   firing=next_fire
   var event:=InputEventKey.new()
   event.keycode=KEY_F
   event.physical_keycode=KEY_F
   event.pressed=firing
   Input.parse_input_event(event)
  samples.append(float(now-previous)/1000.0)
  previous=now
  if combat.is_running(): running_frames+=1
  if scene.get_node("Dragon/DragonBreath").is_firing: fire_frames+=1
  draws=maxf(draws,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
 var elapsed=float(Time.get_ticks_usec()-start)/1000000.0
 var sorted=samples.duplicate()
 sorted.sort()
 var result={"renderer":RenderingServer.get_current_rendering_method(),"viewport":"1280x720", "device":RenderingServer.get_video_adapter_name(),"elapsed_s":elapsed,"frames":samples.size(),"fps_average":samples.size()/elapsed,"frame_p95_ms":sorted[int(sorted.size()*0.95)],"combat_running_fraction":float(running_frames)/samples.size(),"fire_active_fraction":float(fire_frames)/samples.size(),"shots_fired":combat.shots_fired,"health":combat.health,"draws_max":draws}
 result["passed"]=result.fps_average>=60 and result.frame_p95_ms<=25 and result.combat_running_fraction>0.99 and result.shots_fired>=5 and result.fire_active_fraction>0.1
 print("SIEGE_BENCHMARK ",JSON.stringify(result))
 var f=FileAccess.open("res://docs/validation/v2/combat-performance.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(result,"  "))
 root.get_texture().get_image().save_png("res://docs/validation/v2/combat-performance.png")
 scene.queue_free()
 for _i in 30: await process_frame
 quit(0 if result.passed else 1)
