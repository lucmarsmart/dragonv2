extends SceneTree

## Tests the production FlightCamera against physical layer-1/2 surfaces. The
## independent oracle inspects the delivered pose, not the camera's desired pose.
## No substitute camera, collision mask override, or runtime source change.
var scene: Node3D
var camera: FlightCamera
var dragon: DragonController
var wall: StaticBody3D
var checks := 0
var failures: Array[String] = []
var metrics := {"cases": [], "negative_controls": []}
var probe := SphereShape3D.new()
var wall_box := AABB(Vector3(-45, 285, -1), Vector3(90, 35, 2))

func _initialize() -> void:
	call_deferred("run")

func ticks(n: int) -> void:
	for _i in n:
		await physics_frame
		await process_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)

func event_key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await ticks(1)
	e.pressed = false
	Input.parse_input_event(e)

func mouse(button: MouseButton, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	Input.parse_input_event(e)

func saddle() -> Vector3:
	return camera.collision_pivot_world

func ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, 3)
	q.exclude = [dragon.get_rid()]
	q.hit_from_inside = true
	return camera.get_world_3d().direct_space_state.intersect_ray(q)

func inspect_pose(previous: Vector3, inspect_sweep: bool = true) -> Dictionary:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = probe
	q.transform = Transform3D(Basis.IDENTITY, camera.global_position)
	q.collision_mask = 3
	q.margin = 0.0
	q.exclude = [dragon.get_rid()]
	var sphere_hits := camera.get_world_3d().direct_space_state.intersect_shape(q, 8)
	var sight := ray(saddle(), camera.global_position)
	var sweep := ray(previous, camera.global_position) if inspect_sweep and previous.distance_to(camera.global_position) > 0.00001 else {}
	return {"finite": camera.global_transform.is_finite(), "sphere_hits": sphere_hits.size(), "segment_hits": 0 if sight.is_empty() else 1, "sweep_hits": 0 if sweep.is_empty() else 1, "inside_box": wall != null and wall_box.has_point(camera.global_position)}

func measure(label: String, frames: int, move_along_wall: bool = false) -> void:
	var bad_finite := 0
	var inside := 0
	var spheres := 0
	var segments := 0
	var sweeps := 0
	var minimum_clearance := INF
	var previous := camera.global_position
	var minimum_pivot_distance := INF
	var maximum_pivot_distance := 0.0
	for i in frames:
		if move_along_wall:
			dragon.position.x = -24.0 + 48.0 * float(i) / maxf(frames - 1.0, 1.0)
		await ticks(1)
		var data := inspect_pose(previous)
		bad_finite += 0 if data.finite else 1
		inside += 1 if data.inside_box else 0
		spheres += data.sphere_hits
		segments += data.segment_hits
		sweeps += data.sweep_hits
		var p := camera.global_position
		if wall != null:
			var nearest := Vector3(clampf(p.x, wall_box.position.x, wall_box.end.x), clampf(p.y, wall_box.position.y, wall_box.end.y), clampf(p.z, wall_box.position.z, wall_box.end.z))
			minimum_clearance = minf(minimum_clearance, p.distance_to(nearest))
		minimum_pivot_distance = minf(minimum_pivot_distance, saddle().distance_to(p))
		maximum_pivot_distance = maxf(maximum_pivot_distance, saddle().distance_to(p))
		previous = p
	var item := {"label": label, "frames": frames, "nonfinite": bad_finite, "inside_box": inside, "sphere_intersections": spheres, "pivot_segment_intersections": segments, "interframe_sweep_intersections": sweeps, "min_box_clearance_m": minimum_clearance if is_finite(minimum_clearance) else -1.0, "min_pivot_distance_m": minimum_pivot_distance, "max_pivot_distance_m": maximum_pivot_distance, "final_position": [camera.position.x, camera.position.y, camera.position.z], "orbit_yaw": camera.orbit_yaw, "distance": camera.distance}
	metrics.cases.append(item)
	print("CAMERA CASE ", JSON.stringify(item))
	check(bad_finite == 0 and inside == 0 and spheres == 0 and segments == 0 and sweeps == 0, label + ": finite pose, 0.2m camera volume and both physical segments stay outside surfaces on every frame")

