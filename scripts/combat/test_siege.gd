extends SceneTree
var scene: Node3D
var combat: SiegeCombat
var dragon: DragonController
var breath: DragonBreath
var checks := 0
var failures: Array[String] = []
var metrics := {}
func _initialize(): call_deferred("run")
func ticks(n: int):
 for _i in n:
  await physics_frame
  await process_frame
func snapshot(label: String):
 if DisplayServer.get_name()=="headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/validation/v2/combat-"+label+".png")
func check(ok: bool,message: String):
 checks+=1
 print("PASS " if ok else "FAIL ",message)
 if not ok: failures.append(message)
func key(code: Key,pressed: bool):
 var e:=InputEventKey.new()
 e.keycode=code
 e.physical_keycode=code
 e.pressed=pressed
 Input.parse_input_event(e)
func click(button: Button):
 var p:=button.get_global_transform_with_canvas()*(button.size*0.5)
 for pressed in [true,false]:
  var e:=InputEventMouseButton.new()
  e.position=p
  e.global_position=p
  e.button_index=MOUSE_BUTTON_LEFT
  e.pressed=pressed
  root.push_input(e,true)
  await ticks(2)
func set_ground(p: Vector3):
 dragon.global_position=p
 dragon.rotation=Vector3.ZERO
 dragon.target_yaw=0
 dragon.target_pitch=0
 dragon.target_roll=0
 dragon.locomotion_state=dragon.LocomotionState.GROUNDED
 dragon.current_speed=0
 dragon.velocity=Vector3.ZERO
 dragon.ground_pose.reset()
 dragon.manual_input_override=true
 dragon.manual_move_input=0
 dragon.manual_turn_input=0
func aim(target: Vector3):
 # Turning the long neck moves the mouth; track the target as a player does.
 for _i in 60:
  var direction: Vector3=(target-breath.mouth_position).normalized()
  var local: Vector3=dragon.global_basis.inverse()*direction
  dragon.set_head_aim(atan2(-local.x,-local.z),asin(clampf(local.y,-1,1)))
  await ticks(1)
