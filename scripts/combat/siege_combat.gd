extends Node3D
class_name SiegeCombat

signal state_changed
signal player_hurt(amount: float)

const Enemy = preload("res://scripts/combat/siege_enemy.gd")
const CollisionEffects = preload("res://scripts/collision_effects.gd")
enum Phase { BRIEFING, DEFENSES, CAPTAIN, RESCUE, ESCAPE, VICTORY, DEFEAT }
var phase := Phase.BRIEFING
var is_free_flight := false
var difficulty := "normal" # "easy", "normal", "hard"
var dragon: CharacterBody3D
var breath: Node3D
var arena: Node3D
var enemies: Array[CharacterBody3D] = []
var projectiles: Node3D
var health := 240.0
var max_health := 240.0
var active_time := 0.0
var grace := 4.0
var hit_flash := 0.0
var captain_dead := false
var turrets_destroyed := 0
var shots_fired := 0
var projectile_impacts := 0
var telegraph_count := 0
var damage_events := 0
var fire_hits := 0
var music: AudioStreamPlayer
var event_text := ""
var event_life := 0.0
var impacts: Array[Node3D] = []
var initialized := false

func _ready() -> void:
	add_to_group("siege_combat")
	if get_parent() and get_parent().has_node("Dragon"):
		dragon = get_parent().get_node("Dragon")
		if dragon.has_node("DragonBreath"):
			breath = dragon.get_node("DragonBreath")
	arena = get_tree().get_first_node_in_group("siege_environment")
	projectiles = Node3D.new()
	projectiles.name = "Projectiles"
	add_child(projectiles)
	call_deferred("_prepare")

func _prepare() -> void:
	if not is_instance_valid(dragon):
		return
	while dragon.calibrating:
		await get_tree().process_frame
	if not is_instance_valid(arena):
		push_error("Siege environment is required for mission")
		return
	if arena.turret_spawn_points.size() < 3 or arena.knight_spawn_points.size() < 2:
		push_error("Mission cannot initialize without fortress and all enemy spawn points")
		return
	for path in ["res://assets/characters/knight.glb","res://assets/siege/weapons/ballista.glb"]:
		if not ResourceLoader.exists(path):
			push_error("Mission model unavailable: " + path)
			return
	_spawn_enemies()
	if dragon.wing_contact.hulls.is_empty():
		dragon.wing_contact.configure(dragon,dragon.skeleton)
	dragon.ground_pose.prepare(dragon,dragon.skeleton)
	initialized = true
	_reset_player()
	_hold_player(true)
	state_changed.emit()

func is_running() -> bool:
	return initialized and phase >= Phase.DEFENSES and phase <= Phase.ESCAPE

func _hold_player(held: bool) -> void:
	dragon.set_physics_process(not held)
	breath.set_physics_process(not held)
	if held:
		dragon.velocity = Vector3.ZERO
		breath.is_firing = false
		breath.requested = false
		breath.intensity = 0
		for emitter in [breath.flames,breath.smoke,breath.embers,breath.impact]:
			if emitter:
				emitter.emitting = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _spawn_enemies() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	for child in projectiles.get_children():
		child.queue_free()
	for i in arena.turret_spawn_points.size():
		var turret := Enemy.new()
		turret.name = "Ballista_%d" % i
		turret.kind = "turret"
		turret.combat = self
		add_child(turret)
		turret.global_position = arena.turret_spawn_points[i]
		turret.home = turret.global_position
		enemies.append(turret)
	for i in arena.knight_spawn_points.size():
		var knight := Enemy.new()
		knight.name = "Captain" if i == 0 else "Knight_%d" % i
		knight.kind = "captain" if i == 0 else "knight"
		knight.combat = self
		add_child(knight)
		knight.global_position = arena.knight_spawn_points[i]
		knight.home = knight.global_position
		knight.waypoint = knight.home
		enemies.append(knight)

func set_difficulty(new_diff: String) -> void:
	difficulty = new_diff
	match difficulty:
		"easy":
			max_health = 360.0
		"hard":
			max_health = 160.0
		_:
			max_health = 240.0
	health = max_health

func start_mission(free_flight: bool = false) -> void:
	if not initialized:
		return
	is_free_flight = free_flight
	_reset_player()
	phase = Phase.DEFENSES
	active_time = 0
	grace = 6.0 if difficulty == "easy" else (4.0 if difficulty == "normal" else 2.5)
	_hold_player(false)
	if is_free_flight:
		_notify("¡MODO VUELO LIBRE ACTIVADO! Explora las cumbres y practica el vuelo.")
	else:
		_notify("El nido está al norte. Destruye las tres ballistas.")
	state_changed.emit()

func return_to_briefing() -> void:
	if not initialized:
		return
	_hold_player(true)
	phase = Phase.BRIEFING
	is_free_flight = false
	_spawn_enemies()
	set_difficulty(difficulty)
	captain_dead = false
	turrets_destroyed = 0
	if arena.has_method("reset_nest"):
		arena.reset_nest()
	active_time = 0
	_reset_player()
	state_changed.emit()

