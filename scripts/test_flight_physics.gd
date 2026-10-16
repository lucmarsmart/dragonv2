extends SceneTree
# Verifica el modelo de energía, sustentación y viraje alabeado (docs/plans/vuelo-natural-dragontwin.md, V-01..V-04).
# Uso: tools/godot.sh --headless --path . --fixed-fps 60 --script res://scripts/test_flight_physics.gd

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

func reset_air(speed: float = 26.0) -> void:
	dragon.global_position = Vector3(180, 320, 120)
	dragon.rotation = Vector3.ZERO
	dragon.target_pitch = 0
	dragon.target_yaw = 0
	dragon.target_roll = 0
	dragon.velocity = Vector3(0, 0, -speed)
	dragon.current_speed = speed
	dragon.locomotion_state = dragon.LocomotionState.FLYING
	dragon.manual_input_override = true
	dragon.manual_move_input = 0.0
	dragon.manual_turn_input = 0.0
	dragon.manual_climb = false
	dragon.manual_dive = false
	dragon.manual_brake = false
	dragon.glide_mode_active = false

func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.get_node("SiegeUI").free()
	scene.get_node("SiegeCombat").free()
	root.add_child(scene)
	dragon = scene.get_node("Dragon")
	await ticks(150)
	dragon.has_taken_off = true

	# V-01 Trepar cuesta velocidad: una trepada sostenida termina más lenta que el crucero.
	reset_air()
	dragon.manual_climb = true
	await ticks(240)
	var climb_speed := dragon.current_speed
	check(climb_speed < 26.0 - 3.0, "Sustained climb trades speed for height (26 -> %.1f m/s in 4s)" % climb_speed)

	# V-01 Picar gana velocidad por encima del crucero en >=30 %.
	reset_air()
	dragon.manual_dive = true
	await ticks(240)
	check(dragon.current_speed > 26.0 * 1.3, "Sustained dive exceeds cruise by 30%% (%.1f m/s)" % dragon.current_speed)

	# V-01 Zoom: la velocidad de picada se convierte en altura al recoger.
	dragon.manual_dive = false
	dragon.manual_climb = true
	var lowest := dragon.global_position.y
	var fast_entry := dragon.current_speed
	# Recoger hasta volver a velocidad de crucero (o 8 s): la energía cinética sobrante se vuelve altura.
	for _i in 480:
		await ticks(1)
		lowest = minf(lowest, dragon.global_position.y)
		if dragon.current_speed <= 26.0 and dragon.velocity.y > 0.0:
			break
	var regained := dragon.global_position.y - lowest
	check(regained > 30.0 and dragon.current_speed < fast_entry, "Pull-up converts dive speed into height (+%.1f m from lowest, %.1f -> %.1f m/s)" % [regained, fast_entry, dragon.current_speed])

	# V-02 Planeo sin batir: pierde altura de forma continua (no flota indefinidamente).
	reset_air()
	dragon.glide_mode_active = true
	var y_glide := dragon.global_position.y
	await ticks(300)
	check(dragon.global_position.y < y_glide - 5.0 and dragon.current_mode == dragon.FlightMode.GLIDE, "Glide without flapping descends (%.1f m)" % (dragon.global_position.y - y_glide))

	# V-02 Lento = poca sustentación: frenado se hunde.
	reset_air()
	dragon.manual_brake = true
	await ticks(240)
	check(dragon.velocity.y < -1.5, "Low-speed brake loses lift and sinks (vy %.1f)" % dragon.velocity.y)

	# V-03 Viraje alabeado: el alabeo precede al giro y alcanza >= 50°.
	reset_air()
	dragon.manual_turn_input = 1.0
	await ticks(12)
	var early_roll := absf(dragon.rotation.z)
	var early_yaw := absf(dragon.rotation.y)
	await ticks(168)
	var max_roll := absf(dragon.rotation.z)
	var heading_change := absf(dragon.rotation.y)
	check(early_roll > 0.05 and early_yaw < early_roll, "Bank leads the turn (roll %.2f, yaw %.2f rad at 0.2s)" % [early_roll, early_yaw])
	check(max_roll > deg_to_rad(50.0), "Hard turn banks beyond 50 deg (%.0f deg)" % rad_to_deg(max_roll))
	check(heading_change > 1.2 and heading_change < 4.0, "Coordinated turn rate is heavy but usable (%.0f deg in 3s)" % rad_to_deg(heading_change))

	# V-02 Un viraje cerrado sin tirar pierde algo de altura a velocidad de planeo.
	reset_air(22.0)
	dragon.glide_mode_active = true
	dragon.manual_turn_input = 1.0
	var y_turn := dragon.global_position.y
	await ticks(180)
	var turn_drop := y_turn - dragon.global_position.y
	reset_air(22.0)
	dragon.glide_mode_active = true
	var y_straight := dragon.global_position.y
	await ticks(180)
	var straight_drop := y_straight - dragon.global_position.y
	check(turn_drop > straight_drop + 2.0, "Banked glide sinks more than straight glide (%.1f vs %.1f m)" % [turn_drop, straight_drop])

	# V-03 Al soltar, el alabeo vuelve a nivel.
	dragon.manual_turn_input = 0.0
	dragon.glide_mode_active = false
	await ticks(150)
	check(absf(dragon.rotation.z) < deg_to_rad(8.0), "Releasing turn rolls back to level")

	# Recuperación: lento (8 m/s), batir con W no se desploma y recupera velocidad; trepar gana altura.
	reset_air(8.0)
	dragon.manual_move_input = 1.0
	var y_slow := dragon.global_position.y
	await ticks(180)
	check(y_slow - dragon.global_position.y < 8.0 and dragon.current_speed > 14.0, "Flapping recovers from stall speed (drop %.1f m, %.1f m/s)" % [y_slow - dragon.global_position.y, dragon.current_speed])
	reset_air(8.0)
	dragon.manual_climb = true
	var y_climb := dragon.global_position.y
	await ticks(180)
	check(dragon.global_position.y > y_climb + 10.0, "Climb from stall speed gains height (+%.1f m)" % (dragon.global_position.y - y_climb))
	dragon.manual_climb = false

	# V-04 Tempo de aleteo de crucero >= 1.9 s por batido (2 batidos por ciclo de 3 s).
	reset_air()
	await ticks(60)
	var flap_period := 1.5 / maxf(dragon.anim_player.speed_scale, 0.01)
	check(flap_period >= 1.9, "Cruise flap period is heavy (%.2f s)" % flap_period)

	print("RESULT %s (%d failures)" % ["OK" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
