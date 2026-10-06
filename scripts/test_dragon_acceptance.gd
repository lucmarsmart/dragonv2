extends SceneTree

var scene: Node3D
var dragon: DragonController
var breath: DragonBreath
var checks := 0
var failures: Array[String] = []
var metrics := {}

func _initialize() -> void:
	call_deferred("run")

func ticks(count: int) -> void:
	for _i in range(count):
		await physics_frame
		await process_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func click(button: Button) -> void:
	var point := button.get_global_transform_with_canvas() * (button.size * 0.5)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await ticks(2)

func reset_air(position: Vector3) -> void:
	dragon.global_position = position
	dragon.rotation = Vector3.ZERO
	dragon.target_yaw = 0
	dragon.target_pitch = 0
	dragon.target_roll = 0
	dragon.velocity = Vector3(0,0,-26)
	dragon.current_speed = 26
	dragon.locomotion_state = dragon.LocomotionState.FLYING
	dragon.trigger_normal()
	dragon.manual_climb = false
	dragon.manual_dive = false
	dragon.manual_move_input = 0
	dragon.manual_turn_input = 0

func select_ground_corridor() -> bool:
	var landscape := get_first_node_in_group("landscape")
	var space := dragon.get_world_3d().direct_space_state
	for candidate in [Vector3(300,0,170),Vector3(280,0,160),Vector3(300,0,120),Vector3(320,0,170)]:
		var support: Dictionary = landscape.ground_surface(candidate)
		if support.is_empty() or landscape.is_water_at(candidate): continue
		dragon.global_position = support.position + Vector3.UP * 3.5
		dragon.rotation = Vector3.ZERO
		dragon.target_yaw = 0
		dragon.target_pitch = 0
		dragon.target_roll = 0
		dragon.velocity = Vector3.ZERO
		dragon.current_speed = 0
		dragon.head_aim_direction = Vector3.FORWARD
		dragon.head_rendered_direction = Vector3.FORWARD
		dragon.ground_pose.reset()
		await ticks(90)
		for angle_index in range(24):
			var yaw := float(angle_index) * TAU / 24.0
			var heading := -Basis(Vector3.UP,yaw).z
			var clear := true
			# Includes walk/reverse/sprint travel plus stopping distance and actual anatomy.
			for distance in range(0,49,3):
				var point: Vector3 = dragon.global_position + heading * distance
				var floor_hit: Dictionary = landscape.ground_surface(point)
				if floor_hit.is_empty() or landscape.is_water_at(point) or floor_hit.normal.y < cos(deg_to_rad(15)):
					clear = false
					break
				point.y = floor_hit.position.y + 3.5
				for hull_index in dragon.wing_contact.hulls.size():
					var query := PhysicsShapeQueryParameters3D.new()
					query.shape = dragon.wing_contact.hulls[hull_index]
					query.transform = Transform3D(Basis(Vector3.UP,yaw),point)
					query.collision_mask = 2 if hull_index == 2 else 3
					query.margin = 0.25
					query.exclude = [dragon.get_rid()]
					if not space.intersect_shape(query,1).is_empty():
						var contact := space.get_rest_info(query)
						var collider = instance_from_id(contact.collider_id) if not contact.is_empty() else null
						if contact.is_empty() or contact.normal.y < 0.985 or not collider is CollisionObject3D or (collider.collision_layer & 1) == 0:
							clear = false
							break
				if not clear: break
			if clear:
				dragon.target_yaw = yaw
				print("SURVEYED_CORRIDOR position=",dragon.global_position," yaw=",yaw," clear_distance=48m full_wing_body_neck_hulls layers1+2")
				return true
	return false

