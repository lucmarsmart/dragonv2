extends SceneTree
func _initialize(): call_deferred('go')
func go():
 var scene=load('res://scenes/main.tscn').instantiate()
 root.add_child(scene)
 var cam=scene.get_node('FlightCamera')
 cam.set_process(false)
 cam.set_physics_process(false)
 cam.position=Vector3(-210,170,260)
 cam.look_at(Vector3(-180,110,-300))
 var dragon=scene.get_node('Dragon')
 dragon.set_physics_process(false)
 for i in 90:await process_frame
 var start=Time.get_ticks_usec()
 for i in 180:await process_frame
 var elapsed=(Time.get_ticks_usec()-start)/1000000.0
 print('BENCH:180 rendered frames / ',elapsed,' seconds = ',180.0/elapsed,' fps; draws=',Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),' primitives=',Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),' process=',Performance.get_monitor(Performance.TIME_PROCESS))
 scene.queue_free()
 await process_frame
 quit()
