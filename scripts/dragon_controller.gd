extends CharacterBody3D
class_name DragonController

# ==============================================================================
# SIMULADOR DE VUELO DE DRAGÓN - BIOMECÁNICA NATURAL (Jonathan Symmonds & Dragontwin)
# Vuelo original natural de Qishilong_fly2, despegue fluido y control total de maniobras
# ==============================================================================

const DragonSkeletonModifier = preload("res://scripts/dragon_skeleton_modifier.gd")

# --- Modos de Vuelo ---
enum FlightMode {
	NORMAL,   # Ciclo de aleteo rítmico continuo natural del artista original
	GLIDE,    # Modo planeo majestuoso con alas extendidas
	CLIMB,    # Ascenso / Trepada potente ganando altitud
	DIVE,     # Picada controlada con alas plegadas en delta (alta velocidad)
	BRAKE     # Frenado aerodinámico (flare con patas y alas abiertas)
}

# --- Estados de Locomoción ---
enum LocomotionState {
	FLYING,     # Vuelo libre en el aire
	LANDING,    # Flare y descenso controlado de aterrizaje
	GROUNDED,   # En tierra: caminata, trote y reposo
	TAKING_OFF  # Impulso vertical y transición a vuelo
}

# --- Parámetros de Vuelo y Físicas ---
@export_group("Locomoción Terrestre y Aterrizaje")
@export var walk_speed: float = 7.5             # Velocidad de marcha en tierra (m/s)
@export var sprint_speed: float = 14.0          # Velocidad de trote/carrera en tierra (Shift, m/s)
@export var ground_turn_speed: float = 2.0       # Tasa de giro horizontal en tierra (rad/s)
@export var ground_accel: float = 18.0          # Aceleración en tierra
@export var ground_friction: float = 14.0       # Fricción al detenerse
@export var jump_impulse: float = 16.0          # Impulso de salto / despegue (m/s)

@export_group("Aerodinámica y Modos de Vuelo")
@export var cruise_speed: float = 26.0          # Velocidad de planeo nivelado (m/s, ~95 km/h)
@export var climb_forward_speed: float = 22.0   # Velocidad horizontal al trepar
@export var climb_vertical_rate: float = 16.0   # Fuerza de ascenso vertical al subir (m/s)
@export var min_stall_speed: float = 7.0        # Velocidad mínima antes de pérdida
@export var max_flap_speed: float = 34.0        # Velocidad máxima aleteando
@export var dive_terminal_speed: float = 38.0   # Picada controlada (~140 km/h)
@export var flap_acceleration: float = 12.0     # Impulso de aceleración por aleteo
@export var air_brake_decel: float = 18.0       # Resistencia al frenar (S)
@export var normal_drag: float = 1.6            # Fricción natural del aire en planeo
@export var gravity_magnitude: float = 9.8      # Gravedad

@export_group("Maniobrabilidad (Sensibilidad)")
@export var mouse_sensitivity: float = 0.0018
@export var pitch_speed: float = 1.6             # Cabeceo (Arriba/Abajo)
@export var yaw_speed: float = 1.4               # Giro horizontal
@export var roll_speed: float = 2.4              # Alabeo (Inclinación de alas)
@export var bank_amount: float = 0.65            # Auto-inclinación al virar (~37 grados)
@export var return_to_level_rate: float = 2.4    # Retorno automático a vuelo horizontal

@export_group("Bamboleo y Biomecánica Procedural")
@export var weight_sway_strength: float = 1.20      # Amplitud del desplazamiento lateral del vientre/torso (m)
@export var weight_spring_stiffness: float = 8.5    # Reactividad elástica de la masa
@export var weight_damping: float = 5.0             # Amortiguación del bamboleo pendular
@export var spine_curve_strength: float = 0.40      # Curvatura lateral de columna en virajes
@export var neck_lead_strength: float = 0.60        # Anticipación del cuello/cabeza hacia el viraje
@export var tail_lag_strength: float = 0.90         # Retraso/arrastre elástico de la cola
@export var wing_asymmetry_strength: float = 0.35   # Desnivel diedro entre ala interior y exterior

@export_group("Alineación del Modelo Visual (Cinemática Natural)")
# Espina dorsal, montura y cabeza perfectamente alineadas con el eje de vuelo -Z hacia el horizonte.
# El lomo/espalda mira al cielo (+Y) y el vientre/patas miran al suelo (-Y).
@export var model_pitch_offset: float = 0.0   # Ajuste fino sobre la calibración automática (grados)
@export var model_yaw_offset: float = 0.0     # Ajuste fino sobre la calibración automática (grados)
@export var model_roll_offset: float = 0.0    # Ajuste fino sobre la calibración automática (grados)
@export var model_pos_offset: Vector3 = Vector3.ZERO
@export var auto_calibrate_orientation: bool = true
@export var reverse_speed: float = 6.0         # Velocidad máxima de marcha atrás (S mantenido, m/s)

# Base de orientación calculada a partir de los huesos (nariz -> -Z, lomo -> +Y)
var calib_basis: Basis = Basis.from_euler(Vector3(0.0, deg_to_rad(-25.0), 0.0))

# --- Variables de Estado Interno ---
var locomotion_state: LocomotionState = LocomotionState.FLYING
var current_mode: FlightMode = FlightMode.NORMAL
var glide_mode_active: bool = false

var ground_blend: float = 0.0          # 0 = Vuelo, 1 = Tierra
var landing_blend: float = 0.0         # 1 = Flare / Aterrizaje
var wing_fold_blend: float = 0.0       # 1 = Alas plegadas
var walk_cycle_phase: float = 0.0      # Fase cíclica de las patas
var ground_normal: Vector3 = Vector3.UP

var current_speed: float = 25.0
var target_pitch: float = 0.0
var target_yaw: float = 0.0
var target_roll: float = 0.0

var is_diving: bool = false
var is_braking: bool = false
var is_flapping: bool = false
var w_boost: bool = false
var is_climbing: bool = false
var calibrating: bool = false
var wings_contracted: bool = false
var mouse_captured: bool = true
var ui_climb_active: bool = false
var ui_dive_active: bool = false

# Estado de despegue inicial (el dragón empieza tieso y despega majestuosamente)
var has_taken_off: bool = false
var takeoff_timer: float = 0.0

# Controles programáticos (para scripts, cinemáticas y tests)
var manual_input_override: bool = false
var manual_move_input: float = 0.0
var manual_turn_input: float = 0.0
var manual_sprint: bool = false
var manual_climb: bool = false
var manual_dive: bool = false

# Blends de transición cinemática para posturas suaves
var dive_fold_blend: float = 0.0
var climb_blend: float = 0.0
var brake_blend: float = 0.0
var glide_blend: float = 0.0

# Dinámica de bamboleo y transferencia de peso (Resorte de 2do orden)
var smoothed_turn_rate: float = 0.0
var sway_offset_x: float = 0.0
var sway_vel_x: float = 0.0
var sway_offset_y: float = 0.0
var sway_vel_y: float = 0.0

var tail_wave_time: float = 0.0

# Detección de suelo y efecto suelo aerodinámico
var ground_proximity: float = 999.0
var is_touching_ground: bool = false

# Estabilizador dinámico de orientación y anclaje (Jonathan Symmonds & Dragontwin)
var smoothed_anchor_offset: Vector3 = Vector3.ZERO
var stabilizer_initialized: bool = false