func run() -> void:
	root.size = Vector2i(1280,720)
	scene = load("res://scenes/main.tscn").instantiate()
	# Flight regression runs without the mission's briefing/AI gating the player.
	# Mission behavior has its separate live combat and complete-playthrough gates.
	scene.get_node("SiegeUI").free()
	scene.get_node("SiegeCombat").free()
	root.add_child(scene)
	dragon = scene.get_node("Dragon")
	breath = dragon.get_node("DragonBreath")
	await ticks(150)
	var scenery := scene.get_node("SceneryCollisions")
	check(scenery.active.size() > 0 and scenery.active.size() <= 256,"Nearby scenery collision pool is populated and bounded")
	var prop: StaticBody3D = scenery.active.values()[0]
	var prop_shape: CollisionShape3D = prop.get_child(0)
	var prop_center := prop.to_global(prop_shape.position)
	var prop_ray := PhysicsRayQueryParameters3D.create(prop_center + Vector3.BACK * 10, prop_center + Vector3.FORWARD * 10, 2)
	var prop_hit := dragon.get_world_3d().direct_space_state.intersect_ray(prop_ray)
	check(not prop_hit.is_empty() and prop_hit.collider.is_in_group("scenery_obstacle"),"Visible scenery has real obstacle collision")
	check(not dragon.calibrating and dragon.visual_root.visible, "Initial calibration finishes and dragon is visible")
	dragon.has_taken_off = true
	dragon.manual_input_override = true
	reset_air(Vector3(180,250,120))
	var y0 := dragon.global_position.y
	dragon.manual_climb = true
	var max_delta := 0.0
	var previous_velocity := dragon.velocity
	for _i in range(180):
		await ticks(1)
		max_delta = maxf(max_delta, dragon.velocity.distance_to(previous_velocity))
		previous_velocity = dragon.velocity
	check(dragon.global_position.y > y0 + 20 and dragon.velocity.y > 8, "Climb gains height and sustains positive vertical speed")
	check(dragon.is_flapping and dragon.climb_blend > 0.9 and dragon.rotation.x > 0.35, "Climb coordinates pitch and active wings")
	var top_y := dragon.global_position.y
	dragon.manual_climb = false
	dragon.manual_dive = true
	for _i in range(180):
		await ticks(1)
		max_delta = maxf(max_delta, dragon.velocity.distance_to(previous_velocity))
		previous_velocity = dragon.velocity
	check(dragon.global_position.y < top_y - 35 and dragon.velocity.y < -15, "Dive loses height and accelerates downward")
	check(dragon.current_speed > 32 and dragon.dive_fold_blend > 0.9, "Dive gains speed and enters folded pose")
	check(max_delta < 3, "Air velocity has no discontinuity above 3m/s per 60Hz tick")
	metrics.max_air_velocity_delta = max_delta
	dragon.manual_dive = false
	reset_air(Vector3(180,250,120))
	dragon.manual_input_override = false
	key(KEY_S,true)
	await ticks(180)
	check(dragon.current_speed > 0 and dragon.velocity.dot(-dragon.global_basis.z) >= 0, "Brake never flies backward")
	key(KEY_S,false)
	await ticks(10)
	key(KEY_G,true)
	key(KEY_G,false)
	await ticks(60)
	check(dragon.current_mode == dragon.FlightMode.GLIDE and not dragon.is_flapping, "Keyboard G enters glide without wing beating")
	await click(scene.get_node("HUD/ActionBar/HBoxContainer/BtnClimb"))
	await ticks(30)
	check(dragon.current_mode == dragon.FlightMode.CLIMB, "Actual GUI click enters climb")
	dragon.manual_input_override = true
	reset_air(Vector3(180,160,120))
	key(KEY_L,true)
	key(KEY_L,false)
	await ticks(30)
	check(dragon.locomotion_state == dragon.LocomotionState.LANDING, "Keyboard L begins landing")
	key(KEY_L,true)
	key(KEY_L,false)
	await ticks(1)
	check(dragon.locomotion_state == dragon.LocomotionState.FLYING, "Keyboard L cancels approach")
	dragon.trigger_landing()
	var touchdown_velocity := 999.0
	for _i in range(1500):
		var vertical := absf(dragon.velocity.y)
		await ticks(1)
		if dragon.locomotion_state == dragon.LocomotionState.GROUNDED:
			touchdown_velocity = vertical
			break
	check(dragon.locomotion_state == dragon.LocomotionState.GROUNDED and dragon.is_on_floor(), "Dry-terrain landing completes on actual floor")
	check(touchdown_velocity < 5, "Landing flare slows vertical approach below 5m/s")
	metrics.touchdown_vertical_speed = touchdown_velocity
	await ticks(60)
	# Measure locomotion in a surveyed dry corridor. The old 3.6m sphere on layer2
	# classified a 28-degree terrain rise under the visible neck as unobstructed.
	var corridor_found := await select_ground_corridor()
	check(corridor_found,"Test walking corridor is unobstructed by physical scenery")
	await ticks(90)
	var start := dragon.global_position
	dragon.manual_move_input = 1
	await ticks(120)
	check(dragon.global_position.distance_to(start) > 8 and dragon.is_on_floor(), "Walking moves over terrain and keeps floor contact")
	check(dragon.ground_blend > 0.98 and dragon.wing_fold_blend > 0.98, "Ground posture fully blends and folds wings")
	var max_foot_error := 0.0
	if dragon.ground_pose.debug_errors.size() == 4:
		for error: float in dragon.ground_pose.debug_errors:
			max_foot_error = maxf(max_foot_error,error)
		check(max_foot_error < 0.45, "All four feet solve within 45cm of planted/swing targets")
	else:
		check(false,"Four physical foot targets exist")
	metrics.max_foot_error = max_foot_error
	dragon.manual_move_input = 0
	await ticks(90)
	check(absf(dragon.current_speed) < 0.05, "Walking releases to stable idle")
	var walk_wall := StaticBody3D.new()
	walk_wall.collision_layer = 2
	var walk_wall_shape := CollisionShape3D.new()
	var walk_wall_box := BoxShape3D.new()
	walk_wall_box.size = Vector3(20,20,1)
	walk_wall_shape.shape = walk_wall_box
	walk_wall.add_child(walk_wall_shape)
	scene.add_child(walk_wall)
	var walk_heading := -Basis(Vector3.UP, dragon.rotation.y).z
	walk_wall.global_position = dragon.global_position + walk_heading * 7.0
	walk_wall.global_basis = Basis.looking_at(walk_heading, Vector3.UP)
	dragon.manual_move_input = 1
	await ticks(180)
	var blocked_position := dragon.global_position
	var blocked_phase := dragon.walk_cycle_phase
	await ticks(30)
	check(dragon.global_position.distance_to(blocked_position) < 0.15 and absf(dragon.current_speed) < 0.1 and absf(dragon.walk_cycle_phase-blocked_phase) < 0.1, "Blocked ground motion stops gait instead of walking against obstacle")
	walk_wall.queue_free()
	dragon.manual_move_input = 0
	await ticks(30)
	dragon.manual_move_input = -0.6
	start = dragon.global_position
	await ticks(100)
	check(dragon.current_speed < -1 and dragon.global_position.distance_to(start) > 3, "Ground reverse works")
	dragon.manual_move_input = 1
	dragon.manual_sprint = true
	await ticks(100)
	check(dragon.current_speed > dragon.walk_speed + 1, "Ground sprint is faster than walk")
	dragon.manual_sprint = false
	dragon.manual_move_input = 0
	dragon.manual_turn_input = 0.5
	var yaw0 := dragon.rotation.y
	await ticks(60)
	check(absf(wrapf(dragon.rotation.y - yaw0,-PI,PI)) > 0.3, "Ground turn changes heading")
	dragon.manual_turn_input = 0
	await ticks(90)
	breath.manual_override = true
	breath.manual_fire = true
	await ticks(30)
	check(breath.is_firing and breath.intensity > 0.9 and breath.fuel < 1, "Ground breath starts and consumes fuel")
	check(breath.breath_direction.y > -0.15, "Ground breath raises the neck and aims forward")
	var sk: Skeleton3D = dragon.skeleton
	var head_pos := sk.to_global(sk.get_bone_global_pose(dragon.bone_head_idx).origin)
	var mouth_tip := breath.rendered_oral_center
	print("MUZZLE measured oral-gap=", breath.mouth_position.distance_to(mouth_tip), " head-gap=", breath.mouth_position.distance_to(head_pos))
	check(breath.mouth_landmarks_valid and breath.mouth_position.distance_to(mouth_tip) < 0.12, "Breath emitter follows actual oral opening")
	var wall := StaticBody3D.new()
	wall.name = "TestBreathObstacle"
	wall.collision_layer = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8,8,1)
	shape.shape = box
	wall.add_child(shape)
	scene.add_child(wall)
	wall.global_position = breath.mouth_position + breath.breath_direction * 7
	wall.global_basis = Basis.looking_at(breath.breath_direction, Vector3.UP)
	await ticks(10)
	check(breath.impact_active and breath.hit_distance < 8, "Breath detects nearby obstacle and clips reach")
	check(breath.flame_material.get_shader_parameter("reach") <= 8 and breath.flame_material.get_shader_parameter("has_impact"), "Rendered flame receives obstacle clipping plane and distance")
	var resets_before_wall_removed := breath.effect_resets
	wall.queue_free()
	await ticks(3)
	var ground_breath_transform := dragon.global_transform
	reset_air(Vector3(180,450,120))
	await ticks(3)
	check(breath.effect_resets > resets_before_wall_removed, "Changing impact clears residual particles behind old clipping plane")
	var trunk := StaticBody3D.new()
	trunk.collision_layer = 2
	var trunk_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.12
	cylinder.height = 5.0
	trunk_shape.shape = cylinder
	trunk.add_child(trunk_shape)
	scene.add_child(trunk)
	trunk.global_position = breath.mouth_position + breath.breath_direction * 10.0 + breath.global_basis.x * 0.95
	await ticks(10)
	check(breath.impact_active and breath.hit_distance < 12 and breath.hit_collider_id == trunk.get_instance_id(), "Breath volume catches thin off-axis trunk between fan rays")
	trunk.queue_free()
	await ticks(3)
	var far_trunk := StaticBody3D.new()
	far_trunk.collision_layer = 2
	var far_shape := CollisionShape3D.new()
	var far_cylinder := CylinderShape3D.new()
	far_cylinder.radius = 0.32
	far_cylinder.height = 5.0
	far_shape.shape = far_cylinder
	far_trunk.add_child(far_shape)
	scene.add_child(far_trunk)
	far_trunk.global_position = breath.mouth_position + breath.breath_direction * 20.0 + breath.global_basis.x * 2.7
	await ticks(10)
	check(breath.impact_active and breath.hit_distance < 22 and breath.hit_collider_id == far_trunk.get_instance_id(), "Breath covers maximum spread and card width against distant offset trunk")
	far_trunk.queue_free()
	dragon.global_transform = ground_breath_transform
	dragon.target_yaw = dragon.rotation.y
	dragon.target_pitch = dragon.rotation.x
	dragon.target_roll = dragon.rotation.z
	dragon.locomotion_state = dragon.LocomotionState.GROUNDED
	dragon.current_speed = 0
	dragon.velocity = Vector3.ZERO
	dragon.ground_pose.reset()
	await ticks(320)
	check(breath.exhausted and not breath.is_firing, "Continuous breath exhausts reserve and stops")
	breath.manual_fire = false
	await ticks(540)
	check(breath.fuel > 0.98 and not breath.exhausted and breath.intensity < 0.01, "Release extinguishes breath and restores reserve")
	dragon.trigger_takeoff()
	await ticks(100)
	check(dragon.locomotion_state == dragon.LocomotionState.FLYING and dragon.ground_proximity > 10, "Takeoff clears real ground and returns to flight")
	breath.manual_fire = true
	await ticks(15)
	check(breath.is_firing,"Breath also works during flight")
	breath.manual_fire = false
	await ticks(30)
	# Wall contact is not a valid touchdown.
	dragon.manual_input_override = false
	scene.get_node("HUD/ActionBar/HBoxContainer/BtnLand").grab_focus()
	key(KEY_SPACE,true)
	await ticks(8)
	var focused_space_climbs := dragon.is_climbing
	key(KEY_SPACE,false)
	await ticks(2)
	check(dragon.locomotion_state == dragon.LocomotionState.FLYING and focused_space_climbs, "SPACE climbs without activating focused landing button")
	dragon.manual_input_override = true
	reset_air(Vector3(180,500,120))
	var landing_wall := StaticBody3D.new()
	shape = CollisionShape3D.new()
	box = BoxShape3D.new()
	box.size = Vector3(30,120,1)
	shape.shape = box
	landing_wall.add_child(shape)
	scene.add_child(landing_wall)
	landing_wall.global_position = dragon.global_position + Vector3.FORWARD * 8
	dragon.trigger_landing()
	await ticks(90)
	check(dragon.locomotion_state == dragon.LocomotionState.LANDING and not dragon.is_on_floor(), "Vertical wall contact never counts as landing")
	landing_wall.queue_free()
	reset_air(Vector3(1490,200,0))
	await ticks(180)
	check(dragon.global_position.is_finite() and absf(dragon.global_position.x) < 1480, "World edge recovers toward playable terrain")
	# Starting over water must choose a dry approach and finish on dry collision.
	reset_air(Vector3(0,75,0))
	dragon.trigger_landing()
	var landscape := get_first_node_in_group("landscape")
	check(dragon.landing_target_active, "Landing over water selects a dry destination")
	for _i in range(2400):
		await ticks(1)
		if dragon.locomotion_state == dragon.LocomotionState.GROUNDED:
			break
	check(dragon.locomotion_state == dragon.LocomotionState.GROUNDED and not landscape.is_water_at(dragon.global_position), "Water approach lands on dry visible ground")
	# GUI hold is a separate input path from keyboard/manual fire.
	breath.manual_override = false
	breath.fuel = 1
	breath.exhausted = false
	var fire_button: Button = scene.get_node("HUD/ActionBar/HBoxContainer/BtnFire")
	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.position = fire_button.get_global_transform_with_canvas() * (fire_button.size * 0.5)
	mouse_down.pressed = true
	root.push_input(mouse_down,true)
	await ticks(15)
	check(breath.is_firing, "Actual fire-button press begins breath")
	var mouse_up := InputEventMouseButton.new()
	mouse_up.button_index = MOUSE_BUTTON_LEFT
	mouse_up.position = Vector2(12,300)
	mouse_up.pressed = false
	root.push_input(mouse_up,true)
	await ticks(20)
	check(not breath.is_firing and not breath.requested, "Releasing fire outside button extinguishes request")
	key(KEY_F,true)
	await ticks(5)
	check(breath.is_firing, "Keyboard F starts breath within 100ms")
	key(KEY_F,false)
	await ticks(5)
	check(not breath.is_firing, "Keyboard F release stops emission")
	reset_air(Vector3(180,250,120))
	var camera: FlightCamera = scene.get_node("FlightCamera")
	camera.zoom_offset = 4
	await ticks(120)
	check(camera.target_distance > 20.5, "Camera zoom choice persists during follow")
	var bad_camera := false
	for _i in range(100):
		dragon.manual_climb = _i < 50
		dragon.manual_dive = _i >= 50
		await ticks(1)
		bad_camera = bad_camera or not camera.global_transform.is_finite()
	check(not bad_camera,"Camera stays finite during steep pitch transitions")
	for child: Button in scene.get_node("HUD/ActionBar/HBoxContainer").get_children():
		check(child.size.y >= 44 and child.size.x >= 44,"Button target >=44px: " + child.name)
	metrics.checks = checks
	metrics.failures = failures
	var report := FileAccess.open("res://docs/validation/acceptance.json",FileAccess.WRITE)
	if report:
		report.store_string(JSON.stringify(metrics,"  "))
	else:
		push_warning("Could not save acceptance.json: " + str(FileAccess.get_open_error()))
	print("RESULT ",checks - failures.size(),"/",checks," checks passed; failures=",failures)
	root.remove_child(scene)
	scene.free()
	await ticks(2)
	quit(0 if failures.is_empty() else 1)
