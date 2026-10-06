extends SceneTree

# Controlled LOS fixture: only the selected production enemy runs AI. The real
# dragon collider stays grounded and stationary so target movement cannot erase
# the obstruction. Shots and damage are produced exclusively by production AI.
var scene: Node3D
var combat: SiegeCombat
var dragon: DragonController
var checks := 0
var failures: Array[String] = []
var metrics := {}

func _initialize() -> void:
	call_deferred("run")

func ticks(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures.append(message)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func place_target(position: Vector3) -> void:
	dragon.set_physics_process(false)
	dragon.get_node("DragonBreath").set_physics_process(false)
	dragon.global_position = position
	dragon.rotation = Vector3.ZERO
	dragon.velocity = Vector3.ZERO
	dragon.locomotion_state = dragon.LocomotionState.GROUNDED
	combat.grace = 0

func isolate(enemy: CharacterBody3D, position: Vector3) -> void:
	for actor in combat.enemies:
		actor.set_physics_process(actor == enemy)
	for bolt in combat.projectiles.get_children():
		bolt.queue_free()
	enemy.global_position = position
	enemy.rotation = Vector3.ZERO
	enemy.velocity = Vector3.ZERO
	enemy.home = position
	enemy.waypoint = position
	enemy.state = "patrol" if enemy.kind == "knight" else "idle"
	enemy.state_time = 0
	enemy.cooldown = 0
	enemy.patrol_clock = 0

func blocker(position: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = "ActiveAILOSBlocker"
	wall.collision_layer = 2
	wall.collision_mask = 0
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 20, 1)
	collider.shape = box
	wall.add_child(collider)
	scene.add_child(wall)
	wall.global_position = position
	return wall

func observe(enemy: CharacterBody3D, count: int) -> Dictionary:
	var before_health := combat.health
	var before_shots: int = enemy.shot_count
	var before_attacks: int = enemy.attacks
	var before_telegraphs := combat.telegraph_count
	var before_damage := combat.damage_events
	var states := {}
	var active_frames := 0
	var visible_frames := 0
	var aimed_frames := 0
	var active_projectile_frames := 0
	var excluded: Array[RID] = [enemy.get_rid(), dragon.get_rid()]
	for _i in count:
		await ticks(1)
		states[enemy.state] = int(states.get(enemy.state, 0)) + 1
		if enemy.is_physics_processing() and combat.is_running():
			active_frames += 1
		if enemy._line_of_sight(dragon.global_position, excluded):
			visible_frames += 1
		if enemy.kind == "turret" and enemy.turret_pivot and absf(enemy.turret_pivot.rotation.y) > 0.2:
			aimed_frames += 1
		if combat.projectiles.get_child_count() > 0:
			active_projectile_frames += 1
	return {
		"frames": count, "active_ai_frames": active_frames, "los_visible_frames": visible_frames,
		"states": states, "shots": enemy.shot_count - before_shots,
		"attacks": enemy.attacks - before_attacks,
		"telegraphs": combat.telegraph_count - before_telegraphs,
		"damage_events": combat.damage_events - before_damage,
		"health_loss": before_health - combat.health,
		"aimed_frames": aimed_frames, "live_projectile_frames": active_projectile_frames,
		"enemy_end_position": [enemy.position.x, enemy.position.y, enemy.position.z],
	}

func run() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	combat = scene.get_node("SiegeCombat")
	dragon = scene.get_node("Dragon")
	await ticks(150)
	check(combat.initialized and combat.enemies.size() == 11, "Production mission initializes all eleven imported enemy actors")
	key(KEY_ENTER, true)
	await ticks(2)
	key(KEY_ENTER, false)
	check(combat.is_running(), "Actual ENTER starts mission before controlled LOS fixture")
	var knight: CharacterBody3D
	var turret: CharacterBody3D
	for enemy in combat.enemies:
		if not knight and enemy.kind == "knight":
			knight = enemy
		if not turret and enemy.kind == "turret":
			turret = enemy
	check(knight != null and turret != null and knight.visual != null and knight.animator != null and turret.visual != null, "Selected active actors are production rigged knight and imported ballista")
	place_target(Vector3(300, 28.1, 135))
	isolate(knight, Vector3(300, 24.05, 130))
	var wall := blocker(Vector3(300, 32, 132.5))
	await ticks(3)
	metrics.knight_blocked = await observe(knight, 360)
	var blocked: Dictionary = metrics.knight_blocked
	check(blocked.active_ai_frames == blocked.frames and blocked.los_visible_frames == 0, "Knight AI remains active for every blocked observation frame; physical wall occludes target")
	check(not blocked.states.has("chase") and not blocked.states.has("windup") and blocked.attacks == 0 and blocked.health_loss == 0 and blocked.damage_events == 0, "Occluded active knight never acquires/chases/winds up/attacks or damages grounded target")
	wall.queue_free()
	await ticks(3)
	metrics.knight_clear = await observe(knight, 540)
	var clear: Dictionary = metrics.knight_clear
	check(clear.active_ai_frames == clear.frames and clear.los_visible_frames > 0 and clear.states.has("chase") and clear.states.has("windup"), "Same knight naturally acquires, approaches and winds up after only blocker removal")
	check(clear.attacks > 0 and clear.health_loss > 0 and clear.damage_events > 0, "Same knight's production melee causes real health loss without fixture damage calls")
	place_target(Vector3(300, 28.1, 155))
	isolate(turret, Vector3(300, 24.05, 130))
	wall = blocker(Vector3(300, 32, 142.5))
	await ticks(3)
	metrics.turret_blocked = await observe(turret, 360)
	blocked = metrics.turret_blocked
	check(blocked.active_ai_frames == blocked.frames and blocked.los_visible_frames == 0, "Ballista AI remains active for every blocked observation frame; physical wall occludes target")
	check(blocked.states.size() == 1 and blocked.states.has("idle") and blocked.shots == 0 and blocked.telegraphs == 0 and blocked.health_loss == 0 and blocked.damage_events == 0 and blocked.live_projectile_frames == 0, "Occluded active ballista never acquires/winds up/telegraphs/fires or damages target")
	wall.queue_free()
	await ticks(3)
	metrics.turret_clear = await observe(turret, 660)
	clear = metrics.turret_clear
	check(clear.active_ai_frames == clear.frames and clear.los_visible_frames > 0 and clear.states.has("windup") and clear.aimed_frames > 0, "Same ballista naturally acquires, rotates aim and winds up after only blocker removal")
	check(clear.shots > 0 and clear.telegraphs > 0 and clear.live_projectile_frames > 0 and clear.health_loss > 0 and clear.damage_events > 0, "Same ballista fires production bolts causing real health loss without fixture projectile/damage calls")
	metrics.checks = checks
	metrics.failures = failures
	metrics.fixture = {"target_stationary": true, "target_grounded": true, "other_enemies_disabled_for_attribution": true, "selected_enemy_active": true, "direct_fixture_damage_calls": false, "fixture_projectiles": false, "wall_size": [80, 20, 1], "wall_layer": 2, "start_input": "ENTER", "positive_control": "remove_only_wall_without_repositioning_selected_enemy"}
	var file := FileAccess.open("res://docs/validation/v2/active-ai-los.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(metrics, "  "))
	print("ACTIVE_AI_LOS_METRICS ", JSON.stringify(metrics))
	print("RESULT ", checks - failures.size(), "/", checks, " active AI LOS checks; failures=", failures)
	scene.free()
	await ticks(15)
	quit(0 if failures.is_empty() else 1)