# Referencias a nodos
@onready var anim_player: AnimationPlayer = null
@onready var visual_root: Node3D = $VisualModel
var skeleton: Skeleton3D = null

# Índices de huesos
var bone_pelvis: int = -1
var bone_l_thigh: int = -1
var bone_r_thigh: int = -1
var bone_l_calf: int = -1
var bone_r_calf: int = -1
var bone_l_foot: int = -1
var bone_r_foot: int = -1

var bone_l_clavicle: int = -1
var bone_r_clavicle: int = -1
var bone_l_arm: int = -1
var bone_r_arm: int = -1
var bone_l_forearm: int = -1
var bone_r_forearm: int = -1

var bone_l_wing_root: int = -1
var bone_r_wing_root: int = -1
var bone_l_wing_mid: int = -1
var bone_r_wing_mid: int = -1

var bone_spine_indices: Array[int] = []
var bone_neck_indices: Array[int] = []
var bone_head_idx: int = -1
var bone_tail_indices: Array[int] = []

# Ejes locales precalculados respecto al padre para cada hueso
var bone_yaw_axes: Dictionary = {}
var bone_pitch_axes: Dictionary = {}
var bone_roll_axes: Dictionary = {}

func _ready() -> void:
	# Cursor libre por defecto: el dragón se maneja con el teclado (ESC activa el timón con mouse)
	mouse_captured = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if visual_root:
		visual_root.position = model_pos_offset
		visual_root.basis = _offset_basis() * calib_basis
	
	_find_and_setup_skeleton(self)
	_find_and_setup_anim_player(self)
	
	floor_snap_length = 0.8
	floor_max_angle = deg_to_rad(50.0)
	floor_stop_on_slope = true
	
	target_yaw = rotation.y
	target_pitch = rotation.x
	target_roll = rotation.z
	
	if auto_calibrate_orientation:
		_calibrate_model_orientation()

func _offset_basis() -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(model_pitch_offset), deg_to_rad(model_yaw_offset), deg_to_rad(model_roll_offset)))

# Calcula la base del modelo usando los huesos: nariz (cabeza respecto de la cola) -> -Z,
# lateral (muslo izq -> der) -> +X y lomo -> +Y. Independiente de la orientación horneada del rig.
func _calibrate_model_orientation() -> void:
	for i in range(3):
		await get_tree().process_frame
	if not skeleton or not visual_root or not anim_player or not anim_player.has_animation("Qishilong_fly2"):
		return
	var head = skeleton.find_bone("Bip001-Head_011")
	var tail = skeleton.find_bone("Bone008_0154")
	if head == -1 or tail == -1 or bone_l_thigh == -1 or bone_r_thigh == -1:
		push_warning("Calibración de orientación: faltan huesos de referencia")
		return
	
	# Se muestrea la pose REAL de vuelo (la pose de reposo del rig no coincide con la del clip de aleteo)
	# a lo largo del ciclo completo y se promedian los ejes del cuerpo.
	calibrating = true
	visual_root.visible = false
	anim_player.play("Qishilong_fly2")
	anim_player.pause()
	var sum_fwd := Vector3.ZERO
	var sum_right := Vector3.ZERO
	var samples := 8
	var cycle_len: float = anim_player.get_animation("Qishilong_fly2").length
	for s in range(samples):
		anim_player.seek(cycle_len * float(s) / float(samples), true)
		await get_tree().process_frame
		await get_tree().process_frame
		var to_pre: Basis = visual_root.global_transform.basis.inverse() * skeleton.global_transform.basis
		var p_head = skeleton.get_bone_global_pose(head).origin
		var p_tail = skeleton.get_bone_global_pose(tail).origin
		var p_l = skeleton.get_bone_global_pose(bone_l_thigh).origin
		var p_r = skeleton.get_bone_global_pose(bone_r_thigh).origin
		sum_fwd += (to_pre * (p_head - p_tail)).normalized()
		sum_right += (to_pre * (p_r - p_l)).normalized()
	anim_player.seek(0.0, true)
	anim_player.pause()
	visual_root.visible = true
	calibrating = false
	
	var fwd: Vector3 = sum_fwd.normalized()
	var right: Vector3 = sum_right.normalized()
	var up: Vector3 = right.cross(fwd).normalized()
	right = fwd.cross(up).normalized()
	calib_basis = Basis(right, up, -fwd).transposed()
	print("Orientación calibrada. forward=%s up=%s right=%s" % [fwd, up, right])

func _input(event: InputEvent) -> void:
	# ESC: alterna el timón con mouse (opcional). Por defecto está apagado.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		mouse_captured = !mouse_captured
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE)

	# Tecla G: alternar (toggle) Modo Planear
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		glide_mode_active = !glide_mode_active

	# Tecla L: Alternar Aterrizar / Despegar
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		toggle_land_takeoff()

	if not mouse_captured:
		return

	if event is InputEventMouseMotion:
		target_yaw -= event.relative.x * mouse_sensitivity
		target_pitch -= event.relative.y * mouse_sensitivity
		target_pitch = clamp(target_pitch, -deg_to_rad(80.0), deg_to_rad(80.0))

func _physics_process(delta: float) -> void:
	if calibrating:
		return
	# Manejo del despegue inicial ("empezaba tieso y luego despegaba")
	if not has_taken_off:
		takeoff_timer += delta
		var input_takeoff = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_UP)
		if input_takeoff or takeoff_timer >= 1.2:
			has_taken_off = true
			if anim_player and anim_player.has_animation("Qishilong_fly2"):
				anim_player.play("Qishilong_fly2", 0.5)
	
	_handle_input_keys(delta)
	_calculate_flight_physics(delta)
	_apply_smooth_rotations(delta)
	_update_animations()
	
	move_and_slide()
	_handle_terrain_collisions(delta)

