extends SceneTree
# V-09: la marcha avanza de forma continua (sin tirones entre 0 y la velocidad nominal)
# y la carrera es claramente más rápida. Uso:
# tools/godot.sh --headless --path . --fixed-fps 60 --script res://scripts/test_walk_gait.gd

var dragon: DragonController
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func ticks(count: int) -> void:
	for _i in count:
		await physics_frame

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1

func measure(seconds: float) -> Dictionary:
	var samples: Array[float] = []
	var start := dragon.global_position
	for _i in int(seconds * 60.0):
		await ticks(1)
		samples.append(dragon.ground_motion_speed)
		if OS.get_cmdline_user_args().has("--trace"):
			var st := []
			for l in dragon.ground_pose.limbs:
				st.append("%d:%s%s%s" % [l.end, "S" if l.swinging else "-", "R" if l.repositioning else "-", "L" if l.get("support_limited", false) else "-"])
			print("TRACE v=%.2f cmd=%.2f phase=%.2f pred=%s wall=%s %s" % [dragon.ground_motion_speed, dragon.current_speed, dragon.walk_cycle_phase, dragon.wing_contact.predictive_contact, dragon.is_on_wall(), " ".join(st)])
	var lowest := INF
	var total := 0.0
	var slow := 0
	for v in samples:
		lowest = minf(lowest, v)
		total += v
		if v < dragon.walk_speed * 0.5:
			slow += 1
	return {"min": lowest, "mean": total / samples.size(), "stalled": float(slow) / samples.size(), "distance": dragon.global_position.distance_to(start)}

func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.get_node("SiegeUI").free()
	scene.get_node("SiegeCombat").free()
	root.add_child(scene)
	dragon = scene.get_node("Dragon")
	await ticks(150)
	var landscape = get_first_node_in_group("landscape")
	var spot := Vector3.ZERO
	for candidate in [Vector3(300, 0, 170), Vector3(280, 0, 160), Vector3(300, 0, 120), Vector3(320, 0, 170)]:
		var support: Dictionary = landscape.ground_surface(candidate)
		if not support.is_empty() and not landscape.is_water_at(candidate):
			spot = support.position
			break
	dragon.has_taken_off = true
	dragon.manual_input_override = true
	dragon.global_position = spot + Vector3.UP * 3.5
	dragon.rotation = Vector3.ZERO
	dragon.target_yaw = 0
	dragon.target_pitch = 0
	dragon.target_roll = 0
	dragon.velocity = Vector3.ZERO
	dragon.current_speed = 0
	dragon.landing_target_active = false
	dragon.locomotion_state = dragon.LocomotionState.LANDING
	await ticks(200)
	check(dragon.locomotion_state == dragon.LocomotionState.GROUNDED, "Dragon settles on real terrain")
	dragon.manual_move_input = 1.0
	await ticks(60)
	var walk := await measure(3.0)
	print("WALK min=%.2f mean=%.2f stalled=%.0f%% distance=%.1f" % [walk.min, walk.mean, walk.stalled * 100.0, walk.distance])
	check(walk.mean > dragon.walk_speed * 0.75, "Walk sustains nominal pace (mean %.2f m/s)" % walk.mean)
	check(walk.stalled < 0.15, "Walk spends <15%% of the time below half pace (%.0f%%)" % (walk.stalled * 100.0))
	dragon.manual_sprint = true
	await ticks(60)
	var run_pace := await measure(3.0)
	print("RUN min=%.2f mean=%.2f distance=%.1f" % [run_pace.min, run_pace.mean, run_pace.distance])
	check(run_pace.mean > walk.mean + 1.0, "Run is clearly faster than walk (%.2f vs %.2f m/s)" % [run_pace.mean, walk.mean])
	var errors: Array = dragon.ground_pose.debug_errors
	var worst := 0.0
	for e in errors:
		worst = maxf(worst, float(e))
	check(errors.size() == 4 and worst < 0.45, "Feet stay on targets while running (worst %.2f m)" % worst)
	print("RESULT %s (%d failures)" % ["OK" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
