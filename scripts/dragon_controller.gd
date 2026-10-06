extends CharacterBody3D
class_name DragonController

# ==============================================================================
# SIMULADOR DE VUELO DE DRAGÓN - BIOMECÁNICA NATURAL (Jonathan Symmonds & Dragontwin)
# Vuelo original natural de Qishilong_fly2, despegue fluido y control total de maniobras
# ==============================================================================

const GroundPose = preload("res://scripts/dragon_ground_pose.gd")
var ground_pose = GroundPose.new()
var ground_guard_motion := Vector3.ZERO
var ground_executed_motion := Vector3.ZERO
var ground_yaw_motion := 0.0
var ground_guard_snap_delta := Vector3.ZERO
const HeadPose = preload("res://scripts/dragon_head_pose.gd")
var head_pose = HeadPose.new()
const PoseProbe = preload("res://scripts/dragon_pose_probe.gd")
var glide_pose_probe = PoseProbe.new()
const WingContact = preload("res://scripts/dragon_wing_contact.gd")
var wing_contact = WingContact.new()
var contact_fold_requested := 0.0
var has_head_pose_driver := true
var head_pose_blocked := false
var pose_turn_blocked := false
var head_aim_active := false
var attack_mode_active := false
var head_aim_direction := Vector3.FORWARD
var head_rendered_direction := Vector3.FORWARD
var head_aim_yaw := 0.0
var head_aim_pitch := 0.0
var head_requested_yaw := 0.0
var head_requested_pitch := 0.0

func set_head_aim(yaw: float, pitch: float) -> void:
	head_aim_active = true
	head_requested_yaw = clampf(yaw, -PI / 4.0, PI / 4.0)
	head_requested_pitch = clampf(pitch, -PI / 6.0, PI / 6.0)

func _update_head_aim(delta: float) -> void:
	if head_aim_active and not manual_input_override:
		var horizontal := float(Input.is_key_pressed(KEY_LEFT)) - float(Input.is_key_pressed(KEY_RIGHT))
		var vertical := float(Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_DOWN))
		set_head_aim(head_requested_yaw + horizontal * delta * 0.9, head_requested_pitch + vertical * delta * 0.9)
	var yaw := head_requested_yaw if head_aim_active else sin(tail_wave_time * 0.43) * deg_to_rad(2.2) + smoothed_turn_rate * 0.12
	var pitch := head_requested_pitch if head_aim_active else deg_to_rad(3.0) + sin(tail_wave_time * 0.68) * deg_to_rad(1.4)
	var response := 1.0 - exp(-9.0 * delta)
	var head_step := (Vector2(yaw, pitch) - Vector2(head_aim_yaw, head_aim_pitch)) * response
	head_step = head_step.limit_length(deg_to_rad(240.0) * delta)
	head_aim_yaw += head_step.x
	head_aim_pitch += head_step.y
	var world_wanted := (global_basis * Basis(Vector3.UP, head_aim_yaw) * Basis(Vector3.RIGHT, head_aim_pitch) * Vector3.FORWARD).normalized()
	var world_angle := head_aim_direction.angle_to(world_wanted)
	if world_angle < 0.01:
		head_aim_direction = world_wanted
	else:
		var axis := head_aim_direction.cross(world_wanted)
		if axis.length_squared() < 0.000001:
			axis = head_aim_direction.cross(Vector3.UP)
			if axis.length_squared() < 0.000001: axis = head_aim_direction.cross(Vector3.RIGHT)
		head_aim_direction = (Basis(axis.normalized(),minf(world_angle,deg_to_rad(240.0) * delta)) * head_aim_direction).normalized()


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
@export var ground_turn_speed: float = 0.7       # Tasa de giro horizontal en tierra (rad/s)
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
var body_clearance_lift := 0.0
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
var ground_motion_speed: float = 0.0
var manual_input_override: bool = false
var manual_move_input: float = 0.0
var manual_turn_input: float = 0.0
var manual_sprint: bool = false
var manual_climb: bool = false
var manual_dive: bool = false
var manual_brake: bool = false
var ground_contact: Dictionary = {}
var ground_air_timer: float = 0.0
var landing_target: Vector3 = Vector3.ZERO
var landing_target_active: bool = false
var landscape: Node = null
var shoreline_blocked: bool = false
var recovery_count: int = 0
var recovery_message: String = ""

# Blends de transición cinemática para posturas suaves
var dive_fold_blend: float = 0.0
var climb_blend: float = 0.0
var brake_blend: float = 0.0
var glide_blend: float = 0.0