# --- Entrada de Teclado y Control de Modos ---
func _handle_input_keys(delta: float) -> void:
	# Actualizar blends de locomoción
	ground_blend = move_toward(ground_blend, 1.0 if locomotion_state == LocomotionState.GROUNDED else 0.0, 4.5 * delta)
	landing_blend = move_toward(landing_blend, 1.0 if locomotion_state == LocomotionState.LANDING else 0.0, 4.5 * delta)
	wing_fold_blend = move_toward(wing_fold_blend, 1.0 if (locomotion_state == LocomotionState.GROUNDED or is_diving) else 0.0, 3.8 * delta)

	# --- MODO TERRESTRE (GROUNDED) ---
	if locomotion_state == LocomotionState.GROUNDED:
		# Despegue con ESPACIO
		if (Input.is_key_pressed(KEY_SPACE) and not manual_input_override) or (manual_input_override and manual_climb):
			trigger_takeoff()
			return

		# Movimiento: W = avanzar, S = retroceder
		var move_input := 0.0
		var turn_input := 0.0
		var is_sprint := false
		
		if manual_input_override:
			move_input = manual_move_input
			turn_input = manual_turn_input
			is_sprint = manual_sprint
		else:
			if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
				move_input += 1.0
			if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
				move_input -= 0.6
				
			is_sprint = Input.is_key_pressed(KEY_SHIFT)
			if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
				turn_input += 1.0
			if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
				turn_input -= 1.0
			
		var target_walk = (sprint_speed if is_sprint else walk_speed) * move_input
		current_speed = move_toward(current_speed, target_walk, (ground_accel if move_input != 0.0 else ground_friction) * delta)
		
		# Giro horizontal (Yaw) en tierra
		if turn_input != 0.0:
			target_yaw += turn_input * ground_turn_speed * delta
			
		is_flapping = false
		glide_mode_active = false
		is_diving = false
		is_braking = false
		is_climbing = false
		return

	# --- MODO ATERRIZAJE (LANDING) ---
	if locomotion_state == LocomotionState.LANDING:
		current_mode = FlightMode.BRAKE
		target_pitch = lerp(target_pitch, deg_to_rad(12.0), 3.5 * delta)
		is_flapping = false
		
		var turn_input := 0.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			turn_input += 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			turn_input -= 1.0
		if turn_input != 0.0:
			target_yaw += turn_input * yaw_speed * delta
			
		var yaw_diff_landing = wrapf(target_yaw - rotation.y, -PI, PI)
		smoothed_turn_rate = lerp(smoothed_turn_rate, clamp(yaw_diff_landing * 2.0, -0.6, 0.6), 6.0 * delta)
		target_roll = lerp_angle(target_roll, smoothed_turn_rate * bank_amount * 0.4, return_to_level_rate * delta)
		return

	# --- MODO DESPEGUE (TAKING_OFF) ---
	if locomotion_state == LocomotionState.TAKING_OFF:
		current_mode = FlightMode.CLIMB
		target_pitch = lerp(target_pitch, deg_to_rad(20.0), 4.0 * delta)
		is_flapping = true
		return

	# --- MODO VUELO LIBRE (FLYING) ---
	# 1. BOTÓN DE SUBIR (CLIMB / UP) - ESPACIO, R o Botón HUD
	is_climbing = Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_R) or ui_climb_active
	
	# 2. BOTÓN DE PICADA (DIVE / DOWN) - C, CTRL o Botón HUD
	is_diving = Input.is_key_pressed(KEY_C) or Input.is_key_pressed(KEY_CTRL) or ui_dive_active
	wings_contracted = is_diving
	
	# 3. FRENADO / MARCHA ATRÁS (BRAKE) - S (si no estamos en picada)
	is_braking = Input.is_key_pressed(KEY_S) and not is_diving
	
	# 4. ALETEO ACTIVO / AVANCE - W o SHIFT
	var w_pressed = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SHIFT)
	w_boost = w_pressed and not is_braking
	if w_pressed or is_climbing or is_diving:
		glide_mode_active = false
	
	# 4b. CABECEO FINO - FLECHAS ARRIBA / ABAJO
	var pitch_input: float = 0.0
	if Input.is_key_pressed(KEY_UP):
		pitch_input += 1.0
	if Input.is_key_pressed(KEY_DOWN):
		pitch_input -= 1.0
	if pitch_input != 0.0:
		target_pitch = clamp(target_pitch + pitch_input * pitch_speed * delta, -deg_to_rad(80.0), deg_to_rad(80.0))
	elif not mouse_captured and not (is_diving or is_braking or is_climbing):
		target_pitch = lerp(target_pitch, 0.0, 0.8 * delta)
		
	# 5. DETERMINAR MODO ACTIVO
	if is_diving:
		current_mode = FlightMode.DIVE
		target_pitch = lerp(target_pitch, -deg_to_rad(45.0), 3.5 * delta)
	elif is_braking:
		current_mode = FlightMode.BRAKE
		target_pitch = lerp(target_pitch, deg_to_rad(15.0), 4.0 * delta)
	elif is_climbing:
		current_mode = FlightMode.CLIMB
		target_pitch = lerp(target_pitch, deg_to_rad(26.0), 3.5 * delta)
	elif glide_mode_active:
		current_mode = FlightMode.GLIDE
	else:
		current_mode = FlightMode.NORMAL
		
	is_flapping = (current_mode == FlightMode.NORMAL or current_mode == FlightMode.CLIMB)
	
	# Blends cinemáticos de posturas
	dive_fold_blend = lerp(dive_fold_blend, 1.0 if current_mode == FlightMode.DIVE else 0.0, 5.5 * delta)
	climb_blend = lerp(climb_blend, 1.0 if current_mode == FlightMode.CLIMB else 0.0, 4.5 * delta)
	brake_blend = lerp(brake_blend, 1.0 if current_mode == FlightMode.BRAKE else 0.0, 6.0 * delta)
	glide_blend = lerp(glide_blend, 1.0 if current_mode == FlightMode.GLIDE else 0.0, 4.0 * delta)
	
	# 6. VIRAJE Y ALABEO COORDINADO
	var turn_dir: float = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		turn_dir += 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		turn_dir -= 1.0
		
	if Input.is_key_pressed(KEY_Q):
		turn_dir += 0.8
	if Input.is_key_pressed(KEY_E):
		turn_dir -= 0.8

	if turn_dir != 0.0:
		target_yaw += turn_dir * yaw_speed * 1.5 * delta
		
	var yaw_diff = wrapf(target_yaw - rotation.y, -PI, PI)
	var instant_turn_rate = clamp(yaw_diff * 3.5, -1.0, 1.0)
	smoothed_turn_rate = lerp(smoothed_turn_rate, instant_turn_rate, 8.0 * delta)
	
	var desired_bank = smoothed_turn_rate * bank_amount
	target_roll = lerp_angle(target_roll, desired_bank, return_to_level_rate * delta)