func retry() -> void:
	if not initialized:
		return
	_hold_player(true)
	_spawn_enemies()
	set_difficulty(difficulty)
	captain_dead = false
	turrets_destroyed = 0
	if arena.has_method("reset_nest"):
		arena.reset_nest()
	active_time = 0
	shots_fired = 0
	projectile_impacts = 0
	telegraph_count = 0
	damage_events = 0
	fire_hits = 0
	_reset_player()
	phase = Phase.DEFENSES
	grace = 4.0
	_hold_player(false)
	if is_free_flight:
		_notify("Modo Vuelo Libre reiniciado.")
	else:
		_notify("El nido está al norte. Destruye las tres ballistas.")
	state_changed.emit()

func _reset_player() -> void:
	dragon.global_position = arena.approach_spawn
	dragon.rotation = Vector3.ZERO
	dragon.target_yaw = 0
	dragon.target_pitch = 0
	dragon.target_roll = 0
	dragon.locomotion_state = dragon.LocomotionState.FLYING
	dragon.current_mode = dragon.FlightMode.NORMAL
	dragon.current_speed = dragon.cruise_speed
	dragon.velocity = Vector3.FORWARD * dragon.cruise_speed
	dragon.manual_input_override = false
	dragon.manual_move_input = 0
	dragon.manual_turn_input = 0
	dragon.mouse_captured = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	dragon.ui_climb_active = false
	dragon.ui_dive_active = false
	dragon.glide_mode_active = false
	dragon.has_taken_off = true
	dragon.ground_pose.reset()
	dragon.body_clearance_lift = 0.0
	if dragon.has_method("set_head_aim"):
		dragon.set_head_aim(0,0)
	dragon.head_aim_active = false
	dragon.attack_mode_active = false
	breath.fuel = 1
	breath.exhausted = false
	breath.intensity = 0
	breath.manual_override = false
	breath.requested = false
	health = max_health
	hit_flash = 0
	var camera := get_parent().get_node("FlightCamera")
	camera.global_position = dragon.global_position + Vector3(0,5,18)
	camera.set_view(camera.ViewPreset.BACK)

func _physics_process(delta: float) -> void:
	event_life = maxf(0,event_life-delta)
	hit_flash = maxf(0,hit_flash-delta)
	if not is_running():
		return
	active_time += delta
	grace = maxf(0,grace-delta)
	if breath.is_firing and breath.intensity > 0.05:
		_damage_with_breath(delta)
	if is_free_flight:
		return
	if phase == Phase.DEFENSES and turrets_destroyed >= arena.turret_spawn_points.size():
		phase = Phase.CAPTAIN if not captain_dead else Phase.RESCUE
		_notify("Las defensas han caído. Derrota al capitán del Hierro." if not captain_dead else "Acércate al nido o lánzale fuego para romper las cadenas.")
		state_changed.emit()
	if phase == Phase.CAPTAIN and captain_dead:
		phase = Phase.RESCUE
		_notify("La orden ha perdido a su capitán. Acércate al nido o dispara fuego (o E) para liberarlo.")
		state_changed.emit()
	if phase == Phase.RESCUE:
		var dist_nest := dragon.global_position.distance_to(arena.rescue_point)
		if dist_nest < 15.0 or (dist_nest < 24.0 and Input.is_key_pressed(KEY_E)) or (dist_nest < 34.0 and breath.is_firing):
			rescue_nest()
	if phase == Phase.ESCAPE:
		var horiz_escape := Vector2(dragon.global_position.x - arena.escape_point.x, dragon.global_position.z - arena.escape_point.z).length()
		if dragon.global_position.distance_to(arena.escape_point) < 35.0 or horiz_escape < 38.0:
			phase = Phase.VICTORY
			_hold_player(true)
			_notify("El valle vuelve a respirar. La última cría está a salvo.")
			state_changed.emit()

func rescue_nest() -> void:
	if phase != Phase.RESCUE or dragon.global_position.distance_to(arena.rescue_point) >= 35.0:
		return
	phase = Phase.ESCAPE
	if arena.has_method("liberate_nest"):
		arena.liberate_nest()
	_notify("El nido está libre. Vuela hacia el paso del sur para escapar.")
	state_changed.emit()

