extends "res://scripts/combat/test_ground_escape.gd"

var terrain_capture_prefix:="terrain-player-escape"
func capture(label:String):
 if not OS.get_cmdline_user_args().has("--capture-ground-escape") or DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/validation/v2/"+terrain_capture_prefix+"-"+label+".png")

# One legal aerial fixture; every transition after it uses production keyboard
# input. Reuse the original full-skin and final-hull oracle from ground escape.
func run():
 source_before=source_hashes()
 source_before["res://scripts/combat/test_terrain_player_escape.gd"]=FileAccess.get_sha256("res://scripts/combat/test_terrain_player_escape.gd")
 scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 dragon=scene.get_node("Dragon")
 combat=scene.get_node("SiegeCombat")
 breath=dragon.get_node("DragonBreath")
 await ticks(150)
 key(KEY_ENTER,true)
 await ticks(2)
 key(KEY_ENTER,false)
 var x:=500.0
 var z:=450.0
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--x="):x=float(arg.trim_prefix("--x="))
  if arg.begins_with("--z="):z=float(arg.trim_prefix("--z="))
 terrain_capture_prefix="terrain-player-escape-%s-%s"%[int(x),int(z)]
 dragon.global_position=Vector3(x,dragon.landscape.ground_height(x,z)+40,z)
 dragon.rotation=Vector3.ZERO
 dragon.target_yaw=0
 dragon.target_pitch=0
 dragon.target_roll=0
 dragon.velocity=Vector3.ZERO
 dragon.current_speed=7
 dragon.has_taken_off=true
 dragon.locomotion_state=dragon.LocomotionState.FLYING
 dragon.ground_pose.reset()
 await ticks(5)
 check(overlapping_hulls().is_empty(),"Initial legal aerial fixture clears all actual hulls")
 var flight_start:=dragon.global_position
 key(KEY_W,true)
 await ticks(90)
 key(KEY_W,false)
 check(dragon.global_position.distance_to(flight_start)>2,"Actual W advances in air before landing")
 key(KEY_L,true)
 await ticks(1)
 key(KEY_L,false)
 print("SELECTED_LANDING_TARGET ",dragon.landing_target)
 var landing_ticks:=0
 while dragon.locomotion_state!=dragon.LocomotionState.GROUNDED and landing_ticks<1800:
  await ticks(1)
  landing_ticks+=1
 check(dragon.locomotion_state==dragon.LocomotionState.GROUNDED,"Actual L lands on real terrain within30s")
 var landing_position:=dragon.global_position
 print("ACTUAL_LANDING_TARGET_ERROR ",Vector2(landing_position.x-dragon.landing_target.x,landing_position.z-dragon.landing_target.z).length())
 await ticks(90)
 skin_probe.configure(dragon,dragon.skeleton,1)
 var final_modifier:SkeletonModifier3D
 for child in dragon.skeleton.get_children():
  if child is SkeletonModifier3D:final_modifier=child
 final_modifier.modification_processed.connect(observe_final)
 previous_head=dragon.head_rendered_direction
 observation_on=true
 await stage("forward",KEY_W,150)
 await stage("reverse",KEY_S,150)
 await stage("left",KEY_A,120)
 await stage("forward_after_turn",KEY_W,150)
 await stage("reverse_after_turn",KEY_S,150)
 observation_on=false
 check(stages.forward.horizontal_distance_m>1,"W walks more than1m after landing on this terrain")
 check(stages.reverse.horizontal_distance_m>1,"S retreats more than1m after terrain landing")
 check(absf(stages.left.yaw_delta_deg)>30,"A turns more than30deg after terrain landing")
 check(stages.forward_after_turn.horizontal_distance_m>1 and stages.reverse_after_turn.horizontal_distance_m>1,"Both ground directions remain available after turning")
 check(maximum_prop_overlap_count==0,"All18 published hulls remain outside real trees and rocks")
 check(minimum_skin_terrain_clearance_m>=-.05,"Every original rendered vertex stays within the existing5cm terrain limit")
 check(maximum_stance_slide_m<=.015,"Original grounded claws stay within the existing1.5cm stance limit")
 check(observed_non_grounded_frames==0,"All measured WASD actions remain grounded")
 source_after=source_hashes()
 source_after["res://scripts/combat/test_terrain_player_escape.gd"]=FileAccess.get_sha256("res://scripts/combat/test_terrain_player_escape.gd")
 check(source_before==source_after,"Runtime and actual-input driver remain frozen")
 var report:={"fixture_xz":[x,z],"landing_ticks":landing_ticks,"landing_position":str(landing_position),"stages":stages,"stage_quality":stage_quality,"maximum_prop_overlap_count":maximum_prop_overlap_count,"maximum_overlap_count":maximum_overlap_count,"minimum_skin_terrain_clearance_m":minimum_skin_terrain_clearance_m,"maximum_stance_slide_m":maximum_stance_slide_m,"original_vertices_checked":original_vertices_checked,"worst_skin":worst_skin,"worst_stance":worst_stance,"frames":frames,"overlap_diagnostics":overlap_diagnostics,"source_before":source_before,"source_after":source_after,"manual_override":dragon.manual_input_override,"teleports_after_initial_aerial_fixture":0,"failures":failures}
 FileAccess.open("res://docs/validation/v2/terrain-player-escape-%s-%s.json"%[int(x),int(z)],FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("TERRAIN_PLAYER_ESCAPE_RESULT ",JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