# --- Físicas Aerodinámicas y Comportamiento por Modos ---
func _calculate_flight_physics(delta: float) -> void:
	if not has_taken_off:
		velocity = Vector3.ZERO
		return

	# 1. FÍSICAS EN TIERRA (GROUNDED)
	if locomotion_state == LocomotionState.GROUNDED:
		var forward_flat = -transform.basis.z
		forward_flat.y = 0.0
		forward_flat = forward_flat.normalized()
		
		if is_on_floor():
			var floor_n = get_floor_normal()
			forward_flat = forward_flat.slide(floor_n).normalized()
			var local_n = global_transform.basis.inverse() * floor_n
			target_pitch = lerp_angle(target_pitch, -atan2(local_n.z, local_n.y), 6.0 * delta)
			target_roll = lerp_angle(target_roll, atan2(local_n.x, local_n.y), 6.0 * delta)
			velocity.y = forward_flat.y * current_speed - 2.0
		else:
			velocity.y -= gravity_magnitude * 2.2 * delta
			target_pitch = lerp_angle(target_pitch, 0.0, 4.0 * delta)
			target_roll = lerp_angle(target_roll, 0.0, 4.0 * delta)
			
		velocity.x = forward_flat.x * current_speed
		velocity.z = forward_flat.z * current_speed
		
		if abs(current_speed) > 0.1:
			walk_cycle_phase += current_speed * delta * 2.2
		else:
			walk_cycle_phase = lerp_angle(walk_cycle_phase, 0.0, 5.0 * delta)
		return

	# 2. FÍSICAS DE ATERRIZAJE (LANDING)
	if locomotion_state == LocomotionState.LANDING:
		current_speed = move_toward(current_speed, 4.5, air_brake_decel * 0.8 * delta)
		var fwd_dir = -transform.basis.z.normalized()
		velocity.x = fwd_dir.x * current_speed
		velocity.z = fwd_dir.z * current_speed
		
		var space_state = get_world_3d().direct_space_state
		var ground_ray = PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 250.0)
		ground_ray.exclude = [get_rid()]
		var ground_hit = space_state.intersect_ray(ground_ray)
		if ground_hit:
			ground_proximity = global_position.distance_to(ground_hit.position)
			# Descenso suave y flare gradual al aproximarse a tierra
			if ground_proximity < 14.0:
				velocity.y = move_toward(velocity.y, -3.2, 10.0 * delta)
			else:
				velocity.y = move_toward(velocity.y, -12.0, 6.0 * delta)
		else:
			ground_proximity = 999.0
			velocity.y = move_toward(velocity.y, -12.0, 6.0 * delta)
			
		if is_on_floor() or get_slide_collision_count() > 0 or (ground_proximity < 3.8 and velocity.y <= 0.0):
			locomotion_state = LocomotionState.GROUNDED
			current_speed = 0.0
			velocity = Vector3.ZERO
			target_pitch = 0.0
			target_roll = 0.0
			print("¡Aterrizaje completado con éxito! Bienvenido a tierra.")
		return

	# 3. FÍSICAS DE DESPEGUE (TAKING_OFF)
	if locomotion_state == LocomotionState.TAKING_OFF:
		takeoff_timer += delta
		velocity = Vector3.UP * jump_impulse + (-transform.basis.z * 10.0)
		if takeoff_timer >= 0.8 or (ground_proximity > 6.0 and takeoff_timer >= 0.35):
			locomotion_state = LocomotionState.FLYING
			current_mode = FlightMode.NORMAL
			current_speed = cruise_speed * 0.85
			print("¡Despegue completado! Transición a vuelo libre.")
		return

	# 4. FÍSICAS DE VUELO LIBRE (FLYING)
	var forward_dir: Vector3 = -transform.basis.z.normalized()
	var up_dir: Vector3 = transform.basis.y.normalized()
	
	var pitch_gravity_factor = -forward_dir.y * gravity_magnitude * 1.5
	var target_speed = cruise_speed
	var acceleration = 0.0
	var vertical_thrust = Vector3.ZERO
	
	match current_mode:
		FlightMode.DIVE:
			target_speed = dive_terminal_speed
			acceleration = flap_acceleration * 1.4 + pitch_gravity_factor
			current_speed = move_toward(current_speed, target_speed, acceleration * delta)
		FlightMode.CLIMB:
			target_speed = climb_forward_speed
			acceleration = flap_acceleration * 1.3
			current_speed = move_toward(current_speed, target_speed, acceleration * delta)
			vertical_thrust = Vector3.UP * (climb_vertical_rate * 1.8)
		FlightMode.GLIDE:
			target_speed = cruise_speed + pitch_gravity_factor * 1.5
			current_speed = move_toward(current_speed, target_speed, (normal_drag * 0.5) * delta)
		FlightMode.BRAKE:
			target_speed = -reverse_speed
			acceleration = air_brake_decel
			current_speed = move_toward(current_speed, target_speed, acceleration * delta)
		FlightMode.NORMAL:
			target_speed = cruise_speed + pitch_gravity_factor * 1.8
			if w_boost:
				target_speed = max_flap_speed + pitch_gravity_factor * 1.8
			acceleration = flap_acceleration + pitch_gravity_factor
			current_speed = move_toward(current_speed, target_speed, acceleration * delta)
		
	current_speed = clamp(current_speed, -reverse_speed, dive_terminal_speed)
	
	var lift_ratio = clamp(current_speed / cruise_speed, 0.0, 2.0)
	var lift_force = up_dir * (gravity_magnitude * lift_ratio)
	var gravity_force = Vector3.DOWN * gravity_magnitude
	
	var ground_cushion_lift = Vector3.ZERO
	var space_state = get_world_3d().direct_space_state
	var ground_ray = PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 20.0)
	ground_ray.exclude = [get_rid()]
	var ground_hit = space_state.intersect_ray(ground_ray)
	
	if ground_hit:
		ground_proximity = global_position.distance_to(ground_hit.position)
		if ground_proximity < 12.0:
			var cushion_factor = 1.0 - (ground_proximity / 12.0)
			ground_cushion_lift = Vector3.UP * (gravity_magnitude * 3.2 * cushion_factor)
			if ground_proximity < 6.0 and target_pitch < 0.0:
				target_pitch = lerp(target_pitch, deg_to_rad(6.0), 6.0 * delta)
	else:
		ground_proximity = 999.0
	
	var flight_velocity = forward_dir * current_speed
	var net_vertical_force = (lift_force + gravity_force) * (0.2 if is_diving else 1.0) + ground_cushion_lift + vertical_thrust
	velocity = flight_velocity + (net_vertical_force * delta * 5.0)

	var centrifugal_accel = -smoothed_turn_rate * (current_speed / cruise_speed) * weight_sway_strength * 3.0
	var spring_force_x = -weight_spring_stiffness * sway_offset_x - weight_damping * sway_vel_x + centrifugal_accel
	sway_vel_x += spring_force_x * delta
	sway_offset_x += sway_vel_x * delta
	sway_offset_x = clamp(sway_offset_x, -1.8, 1.8)

# --- Respuesta Físico-Colisional con el Terreno ---
func _handle_terrain_collisions(delta: float) -> void:
	is_touching_ground = is_on_floor() or get_slide_collision_count() > 0
	
	# En tierra respetamos el terreno mediante las colisiones físicas de move_and_slide()
	if locomotion_state == LocomotionState.GROUNDED:
		return
		
	if locomotion_state == LocomotionState.LANDING:
		if is_on_floor() or get_slide_collision_count() > 0:
			locomotion_state = LocomotionState.GROUNDED
			current_speed = 0.0
			velocity = Vector3.ZERO
		return
		
	# En vuelo: amortiguación y rebote
	var col_count = get_slide_collision_count()
	if col_count > 0:
		for i in range(col_count):
			var col = get_slide_collision(i)
			var n = col.get_normal()
			if n.y > 0.15:
				if velocity.dot(n) < 0.0:
					velocity = velocity.slide(n)
				target_pitch = max(target_pitch, deg_to_rad(6.0))
				current_speed = move_toward(current_speed, cruise_speed * 0.75, 30.0 * delta)
				if is_diving:
					is_diving = false
					wings_contracted = false
			else:
				if velocity.dot(n) < 0.0:
					velocity = velocity.slide(n)
				current_speed = move_toward(current_speed, min_stall_speed, 40.0 * delta)
				
	if global_position.y < 3.8:
		global_position.y = 3.8
		if velocity.y < 0.0:
			velocity.y = 0.0
		target_pitch = max(target_pitch, deg_to_rad(5.0))

# --- Suavizado de Rotaciones Globales ---
func _apply_smooth_rotations(delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, target_yaw, 10.0 * delta)
	rotation.x = lerp_angle(rotation.x, target_pitch, 8.0 * delta)
	rotation.z = lerp_angle(rotation.z, target_roll, 8.0 * delta)

# --- Animaciones Naturales del Artista Original (Qishilong_fly2) ---
func _find_and_setup_anim_player(node: Node) -> void:
	if node is AnimationPlayer:
		anim_player = node
		_configure_animations()
		return
	for child in node.get_children():
		_find_and_setup_anim_player(child)

# Rangos de animación extraídos de la cinemática original continua:
# Qishilong_fly2 contiene la auténtica secuencia de aleteo fluido y natural (de 33.6s a 36.6s, ciclo de 3.0s con 2 batidos completos y empalme slerp hermético)
const ANIM_SPECS = {
	"Qishilong_fly2": {"source": "Qishilong_fly2", "range": Vector2(33.600, 36.600)}, # Ciclo completo de vuelo natural original
	"Qishilong_up": {"source": "Qishilong_fly2", "range": Vector2(33.600, 36.600)},   # Vuelo activo
	"Qishilong_down": {"source": "Qishilong_down", "range": Vector2(26.067, 27.875)}  # Picada
}

