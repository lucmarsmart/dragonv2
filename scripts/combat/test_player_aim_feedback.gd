extends SceneTree

# Main scene, production enemies/camera/pose and actual input only. The driver
# never teleports actors, replaces the camera, changes HP or invokes damage.
var scene: Node3D
var dragon: DragonController
var combat: SiegeCombat
var breath: DragonBreath
var camera: FlightCamera
var hud: CanvasLayer
var held := {}
var failures: Array[String] = []
var checks := 0
var rows: Array = []
var sources := {}
var target: CharacterBody3D
var input_count := 0
var snapshots: Array[String] = []
var stage := "initialization"
var measured_retreat := {}
var mouse_left_held := false
var attack_mode_pulses := 0
var human_input_violations := 0
var attack_camera_regression := {}
const OUT := "res://docs/validation/v2/player-aim-feedback"

func _initialize() -> void:
	call_deferred("run")

func tick() -> void:
	await physics_frame
	await process_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)

func key(code: Key, pressed: bool) -> void:
	if bool(held.get(code, false)) == pressed:
		return
	held[code] = pressed
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)
	input_count += 1

func pulse(code: Key) -> void:
	key(code, true)
	await tick()
	key(code, false)
	# Parsed releases update Input on the next frame; callers observe settled state.
	await tick()

func release() -> void:
	for code in held.keys():
		key(code, false)
	left_click(false)

func left_click(pressed: bool) -> void:
	if mouse_left_held == pressed:
		return
	mouse_left_held = pressed
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = root.get_visible_rect().size * 0.5
	event.global_position = event.position
	Input.parse_input_event(event)
	input_count += 1

func aim(point: Vector3) -> void:
	var local: Vector3 = dragon.global_basis.inverse() * (point - breath.mouth_position).normalized()
	# Send the human's full mouse intent. The production controller owns the
	# head limit and transfers yaw overflow to the body in attack mode.
	var yaw := atan2(-local.x, -local.z)
	var pitch := clampf(asin(clampf(local.y, -1, 1)), -PI / 6.0, PI / 6.0)
	var e := InputEventMouseMotion.new()
	e.relative = Vector2((dragon.head_requested_yaw - yaw) / dragon.mouse_sensitivity, (dragon.head_requested_pitch - pitch) / dragon.mouse_sensitivity).limit_length(80)
	e.screen_relative = e.relative
	Input.parse_input_event(e)
	input_count += 1

func center(enemy: CharacterBody3D) -> Vector3:
	return enemy.global_position + Vector3.UP

func ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, 7)
	q.exclude = [dragon.get_rid()]
	return scene.get_world_3d().direct_space_state.intersect_ray(q)

func support_snapshot() -> Array:
	# Read the published support joints used by constrain_support_motion. No
	# sampler, pose update or runtime state write is needed for this diagnostic.
	var result: Array = []
	var reverse_heading := Basis(Vector3.UP, dragon.rotation.y).z
	for limb in dragon.ground_pose.limbs:
		var row := {"end": int(limb.end), "swinging": bool(limb.get("swinging", false)),
			"repositioning": bool(limb.get("repositioning", false)),
			"swing_elapsed": float(limb.get("swing_elapsed", 0)),
			"step_t": float(limb.get("step_t", 0)),
			"startup_step": bool(limb.get("startup_step", false)),
			"startup_pending": bool(limb.get("startup_pending", false)),
			"support_limited": bool(limb.get("support_limited", false)),
			"support_transition": bool(limb.get("support_transition", false)),
			"swing_clock_frame": int(limb.get("swing_clock_frame", -1)),
			"last_swing_started_frame": int(limb.get("last_swing_started_frame", -1))}
		row["startup_distance_scale"]=float(limb.get("startup_distance_scale",1))
		row["swing_clock_rate"]=float(limb.get("swing_clock_rate",0))
		row["clearance_m"]=float(limb.clearance)
		for field in ["start","finish","planted","actual","contact_anchor"]:
			var point:Vector3=limb[field]
			row[field]=[point.x,point.y,point.z]
		if not limb.contact_sample.is_empty() and limb.has("published_wrist"):
			# SkeletonModifier poses are restored outside their callback. Compare
			# the final cached joints, rather than sampling the imported pose here.
			row["support_wrist_anchor_correction_m"]=(limb.published_wrist as Vector3).distance_to(limb.actual)
		if limb.has("published_hip_actor") and limb.has("published_wrist") and limb.has("published_reach"):
			var hip: Vector3 = dragon.to_global(limb.published_hip_actor)
			var offset: Vector3 = hip - (limb.published_wrist as Vector3)
			var radius := maxf(0.1, float(limb.published_reach) - 0.12)
			row["published_support"] = not row.swinging
			row["published_reach_m"] = float(limb.published_reach)
			row["hip_to_published_wrist_m"] = offset.length()
			row["support_radius_m"] = radius
			row["support_reach_remaining_m"] = radius - offset.length()
			row["reverse_outward_dot_m"] = offset.dot(reverse_heading)
		result.append(row)
	return result

