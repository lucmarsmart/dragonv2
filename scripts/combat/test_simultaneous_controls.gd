extends SceneTree

# Input integration fixture. The production dragon, skeleton modifiers, skin,
# breath emitters and collisions stay active. Only initial placement/reset is a
# fixture; all measured movement, aim and firing comes from actual input events.
var dragon: DragonController
var breath: DragonBreath
var scene: Node3D
var camera: Camera3D
var checks := 0
var failures: Array[String] = []
var metrics := {}
var cases: Array = []
const SOURCE_PATHS := ["res://scripts/combat/test_simultaneous_controls.gd", "res://scripts/dragon_controller.gd", "res://scripts/dragon_breath.gd", "res://scripts/dragon_head_pose.gd", "res://scripts/dragon_ground_pose.gd", "res://scripts/dragon_ground_contact.gd", "res://scripts/dragon_pose_probe.gd", "res://scripts/dragon_wing_contact.gd", "res://scripts/dragon_wing_extrema.json", "res://scripts/dragon_skeleton_modifier.gd", "res://scripts/dragon_breath_modifier.gd", "res://scripts/dragon_surface_materials.gd", "res://shaders/flame.gdshader", "res://shaders/smoke.gdshader", "res://assets/models/dragon.glb", "res://assets/models/dragon.glb.import", "res://project.godot", "res://scenes/main.tscn"]

func _initialize() -> void:
	call_deferred("run")

func hashes() -> Dictionary:
	var result := {}
	for path in SOURCE_PATHS:
		result[path] = FileAccess.get_sha256(path)
	return result

func ticks(count: int) -> void:
	for _i in count:
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