func _configure_animations() -> void:
	if not anim_player:
		return
	var lib = anim_player.get_animation_library("")
	if not lib:
		return
		
	var source_anims = {}
	for anim_name in ANIM_SPECS:
		var src_name = ANIM_SPECS[anim_name]["source"]
		if not source_anims.has(src_name) and anim_player.has_animation(src_name):
			source_anims[src_name] = anim_player.get_animation(src_name)
			
	var rest_pelvis_pos = Vector3(32.7745, 356.433, 549.343)
	
	# Orientación de referencia de la pelvis: inicio del ciclo de vuelo de Qishilong_fly2
	var pelvis_ref_rot = null
	if source_anims.has("Qishilong_fly2"):
		var fly_anim: Animation = source_anims["Qishilong_fly2"]
		for t in range(fly_anim.get_track_count()):
			if "Bip001_03" in str(fly_anim.track_get_path(t)) and fly_anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				pelvis_ref_rot = fly_anim.rotation_track_interpolate(t, ANIM_SPECS["Qishilong_fly2"]["range"].x)
				break
	
	for anim_name in ANIM_SPECS:
		var spec = ANIM_SPECS[anim_name]
		var src_name = spec["source"]
		if not source_anims.has(src_name):
			continue
		var r = spec["range"]
		var src_anim = source_anims[src_name]
		var new_anim = Animation.new()
		var loop_len = r.y - r.x
		new_anim.length = loop_len
		new_anim.loop_mode = Animation.LOOP_LINEAR
		
		for t in range(src_anim.get_track_count()):
			var track_type = src_anim.track_get_type(t)
			var track_path = str(src_anim.track_get_path(t))
			var is_pelvis = "Bip001_03" in track_path
			
			var new_t = new_anim.add_track(track_type)
			new_anim.track_set_path(new_t, NodePath(track_path))
			new_anim.track_set_interpolation_type(new_t, Animation.INTERPOLATION_CUBIC)
			
			# En la posición de la pelvis: conservamos la posición central fija para que el dragón
			# no se aleje al infinito en coordenadas mundiales, mientras TODAS las demás 155 pistas
			# (alas, columna, cuello, cabeza, patas y cola) ejecutan la animación auténtica del artista.
			if is_pelvis and track_type == Animation.TYPE_POSITION_3D:
				new_anim.track_insert_key(new_t, 0.0, rest_pelvis_pos)
				new_anim.track_insert_key(new_t, loop_len, rest_pelvis_pos)
			else:
				var pelvis_fix = is_pelvis and track_type == Animation.TYPE_ROTATION_3D and pelvis_ref_rot != null
				var pelvis_base_inv: Quaternion = Quaternion.IDENTITY
				if pelvis_fix:
					pelvis_base_inv = (src_anim.rotation_track_interpolate(t, r.x) as Quaternion).inverse()
				
				var first_val = null
				var end_val = null
				if track_type == Animation.TYPE_ROTATION_3D:
					first_val = src_anim.rotation_track_interpolate(t, r.x)
					end_val = src_anim.rotation_track_interpolate(t, r.y)
					if pelvis_fix:
						first_val = ((first_val as Quaternion) * pelvis_base_inv) * (pelvis_ref_rot as Quaternion)
						end_val = ((end_val as Quaternion) * pelvis_base_inv) * (pelvis_ref_rot as Quaternion)
				elif track_type == Animation.TYPE_POSITION_3D:
					first_val = src_anim.position_track_interpolate(t, r.x)
					end_val = src_anim.position_track_interpolate(t, r.y)
				elif track_type == Animation.TYPE_SCALE_3D:
					first_val = src_anim.scale_track_interpolate(t, r.x)
					end_val = src_anim.scale_track_interpolate(t, r.y)
				
				# Cálculo de la deriva acumulada a lo largo de todo el ciclo
				var rot_delta: Quaternion = Quaternion.IDENTITY
				var pos_delta: Vector3 = Vector3.ZERO
				if track_type == Animation.TYPE_ROTATION_3D and first_val != null and end_val != null:
					rot_delta = (end_val as Quaternion).inverse() * (first_val as Quaternion)
				elif (track_type == Animation.TYPE_POSITION_3D or track_type == Animation.TYPE_SCALE_3D) and first_val != null and end_val != null:
					pos_delta = (first_val as Vector3) - (end_val as Vector3)
				
				# Clave inicial exacta en t=0.0
				if first_val != null:
					new_anim.track_insert_key(new_t, 0.0, first_val)
				
				for k in range(src_anim.track_get_key_count(t)):
					var kt = src_anim.track_get_key_time(t, k)
					if kt >= r.x - 0.005 and kt <= r.y + 0.005:
						var val = src_anim.track_get_key_value(t, k)
						if pelvis_fix:
							val = ((val as Quaternion) * pelvis_base_inv) * (pelvis_ref_rot as Quaternion)
						var new_t_pos = clamp(kt - r.x, 0.0, loop_len)
						var progress = new_t_pos / loop_len
						
						# Compensación progresiva y uniforme de la deriva a lo largo del ciclo entero:
						# Distribuye la corrección de forma homogénea e imperceptible a ritmo constante,
						# eliminando cualquier tirón, corrección repentina o giro brusco al terminar el 2º aleteo.
						if track_type == Animation.TYPE_ROTATION_3D:
							var corr = Quaternion.IDENTITY.slerp(rot_delta, progress)
							val = (val as Quaternion) * corr
						elif track_type == Animation.TYPE_POSITION_3D or track_type == Animation.TYPE_SCALE_3D:
							val = (val as Vector3) + pos_delta * progress
							
						new_anim.track_insert_key(new_t, new_t_pos, val)
				
				# Clave final idéntica en t=loop_len para garantizar continuidad de bucle al 100% (cero saltos)
				if first_val != null:
					new_anim.track_insert_key(new_t, loop_len, first_val)
					
		if lib.has_animation(anim_name):
			lib.remove_animation(anim_name)
		lib.add_animation(anim_name, new_anim)
		print("Animación natural original configurada: %s (duración: %.2fs)" % [anim_name, new_anim.length])

	# Si aún no ha despegado, empieza pausado en la pose estática inicial
	if not has_taken_off:
		anim_player.play("Qishilong_fly2")
		anim_player.pause()

func _update_animations() -> void:
	if not anim_player or not has_taken_off:
		return
		
	if locomotion_state == LocomotionState.GROUNDED:
		if anim_player.current_animation != "Qishilong_fly2" or not anim_player.is_playing():
			anim_player.play("Qishilong_fly2", 0.4)
		if abs(current_speed) > 0.2:
			anim_player.speed_scale = clamp(abs(current_speed) / walk_speed, 0.4, 1.2)
		else:
			anim_player.speed_scale = 0.25 # Reposo / respiración sutil
		return

	var target_anim = "Qishilong_fly2"
	var custom_speed = 1.0
	
	match current_mode:
		FlightMode.DIVE:
			if anim_player.has_animation("Qishilong_down"):
				target_anim = "Qishilong_down"
			custom_speed = 1.25
		FlightMode.CLIMB:
			target_anim = "Qishilong_fly2"
			custom_speed = 1.30
		FlightMode.GLIDE:
			target_anim = "Qishilong_fly2"
			custom_speed = 0.55  # Batir majestuoso espaciado
		FlightMode.BRAKE:
			target_anim = "Qishilong_fly2"
			custom_speed = 0.75
		FlightMode.NORMAL:
			target_anim = "Qishilong_fly2"
			custom_speed = 1.05
		
	if anim_player.current_animation != target_anim or not anim_player.is_playing():
		anim_player.play(target_anim, 0.35)
	anim_player.speed_scale = custom_speed