func run() -> void:
	probe.radius = 0.2
	scene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await ticks(5)
	dragon = scene.get_node("Dragon")
	camera = scene.get_node("FlightCamera")
	# Freeze gameplay only: the camera retains its real physics callback and input.
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	for child in scene.find_children("*", "", true, false):
		if child is CanvasLayer:
			child.process_mode = Node.PROCESS_MODE_DISABLED
		if child is CollisionObject3D:
			child.process_mode = Node.PROCESS_MODE_ALWAYS
			child.set_physics_process(false)
			child.set_process(false)
	camera.process_mode = Node.PROCESS_MODE_ALWAYS
	dragon.position = Vector3(0, 300, 10)
	dragon.rotation = Vector3.ZERO
	camera.position = saddle() + Vector3(0, 5, 18)
	camera.set_view(FlightCamera.ViewPreset.BACK)
	await ticks(60)
	check(camera.get_script().resource_path == "res://scripts/flight_camera.gd", "Fixture exercises unchanged production FlightCamera from main scene")
	wall = StaticBody3D.new()
	wall.name = "CameraCalibrationWall"
	wall.process_mode = Node.PROCESS_MODE_ALWAYS
	wall.collision_layer = 2
	wall.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = wall_box.size
	shape.shape = box
	wall.add_child(shape)
	scene.add_child(wall)
	wall.position = wall_box.get_center()
	await ticks(2)
	check(not ray(saddle(), Vector3(0, 305.5, -20)).is_empty(), "Physical scenery layer-2 wall blocks the shared mask-3 segment")
	# Calibrate independent geometry/physics oracle before accepting any positives.
	var saved := camera.global_position
	camera.global_position = wall.position
	var negative := inspect_pose(saved, false)
	metrics.negative_controls.append({"label": "actual Camera3D deliberately inside physical box", "result": negative})
	check(negative.inside_box and negative.sphere_hits > 0 and negative.segment_hits > 0, "Negative control rejects a finite Camera3D placed inside the wall")
	camera.global_position = saved
	await event_key(KEY_2)
	await measure("frontal approaches a wall during smoothing", 150)
	var blocked_distance := saddle().distance_to(camera.position)
	check(camera.global_position.z >= 1.79 and camera.global_position.z <= 1.81, "Flat-wall frontal response retains the production 0.8m surface margin")
	# With a settled frontal view, lerp from the wall centre toward the clipped
	# desired pose would still be INSIDE after one frame without the second ray.
	camera.global_position = wall.position
	var pre_recovery := inspect_pose(camera.global_position, false)
	await ticks(1)
	var post_recovery := inspect_pose(camera.global_position, false)
	metrics.negative_controls.append({"label": "post-smoothing ray repairs deliberately invalid previous camera pose in one physics frame", "before": pre_recovery, "after": post_recovery, "actual_position": [camera.position.x, camera.position.y, camera.position.z], "unrechecked_lerp_z": 1.8 * (1.0 - exp(-camera.follow_smoothness / 60.0))})
	check(pre_recovery.inside_box and pre_recovery.sphere_hits > 0 and not post_recovery.inside_box and post_recovery.sphere_hits == 0 and post_recovery.segment_hits == 0, "Post-smoothing ray clears a deliberately invalid previous pose on the first physics frame")
	await measure("settled frontal camera after negative-control recovery", 45)
	await event_key(KEY_3)
	await measure("front-to-right lateral transition", 120)
	await event_key(KEY_4)
	await measure("right-to-left orbit passes the wall", 150)
	await event_key(KEY_2)
	await measure("frontal parallel traversal", 180, true)
	dragon.position.x = 0.0
	await ticks(1)
	for _i in 8:
		mouse(MOUSE_BUTTON_WHEEL_DOWN, true)
		mouse(MOUSE_BUTTON_WHEEL_DOWN, false)
		await ticks(1)
	await measure("zoom out against wall", 150)
	check(camera.target_distance > 23.9, "Real wheel input selects maximum zoom while wall still clips delivered pose")
	for _i in 24:
		mouse(MOUSE_BUTTON_WHEEL_UP, true)
		mouse(MOUSE_BUTTON_WHEEL_UP, false)
		await ticks(1)
	await measure("zoom in releases wall clipping", 150)
	check(camera.target_distance < 7.1 and camera.global_position.z > 2.9, "Real wheel input selects the production minimum in flight (7m) and pulls the camera into free space")
	mouse(MOUSE_BUTTON_RIGHT, true)
	await ticks(1)
	check(camera.orbiting, "Real right-click starts production free orbit")
	for _i in 120:
		var e := InputEventMouseMotion.new()
		e.relative = Vector2(8.0, 0.6)
		Input.parse_input_event(e)
		await measure("free orbit step %03d" % _i, 1)
	mouse(MOUSE_BUTTON_RIGHT, false)
	await measure("release orbit and automatic return near wall", 180)
	check(not camera.orbiting and absf(wrapf(camera.orbit_yaw - PI, -PI, PI)) < 0.01, "Released orbit returns to selected frontal preset")
	# Remove only the calibration obstacle: production ray/mask/margin stay intact.
	wall.queue_free()
	wall = null
	await ticks(2)
	for _i in 24:
		mouse(MOUSE_BUTTON_WHEEL_DOWN, true)
		mouse(MOUSE_BUTTON_WHEEL_DOWN, false)
		await ticks(1)
	await measure("obstacle removed, free frontal camera recovers", 180)
	check(saddle().distance_to(camera.position) > 23.9 and saddle().distance_to(camera.position) > blocked_distance + 12.0, "Removing obstacle restores chosen distance without changing camera code or mask")
	# A second test uses a production imported fortress trimesh, not the box.
	var fort: Node3D = scene.get_node("SiegeEnvironment")
	var c: Vector3 = fort.arena_center
	dragon.position = c + Vector3(-40, 3.5, -52)
	dragon.locomotion_state = dragon.LocomotionState.GROUNDED
	dragon.rotation = Vector3.ZERO
	camera.set_view(FlightCamera.ViewPreset.BACK)
	camera.position = saddle() + Vector3(0, 5, 8)
	await ticks(90)
	var hit := ray(saddle(), saddle() + Vector3(0, 5, -30))
	var named_wall := fort.get_node_or_null("wall_thick_straight_01") as MeshInstance3D
	var actual_wall: bool = not hit.is_empty() and hit.collider is StaticBody3D and hit.collider.get_parent() is MeshInstance3D and named_wall != null and hit.collider.get_parent().mesh == named_wall.mesh and hit.collider.get_parent().get_parent() == fort
	metrics.fortress_surface = {"observed": actual_wall, "collider": String(hit.collider.get_path()) if not hit.is_empty() else "", "layer": hit.collider.collision_layer if not hit.is_empty() else 0}
	check(actual_wall and hit.collider.collision_layer == 2, "Real imported fortress wall is the mask-3 physical obstruction")
	await event_key(KEY_2)
	await measure("real fortress front wall and smoothing", 180)
	check(saddle().distance_to(camera.position) < camera.distance - 5.0, "Imported fortress surface visibly constrains the actual camera distance, rather than passing overhead")
	await event_key(KEY_3)
	await measure("real fortress frontal-to-lateral orbit", 120)
	await event_key(KEY_2)
	await measure("real fortress lateral-to-frontal return", 120)
	metrics.checks = checks
	metrics.failures = failures
	metrics.pass = failures.is_empty()
	metrics.production_camera_sha256 = FileAccess.get_sha256("res://scripts/flight_camera.gd")
	metrics.environment_sha256 = FileAccess.get_sha256("res://scripts/siege_environment.gd")
	metrics.driver_sha256 = FileAccess.get_sha256("res://scripts/test_camera_surfaces.gd")
	metrics.oracle = {"mask": 3, "sphere_radius_m": probe.radius, "shape_margin_m": 0.0, "camera_runtime_surface_margin_m": 0.8, "excluded": "target dragon RID only", "frame_checks": "physical pivot-to-camera, interframe camera segment, sphere overlap; synthetic box analytic inside/clearance"}
	metrics.limits = "Target is positioned by the test and gameplay frozen; real camera physics and real input run unchanged. This is a deterministic surface regression, not a native performance or screenshot measurement. 0.2m probe represents near camera clearance, not a full frustum swept convex hull. Fortress concave interiors are checked with the pivot segment and sphere-to-surface, not analytic box containment."
	var report := FileAccess.open("res://docs/validation/v2/camera-surfaces.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(metrics, "  "))
	print("CAMERA RESULT ", checks - failures.size(), "/", checks, " failures=", failures)
	scene.queue_free()
	await ticks(3)
	quit(0 if failures.is_empty() else 1)
