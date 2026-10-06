extends CharacterBody3D

var combat: Node
var kind := "knight"
var health := 80.0
var max_health := 80.0
var home := Vector3.ZERO
var dead := false
var cooldown := 0.0
var state := "patrol"
var state_time := 0.0
var shot_count := 0
var attacks := 0
var visual: Node3D
var animator: AnimationPlayer
var turret_pivot: Node3D
var barrel_pivot: Node3D
var warning: OmniLight3D
var label: Label3D
var attack_delivered := false
var waypoint := Vector3.ZERO
var facing_yaw := 0.0
var last_anim := ""
var burning := 0.0
var patrol_clock := 0.0
const Projectile = preload("res://scripts/combat/siege_projectile.gd")

func _ready() -> void:
	collision_layer = 4 if kind == "knight" else 6
	collision_mask = 3
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(38)
	add_to_group("siege_enemy")
	home = global_position
	waypoint = home
	max_health = 100 if kind == "turret" else (140 if kind == "captain" else 70)
	health = max_health
	var collision := CollisionShape3D.new()
	if kind == "turret":
		var shape := BoxShape3D.new()
		shape.size = Vector3(5.0,3.5,4.0)
		collision.shape = shape
		collision.position.y = 1.75
	else:
		var shape := CapsuleShape3D.new()
		shape.radius = 0.42
		shape.height = 1.9
		collision.shape = shape
		collision.position.y = 0.95
	add_child(collision)
	_load_visual()
	warning = OmniLight3D.new()
	warning.omni_range = 7
	warning.light_color = Color(1,0.24,0.07)
	warning.light_energy = 0
	warning.position.y = 2.0
	add_child(warning)
	label = Label3D.new()
	label.font_size = 36
	label.pixel_size = 0.01
	label.position.y = 4.2 if kind == "turret" else 2.7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.modulate = Color(1,0.76,0.45)
	label.text = "BALLISTA" if kind == "turret" else ("CAPITÁN" if kind == "captain" else "GUARDIA")
	label.visibility_range_end = 80.0
	add_child(label)
	cooldown = 2.0 + float(get_instance_id() % 19) * 0.08

func _load_visual() -> void:
	var path := "res://assets/siege/weapons/ballista.glb" if kind == "turret" else "res://assets/characters/knight.glb"
	if not ResourceLoader.exists(path):
		push_error("Required siege model missing: " + path)
		return
	visual = load(path).instantiate()
	visual.name = "EnemyModel"
	add_child(visual)
	# Models are normalized by the asset pipeline; preserve their authored rig and material.
	for player: AnimationPlayer in visual.find_children("*","AnimationPlayer",true,false):
		animator = player
		break
	if kind == "turret":
		turret_pivot = visual.find_child("AimYaw",true,false) as Node3D
		barrel_pivot = visual.find_child("AimPitch",true,false) as Node3D
		if not turret_pivot:
			turret_pivot = visual
	else:
		_play("idle")

func _play(fragment: String) -> void:
	if not animator:
		return
	for animation_name: String in animator.get_animation_list():
		if fragment in animation_name.to_lower() or (fragment == "walk_loop" and "walk" in animation_name.to_lower()):
			if animation_name != last_anim:
				animator.play(animation_name,0.18)
				last_anim = animation_name
			return

func damage_from_fire(amount: float) -> void:
	if dead or amount <= 0:
		return
	health = maxf(0, health - amount)
	burning = 0.22
	label.text = ("BALLISTA" if kind == "turret" else ("CAPITÁN" if kind == "captain" else "GUARDIA")) + "  %d%%" % roundi(health / max_health * 100)
	if health <= 0:
		_die()