# Dinámica de bamboleo y transferencia de peso (Resorte de 2do orden)
var smoothed_turn_rate: float = 0.0
var climb_roll_wobble: float = 0.0
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
	
	floor_snap_length = 1.2
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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		head_aim_active = not head_aim_active
		attack_mode_active = head_aim_active
		mouse_captured = head_aim_active
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if head_aim_active else Input.MOUSE_MODE_VISIBLE)
		return
	if event is InputEventMouseMotion and head_aim_active:
		var wanted_yaw:float=head_requested_yaw-event.relative.x*mouse_sensitivity
		var neck_yaw:float=clampf(wanted_yaw,-PI/4.0,PI/4.0)
		# One mouse controls aim and, beyond the neck's range, body orientation.
		# Ordinary head aiming retains its independent anatomical range.
		if attack_mode_active and not manual_input_override and locomotion_state in [LocomotionState.GROUNDED,LocomotionState.FLYING]:
			var overflow:=wanted_yaw-neck_yaw
			if not is_zero_approx(overflow):
				# Repeated aiming events must not queue several complete body turns
				# while the grounded animal is still stepping into the first one.
				target_yaw=rotation.y+overflow if locomotion_state==LocomotionState.GROUNDED else target_yaw+overflow
		set_head_aim(neck_yaw, head_requested_pitch - event.relative.y * mouse_sensitivity)
		return

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
	
	_check_world_boundary()
	_sample_ground()
	_handle_input_keys(delta)
	_update_mode_blends(delta)
	_calculate_flight_physics(delta)
	var rotation_before_pose := rotation
	_apply_smooth_rotations(delta)
	ground_pose.constrain_support_rotation(self,rotation_before_pose.y)
	var turn_started := Time.get_ticks_usec() if PoseProbe.profiling else 0
	wing_contact.constrain_rotation(self,rotation_before_pose)
	ground_yaw_motion=wrapf(rotation.y-rotation_before_pose.y,-PI,PI) if locomotion_state==LocomotionState.GROUNDED else 0.0
	PoseProbe.record("rotation_guard",turn_started)
	_update_head_aim(delta)
	var position_before_move := global_position
	var grounded_before_move := locomotion_state == LocomotionState.GROUNDED
	var constrain_started := Time.get_ticks_usec() if PoseProbe.profiling else 0
	ground_pose.constrain_support_motion(self,delta)
	wing_contact.constrain(self, delta)
	if ground_pose.constrain_support_motion(self,delta):
		# Support limits can shorten a projected wall slide; recast the actual final displacement.
		wing_contact.constrain(self,delta)
	PoseProbe.record("wing_constrain",constrain_started)
	ground_guard_motion = velocity*delta if grounded_before_move else Vector3.ZERO
	move_and_slide()
	ground_executed_motion = global_position-position_before_move if grounded_before_move else Vector3.ZERO
	ground_guard_snap_delta = ground_executed_motion-ground_guard_motion
	_handle_terrain_collisions(delta)
	if grounded_before_move and locomotion_state == LocomotionState.GROUNDED:
		var actual_motion := global_position - position_before_move
		var heading := -Basis(Vector3.UP, rotation.y).z
		ground_motion_speed = actual_motion.dot(heading) / maxf(delta, 0.0001)
		var distance_walked := Vector2(actual_motion.x, actual_motion.z).length()
		if (is_on_wall() or wing_contact.predictive_contact) and absf(ground_motion_speed) < 0.1:
			current_speed = 0.0
		if distance_walked > 0.001 or absf(ground_yaw_motion) > 0.0001:
			walk_cycle_phase += (distance_walked + absf(ground_yaw_motion) * 4.0) * TAU / 3.5
	_update_animations()

# --- Entrada de Teclado y Control de Modos ---
func _handle_input_keys(delta: float) -> void:
	# Actualizar blends de locomoción
	ground_blend = move_toward(ground_blend, 1.0 if locomotion_state == LocomotionState.GROUNDED else 0.0, 4.5 * delta)
	landing_blend = move_toward(landing_blend, 1.0 if locomotion_state == LocomotionState.LANDING else 0.0, 4.5 * delta)
	var safe_fold := 1.0 if locomotion_state == LocomotionState.GROUNDED or is_diving else 0.0
	if locomotion_state == LocomotionState.FLYING:
		safe_fold = maxf(safe_fold, clampf((26.0 - ground_proximity) / 14.0, 0.0, 1.0))
	if locomotion_state == LocomotionState.LANDING:
		safe_fold = clampf((42.0 - ground_proximity) / 25.0, 0.0, 1.0)
	if locomotion_state == LocomotionState.TAKING_OFF:
		safe_fold = clampf((20.0 - ground_proximity) / 14.0, 0.0, 1.0)
	safe_fold = maxf(safe_fold, contact_fold_requested)
	contact_fold_requested = move_toward(contact_fold_requested, 0.0, delta)
	wing_fold_blend = move_toward(wing_fold_blend, safe_fold, 2.5 * delta)

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
			if Input.is_key_pressed(KEY_W) or (Input.is_key_pressed(KEY_UP) and not head_aim_active):
				move_input += 1.0
			if Input.is_key_pressed(KEY_S) or (Input.is_key_pressed(KEY_DOWN) and not head_aim_active):
				move_input -= 0.6
				
			is_sprint = Input.is_key_pressed(KEY_SHIFT)
			if Input.is_key_pressed(KEY_A) or (Input.is_key_pressed(KEY_LEFT) and not head_aim_active):
				turn_input += 1.0
			if Input.is_key_pressed(KEY_D) or (Input.is_key_pressed(KEY_RIGHT) and not head_aim_active):
				turn_input -= 1.0
			
		var target_walk = (sprint_speed if is_sprint else walk_speed) * move_input
		# The landing stabilizer is still settling the four planted supports.
		# Retain the input, but begin walking acceleration after that pose settles.
		var settling_supports := ground_blend < 0.99
		if settling_supports: target_walk = 0.0
		shoreline_blocked = false
		if target_walk != 0.0 and is_instance_valid(landscape) and landscape.has_method("is_water_at"):
			var walk_direction := -Basis(Vector3.UP, rotation.y).z * signf(target_walk)
			var stopping_distance := current_speed * current_speed / (2.0 * ground_accel) + 3.2
			for step in range(1, ceili(stopping_distance) + 1):
				if landscape.is_water_at(global_position + walk_direction * float(step)):
					shoreline_blocked = true
					target_walk = 0.0
					break
		current_speed = move_toward(current_speed, target_walk, (ground_accel if move_input != 0.0 and not settling_supports else ground_friction) * delta)
		
		# Giro horizontal (Yaw) en tierra
		if turn_input != 0.0:
			target_yaw += turn_input * ground_turn_speed * delta
			
		current_mode = FlightMode.NORMAL
		smoothed_turn_rate = lerpf(smoothed_turn_rate, turn_input * 0.35, 1.0 - exp(-8.0 * delta))
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
		if Input.is_key_pressed(KEY_A) or (Input.is_key_pressed(KEY_LEFT) and not head_aim_active):
			turn_input += 1.0
		if Input.is_key_pressed(KEY_D) or (Input.is_key_pressed(KEY_RIGHT) and not head_aim_active):
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
	is_climbing = (Input.is_key_pressed(KEY_SPACE) and not manual_input_override) or Input.is_key_pressed(KEY_R) or ui_climb_active or (manual_input_override and manual_climb)
	
	# 2. BOTÓN DE PICADA (DIVE / DOWN) - C, CTRL o Botón HUD
	is_diving = Input.is_key_pressed(KEY_C) or Input.is_key_pressed(KEY_CTRL) or ui_dive_active or (manual_input_override and manual_dive)
	wings_contracted = is_diving
	
	# 3. FRENADO / MARCHA ATRÁS (BRAKE) - S (si no estamos en picada)
	is_braking = ((manual_brake if manual_input_override else Input.is_key_pressed(KEY_S))) and not is_diving
	
	# 4. ALETEO ACTIVO / AVANCE - W o SHIFT
	var w_pressed = (manual_move_input > 0.0 or manual_sprint) if manual_input_override else (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SHIFT))
	w_boost = w_pressed and not is_braking
	if w_pressed or is_climbing or is_diving:
		glide_mode_active = false
	
	# 4b. CABECEO FINO - FLECHAS ARRIBA / ABAJO
	var pitch_input: float = 0.0
	if (Input.is_key_pressed(KEY_UP) and not head_aim_active):
		pitch_input += 1.0
	if (Input.is_key_pressed(KEY_DOWN) and not head_aim_active):
		pitch_input -= 1.0
	if pitch_input != 0.0:
		target_pitch = clamp(target_pitch + pitch_input * pitch_speed * delta, -deg_to_rad(80.0), deg_to_rad(80.0))
	elif not mouse_captured and not (is_diving or is_braking or is_climbing):
		target_pitch = lerp(target_pitch, 0.0, 0.8 * delta)
		
	# 5. DETERMINAR MODO ACTIVO
	if is_diving:
		current_mode = FlightMode.DIVE
		target_pitch = lerp(target_pitch, -deg_to_rad(52.0), 3.8 * delta)
	elif is_braking:
		current_mode = FlightMode.BRAKE
		target_pitch = lerp(target_pitch, deg_to_rad(15.0), 4.0 * delta)
	elif is_climbing:
		current_mode = FlightMode.CLIMB
		target_pitch = lerp(target_pitch, deg_to_rad(42.0), 3.0 * delta)
	elif glide_mode_active:
		current_mode = FlightMode.GLIDE
	else:
		current_mode = FlightMode.NORMAL
		
	is_flapping = (current_mode == FlightMode.NORMAL or current_mode == FlightMode.CLIMB)
	
	# 6. VIRAJE Y ALABEO COORDINADO
	var turn_dir: float = 0.0
	if manual_input_override:
		turn_dir = manual_turn_input
	else:
		if Input.is_key_pressed(KEY_A) or (Input.is_key_pressed(KEY_LEFT) and not head_aim_active):
			turn_dir += 1.0
		if Input.is_key_pressed(KEY_D) or (Input.is_key_pressed(KEY_RIGHT) and not head_aim_active):
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