# --- Métodos de Control para Botones de Interfaz / HUD ---
func trigger_landing() -> void:
	if locomotion_state == LocomotionState.FLYING:
		has_taken_off = true
		locomotion_state = LocomotionState.LANDING
		current_mode = FlightMode.BRAKE
		print("Iniciando aproximación y flare de aterrizaje...")

func trigger_takeoff() -> void:
	if locomotion_state == LocomotionState.GROUNDED:
		has_taken_off = true
		locomotion_state = LocomotionState.TAKING_OFF
		takeoff_timer = 0.0
		velocity = Vector3.UP * jump_impulse + (-transform.basis.z * 8.0)
		target_pitch = deg_to_rad(18.0)
		if anim_player and anim_player.has_animation("Qishilong_fly2"):
			anim_player.play("Qishilong_fly2", 0.3)
		print("¡Despegando con impulso vertical!")

func toggle_land_takeoff() -> void:
	if locomotion_state == LocomotionState.GROUNDED:
		trigger_takeoff()
	elif locomotion_state == LocomotionState.FLYING:
		trigger_landing()
	elif locomotion_state == LocomotionState.LANDING:
		locomotion_state = LocomotionState.FLYING
		current_mode = FlightMode.NORMAL

func trigger_climb() -> void:
	has_taken_off = true
	glide_mode_active = false
	ui_dive_active = false
	ui_climb_active = !ui_climb_active
	if not ui_climb_active and not is_diving and not glide_mode_active:
		current_mode = FlightMode.NORMAL

func toggle_glide() -> void:
	has_taken_off = true
	ui_climb_active = false
	ui_dive_active = false
	glide_mode_active = !glide_mode_active
	if glide_mode_active:
		current_mode = FlightMode.GLIDE
	else:
		current_mode = FlightMode.NORMAL

func trigger_normal() -> void:
	has_taken_off = true
	glide_mode_active = false
	ui_climb_active = false
	ui_dive_active = false
	current_mode = FlightMode.NORMAL

func toggle_dive() -> void:
	has_taken_off = true
	glide_mode_active = false
	ui_climb_active = false
	ui_dive_active = !ui_dive_active
	if ui_dive_active:
		current_mode = FlightMode.DIVE
	else:
		current_mode = FlightMode.NORMAL

func walk_forward(sprint: bool = false) -> void:
	manual_input_override = true
	manual_move_input = 1.0
	manual_sprint = sprint

func walk_backward() -> void:
	manual_input_override = true
	manual_move_input = -0.6
	manual_sprint = false

func stop_walking() -> void:
	manual_move_input = 0.0
	manual_turn_input = 0.0
	manual_input_override = false

# --- Detección y Configuración de Huesos y SkeletonModifier3D ---
func _find_and_setup_skeleton(node: Node) -> void:
	if node is Skeleton3D:
		skeleton = node
		bone_pelvis = skeleton.find_bone("Bip001_03")
		bone_l_thigh = skeleton.find_bone("Bip001-L-Thigh_0115")
		bone_r_thigh = skeleton.find_bone("Bip001-R-Thigh_0130")
		bone_l_calf = skeleton.find_bone("Bip001-L-Calf_0116")
		bone_r_calf = skeleton.find_bone("Bip001-R-Calf_0131")
		bone_l_foot = skeleton.find_bone("Bip001-L-Foot_0118")
		bone_r_foot = skeleton.find_bone("Bip001-R-Foot_0133")
		
		bone_l_clavicle = skeleton.find_bone("Bip001-L-Clavicle_037")
		bone_r_clavicle = skeleton.find_bone("Bip001-R-Clavicle_052")
		bone_l_arm = skeleton.find_bone("Bip001-L-UpperArm_038")
		bone_r_arm = skeleton.find_bone("Bip001-R-UpperArm_053")
		bone_l_forearm = skeleton.find_bone("Bip001-L-Forearm_039")
		bone_r_forearm = skeleton.find_bone("Bip001-R-Forearm_054")
		
		bone_l_wing_root = skeleton.find_bone("Bone017(mirrored)_092")
		bone_r_wing_root = skeleton.find_bone("Bone017_068")
		bone_l_wing_mid = skeleton.find_bone("Bone018(mirrored)_096")
		bone_r_wing_mid = skeleton.find_bone("Bone018_069")
		
		bone_spine_indices.clear()
		for spine_name in ["Bip001-Spine_05", "Bip001-Spine1_06", "Bip001-Spine2_07"]:
			var b = skeleton.find_bone(spine_name)
			if b != -1:
				bone_spine_indices.append(b)
				_cache_bone_relative_axes(b)
				
		bone_neck_indices.clear()
		for neck_name in ["Bip001-Neck_08", "Bip001-Neck1_09", "Bip001-Neck2_010"]:
			var b = skeleton.find_bone(neck_name)
			if b != -1:
				bone_neck_indices.append(b)
				_cache_bone_relative_axes(b)
				
		bone_head_idx = skeleton.find_bone("Bip001-Head_011")
		if bone_head_idx != -1:
			_cache_bone_relative_axes(bone_head_idx)
			
		bone_tail_indices.clear()
		for i in range(1, 9):
			var tail_name = "Bone%03d_01%02d" % [i, 46 + i]
			var b = skeleton.find_bone(tail_name)
			if b != -1:
				bone_tail_indices.append(b)
				_cache_bone_relative_axes(b)
				
		for wing_bone in [bone_l_wing_root, bone_r_wing_root, bone_l_wing_mid, bone_r_wing_mid]:
			if wing_bone != -1:
				_cache_bone_relative_axes(wing_bone)
				
		for leg_bone in [bone_l_thigh, bone_r_thigh, bone_l_calf, bone_r_calf, bone_l_foot, bone_r_foot]:
			if leg_bone != -1:
				_cache_bone_relative_axes(leg_bone)
				
		# Conectar SkeletonModifier3D para cinemática procedural y locomoción terrestre
		var existing_mod: DragonSkeletonModifier = null
		for c in skeleton.get_children():
			if c is DragonSkeletonModifier:
				existing_mod = c
				break
		if not existing_mod:
			existing_mod = DragonSkeletonModifier.new()
			existing_mod.name = "DragonLocomotionModifier"
			skeleton.add_child(existing_mod)
		existing_mod.dragon = self
		existing_mod.active = true
		print("Skeleton3D y DragonSkeletonModifier configurados con éxito!")
		return
	for child in node.get_children():
		_find_and_setup_skeleton(child)

