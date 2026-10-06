extends SceneTree
func _initialize(): call_deferred('run')
func ticks(n):
 for _i in n:
  await physics_frame
  await process_frame
func run():
 root.size=Vector2i(1280,720)
 var scene=load('res://scenes/main.tscn').instantiate()
 root.add_child(scene)
 await ticks(120)
 print('MISSION_INIT ',scene.get_node('SiegeCombat').initialized,' actors=',scene.get_node('SiegeCombat').enemies.size())
 if DisplayServer.get_name()!='headless': root.get_texture().get_image().save_png('res://docs/validation/v2/mission-briefing.png')
 scene.get_node('SiegeCombat').start_mission()
 await ticks(240)
 print('COMBAT_LIVE shots=',scene.get_node('SiegeCombat').shots_fired,' health=',scene.get_node('SiegeCombat').health)
 if DisplayServer.get_name()!='headless': root.get_texture().get_image().save_png('res://docs/validation/v2/mission-approach.png')
 scene.free()
 await ticks(15)
 quit()