func oracle() -> Dictionary:
	var p := center(target)
	var offset := p - breath.mouth_position
	var along := offset.dot(breath.breath_direction)
	var lateral := (offset - breath.breath_direction * along).length()
	var cone := 0.95 + along * tan(deg_to_rad(7))
	var los := ray(breath.mouth_position, p)
	var sight := ray(camera.global_position, p)
	var pixel := camera.unproject_position(p)
	var viewport := root.get_visible_rect()
	var preview := ray(breath.mouth_position, breath.mouth_position + breath.breath_direction * breath.max_reach)
	var preview_point: Vector3 = preview.position if not preview.is_empty() else breath.mouth_position + breath.breath_direction * breath.max_reach
	var flat := target.global_position - dragon.global_position
	flat.y = 0
	var wanted_yaw := atan2(-flat.x, -flat.z)
	var contacts: Array = dragon.wing_contact.contact_details.duplicate(true)
	for detail in contacts:
		if detail.get("normal") is Vector3:
			var normal: Vector3 = detail.normal
			detail.normal = [normal.x, normal.y, normal.z]
	return {"stage": stage, "mission_phase": combat.phase, "player_health": combat.health,
		"attack_mode_active": dragon.attack_mode_active, "aim_active": dragon.head_aim_active,
		"input_left_click": Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),
		"input_w": Input.is_key_pressed(KEY_W), "input_s": Input.is_key_pressed(KEY_S),
		"input_a": Input.is_key_pressed(KEY_A), "input_d": Input.is_key_pressed(KEY_D),
		"input_f": Input.is_key_pressed(KEY_F), "input_t": Input.is_key_pressed(KEY_T),
		"body_yaw_deg": rad_to_deg(dragon.rotation.y), "body_requested_yaw_deg": rad_to_deg(dragon.target_yaw),
		"target_body_yaw_error_deg": rad_to_deg(wrapf(wanted_yaw - dragon.rotation.y, -PI, PI)),
		"head_aim_yaw_deg": rad_to_deg(dragon.head_aim_yaw), "head_aim_pitch_deg": rad_to_deg(dragon.head_aim_pitch),
		"head_requested_yaw_deg": rad_to_deg(dragon.head_requested_yaw), "head_requested_pitch_deg": rad_to_deg(dragon.head_requested_pitch),
		"head_pose_blocked": dragon.head_pose_blocked, "pose_turn_blocked": dragon.pose_turn_blocked,
		"wing_predictive_contact": dragon.wing_contact.predictive_contact,
		"wing_contact_details": contacts,
		"physics_frame": Engine.get_physics_frames(), "current_speed_m_s": dragon.current_speed,
		"velocity_m_s": [dragon.velocity.x, dragon.velocity.y, dragon.velocity.z],
		"ground_motion_speed_m_s": dragon.ground_motion_speed, "ground_blend": dragon.ground_blend,
		"shoreline_blocked": dragon.shoreline_blocked,
		"on_floor": dragon.is_on_floor(), "on_wall": dragon.is_on_wall(),
		"walk_cycle_phase": dragon.walk_cycle_phase,
		"gait_planning_frame": dragon.ground_pose.planning_frame,
		"gait_planned_move_direction": dragon.ground_pose.planned_move_direction,
		"published_supports": support_snapshot(),
		"body_pose_blocked": dragon.wing_contact.body_pose_blocked,
		"body_pose_valid": dragon.wing_contact.body_pose_valid,
		"body_pose_recovering": dragon.wing_contact.body_pose_recovering,
		"ground_guard_motion": [dragon.ground_guard_motion.x, dragon.ground_guard_motion.y, dragon.ground_guard_motion.z],
		"ground_executed_motion": [dragon.ground_executed_motion.x, dragon.ground_executed_motion.y, dragon.ground_executed_motion.z],
		"target_name": String(target.name), "target_position": [p.x, p.y, p.z],
		"body_target_distance_m": flat.length(), "along_m": along, "lateral_m": lateral, "cone_limit_m": cone,
		"inside_damage_cone": along >= 0 and along <= breath.max_reach and lateral <= cone,
		"los_clear": los.is_empty() or los.collider == target,
		"los_blocker": str(los.collider.get_path()) if not los.is_empty() else "",
		"projected_in_view": not camera.is_position_behind(p) and viewport.has_point(pixel),
		"camera_los_clear": sight.is_empty() or sight.collider == target,
		"target_pixel": [pixel.x, pixel.y], "enemy_health": target.health,
		"preview_error_m": hud.aim_preview_point.distance_to(preview_point),
		"preview_tick_age": Engine.get_physics_frames() - hud.aim_preview_tick,
		"legacy_max_reach_preview_error_m": (breath.mouth_position + breath.breath_direction * breath.max_reach).distance_to(preview_point),
		"fire": breath.is_firing, "reverse_input": Input.is_key_pressed(KEY_S),
		"body_position": [dragon.position.x, dragon.position.y, dragon.position.z],
		"mouth_position": [breath.mouth_position.x, breath.mouth_position.y, breath.mouth_position.z],
		"camera_position": [camera.position.x, camera.position.y, camera.position.z],
		"head_follow_blend": camera.head_follow_blend}

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := OUT + "-" + label + ".png"
	root.get_texture().get_image().save_png(path)
	snapshots.append(path)