func _cache_bone_relative_axes(b_idx: int) -> void:
	if not skeleton or b_idx == -1 or not visual_root:
		return
	var vm_basis = visual_root.transform.basis
	var char_up_skel = (vm_basis.inverse() * Vector3.UP).normalized()
	var char_right_skel = (vm_basis.inverse() * Vector3.RIGHT).normalized()
	var char_fwd_skel = (vm_basis.inverse() * Vector3.FORWARD).normalized()
	
	var p_idx = skeleton.get_bone_parent(b_idx)
	var p_rot: Quaternion
	if p_idx != -1:
		p_rot = skeleton.get_bone_global_rest(p_idx).basis.get_rotation_quaternion()
	else:
		p_rot = Quaternion.IDENTITY
		
	bone_yaw_axes[b_idx] = (p_rot.inverse() * char_up_skel).normalized()
	bone_pitch_axes[b_idx] = (p_rot.inverse() * char_right_skel).normalized()
	bone_roll_axes[b_idx] = (p_rot.inverse() * char_fwd_skel).normalized()

# ==============================================================================
# POSTURA Y BAMBOLEO BIOMECÁNICO (Jonathan Symmonds & Dragontwin)
# ==============================================================================
func _process(delta: float) -> void:
	tail_wave_time += delta * (3.8 if is_flapping else 1.6)
	
	var heave: float = 0.0
	var pitch_surge: float = 0.0
	var flight_factor: float = clamp(1.0 - ground_blend, 0.0, 1.0)
	
	if anim_player and anim_player.is_playing() and has_taken_off:
		var pos = anim_player.current_animation_position
		var phase = (pos / 3.0) * TAU * 2.0 # Sincronizado con los 2 aleteos reales del ciclo
		var flap_intensity = 0.45 if current_mode == FlightMode.CLIMB else (0.30 if is_flapping else 0.10)
		heave = sin(phase) * flap_intensity * flight_factor
		pitch_surge = -cos(phase) * deg_to_rad(2.5 * flap_intensity) * flight_factor
		
	if visual_root:
		var lateral_sway = sway_offset_x * 0.30 * flight_factor
		var surge_basis = Basis.from_euler(Vector3(pitch_surge, 0.0, 0.0))
		visual_root.basis = surge_basis * _offset_basis() * calib_basis
		
		if skeleton and bone_pelvis != -1 and bone_head_idx != -1 and bone_tail_indices.size() > 0:
			# Estabilizador dinámico de orientación (Paso 2):
			# Se calcula el eje del cuerpo (cabeza a cola) y se contra-rota visual_root
			# para eliminar completamente la deriva del clip original, manteniendo el vuelo perfectamente recto.
			var p_h = skeleton.global_transform * skeleton.get_bone_global_pose(bone_head_idx).origin
			var p_t = skeleton.global_transform * skeleton.get_bone_global_pose(bone_tail_indices[bone_tail_indices.size() - 1]).origin
			var fwd_local = (global_transform.basis.inverse() * (p_h - p_t)).normalized()
			var raw_yaw_err = atan2(fwd_local.x, -fwd_local.z)
			
			visual_root.basis = Basis(Vector3.UP, raw_yaw_err) * visual_root.basis
			
			# En el clip de vuelo la raíz de la pelvis queda desplazada varios metros del cuerpo,
			# así que se centra el núcleo del cuerpo (columna + muslos) sobre el CharacterBody3D con suavizado low-pass.
			var anchor_world = _body_core_world()
			var y_offset = lerp(-0.3 + heave, -0.1, ground_blend)
			var target_center = global_position + Vector3(lateral_sway, y_offset, 0.0)
			var desired_offset = target_center - anchor_world
			if not stabilizer_initialized:
				smoothed_anchor_offset = desired_offset
				stabilizer_initialized = true
			else:
				smoothed_anchor_offset = smoothed_anchor_offset.lerp(desired_offset, 1.0 - exp(-15.0 * delta))
			visual_root.global_position += smoothed_anchor_offset
		elif skeleton and bone_pelvis != -1:
			var anchor_world = _body_core_world()
			var target_center = global_position + Vector3(lateral_sway, -0.3 + heave, 0.0)
			visual_root.global_position += (target_center - anchor_world)
		else:
			visual_root.position = model_pos_offset + Vector3(lateral_sway, heave, 0.0)

func _body_core_world() -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	var core_bones: Array[int] = [bone_l_thigh, bone_r_thigh]
	if bone_spine_indices.size() > 0:
		core_bones.append(bone_spine_indices[bone_spine_indices.size() - 1])
	for b in core_bones:
		if b != -1:
			sum += skeleton.global_transform * skeleton.get_bone_global_pose(b).origin
			n += 1
	if n == 0:
		return skeleton.global_transform * skeleton.get_bone_global_pose(bone_pelvis).origin
	return sum / float(n)