func _update_mode_blends(delta: float) -> void:
	var rate := 1.0 - exp(-5.0 * delta)
	dive_fold_blend = lerpf(dive_fold_blend, 1.0 if current_mode == FlightMode.DIVE and locomotion_state == LocomotionState.FLYING else 0.0, rate)
	climb_blend = lerpf(climb_blend, 1.0 if current_mode == FlightMode.CLIMB and locomotion_state != LocomotionState.GROUNDED else 0.0, rate)
	brake_blend = lerpf(brake_blend, 1.0 if current_mode == FlightMode.BRAKE and locomotion_state != LocomotionState.GROUNDED else 0.0, rate)
	glide_blend = lerpf(glide_blend, 1.0 if current_mode == FlightMode.GLIDE and locomotion_state == LocomotionState.FLYING else 0.0, rate)

func _sample_ground() -> void:
	if not is_instance_valid(landscape):
		landscape = get_tree().get_first_node_in_group("landscape")
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, global_position + Vector3.DOWN * 350.0, 1)
	ray.exclude = [get_rid()]
	ground_contact = get_world_3d().direct_space_state.intersect_ray(ray)
	ground_proximity = maxf(0.0, global_position.y - ground_contact.position.y) if ground_contact else 999.0
	if ground_contact:
		ground_normal = ground_contact.normal

func _over_water() -> bool:
	return is_instance_valid(landscape) and landscape.has_method("is_water_at") and landscape.is_water_at(global_position)