func nearest_knight() -> CharacterBody3D:
	var result: CharacterBody3D
	var distance := INF
	for enemy in combat.enemies:
		if enemy.dead or enemy.kind != "knight":
			continue
		var d := enemy.global_position.distance_to(dragon.global_position)
		if d < distance:
			distance = d
			result = enemy
	return result

func walk(point: Vector3, retreat: bool) -> void:
	var offset := point - dragon.global_position
	offset.y = 0
	var wanted := atan2(-offset.x, -offset.z)
	var error := wrapf(wanted - dragon.target_yaw, -PI, PI)
	var facing := absf(wrapf(wanted - dragon.rotation.y, -PI, PI)) < 0.35
	key(KEY_A, error > 0.025)
	key(KEY_D, error < -0.025)
	key(KEY_S, retreat and facing)
	key(KEY_W, not retreat and facing)
	key(KEY_SHIFT, false)

func run() -> void:
	for path in ["scripts/combat/test_player_aim_feedback.gd", "scripts/flight_camera.gd", "scripts/hud.gd", "scripts/dragon_controller.gd", "scripts/dragon_ground_pose.gd", "scripts/dragon_wing_contact.gd", "scripts/dragon_breath.gd", "scripts/dragon_breath_modifier.gd", "scripts/combat/siege_combat.gd", "scripts/combat/siege_ui.gd", "shaders/flame.gdshader", "scenes/main.tscn"]:
		sources[path] = FileAccess.get_sha256("res://" + path)
	scene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	dragon = scene.get_node("Dragon")
	breath = dragon.get_node("DragonBreath")
	combat = scene.get_node("SiegeCombat")
	camera = scene.get_node("FlightCamera")
	hud = scene.get_node("HUD")
	for _i in 600:
		await tick()
		if combat.initialized:
			break
	check(combat.initialized, "Actual main mission initializes")
	await pulse(KEY_ENTER)
	# Production KEY_4 selects LEFT; start attack from a real lateral preset.
	await pulse(KEY_4)
	var selected_left_before_attack: bool = camera.view_preset == FlightCamera.ViewPreset.LEFT and not dragon.attack_mode_active
	await pulse(KEY_T)
	attack_mode_pulses += 1
	check(combat.is_running() and dragon.head_aim_active and dragon.attack_mode_active and not Input.is_key_pressed(KEY_T), "ENTER and one released T pulse enable production attack mode")
	stage = "air_attack_camera"
	for _i in 60:
		await tick()
	check(dragon.locomotion_state == dragon.LocomotionState.FLYING and camera.head_follow_blend > 0.95, "Above-head production camera also activates in FLYING attack mode")
	var above_muzzle: Vector3 = camera.global_position - breath.mouth_position
	var camera_forward: Vector3 = -camera.global_basis.z.normalized()
	var real_fire_direction: Vector3 = breath.breath_direction.normalized()
	var fire_target_direction: Vector3 = (breath.mouth_position + real_fire_direction * 14.0 - camera.global_position).normalized()
	attack_camera_regression = {"selected_left_before_attack": selected_left_before_attack,
		"view_preset_during_attack": int(camera.view_preset), "head_follow_blend": camera.head_follow_blend,
		"camera_height_above_muzzle_m": above_muzzle.y, "camera_distance_to_muzzle_m": above_muzzle.length(),
		"camera_forward_dot_real_breath": camera_forward.dot(real_fire_direction),
		"camera_forward_dot_fire_target": camera_forward.dot(fire_target_direction),
		"preset_input": "KEY_4 press/release; production mapping LEFT", "attack_input": "one KEY_T press/release"}
	check(selected_left_before_attack and camera.view_preset == FlightCamera.ViewPreset.LEFT and camera.head_follow_blend > 0.95 and above_muzzle.y > 1.0 and camera_forward.dot(real_fire_direction) > 0.95 and camera_forward.dot(fire_target_direction) > 0.95, "One released T overrides a prior LEFT preset: actual camera is above muzzle and faces the real breath direction")
	await capture("air-attack-above-head")
	await pulse(KEY_L)
	for _i in 3600:
		await tick()
		if dragon.locomotion_state == dragon.LocomotionState.GROUNDED or not combat.is_running():
			break
	check(dragon.locomotion_state == dragon.LocomotionState.GROUNDED, "Production landing reaches the ground without actor placement")
	target = nearest_knight()
	if not target or not combat.is_running():
		check(false, "Mission and actual knight remain available after landing")
		finish()
		return
	# Preview must be current while no fire is requested. Point at physical ground
	# before approaching enemies/walls, so this test cannot leave the neck pinned
	# against the breach during combat preparation.
	stage = "silent_preview_before_encounter"
	var preview_bad := 0
	var legacy_bad := 0
	for _i in 90:
		aim(breath.mouth_position + Vector3(0, -8, -16))
		await tick()
		var row := oracle()
		if row.preview_error_m > 0.35 or row.preview_tick_age > 1:
			preview_bad += 1
		if row.legacy_max_reach_preview_error_m > 1:
			legacy_bad += 1
		rows.append(row)
	check(not breath.is_firing and preview_bad == 0, "Unfired reticle follows fresh physical LOS every measured tick")
	check(legacy_bad > 30, "Independent ground LOS rejects stale fixed-26m reticle negative control")
	# Enter the authored 24m breach through its centre. A direct nearest-enemy
	# pursuit previously stopped at the east wall with no valid line of fire.
	for waypoint in [Vector3(300, 24, 210), Vector3(300, 24, 160)]:
		stage = "gate_route_" + str(waypoint.z)
		var reached := false
		for i in 1800:
			if not combat.is_running():
				break
			var offset: Vector3 = waypoint - dragon.global_position
			offset.y = 0
			if offset.length() < 3:
				reached = true
				break
			walk(waypoint, false)
			aim(breath.mouth_position - dragon.global_basis.z * 20)
			await tick()
			if i % 15 == 0:
				rows.append(oracle())
		release()
		check(reached, "Real ground controls reach centre-gate waypoint " + str(waypoint))
		if not reached:
			await capture("gate-route-blocked")
			finish()
			return
	# Human preparation uses W/S and mouse only. The rendered head may aim
	# independently up to its limit, so body alignment is not a prerequisite.
	stage = "prepare_actual_firing_station"
	target = nearest_knight()
	var ready := false
	var ready_ticks := 0
	for _i in 1800:
		if not target or target.dead or not combat.is_running():
			break
		key(KEY_A, false)
		key(KEY_D, false)
		var distance_to_body := target.global_position.distance_to(dragon.global_position)
		key(KEY_W, distance_to_body > 23)
		key(KEY_S, distance_to_body < 18)
		aim(center(target))
		await tick()
		var row := oracle()
		rows.append(row)
		var usable: bool = row.inside_damage_cone and row.los_clear and row.projected_in_view and row.camera_los_clear and row.along_m > 2 and row.along_m < 22
		ready_ticks = ready_ticks + 1 if usable else 0
		if ready_ticks >= 12:
			ready = true
			break
	release()
	check(ready, "W/S and unclamped mouse establish rendered 26m/7-degree cone, target LOS and camera visibility for twelve ticks")
	if not ready:
		await capture("firing-station-blocked")
		finish()
		return
	stage = "continuous_reverse_aim_fire"
	var health_before: float = target.health
	var start := dragon.global_position
	var reverse_m := 0.0
	var concurrent := 0
	var visible := 0
	var damage_reachable := 0
	for i in 150:
		if not combat.is_running() or target.dead:
			break
		key(KEY_W, false)
		key(KEY_A, false)
		key(KEY_D, false)
		key(KEY_F, false)
		key(KEY_T, false)
		# This observation uses the actual human combination: hold S, move the
		# mouse and hold left click; attack T was pulsed once and released.
		key(KEY_S, true)
		aim(center(target))
		left_click(true)
		var previous := dragon.global_position
		await tick()
		var row := oracle()
		rows.append(row)
		if row.input_a or row.input_d or row.input_f or row.input_t:
			human_input_violations += 1
		if row.input_s and row.input_left_click and row.attack_mode_active and breath.is_firing:
			concurrent += 1
			reverse_m += maxf(0, (dragon.global_position - previous).dot(dragon.global_basis.z))
		if row.projected_in_view and row.camera_los_clear:
			visible += 1
		if row.inside_damage_cone and row.los_clear:
			damage_reachable += 1
		if i == 60:
			await capture("reverse-aim-fire")
	release()
	measured_retreat = {"concurrent_frames": concurrent, "visible_frames": visible, "damage_reachable_frames": damage_reachable,
		"reverse_distance_m": reverse_m, "enemy_hp_before": health_before, "enemy_hp_after": target.health,
		"player_health_after": combat.health, "mission_phase_after": combat.phase,
		"input_method": "S + MouseMotion + LEFT_MOUSE; T entered once and released", "forbidden_key_frames": human_input_violations}
	check(human_input_violations == 0 and concurrent > 30 and reverse_m > 2 and dragon.global_position.distance_to(start) > 2, "S, mouse aim and LEFT_CLICK retreat together without A/D/F or held T")
	check(visible > 30 and camera.head_follow_blend > 0.95, "Production camera above head keeps actual target projected and physical sight clear during retreat")
	check(damage_reachable > 15 and target.dead and target.health <= 0 and combat.fire_hits > 0, "Production LEFT_CLICK fire kills the actual knight while retreating and aiming with mouse")
	check(not dragon.manual_input_override and not breath.manual_override, "No movement, aim or fire override enabled")
	await capture("after-retreat")
	# A separate human-input observation proves that continued mouse intent
	# beyond head yaw steers the physical body. Legacy independent head tests
	# stay intact and continue covering motions below the head limit.
	stage = "human_mouse_overflow_body_turn"
	var yaw_before := dragon.rotation.y
	var previous_yaw := yaw_before
	var accumulated_yaw := 0.0
	var max_requested_yaw := 0.0
	var overflow_forbidden := 0
	key(KEY_S, true)
	left_click(true)
	for _i in 45:
		if not combat.is_running():
			break
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(-24, 0)
		motion.screen_relative = motion.relative
		Input.parse_input_event(motion)
		input_count += 1
		await tick()
		accumulated_yaw += wrapf(dragon.rotation.y - previous_yaw, -PI, PI)
		previous_yaw = dragon.rotation.y
		max_requested_yaw = maxf(max_requested_yaw, absf(dragon.head_requested_yaw))
		var row := oracle()
		rows.append(row)
		if row.input_a or row.input_d or row.input_f or row.input_t:
			overflow_forbidden += 1
	release()
	measured_retreat["mouse_overflow_body_yaw_deg"] = rad_to_deg(accumulated_yaw)
	measured_retreat["mouse_overflow_max_requested_head_yaw_deg"] = rad_to_deg(max_requested_yaw)
	check(overflow_forbidden == 0 and rad_to_deg(accumulated_yaw) > 10 and max_requested_yaw <= PI / 4 + 0.001, "Continued mouse turns actual body beyond ten degrees while head stays within 45 degrees; S/LEFT_CLICK need no A/D/F/held T")
	await capture("mouse-overflow-above-head")
	await pulse(KEY_T)
	attack_mode_pulses += 1
	check(not dragon.attack_mode_active and not dragon.head_aim_active and not Input.is_key_pressed(KEY_T), "One released T pulse exits attack mode after human input observation")
	finish()