# Inyección de cinemática procedimental sobre la animación del artista
func _apply_biomechanical_posture_to_skeleton(sk: Skeleton3D) -> void:
	if not sk or not has_taken_off:
		return
		
	var turn = smoothed_turn_rate
	var flight_factor = clamp(1.0 - ground_blend, 0.0, 1.0)
	
	# 1. CUELLO Y CABEZA (Anticipación al viraje + erguido en tierra)
	var neck_yaw_weights = [0.10, 0.15, 0.20]
	var neck_pitch_offset = (climb_blend * 0.20) - (dive_fold_blend * 0.12) + (brake_blend * 0.30) + (ground_blend * 0.30)
	
	for i in range(bone_neck_indices.size()):
		var b = bone_neck_indices[i]
		if b != -1 and bone_yaw_axes.has(b):
			var yaw_rot = Quaternion(bone_yaw_axes[b], turn * neck_lead_strength * neck_yaw_weights[i] * (1.0 - ground_blend * 0.6))
			var pitch_rot = Quaternion(bone_pitch_axes[b], neck_pitch_offset * (0.25 + 0.25 * i))
			sk.set_bone_pose_rotation(b, yaw_rot * pitch_rot * sk.get_bone_pose_rotation(b))
			
	if bone_head_idx != -1 and bone_yaw_axes.has(bone_head_idx):
		var head_yaw = Quaternion(bone_yaw_axes[bone_head_idx], turn * neck_lead_strength * 0.32 * (1.0 - ground_blend * 0.6))
		var head_pitch = Quaternion(bone_pitch_axes[bone_head_idx], neck_pitch_offset * 0.30 - ground_blend * 0.15)
		var head_horizon_roll = Quaternion(bone_roll_axes[bone_head_idx], -target_roll * 0.40 * flight_factor)
		sk.set_bone_pose_rotation(bone_head_idx, head_yaw * head_pitch * head_horizon_roll * sk.get_bone_pose_rotation(bone_head_idx))

	# 2. COLUMNA DORSAL (Arco orgánico)
	var spine_weights = [0.06, 0.12, 0.16]
	for i in range(bone_spine_indices.size()):
		var b = bone_spine_indices[i]
		if b != -1 and bone_yaw_axes.has(b):
			var spine_yaw = Quaternion(bone_yaw_axes[b], turn * spine_curve_strength * spine_weights[i] * flight_factor)
			var spine_pitch = Quaternion(bone_pitch_axes[b], ((brake_blend * 0.12) - (climb_blend * 0.06)) * flight_factor)
			sk.set_bone_pose_rotation(b, spine_yaw * spine_pitch * sk.get_bone_pose_rotation(b))

	# 3. ALAS: ASIMETRÍA EN VIRAJES + PLEGADO EN PICADA Y EN TIERRA
	var fold = clamp(max(dive_fold_blend, wing_fold_blend), 0.0, 1.0)
	if bone_l_wing_root != -1 and bone_roll_axes.has(bone_l_wing_root):
		var l_roll_delta = (turn * wing_asymmetry_strength * 0.30) * (1.0 - fold)
		var l_pitch_dive = (-fold * 0.85) + (brake_blend * 0.25 * flight_factor)
		var l_yaw_fold = (fold * 0.55) + (turn * 0.10 * (1.0 - fold))
		var l_rot = Quaternion(bone_roll_axes[bone_l_wing_root], l_roll_delta) * \
					Quaternion(bone_pitch_axes[bone_l_wing_root], l_pitch_dive) * \
					Quaternion(bone_yaw_axes[bone_l_wing_root], l_yaw_fold)
		sk.set_bone_pose_rotation(bone_l_wing_root, l_rot * sk.get_bone_pose_rotation(bone_l_wing_root))

	if bone_r_wing_root != -1 and bone_roll_axes.has(bone_r_wing_root):
		var r_roll_delta = (turn * wing_asymmetry_strength * 0.30) * (1.0 - fold)
		var r_pitch_dive = (-fold * 0.85) + (brake_blend * 0.25 * flight_factor)
		var r_yaw_fold = (-fold * 0.55) + (turn * 0.10 * (1.0 - fold))
		var r_rot = Quaternion(bone_roll_axes[bone_r_wing_root], r_roll_delta) * \
					Quaternion(bone_pitch_axes[bone_r_wing_root], r_pitch_dive) * \
					Quaternion(bone_yaw_axes[bone_r_wing_root], r_yaw_fold)
		sk.set_bone_pose_rotation(bone_r_wing_root, r_rot * sk.get_bone_pose_rotation(bone_r_wing_root))

	if bone_l_wing_mid != -1 and bone_pitch_axes.has(bone_l_wing_mid):
		var mid_l = Quaternion(bone_pitch_axes[bone_l_wing_mid], -fold * 0.65)
		sk.set_bone_pose_rotation(bone_l_wing_mid, mid_l * sk.get_bone_pose_rotation(bone_l_wing_mid))

	if bone_r_wing_mid != -1 and bone_pitch_axes.has(bone_r_wing_mid):
		var mid_r = Quaternion(bone_pitch_axes[bone_r_wing_mid], -fold * 0.65)
		sk.set_bone_pose_rotation(bone_r_wing_mid, mid_r * sk.get_bone_pose_rotation(bone_r_wing_mid))

	# 4. COLA MULTIVERTEBRAL (8 Vértebras)
	for i in range(bone_tail_indices.size()):
		var b = bone_tail_indices[i]
		if b != -1 and bone_yaw_axes.has(b):
			var idx_ratio = float(i + 1) / float(bone_tail_indices.size())
			var tail_lag_yaw = -turn * (0.07 * (i + 1)) * tail_lag_strength * (1.0 - ground_blend * 0.5)
			var wave_amp = 0.045 * (i + 1) * (0.3 if fold > 0.5 else 1.0)
			var tail_wave_yaw = sin(tail_wave_time - (i * 0.50)) * wave_amp
			var tail_pitch = ((climb_blend * -0.15 * idx_ratio) + \
							 (brake_blend * -0.20 * idx_ratio) + \
							 (dive_fold_blend * 0.08 * idx_ratio)) * flight_factor + \
							 (ground_blend * -0.12 * idx_ratio)
			var t_rot = Quaternion(bone_yaw_axes[b], tail_lag_yaw + tail_wave_yaw) * \
						Quaternion(bone_pitch_axes[b], tail_pitch)
			sk.set_bone_pose_rotation(b, t_rot * sk.get_bone_pose_rotation(b))

	# 5. PATAS TRASERAS (Marcha y apoyo en tierra / Aerodinámica en vuelo)
	if ground_blend > 0.01:
		var speed_ratio = clamp(current_speed / walk_speed, -1.0, 1.5)
		var stride = sin(walk_cycle_phase) * speed_ratio
		var step_lift_l = max(0.0, cos(walk_cycle_phase)) * abs(speed_ratio)
		var step_lift_r = max(0.0, -cos(walk_cycle_phase)) * abs(speed_ratio)
		
		var l_thigh_pitch = (stride * deg_to_rad(30.0) + deg_to_rad(12.0)) * ground_blend
		var r_thigh_pitch = (-stride * deg_to_rad(30.0) + deg_to_rad(12.0)) * ground_blend
		
		var l_calf_pitch = (-step_lift_l * deg_to_rad(32.0) + deg_to_rad(16.0)) * ground_blend
		var r_calf_pitch = (-step_lift_r * deg_to_rad(32.0) + deg_to_rad(16.0)) * ground_blend
		
		var l_foot_pitch = (step_lift_l * deg_to_rad(22.0) - stride * deg_to_rad(14.0) - deg_to_rad(28.0)) * ground_blend
		var r_foot_pitch = (step_lift_r * deg_to_rad(22.0) + stride * deg_to_rad(14.0) - deg_to_rad(28.0)) * ground_blend
		
		if bone_l_thigh != -1 and bone_pitch_axes.has(bone_l_thigh):
			sk.set_bone_pose_rotation(bone_l_thigh, Quaternion(bone_pitch_axes[bone_l_thigh], l_thigh_pitch) * sk.get_bone_pose_rotation(bone_l_thigh))
		if bone_r_thigh != -1 and bone_pitch_axes.has(bone_r_thigh):
			sk.set_bone_pose_rotation(bone_r_thigh, Quaternion(bone_pitch_axes[bone_r_thigh], r_thigh_pitch) * sk.get_bone_pose_rotation(bone_r_thigh))
		if bone_l_calf != -1 and bone_pitch_axes.has(bone_l_calf):
			sk.set_bone_pose_rotation(bone_l_calf, Quaternion(bone_pitch_axes[bone_l_calf], l_calf_pitch) * sk.get_bone_pose_rotation(bone_l_calf))
		if bone_r_calf != -1 and bone_pitch_axes.has(bone_r_calf):
			sk.set_bone_pose_rotation(bone_r_calf, Quaternion(bone_pitch_axes[bone_r_calf], r_calf_pitch) * sk.get_bone_pose_rotation(bone_r_calf))
		if bone_l_foot != -1 and bone_pitch_axes.has(bone_l_foot):
			sk.set_bone_pose_rotation(bone_l_foot, Quaternion(bone_pitch_axes[bone_l_foot], l_foot_pitch) * sk.get_bone_pose_rotation(bone_l_foot))
		if bone_r_foot != -1 and bone_pitch_axes.has(bone_r_foot):
			sk.set_bone_pose_rotation(bone_r_foot, Quaternion(bone_pitch_axes[bone_r_foot], r_foot_pitch) * sk.get_bone_pose_rotation(bone_r_foot))
	else:
		var leg_pitch = (dive_fold_blend * -0.40) + (brake_blend * 0.50) + (climb_blend * -0.15)
		if bone_l_thigh != -1 and bone_pitch_axes.has(bone_l_thigh):
			sk.set_bone_pose_rotation(bone_l_thigh, Quaternion(bone_pitch_axes[bone_l_thigh], leg_pitch) * sk.get_bone_pose_rotation(bone_l_thigh))
		if bone_r_thigh != -1 and bone_pitch_axes.has(bone_r_thigh):
			sk.set_bone_pose_rotation(bone_r_thigh, Quaternion(bone_pitch_axes[bone_r_thigh], leg_pitch) * sk.get_bone_pose_rotation(bone_r_thigh))