func _die() -> void:
	dead = true
	state = "dead"
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	warning.light_energy = 0
	label.text = "DESTRUIDA" if kind == "turret" else ""
	_play("death")
	combat.enemy_defeated(self)
	combat.spawn_impact(global_position + Vector3.UP, Vector3.UP, true)
	if kind == "turret" and visual:
		var tween := create_tween()
		tween.tween_property(visual,"rotation:z",0.12,0.5)

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(combat) or not combat.is_running():
		return
	state_time += delta
	cooldown = maxf(0, cooldown - delta)
	burning = maxf(0, burning-delta)
	warning.light_energy = 1.4 if burning > 0 else (1.5 if state == "windup" else 0.0)
	var dragon: CharacterBody3D = combat.dragon
	var target := dragon.global_position
	var offset := target - global_position
	var range_to_target := offset.length()
	if kind == "turret":
		_update_turret(delta,target,range_to_target)
		return
	var grounded: bool = dragon.locomotion_state == dragon.LocomotionState.GROUNDED
	var visible_target := range_to_target < 65 and _line_of_sight(target, [get_rid(),dragon.get_rid()])
	if state == "windup":
		velocity.x = move_toward(velocity.x,0,18*delta)
		velocity.z = move_toward(velocity.z,0,18*delta)
		if state_time >= 0.68 and not attack_delivered:
			attack_delivered = true
			attacks += 1
			if grounded and range_to_target < 6.5 and _line_of_sight(target,[get_rid(),dragon.get_rid()]):
				combat.damage_dragon(12 if kind == "captain" else 7,"Golpe de caballero")
		if state_time >= 1.14:
			state = "chase"
			state_time = 0
			cooldown = 1.4
	else:
		var wanted := Vector3.ZERO
		if grounded and visible_target:
			state = "chase"
			if range_to_target < 6.2 and cooldown <= 0:
				state = "windup"
				state_time = 0
				attack_delivered = false
				_play("sword_attack")
			else:
				wanted = offset
				wanted.y = 0
				wanted = wanted.normalized() * (3.4 if kind == "captain" else 2.7)
		else:
			state = "patrol"
			patrol_clock += delta
			if global_position.distance_to(waypoint) < 1.2 or patrol_clock > 8:
				patrol_clock = 0
				var angle := float(get_instance_id() % 31) + state_time * 0.45
				waypoint = home + Vector3(sin(angle),0,cos(angle)) * 6
			wanted = waypoint - global_position
			wanted.y = 0
			wanted = wanted.normalized() * 1.4
		# A probe gives blocked patrols a local detour instead of walking through masonry.
		if wanted.length_squared() > 0.1:
			var probe := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,global_position+Vector3.UP+wanted.normalized()*2.0,2)
			if not get_world_3d().direct_space_state.intersect_ray(probe).is_empty():
				wanted = wanted.rotated(Vector3.UP,PI/2)
			facing_yaw = atan2(-wanted.x,-wanted.z)
			rotation.y = lerp_angle(rotation.y,facing_yaw,1-exp(-7*delta))
		velocity.x = move_toward(velocity.x,wanted.x,8*delta)
		velocity.z = move_toward(velocity.z,wanted.z,8*delta)
		if state != "windup":
			_play("walk_loop" if wanted.length() > 0.5 else "idle")
	velocity.y = -2.0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	if animator and state != "windup":
		var actual_speed := Vector2(get_real_velocity().x,get_real_velocity().z).length()
		_play("walk_loop" if actual_speed > 0.15 else "idle")
		animator.speed_scale = clampf(actual_speed/1.6,0.1,1.8) if actual_speed > 0.15 else 1.0
	elif animator:
		animator.speed_scale = 1.0

func _line_of_sight(target: Vector3, excluded: Array[RID]) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*1.8,target,3)
	query.exclude = excluded
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _update_turret(delta: float,target: Vector3,range_to_target: float) -> void:
	if range_to_target > 240 or not _line_of_sight(target,[get_rid(),combat.dragon.get_rid()]):
		state = "idle"
		return
	var muzzle := global_position + Vector3.UP * 2.1
	var lead: Vector3 = combat.dragon.velocity * minf(range_to_target / 65.0,0.7)
	lead = lead.limit_length(12.0)
	var direction := (target + lead - muzzle).normalized()
	var yaw := atan2(-direction.x,-direction.z)
	if turret_pivot:
		turret_pivot.rotation.y = lerp_angle(turret_pivot.rotation.y,yaw,1-exp(-1.8*delta))
	if barrel_pivot:
		barrel_pivot.rotation.x = lerp_angle(barrel_pivot.rotation.x,asin(clampf(direction.y,-1,1)),1-exp(-1.8*delta))
	if cooldown <= 0 and state != "windup":
		state = "windup"
		state_time = 0
		combat.telegraph_count += 1
	if state == "windup" and state_time > 0.85:
		var actual_muzzle := visual.find_child("Muzzle",true,false) as Node3D
		if actual_muzzle:
			muzzle = actual_muzzle.global_position
			direction = -actual_muzzle.global_basis.z.normalized()
		var bolt := Projectile.new()
		bolt.combat = combat
		bolt.owner_rid = get_rid()
		bolt.damage = 18
		combat.projectiles.add_child(bolt)
		bolt.global_position = muzzle if actual_muzzle else muzzle + direction * 3.3
		# Small, deterministic dispersion; the player can evade after the visible warning.
		var side := direction.cross(Vector3.UP).normalized()
		bolt.velocity = (direction + side * sin(float(shot_count)*2.4)*0.015).normalized()*65.0
		shot_count += 1
		combat.shots_fired += 1
		state = "reload"
		state_time = 0
		cooldown = 3.8