func mouse(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.screen_relative = relative
	event.position = Vector2(640, 360)
	event.global_position = event.position
	Input.parse_input_event(event)

func mouse_button(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = Vector2(640, 360)
	event.global_position = event.position
	Input.parse_input_event(event)

func release_inputs() -> void:
	for code in [KEY_W, KEY_S, KEY_A, KEY_D, KEY_F, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_T]:
		key(code, false)
	mouse_button(false)

func fixture(air: bool) -> void:
	release_inputs()
	# Reset occurs before the observation window, never while measured inputs run.
	dragon.global_position = Vector3(0, 340 if air else 203.5, 100)
	dragon.rotation = Vector3.ZERO
	dragon.target_yaw = 0
	dragon.target_pitch = 0
	dragon.target_roll = 0
	dragon.current_speed = 26 if air else 0
	dragon.velocity = Vector3.FORWARD * dragon.current_speed
	dragon.locomotion_state = dragon.LocomotionState.FLYING if air else dragon.LocomotionState.GROUNDED
	dragon.has_taken_off = true
	dragon.ground_pose.reset()
	dragon.body_clearance_lift = 0
	dragon.head_aim_active = false
	dragon.head_requested_yaw = 0
	dragon.head_requested_pitch = 0
	dragon.mouse_captured = false
	dragon.manual_input_override = false
	breath.manual_override = false
	breath.requested = false
	breath.fuel = 1
	breath.exhausted = false
	await ticks(150)
	key(KEY_T, true)
	await ticks(1)
	key(KEY_T, false)
	check(dragon.head_aim_active and dragon.mouse_captured, "T input enables independent head aim")

func head_relative() -> Vector3:
	return dragon.global_basis.inverse() * breath.breath_direction

func observe(label: String, move_keys: Array, aim_keys: Array, mouse_delta: Vector2, air: bool, left_click: bool = false) -> Dictionary:
	await fixture(air)
	var start := dragon.global_position
	var heading := -Basis(Vector3.UP, dragon.rotation.y).z
	var yaw_start := dragon.rotation.y
	var local_start := head_relative()
	var mouth_start := breath.mouth_position
	var fuel_start := breath.fuel
	var count := 120
	var firing_frames := 0
	var emitter_frames := 0
	var simultaneous_frames := 0
	var movement_frames := 0
	var maximum_mouth_error := 0.0
	var maximum_head_direction_error := 0.0
	var maximum_relative_head_change := 0.0
	var blocks := 0
	var shoreline_frames := 0
	var pose_turn_blocks := 0
	var states := {}
	var path := 0.0
	var body_signed_distance := 0.0
	var previous := start
	var previous_yaw := yaw_start
	var accumulated_yaw := 0.0
	var start_tick := Engine.get_physics_frames()
	for code in move_keys:
		key(code, true)
	for code in aim_keys:
		key(code, true)
	if left_click:
		mouse_button(true)
	else:
		key(KEY_F, true)
	for i in count:
		if i % 6 == 0 and mouse_delta != Vector2.ZERO:
			mouse(mouse_delta)
		await ticks(1)
		var movement := dragon.global_position.distance_to(previous)
		path += movement
		body_signed_distance += (dragon.global_position-previous).dot(-Basis(Vector3.UP, dragon.rotation.y).z)
		if movement > .001:
			movement_frames += 1
		previous = dragon.global_position
		# A sustained flight turn can exceed 180 degrees. Integrate actual per-tick
		# yaw instead of mistaking its wrapped final angle for the opposite turn.
		accumulated_yaw += wrapf(dragon.rotation.y-previous_yaw, -PI, PI)
		previous_yaw = dragon.rotation.y
		if breath.is_firing:
			firing_frames += 1
		if breath.flames.emitting and breath.smoke.emitting and breath.embers.emitting:
			emitter_frames += 1
		var controls_held := true
		for code in move_keys:
			controls_held = controls_held and Input.is_key_pressed(code)
		for code in aim_keys:
			controls_held = controls_held and Input.is_key_pressed(code)
		controls_held = controls_held and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) if left_click else Input.is_key_pressed(KEY_F))
		if controls_held and breath.is_firing and dragon.head_aim_active and not dragon.manual_input_override and not breath.manual_override:
			simultaneous_frames += 1
		maximum_mouth_error = maxf(maximum_mouth_error, breath.mouth_position.distance_to(breath.rendered_oral_center + breath.breath_direction * .08))
		maximum_head_direction_error = maxf(maximum_head_direction_error, rad_to_deg(breath.breath_direction.angle_to(dragon.head_rendered_direction)))
		maximum_relative_head_change = maxf(maximum_relative_head_change, rad_to_deg(local_start.angle_to(head_relative())))
		if dragon.wing_contact.predictive_contact:
			blocks += 1
		if dragon.shoreline_blocked:
			shoreline_frames += 1
		if dragon.pose_turn_blocked:
			pose_turn_blocks += 1
		states[str(dragon.locomotion_state)] = int(states.get(str(dragon.locomotion_state), 0)) + 1
	var result := {
		"label": label, "frames": count, "movement_keys": move_keys, "aim_keys": aim_keys,
		"mouse_relative_per_six_ticks": [mouse_delta.x, mouse_delta.y], "fire_input": "LEFT_MOUSE" if left_click else "F",
		"signed_forward_displacement_m": (dragon.global_position - start).dot(heading), "path_m": path, "distance_along_actual_body_heading_m":body_signed_distance,
		"physics_ticks_elapsed":Engine.get_physics_frames()-start_tick,
		"body_yaw_change_deg": rad_to_deg(accumulated_yaw), "body_yaw_wrapped_endpoint_deg":rad_to_deg(wrapf(dragon.rotation.y-yaw_start, -PI, PI)),
		"maximum_relative_rendered_head_change_deg": maximum_relative_head_change,
		"mouth_world_displacement_m": breath.mouth_position.distance_to(mouth_start),
		"fuel_used": fuel_start-breath.fuel, "firing_frames": firing_frames, "emitter_frames": emitter_frames,
		"simultaneous_real_input_frames": simultaneous_frames, "movement_frames": movement_frames,
		"maximum_mouth_attachment_error_m": maximum_mouth_error, "maximum_fire_to_rendered_head_error_deg": maximum_head_direction_error,
		"predictive_contact_frames": blocks, "pose_turn_blocked_frames": pose_turn_blocks,
		"shoreline_blocked_frames": shoreline_frames, "locomotion_states": states,
		"start_position": [start.x,start.y,start.z], "end_position": [dragon.global_position.x,dragon.global_position.y,dragon.global_position.z]
	}
	check(simultaneous_frames >= count-2 and firing_frames >= count-2 and emitter_frames >= count-2, label+": movement/aim/fire inputs remain concurrent and final emitters fire")
	check(maximum_relative_head_change >= 8 and result.mouth_world_displacement_m > 1, label+": actual rendered neck/mouth moves independently of body")
	check(maximum_mouth_error < .001 and maximum_head_direction_error < .1, label+": emitter stays attached to final oral midpoint and points with rendered head")
	check(result.fuel_used > .30, label+": production fire consumes real fuel")
	release_inputs()
	await ticks(8)
	check(not breath.is_firing and not breath.flames.emitting and not Input.is_key_pressed(KEY_W) and not Input.is_key_pressed(KEY_S) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), label+": releasing controls stops requested fire and clears movement keys")
	cases.append(result)
	print("SIMULTANEOUS_CASE ", JSON.stringify(result))
	return result