func finish() -> void:
	release()
	var unchanged := true
	for path in sources:
		unchanged = unchanged and sources[path] == FileAccess.get_sha256("res://" + path)
	check(unchanged, "Measured runtime source hashes remain frozen")
	var report := {"checks": checks, "failures": failures, "pass": failures.is_empty(), "sources_sha256": sources,
		"rows": rows, "snapshots": snapshots, "input_events": input_count, "display_server": DisplayServer.get_name(),
		"final_stage": stage, "final_player_health": combat.health, "final_mission_phase": combat.phase,
		"measured_retreat": measured_retreat,
		"attack_camera_regression": attack_camera_regression,
		"attack_mode_pulses": attack_mode_pulses, "measured_input_method": "W/S + MouseMotion + LEFT_MOUSE; no A/D/F/held T in encounter observation",
		"legacy_head_and_simultaneous_tests_modified": false,
		"fixture": {"production_main_camera": true, "production_enemy_ai": true, "teleports_after_start": 0,
		"direct_damage_calls": 0, "manual_overrides": false, "runtime_state_writes": 0},
		"limits": "Projected viewport and physical camera LOS do not prove rendered skin visibility; native screenshot inspection is required. Cone, target LOS, HP and retreat are measured independently."}
	FileAccess.open(OUT + ".json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("PLAYER_AIM_FEEDBACK_RESULT ", checks - failures.size(), "/", checks, " failures=", failures)
	scene.free()
	quit(0 if failures.is_empty() else 1)