func _damage_with_breath(delta: float) -> void:
	var origin: Vector3 = breath.mouth_position
	var direction: Vector3 = breath.breath_direction.normalized()
	var airborne: bool = dragon.locomotion_state != dragon.LocomotionState.GROUNDED
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var k_scale: float = enemy.knight_scale if ("knight_scale" in enemy) else 1.0
		var approx_along := maxf(0.0, (enemy.global_position - origin).dot(direction))
		var ray_y := origin.y + direction.y * approx_along
		var target_h := 1.8 if enemy.kind == "turret" else clampf(ray_y - enemy.global_position.y, 0.95, 1.45 * k_scale)
		var center := enemy.global_position + Vector3.UP * target_h
		var offset := center-origin
		var along := offset.dot(direction)
		var is_locked: bool = is_instance_valid(dragon.locked_target) and dragon.locked_target == enemy
		var effective_reach: float = breath.max_reach * (2.4 if airborne else (1.25 if is_locked else 1.0))
		if along < 0 or along > effective_reach:
			continue
		var lateral := (offset-direction*along).length()
		var enemy_radius := 1.3 if enemy.kind == "turret" else (0.42 * k_scale)
		var hit_cone_angle: float = deg_to_rad(22.0 if (airborne and is_locked) else (16.0 if (airborne or is_locked) else 7.0))
		var max_allowed_lateral: float = (2.2 if airborne else (1.1 if is_locked else 0.55)) + along * tan(hit_cone_angle) + enemy_radius
		if lateral > max_allowed_lateral:
			continue
		var ray := PhysicsRayQueryParameters3D.create(origin,center,7)
		ray.hit_from_inside = true
		ray.exclude = [dragon.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider != enemy:
			var hit_dist: float = (hit.position as Vector3).distance_to(center)
			var is_turret: bool = (enemy.kind == "turret")
			var tolerance: float = 3.6 if is_turret else (2.0 if is_locked else 1.2)
			if hit_dist > tolerance:
				continue
		enemy.damage_from_fire((64.0 if airborne else 48.0)*delta)
		fire_hits += 1

func damage_dragon(amount: float, source: String) -> void:
	if is_free_flight or not is_running() or grace > 0 or amount <= 0:
		return
	health = maxf(0, health-amount)
	hit_flash = 0.22
	damage_events += 1
	player_hurt.emit(amount)
	if dragon:
		GameAudio.play_dragon_hurt(dragon.global_position, amount)
	if health <= 0:
		phase = Phase.DEFEAT
		_hold_player(true)
		_notify("El guardián cayó ante " + source.to_lower() + ".")
		state_changed.emit()

func enemy_defeated(enemy: Node) -> void:
	if enemy.kind == "turret":
		turrets_destroyed += 1
		_notify("Ballista destruida · %d/%d" % [turrets_destroyed,arena.turret_spawn_points.size()])
	if enemy.kind == "captain":
		captain_dead = true
		_notify("El capitán del Hierro ha caído.")

func objective_text() -> String:
	if is_free_flight:
		return "MODO VUELO LIBRE · Explora el valle y practica las maniobras. [P] Menú"
	match phase:
		Phase.DEFENSES: return "Destruye las ballistas · %d/%d" % [turrets_destroyed,arena.turret_spawn_points.size()]
		Phase.CAPTAIN: return "Derrota al capitán junto al nido"
		Phase.RESCUE: return "Libera el nido · acércate y pulsa E"
		Phase.ESCAPE: return "Escapa por el paso del sur"
		Phase.VICTORY: return "El último guardián · victoria"
		Phase.DEFEAT: return "El último guardián · derrota"
	return "El último guardián · inicia el asedio"

func objective_position() -> Vector3:
	if phase == Phase.DEFENSES:
		var nearest := Vector3.ZERO
		var distance := INF
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.kind == "turret" and not enemy.dead:
				var d := enemy.global_position.distance_to(dragon.global_position)
				if d < distance:
					distance = d
					nearest = enemy.global_position + Vector3.UP*3
		return nearest
	if phase == Phase.CAPTAIN:
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.kind == "captain" and not enemy.dead:
				return enemy.global_position+Vector3.UP*2
	return arena.escape_point if phase == Phase.ESCAPE else arena.rescue_point

func _notify(message: String) -> void:
	event_text = message
	event_life = 4

func spawn_impact(point: Vector3,normal: Vector3,hot: bool) -> void:
	var landscape_node: Node = arena._landscape if is_instance_valid(arena) and "_landscape" in arena else null
	CollisionEffects.spawn_impact(self, point, normal, 1.4 if hot else 1.1, hot, landscape_node)
	var particles := CPUParticles3D.new()
	particles.amount = 24 if hot else 12
	particles.one_shot = true
	particles.explosiveness = 1
	particles.lifetime = 0.45
	particles.direction = normal
	particles.spread = 75
	particles.initial_velocity_min = 1
	particles.initial_velocity_max = 7
	particles.gravity = Vector3(0,-8,0)
	particles.scale_amount_min = 0.04
	particles.scale_amount_max = 0.13
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1,0.28,0.03) if hot else Color(0.53,0.44,0.32)
	mesh.material = material
	particles.mesh = mesh
	particles.finished.connect(particles.queue_free)
	add_child(particles)
	particles.global_position = point
	particles.emitting = true