func _ground_is_walkable() -> bool:
	return not ground_contact.is_empty() and ground_contact.normal.dot(Vector3.UP) >= cos(floor_max_angle) and not _over_water()

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
		
		if is_on_floor() or (ground_proximity<6.0 and _ground_is_walkable()):
			# A volume guard may suppress one snap tick while the centre ray still
			# has a valid support surface. Do not level the torso into that slope.
			var floor_n = ground_normal if ground_proximity<6.0 and _ground_is_walkable() else get_floor_normal()
			forward_flat = forward_flat.slide(floor_n).normalized()
			var local_n = Basis(Vector3.UP, rotation.y).inverse() * floor_n
			target_pitch = lerp_angle(target_pitch, atan2(local_n.z, local_n.y), 6.0 * delta)
			target_roll = lerp_angle(target_roll, -atan2(local_n.x, local_n.y), 6.0 * delta)
			velocity.y = forward_flat.y * current_speed
		else:
			velocity.y -= gravity_magnitude * 2.2 * delta
			target_pitch = lerp_angle(target_pitch, 0.0, 4.0 * delta)
			target_roll = lerp_angle(target_roll, 0.0, 4.0 * delta)
			
		velocity.x = forward_flat.x * current_speed
		velocity.z = forward_flat.z * current_speed
		
		return

	# Approach speed and vertical velocity change continuously; a wall cannot end landing.
	if locomotion_state == LocomotionState.LANDING:
		var approaching_dry := false
		var approach_speed := 3.0 if ground_proximity < 14.0 else 12.0
		if landing_target_active:
			var to_target := landing_target - global_position
			to_target.y = 0.0
			approaching_dry = to_target.length() > 2.0 or _over_water()
			# Keep the selected landing patch until touchdown. Previously arriving
			# horizontally discarded it and carried the dragon onto the next slope.
			approach_speed = minf(approach_speed,to_target.length()*0.8)
			if to_target.length() > 0.5:
				target_yaw = atan2(-to_target.x, -to_target.z)
		current_speed = move_toward(current_speed,approach_speed,air_brake_decel*0.8*delta)
		var heading := -Basis(Vector3.UP, rotation.y).z
		var sink := -clampf((ground_proximity - 3.3) * 0.45, 1.4, 12.0) if _ground_is_walkable() else -4.0
		if approaching_dry:
			var approach_height:float=landing_target.y+22.0
			if not ground_contact.is_empty():approach_height=maxf(approach_height,ground_contact.position.y+22.0)
			sink = clampf((approach_height - global_position.y) * 0.45, -8.0, 8.0)
		var wanted := heading * current_speed + Vector3.UP * sink
		velocity = velocity.move_toward(wanted, 16.0 * delta)
		return

	if locomotion_state == LocomotionState.TAKING_OFF:
		takeoff_timer += delta
		var wanted := -Basis(Vector3.UP, rotation.y).z * climb_forward_speed + Vector3.UP * jump_impulse
		velocity = velocity.move_toward(wanted, 24.0 * delta)
		current_speed = Vector2(velocity.x, velocity.z).length()
		if takeoff_timer >= 0.85 and not is_on_floor():
			locomotion_state = LocomotionState.FLYING
			current_mode = FlightMode.NORMAL
		return

	# Acceleration-limited velocity preserves momentum through pitch and turns.
	var forward_dir := -transform.basis.z.normalized()
	var target_speed := cruise_speed
	var acceleration := flap_acceleration
	match current_mode:
		FlightMode.DIVE:
			target_speed = dive_terminal_speed
			acceleration = flap_acceleration + maxf(0.0, -forward_dir.y) * gravity_magnitude
		FlightMode.CLIMB:
			target_speed = climb_forward_speed
		FlightMode.GLIDE:
			target_speed = clampf(cruise_speed - forward_dir.y * 9.0, min_stall_speed, dive_terminal_speed)
			acceleration = 3.0
		FlightMode.BRAKE:
			target_speed = min_stall_speed
			acceleration = air_brake_decel
		FlightMode.NORMAL:
			target_speed = max_flap_speed if w_boost else cruise_speed
	current_speed = move_toward(current_speed, target_speed, acceleration * delta)
	current_speed = clampf(current_speed, min_stall_speed, dive_terminal_speed)
	var wanted_velocity := forward_dir * current_speed
	if current_mode == FlightMode.GLIDE:
		wanted_velocity.y -= 1.0
	if current_mode == FlightMode.CLIMB:
		# Thrust follows body pitch instead of adding a second full climb velocity.
		wanted_velocity.y = maxf(wanted_velocity.y, climb_vertical_rate * climb_blend)
	if ground_proximity < 10.0 and _ground_is_walkable():
		if velocity.y < -1.0:
			target_pitch = maxf(target_pitch, deg_to_rad(10.0))
			wanted_velocity.y = maxf(wanted_velocity.y, 3.0)
			if current_mode == FlightMode.DIVE:
				ui_dive_active = false
				is_diving = false
				current_mode = FlightMode.NORMAL
	velocity = velocity.move_toward(wanted_velocity, (28.0 if current_mode == FlightMode.DIVE else 22.0) * delta)

	var centrifugal_accel = -smoothed_turn_rate * (current_speed / cruise_speed) * weight_sway_strength * 3.0
	var spring_force_x = -weight_spring_stiffness * sway_offset_x - weight_damping * sway_vel_x + centrifugal_accel
	sway_vel_x += spring_force_x * delta
	sway_offset_x += sway_vel_x * delta
	sway_offset_x = clamp(sway_offset_x, -1.8, 1.8)

# --- Respuesta Físico-Colisional con el Terreno ---
func _handle_terrain_collisions(delta: float) -> void:
	is_touching_ground = is_on_floor()
	if locomotion_state == LocomotionState.GROUNDED:
		ground_air_timer = 0.0 if is_on_floor() else ground_air_timer + delta
		if ground_air_timer > 0.25 and ground_proximity > 6.0:
			locomotion_state = LocomotionState.FLYING
			ground_pose.reset()
		return
	var reached_landing_patch:bool=not landing_target_active or Vector2(global_position.x-landing_target.x,global_position.z-landing_target.z).length()<=2.0
	if locomotion_state == LocomotionState.LANDING and reached_landing_patch and is_on_floor() and get_floor_normal().dot(Vector3.UP) >= cos(floor_max_angle) and not _over_water() and ground_proximity < 5.0:
		locomotion_state = LocomotionState.GROUNDED
		current_mode = FlightMode.NORMAL
		current_speed = Vector2(velocity.x, velocity.z).length()
		target_pitch = 0.0
		target_roll = 0.0
		# Keep contacts calibrated during the landing approach.
		landing_target_active = false
		return
	for i in range(get_slide_collision_count()):
		var n := get_slide_collision(i).get_normal()
		velocity = velocity.slide(n)
		current_speed = move_toward(current_speed, min_stall_speed, 25.0 * delta)
		if n.y >= cos(floor_max_angle):
			target_pitch = maxf(target_pitch, deg_to_rad(12.0))