func run():
 root.size=Vector2i(1280,720)
 scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 combat=scene.get_node("SiegeCombat")
 dragon=scene.get_node("Dragon")
 breath=dragon.get_node("DragonBreath")
 await ticks(150)
 check(combat.initialized and combat.enemies.size()==11,"Mission creates three ballistas and eight real knights")
 var actors_good:=true
 for enemy in combat.enemies:
  actors_good=actors_good and enemy.visual!=null and (enemy.kind=="turret" or enemy.animator!=null)
 check(actors_good,"Every enemy uses imported 3D model; knights have animation player")
 check(combat.phase==combat.Phase.BRIEFING and not dragon.is_physics_processing(),"Briefing holds player and combat before start")
 key(KEY_ENTER,true)
 await ticks(2)
 key(KEY_ENTER,false)
 check(combat.is_running() and dragon.is_physics_processing(),"ENTER starts actual mission and resumes player")
 await ticks(330)
 check(combat.shots_fired>0 and combat.telegraph_count>0,"Ballistas acquire target, telegraph and fire actual bolts")
 metrics.shots_observed=combat.shots_fired
 # Real AI melee with a grounded target, then swept projectile damage.
 combat.grace=0
 set_ground(Vector3(300,28.1,135))
 var captain: CharacterBody3D=combat.enemies[3]
 captain.global_position=Vector3(300,24.05,130)
 captain.home=captain.global_position
 captain.cooldown=0
 var health_before:=combat.health
 await ticks(150)
 check(captain.attacks>0 and combat.health<health_before,"Captain approaches/animates melee and damages grounded dragon")
 # Isolate exact breath collision cases from other AI; no direct damage call.
 for enemy in combat.enemies: enemy.set_physics_process(false)
 set_ground(Vector3(300,28.1,165))
 var target: CharacterBody3D=combat.enemies[4]
 target.global_position=Vector3(300,24.05,145)
 target.health=70
 target.dead=false
 target.collision_layer=4
 await ticks(60)
 if DisplayServer.get_name()!="headless":
  var camera=scene.get_node("FlightCamera")
  camera.set_physics_process(false)
  camera.global_position=Vector3(308,28,140)
  camera.look_at(Vector3(300,25.5,148))
  await snapshot("knight-and-dragon")
 await aim(target.global_position+Vector3.UP)
 await ticks(60)
 breath.manual_override=true
 breath.manual_fire=true
 var enemy_before: float=target.health
 await ticks(45)
 await snapshot("aimed-fire")
 print("FIRE_DIAG mouth=",breath.mouth_position," dir=",breath.breath_direction," target=",target.global_position," fire=",breath.is_firing," fuel=",breath.fuel," hit=",breath.hit_distance," collider=",breath.hit_collider_id," hp=",target.health," phase=",combat.phase)
 print("FIRE_BLOCKER ",instance_from_id(breath.hit_collider_id))
 check(target.health<enemy_before and combat.fire_hits>0,"Player aimed breath damages the actual knight through real input/pose/LOS")
 breath.manual_fire=false
 await ticks(30)
 var wall:=StaticBody3D.new()
 wall.collision_layer=2
 var col:=CollisionShape3D.new()
 var box:=BoxShape3D.new()
 box.size=Vector3(18,14,1)
 col.shape=box
 wall.add_child(col)
 scene.add_child(wall)
 wall.global_position=Vector3(300,30,154)
 await ticks(5)
 var protected_health: float=target.health
 breath.manual_fire=true
 await ticks(60)
 check(is_equal_approx(target.health,protected_health),"Masonry blocks breath damage to knight behind it")
 breath.manual_fire=false
 wall.queue_free()
 await ticks(10)
 await aim(target.global_position+Vector3.UP)
 await ticks(40)
 breath.manual_fire=true
 await ticks(120)
 await snapshot("knight-death")
 check(target.dead and target.health<=0 and target.collision_layer==0,"Sustained aimed fire kills knight and plays death with corpse nonblocking")
 breath.manual_fire=false
 await ticks(15)
 # Thin wall must stop a fast physical bolt before the player.
 var projectile_script=load("res://scripts/combat/siege_projectile.gd")
 wall=StaticBody3D.new()
 wall.collision_layer=2
 col=CollisionShape3D.new()
 box=BoxShape3D.new()
 box.size=Vector3(20,20,0.1)
 col.shape=box
 wall.add_child(col)
 scene.add_child(wall)
 wall.global_position=dragon.global_position+Vector3.FORWARD*8
 await ticks(3)
 health_before=combat.health
 var bolt=projectile_script.new()
 bolt.combat=combat
 bolt.damage=18
 combat.projectiles.add_child(bolt)
 bolt.global_position=dragon.global_position+Vector3.FORWARD*16
 bolt.velocity=Vector3.BACK*220
 await ticks(12)
 check(is_equal_approx(combat.health,health_before),"Swept 220m/s bolt cannot tunnel through 10cm wall into player")
 wall.queue_free()
 await ticks(3)
 bolt=projectile_script.new()
 bolt.combat=combat
 bolt.damage=18
 combat.projectiles.add_child(bolt)
 bolt.global_position=dragon.global_position+Vector3.FORWARD*14
 bolt.velocity=Vector3.BACK*100
 await ticks(15)
 check(combat.health<health_before,"Unobstructed physical projectile damages dragon")
 # Validate GUI focus, real pause/resume and head controls.
 dragon.manual_input_override=false
 var body_yaw:=dragon.rotation.y
 key(KEY_T,true)
 await ticks(2)
 key(KEY_T,false)
 dragon.head_aim_active=true
 var aim_before:=dragon.head_requested_yaw
 key(KEY_LEFT,true)
 await ticks(20)
 key(KEY_LEFT,false)
 check(absf(dragon.head_requested_yaw-aim_before)>0.1 and absf(dragon.rotation.y-body_yaw)<0.05,"Aim arrows move head independently of body while on ground")
 key(KEY_P,true)
 await process_frame
 key(KEY_P,false)
 check(paused,"P opens actual pause")
 key(KEY_P,true)
 await process_frame
 key(KEY_P,false)
 check(not paused,"P resumes actual pause")
 # Expected loss comes from a live projectile, not direct health API.
 combat.health=10
 bolt=projectile_script.new()
 bolt.combat=combat
 bolt.damage=18
 combat.projectiles.add_child(bolt)
 bolt.global_position=dragon.global_position+Vector3.FORWARD*14
 bolt.velocity=Vector3.BACK*100
 await ticks(15)
 check(combat.phase==combat.Phase.DEFEAT and not dragon.is_physics_processing(),"Lethal projectile triggers defeat and stops gameplay")
 dragon.body_clearance_lift=.2
 await click(scene.get_node("SiegeUI").action)
 await ticks(20)
 check(combat.phase==combat.Phase.BRIEFING and combat.health==combat.max_health and combat.enemies.size()==11 and combat.turrets_destroyed==0 and is_zero_approx(dragon.body_clearance_lift),"Actual retry click rebuilds enemies and resets health/objectives/body clearance")
 await snapshot("retry")
 # Victory stages are also validated by an unbroken runtime playthrough; this verifies state predicates.
 key(KEY_ENTER,true)
 await ticks(2)
 key(KEY_ENTER,false)
 check(combat.phase==combat.Phase.DEFENSES,"Second mission starts cleanly")
 for size in [Vector2i(1280,720),Vector2i(960,540)]:
  root.size=size
  await ticks(3)
  var ui=scene.get_node("SiegeUI")
  check(ui.action.size.y>=44 and ui.secondary.size.y>=44,"Mission controls >=44px at "+str(size))
 metrics.checks=checks
 metrics.failures=failures
 var f=FileAccess.open("res://docs/validation/v2/combat-acceptance.json",FileAccess.WRITE)
 if f: f.store_string(JSON.stringify(metrics,"  "))
 print("RESULT ",checks-failures.size(),"/",checks," combat checks; failures=",failures)
 scene.free()
 await ticks(15)
 quit(0 if failures.is_empty() else 1)