func run() -> void:
	metrics.source_hashes_before = hashes()
	var source: Node3D = load("res://scenes/main.tscn").instantiate()
	dragon = source.get_node("Dragon")
	source.remove_child(dragon)
	dragon.owner = null
	scene = Node3D.new()
	for name in ["WorldEnvironment", "DirectionalLight3D"]:
		var light := source.get_node(name)
		source.remove_child(light)
		light.owner = null
		scene.add_child(light)
	source.free()
	scene.add_child(dragon)
	root.add_child(scene)
	dragon.landscape = scene
	breath = dragon.get_node("DragonBreath")
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(500,1,500)
	collider.shape = box
	floor_body.add_child(collider)
	floor_body.position = Vector3(0,199.5,100)
	scene.add_child(floor_body)
	camera = Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	camera.global_position = Vector3(0,215,135)
	camera.look_at(Vector3(0,204,100))
	await ticks(150)
	var row := await observe("ground_forward_mouse_fire", [KEY_W], [], Vector2(-10,-2), false)
	check(row.signed_forward_displacement_m > 10 and row.movement_frames > 110, "W advances grounded dragon while mouse aims and F fires")
	check(absf(row.body_yaw_change_deg) < 1, "Mouse independent aim does not hijack straight ground movement")
	row = await observe("ground_turn_arrow_fire", [KEY_A], [KEY_RIGHT], Vector2.ZERO, false)
	check(row.body_yaw_change_deg > 50, "A turns actual grounded body while arrow aims independently and F fires")
	row = await observe("ground_reverse_mouse_fire", [KEY_S], [], Vector2(10,-2), false)
	check(row.signed_forward_displacement_m < -6 and row.movement_frames > 110, "S reverses grounded dragon while mouse aims and F fires")
	row = await observe("ground_reverse_turn_arrow_fire", [KEY_S,KEY_D], [KEY_LEFT], Vector2.ZERO, false)
	check(row.distance_along_actual_body_heading_m < -6 and row.body_yaw_change_deg < -50, "S+D reverses and turns grounded body while arrow aims and F fires")
	row = await observe("air_move_turn_mouse_fire", [KEY_W,KEY_A], [], Vector2(-10,-2), true)
	check(row.path_m > 40 and row.body_yaw_change_deg > 90 and row.locomotion_states.size() == 1 and row.locomotion_states.has(str(dragon.LocomotionState.FLYING)), "Flight W+A advances and turns while mouse aims and F fires")
	# Same real input integration also covers captured aim plus left mouse firing.
	row = await observe("ground_forward_mouse_left_click", [KEY_W], [], Vector2(-10,-2), false, true)
	check(row.signed_forward_displacement_m > 10, "W movement and mouse aim continue while left click fires")
	metrics.source_hashes_after = hashes()
	check(metrics.source_hashes_before == metrics.source_hashes_after, "Fixture/source hashes stay unchanged during all observations")
	metrics.checks = checks
	metrics.failures = failures
	metrics.cases = cases
	metrics.fixture = {"production_dragon_and_breath":true,"physical_flat_ground_y_m":200,"flat_ground_size_m":[500,1,500],"manual_move_override":false,"manual_fire_override":false,"direct_movement_aim_or_fire_api_calls":false,"placements_only_before_each_observation":true,"real_enemy_damage_validated_here":false,"native_fps_claimed":false,"display_server":DisplayServer.get_name()}
	FileAccess.open("res://docs/validation/v2/simultaneous-controls.json", FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "))
	print("RESULT ", checks-failures.size(), "/", checks, " simultaneous controls checks; failures=", failures)
	quit(0 if failures.is_empty() else 1)