# --- Suavizado de Rotaciones Globales ---
func _apply_smooth_rotations(delta: float) -> void:
	var yaw_step:=wrapf(target_yaw-rotation.y,-PI,PI)*minf(1.0,10.0*delta)
	if locomotion_state==LocomotionState.GROUNDED:
		yaw_step=clampf(yaw_step,-ground_turn_speed*delta,ground_turn_speed*delta)
	rotation.y+=yaw_step
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

	# Configurar animación de planeo auténtica ("Qishilong_glide") con alas extendidas horizontalmente
	# extraída de la pose majestuosa de t=45.30s de Qishilong_fly2
	if source_anims.has("Qishilong_fly2"):
		var fly_anim: Animation = source_anims["Qishilong_fly2"]
		var glide_anim = Animation.new()
		glide_anim.length = 2.0
		glide_anim.loop_mode = Animation.LOOP_LINEAR
		var t_glide = 45.30
		
		for t in range(fly_anim.get_track_count()):
			var track_type = fly_anim.track_get_type(t)
			var track_path = str(fly_anim.track_get_path(t))
			var is_pelvis = "Bip001_03" in track_path
			
			var new_t = glide_anim.add_track(track_type)
			glide_anim.track_set_path(new_t, NodePath(track_path))
			glide_anim.track_set_interpolation_type(new_t, Animation.INTERPOLATION_CUBIC)
			
			if is_pelvis and track_type == Animation.TYPE_POSITION_3D:
				glide_anim.track_insert_key(new_t, 0.0, rest_pelvis_pos)
				glide_anim.track_insert_key(new_t, 2.0, rest_pelvis_pos)
			elif track_type == Animation.TYPE_ROTATION_3D:
				var rot = fly_anim.rotation_track_interpolate(t, t_glide)
				if is_pelvis and pelvis_ref_rot != null:
					var p_inv = (fly_anim.rotation_track_interpolate(t, t_glide) as Quaternion).inverse()
					rot = (rot * p_inv) * (pelvis_ref_rot as Quaternion)
				glide_anim.track_insert_key(new_t, 0.0, rot)
				glide_anim.track_insert_key(new_t, 2.0, rot)
			elif track_type == Animation.TYPE_POSITION_3D:
				var pos = fly_anim.position_track_interpolate(t, t_glide)
				glide_anim.track_insert_key(new_t, 0.0, pos)
				glide_anim.track_insert_key(new_t, 2.0, pos)
			elif track_type == Animation.TYPE_SCALE_3D:
				var scl = fly_anim.scale_track_interpolate(t, t_glide)
				glide_anim.track_insert_key(new_t, 0.0, scl)
				glide_anim.track_insert_key(new_t, 2.0, scl)
				
		if lib.has_animation("Qishilong_glide"):
			lib.remove_animation("Qishilong_glide")
		lib.add_animation("Qishilong_glide", glide_anim)
		print("Animación de planeo auténtico configurada: Qishilong_glide (alas extendidas)")

	# Si aún no ha despegado, empieza pausado en la pose estática inicial
	if not has_taken_off:
		anim_player.play("Qishilong_fly2")
		anim_player.pause()

func _update_animations() -> void:
	if not anim_player or not has_taken_off:
		return
		
	if locomotion_state == LocomotionState.GROUNDED:
		# Constant authored body pose is refreshed each frame, without a flight cycle on land.
		if anim_player.current_animation != "Qishilong_glide" or not anim_player.is_playing():
			anim_player.play("Qishilong_glide", 0.35)
		anim_player.speed_scale = 1.0
		return

	var target_anim = "Qishilong_fly2"
	var custom_speed = 1.0
	
	match current_mode:
		FlightMode.DIVE:
			if anim_player.has_animation("Qishilong_glide"):
				target_anim = "Qishilong_glide"
			else:
				target_anim = "Qishilong_fly2"
			custom_speed = 1.0
		FlightMode.CLIMB:
			target_anim = "Qishilong_fly2"
			custom_speed = 0.72 # Aleteo más lento y pesado: el esfuerzo contra el aire (ref. video climb)
		FlightMode.GLIDE:
			if anim_player.has_animation("Qishilong_glide"):
				target_anim = "Qishilong_glide"
			else:
				target_anim = "Qishilong_fly2"
			custom_speed = 1.0
		FlightMode.BRAKE:
			target_anim = "Qishilong_fly2"
			custom_speed = 0.70
		FlightMode.NORMAL:
			target_anim = "Qishilong_fly2"
			custom_speed = 1.05
		
	if anim_player.current_animation != target_anim or not anim_player.is_playing():
		anim_player.play(target_anim, 0.40)
	anim_player.speed_scale = custom_speed

# --- Métodos de Control para Botones de Interfaz / HUD ---
func trigger_landing() -> void:
	if locomotion_state == LocomotionState.FLYING:
		has_taken_off = true
		locomotion_state = LocomotionState.LANDING
		current_mode = FlightMode.BRAKE
		ui_climb_active = false
		ui_dive_active = false
		if is_instance_valid(landscape) and landscape.has_method("find_landing_site"):
			landing_target = landscape.find_landing_site(global_position)
			landing_target_active = true
		print("Iniciando aproximación y flare de aterrizaje...")

func trigger_takeoff() -> void:
	if locomotion_state == LocomotionState.GROUNDED:
		has_taken_off = true
		locomotion_state = LocomotionState.TAKING_OFF
		takeoff_timer = 0.0
		velocity.y = jump_impulse
		body_clearance_lift = 0.0
		ground_pose.reset()
		ui_climb_active = false
		ui_dive_active = false
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
		landing_target_active = false

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
	
	if anim_player and anim_player.is_playing() and has_taken_off and is_flapping:
		var pos = anim_player.current_animation_position
		var phase = (pos / 3.0) * TAU * 2.0 # Sincronizado con los 2 aleteos reales del ciclo
		var flap_intensity = 1.1 if current_mode == FlightMode.CLIMB else 0.28
		heave = sin(phase) * flap_intensity * flight_factor
		pitch_surge = -cos(phase) * deg_to_rad(7.0 if current_mode == FlightMode.CLIMB else 2.0) * flight_factor
		# Bamboleo de esfuerzo en trepada: el cuerpo se balancea de lado a lado (un ciclo por aleteo doble)
		climb_roll_wobble = sin(phase * 0.5 + 0.6) * deg_to_rad(5.0) * climb_blend * flight_factor
	else:
		climb_roll_wobble = lerp(climb_roll_wobble, 0.0, 0.1)
		
	if visual_root:
		var step_weight := clampf(absf(ground_motion_speed) / walk_speed, 0.0, 1.0)
		var lateral_sway = sway_offset_x * 0.30 * flight_factor + sin(walk_cycle_phase) * 0.045 * step_weight * ground_blend
		var surge_basis = Basis.from_euler(Vector3(pitch_surge, 0.0, climb_roll_wobble))
		visual_root.basis = surge_basis * _offset_basis() * calib_basis
		
		if skeleton and bone_pelvis != -1:
			# Centrar suavemente el núcleo del cuerpo sobre el CharacterBody3D sin interferir en los virajes
			var anchor_world = _body_core_world()
			var y_offset = lerp(-0.3 + heave, -0.65 + cos(walk_cycle_phase * 2.0) * 0.025 * step_weight, ground_blend)
			var target_center = global_position + Vector3(lateral_sway, y_offset+body_clearance_lift*ground_blend, 0.0)
			var desired_offset = target_center - anchor_world
			if not stabilizer_initialized:
				smoothed_anchor_offset = desired_offset
				stabilizer_initialized = true
			else:
				smoothed_anchor_offset = smoothed_anchor_offset.lerp(desired_offset, 1.0 - exp(-15.0 * delta))
			visual_root.global_position += smoothed_anchor_offset
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
	
	# 2. COLUMNA DORSAL (Arco orgánico continuo en virajes)
	var spine_weights = [0.08, 0.14, 0.18]
	for i in range(bone_spine_indices.size()):
		var b = bone_spine_indices[i]
		if b != -1 and bone_yaw_axes.has(b):
			var spine_yaw = Quaternion(bone_yaw_axes[b], turn * spine_curve_strength * spine_weights[i] * flight_factor)
			var spine_pitch = Quaternion(bone_pitch_axes[b], ((brake_blend * 0.12) - (climb_blend * 0.08)) * flight_factor)
			sk.set_bone_pose_rotation(b, spine_yaw * spine_pitch * sk.get_bone_pose_rotation(b))

	# 3. ALAS: ASIMETRÍA EN VIRAJES + PLANEO DIEDRO + PLEGADO EN PICADA + APERTURA EN TREPADA
	var fold = clamp(dive_fold_blend, 0.0, 1.0) * (1.0 - ground_blend)
	var glide_dihedral = glide_blend * deg_to_rad(4.5)
	var glide_breathe = sin(tail_wave_time * 1.8) * deg_to_rad(1.5) * glide_blend
	
	# Carrera de potencia en trepada (power downstroke amplitude + forward reach)
	var flap_anim_pos = anim_player.current_animation_position if (anim_player and anim_player.is_playing()) else 0.0
	var flap_cycle_phase = (flap_anim_pos / 3.0) * TAU * 2.0
	var climb_wing_forward = deg_to_rad(12.0) * climb_blend
	# Carrera de potencia amplia (bajada) y recuperación más corta (subida), con alas hacia adelante
	var climb_downstroke_boost = (max(0.0, sin(flap_cycle_phase)) * deg_to_rad(20.0) - max(0.0, -sin(flap_cycle_phase)) * deg_to_rad(8.0)) * climb_blend
	# Flexión del ala media en la subida (la punta se arrastra por la resistencia del aire)
	var climb_wing_flex = max(0.0, -sin(flap_cycle_phase)) * deg_to_rad(18.0) * climb_blend
	
	if bone_l_wing_root != -1 and bone_roll_axes.has(bone_l_wing_root):
		# Al virar a la izquierda (turn > 0): ala izquierda (interior) desciende (-turn)
		var l_roll_delta = (-turn * wing_asymmetry_strength * 0.35 + glide_dihedral + glide_breathe - climb_downstroke_boost) * (1.0 - fold)
		var l_pitch_dive = (-fold * 0.75) + (brake_blend * 0.25 * flight_factor) - (climb_wing_forward * (1.0 - fold))
		var l_yaw_fold = (fold * 0.50) + (turn * 0.12 * (1.0 - fold))
		var l_rot = Quaternion(bone_roll_axes[bone_l_wing_root], l_roll_delta) * \
					Quaternion(bone_pitch_axes[bone_l_wing_root], l_pitch_dive) * \
					Quaternion(bone_yaw_axes[bone_l_wing_root], l_yaw_fold)
		sk.set_bone_pose_rotation(bone_l_wing_root, l_rot * sk.get_bone_pose_rotation(bone_l_wing_root))

	if bone_r_wing_root != -1 and bone_roll_axes.has(bone_r_wing_root):
		# Ala derecha (exterior al virar a la izquierda): se eleva (+turn)
		var r_roll_delta = (turn * wing_asymmetry_strength * 0.35 - glide_dihedral - glide_breathe + climb_downstroke_boost) * (1.0 - fold)
		var r_pitch_dive = (-fold * 0.75) + (brake_blend * 0.25 * flight_factor) - (climb_wing_forward * (1.0 - fold))
		var r_yaw_fold = (-fold * 0.50) + (turn * 0.12 * (1.0 - fold))
		var r_rot = Quaternion(bone_roll_axes[bone_r_wing_root], r_roll_delta) * \
					Quaternion(bone_pitch_axes[bone_r_wing_root], r_pitch_dive) * \
					Quaternion(bone_yaw_axes[bone_r_wing_root], r_yaw_fold)
		sk.set_bone_pose_rotation(bone_r_wing_root, r_rot * sk.get_bone_pose_rotation(bone_r_wing_root))

	if bone_l_wing_mid != -1 and bone_pitch_axes.has(bone_l_wing_mid):
		var mid_l_pitch = -fold * 0.55 + (glide_breathe * 1.5) - climb_wing_flex
		var mid_l = Quaternion(bone_pitch_axes[bone_l_wing_mid], mid_l_pitch)
		sk.set_bone_pose_rotation(bone_l_wing_mid, mid_l * sk.get_bone_pose_rotation(bone_l_wing_mid))

	if bone_r_wing_mid != -1 and bone_pitch_axes.has(bone_r_wing_mid):
		var mid_r_pitch = -fold * 0.55 + (glide_breathe * 1.5) - climb_wing_flex
		var mid_r = Quaternion(bone_pitch_axes[bone_r_wing_mid], mid_r_pitch)
		sk.set_bone_pose_rotation(bone_r_wing_mid, mid_r * sk.get_bone_pose_rotation(bone_r_wing_mid))

	# The source's held frame is asymmetric. Level equivalent distal joints in body space,
	# rather than assuming mirrored imported quaternion axes have mirrored poses.
	if glide_blend > 0.01:
		var held_weight := glide_blend * (1.0 - wing_fold_blend)
		_aim_bone_direction(sk, 96, 108, global_basis * Vector3(-1.0, 0.075, 0.08), held_weight)
		_aim_bone_direction(sk, 120, 132, global_basis * Vector3(1.0, 0.075, 0.08), held_weight)

	if glide_blend > 0.95 and wing_fold_blend < 0.01:
		if glide_pose_probe.samples.is_empty():
			glide_pose_probe.configure(self, sk, 12)
			glide_pose_probe.samples = glide_pose_probe.samples.filter(func(sample): return sample.wing)
		for level_pass in 2:
			var left := Vector3.ZERO
			var right := Vector3.ZERO
			for point in glide_pose_probe.points(sk, true):
				var local: Vector3 = to_local(point.position)
				if local.x < left.x: left = local
				if local.x > right.x: right = local
			var center_y := (left.y + right.y) * 0.5
			_aim_bone_skin_point(sk, 96, to_global(left), to_global(Vector3(left.x,center_y,left.z)))
			_aim_bone_skin_point(sk, 120, to_global(right), to_global(Vector3(right.x,center_y,right.z)))

	# A folded wing doubles back at the elbow and long finger joints.
	# Directions are measured on the live rig, independent of imported bone axes.

	# 4. COLA MULTIVERTEBRAL (8 Vértebras con propagación de látigo fluido)
	for i in range(bone_tail_indices.size()):
		var b = bone_tail_indices[i]
		if b != -1 and bone_yaw_axes.has(b):
			var idx_ratio = float(i + 1) / float(bone_tail_indices.size())
			var tail_lag_yaw = -turn * (0.08 * (i + 1)) * tail_lag_strength * (1.0 - ground_blend * 0.5)
			var wave_amp = 0.040 * (i + 1) * (0.12 if fold > 0.5 else 1.0)
			var tail_wave_yaw = sin(tail_wave_time - (i * 0.45)) * wave_amp
			var tail_flap_lag = sin(flap_cycle_phase - (i + 1) * 0.5) * deg_to_rad(2.5) * (i + 1) * climb_blend * flight_factor
			var tail_pitch = ((climb_blend * -0.22 * idx_ratio) + \
							 (brake_blend * -0.20 * idx_ratio) + \
							 (dive_fold_blend * 0.05 * idx_ratio) + \
							 (glide_blend * 0.05 * idx_ratio)) * flight_factor + \
							 (ground_blend * -0.12 * idx_ratio)
			var t_rot = Quaternion(bone_yaw_axes[b], tail_lag_yaw + tail_wave_yaw) * \
						Quaternion(bone_pitch_axes[b], tail_pitch + tail_flap_lag)
			sk.set_bone_pose_rotation(b, t_rot * sk.get_bone_pose_rotation(b))

	# Recover parents before solving any descendant pose or stance contact.
	wing_contact.smooth_body_recovery(self,sk)
	var head_started := Time.get_ticks_usec() if PoseProbe.profiling else 0
	head_pose.apply(self, sk)
	PoseProbe.record("head_total",head_started)
	_refit_compact_wings(sk)
	# Rear knees/hocks prepare beneath the torso before ground IK takes over.
	# Authored brake frames lift the hind feet above the spine. Correct live FK
	# directions in body space; never change bind/pose translations or link lengths.
	var rear_preparation := maxf(brake_blend,landing_blend) if locomotion_state in [LocomotionState.FLYING,LocomotionState.LANDING] else 0.0
	var support_ik := locomotion_state == LocomotionState.GROUNDED or ground_blend > 0.01 or (locomotion_state == LocomotionState.LANDING and ground_proximity < 12.0)
	# Retain the authored airborne kick when it is not preparing a landing.
	if not support_ik and rear_preparation<=.01:
		var flap_leg_kick = sin((anim_player.current_animation_position / 3.0) * TAU * 2.0) * deg_to_rad(3.5) if (is_flapping and anim_player) else 0.0
		var leg_pitch = (dive_fold_blend * -0.45) + (climb_blend * -0.25) + (glide_blend * -0.10) + flap_leg_kick
		if bone_l_thigh != -1 and bone_pitch_axes.has(bone_l_thigh):
			sk.set_bone_pose_rotation(bone_l_thigh, Quaternion(bone_pitch_axes[bone_l_thigh], leg_pitch) * sk.get_bone_pose_rotation(bone_l_thigh))
		if bone_r_thigh != -1 and bone_pitch_axes.has(bone_r_thigh):
			sk.set_bone_pose_rotation(bone_r_thigh, Quaternion(bone_pitch_axes[bone_r_thigh], leg_pitch) * sk.get_bone_pose_rotation(bone_r_thigh))
	var rear_cache: Dictionary = get_meta("air_rear_joint_pose",{})
	var recovering: bool = get_meta("air_rear_prepared",false) and locomotion_state == LocomotionState.FLYING
	var current_tick := Engine.get_physics_frames()
	if rear_preparation>.01 or recovering:
		# Seed all orientations before changing any parent; sequential initialization
		# would add each parent's angular change to its child on the first frame.
		var authored := {}
		for b in [5,6,7,20,21,22,39,40,80,81]:
			var q := (global_basis.inverse()*sk.global_basis*sk.get_bone_global_pose(b).basis).get_rotation_quaternion()
			authored[b]=q
			if not rear_cache.has(b) or current_tick-int(rear_cache[b].tick)>6:
				rear_cache[b]={"rotation":q,"tick":current_tick-1}
		var needs_recovery := false
		for chain in [[5,6,7,8,-1.0],[20,21,22,23,1.0],[39,40,41,-1.0],[80,81,82,1.0]]:
			var fore:bool=chain.size()==4
			var side_sign:float=chain[-1]
			var directions:Array=[Vector3(side_sign*.08,-.85,.25),Vector3(side_sign*.04,-.85,-.35)] if fore else [Vector3(side_sign*.12,-.8,-.55),Vector3(side_sign*.05,-.7,.75),Vector3(0,-.9,-.35)]
			for joint in directions.size():
				var b: int = chain[joint]
				var old: Dictionary = rear_cache[b]
				var wanted: Quaternion = authored[b]
				if rear_preparation>.01:
					_aim_bone_direction(sk,b,chain[joint+1],global_basis*directions[joint],rear_preparation)
					wanted=(global_basis.inverse()*sk.global_basis*sk.get_bone_global_pose(b).basis).get_rotation_quaternion()
				var previous: Quaternion = old.rotation
				var maximum_angle := deg_to_rad(4.0)*clampf(current_tick-int(old.tick),0,2)
				var angle := previous.angle_to(wanted)
				needs_recovery=needs_recovery or angle>maximum_angle+.0001
				var published := previous.slerp(wanted,minf(1.0,maximum_angle/maxf(angle,.000001)))
				var parent := sk.get_bone_parent(b)
				var parent_q := sk.get_bone_global_pose(parent).basis.get_rotation_quaternion()
				var sk_q := (sk.global_basis.inverse()*global_basis*Basis(published)).get_rotation_quaternion()
				sk.set_bone_pose_rotation(b,parent_q.inverse()*sk_q)
		set_meta("air_rear_prepared",rear_preparation>.01 or needs_recovery)
	# Ground IK has precedence. Keep the published result as the next air anchor,
	# including its transition blend, instead of caching a pose that IK overwrites.
	if support_ik:
		var ground_started := Time.get_ticks_usec() if PoseProbe.profiling else 0
		ground_pose.apply(self, sk)
		PoseProbe.record("ground_total",ground_started)
	if locomotion_state == LocomotionState.GROUNDED:
		set_meta("air_rear_joint_pose",{})
		set_meta("air_rear_prepared",false)
	else:
		for b in [5,6,7,20,21,22,39,40,80,81]:
			rear_cache[b]={"rotation":(global_basis.inverse()*sk.global_basis*sk.get_bone_global_pose(b).basis).get_rotation_quaternion(),"tick":current_tick}
		set_meta("air_rear_joint_pose",rear_cache)

	var sample_started := Time.get_ticks_usec() if PoseProbe.profiling else 0
	wing_contact.sample_final(self, sk)
	wing_contact.guard_body_pose(self,sk)
	PoseProbe.record("wing_total",sample_started)

func _refit_compact_wings(sk: Skeleton3D) -> void:
	var compact_blend := maxf(wing_fold_blend,dive_fold_blend)
	if compact_blend<=0.01: return
	var narrow := wing_fold_blend if locomotion_state in [LocomotionState.LANDING,LocomotionState.GROUNDED] else ground_blend
	# Digital flexors gather the membrane before the elbow and shoulder tuck;
	# opening follows the reverse order. The same original final pose is kept.
	var digit_fold:float=smoothstep(0.0,.65,compact_blend)
	var elbow_fold:float=smoothstep(.08,.82,compact_blend)
	var shoulder_fold:float=smoothstep(.18,.95,compact_blend)
	for side in [[96,97,104,108,98,102,111,115,-1.0],[120,121,128,132,122,126,135,139,1.0]]:
		var sign_side: float = side[8]
		_aim_bone_direction(sk,side[0],side[1],global_basis*Vector3(sign_side*lerpf(1.0,.12,narrow),1.0,2.2),shoulder_fold)
		_aim_bone_direction(sk,side[1],side[2],global_basis*Vector3(sign_side*lerpf(.7,.0,narrow),.4,3.6),elbow_fold)
		_aim_bone_direction(sk,side[2],side[3],global_basis*Vector3(sign_side*lerpf(.1,.0,narrow),.7,-5.5),digit_fold)
		_aim_bone_direction(sk,side[4],side[5],global_basis*Vector3(sign_side*lerpf(.2,.0,narrow),.6,-5.0),digit_fold)
		_aim_bone_direction(sk,side[6],side[7],global_basis*Vector3(sign_side*lerpf(.2,.0,narrow),.8,-4.8),digit_fold)

func _aim_bone_skin_point(sk: Skeleton3D, bone: int, current_world: Vector3, desired_world: Vector3) -> void:
	var pose := sk.get_bone_global_pose(bone)
	var current := sk.to_local(current_world) - pose.origin
	var desired := sk.to_local(desired_world) - pose.origin
	var correction := Quaternion(current.normalized(), desired.normalized())
	var parent := sk.get_bone_parent(bone)
	var parent_q := sk.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	sk.set_bone_pose_rotation(bone, parent_q.inverse() * correction * pose.basis.get_rotation_quaternion())

func _rotate_bone_world(sk: Skeleton3D, bone: int, axis: Vector3, angle: float) -> void:
	if bone < 0:
		return
	var parent := sk.get_bone_parent(bone)
	var parent_basis := sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var axis_local := (parent_basis.inverse() * sk.global_basis.inverse() * axis).normalized()
	sk.set_bone_pose_rotation(bone, Quaternion(axis_local, angle) * sk.get_bone_pose_rotation(bone))

func _aim_bone_direction(sk: Skeleton3D, bone: int, tip: int, wanted_world_direction: Vector3, weight: float) -> void:
	var pose := sk.get_bone_global_pose(bone)
	var actual := sk.get_bone_global_pose(tip).origin - pose.origin
	var desired := sk.global_basis.inverse() * wanted_world_direction
	var correction := Quaternion(actual.normalized(), desired.normalized())
	correction = Quaternion.IDENTITY.slerp(correction, weight)
	var parent := sk.get_bone_parent(bone)
	var parent_q := sk.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	sk.set_bone_pose_rotation(bone, parent_q.inverse() * correction * pose.basis.get_rotation_quaternion())

func _check_world_boundary() -> void:
	var extent := maxf(absf(global_position.x), absf(global_position.z))
	if extent > 1320.0 and locomotion_state != LocomotionState.GROUNDED:
		var inward := -Vector2(global_position.x, global_position.z).normalized()
		target_yaw = atan2(-inward.x, -inward.y)
		if locomotion_state == LocomotionState.LANDING:
			locomotion_state = LocomotionState.FLYING
			ui_climb_active = true
	if extent > 1650.0 or global_position.y < -90.0:
		global_position = Vector3(180.0, 160.0, 120.0)
		velocity = Vector3.ZERO
		locomotion_state = LocomotionState.FLYING
		current_mode = FlightMode.NORMAL
		current_speed = cruise_speed
		ui_climb_active = false
		ui_dive_active = false
		target_pitch = 0.0
		target_roll = 0.0
		ground_pose.reset()
		recovery_count += 1
		recovery_message = "Regreso al valle: límite del mundo alcanzado"
