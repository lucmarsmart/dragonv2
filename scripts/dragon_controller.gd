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
const CollisionEffects = preload("res://scripts/collision_effects.gd")
var contact_fold_requested := 0.0
var has_head_pose_driver := true
var head_pose_blocked := false
var pose_turn_blocked := false
var pose_rollback_tick := -100
var blocked_gait_time := 0.0
var head_aim_active := false
var attack_mode_active := false
var head_aim_direction := Vector3.FORWARD
var head_rendered_direction := Vector3.FORWARD
var head_aim_yaw := 0.0
var head_aim_pitch := 0.0
var head_requested_yaw := 0.0
var head_requested_pitch := 0.0

# --- Sistema de Fijación de Objetivo (Inspirado en Pokémon Leyendas: Arceus) ---
var locked_target: CharacterBody3D = null
var lock_on_enabled: bool = true
var target_occlusion_timer: float = 0.0
var lock_on_distance: float = 0.0
var lock_sound_player: AudioStreamPlayer = null
var breath: Node = null

# --- Audio del Dragón ---
var _prev_flap_downstroke: float = 0.0
var _prev_step_phase: float = 0.0
var _last_roar_time: float = -10.0

func roar(situation: String = "") -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_roar_time < 1.8:
		return
	_last_roar_time = now
	var sit := situation
	if sit == "":
		if locomotion_state == LocomotionState.GROUNDED:
			sit = "ground"
		elif current_mode == FlightMode.DIVE or current_speed > 28.0:
			sit = "dive"
		elif current_mode == FlightMode.CLIMB:
			sit = "climb"
		else:
			sit = "general"
	GameAudio.play_roar(global_position, sit)


func get_locked_target() -> CharacterBody3D:
	return locked_target if (is_instance_valid(locked_target) and not locked_target.dead and locked_target.is_inside_tree()) else null

func _get_target_aim_point(enemy: Node3D) -> Vector3:
	if not is_instance_valid(enemy):
		return Vector3.ZERO
	var kind: String = enemy.kind if "kind" in enemy else ""
	var k_scale: float = enemy.knight_scale if "knight_scale" in enemy else 1.0
	var y_offset: float = 1.8 if kind == "turret" else (0.95 * k_scale)
	return enemy.global_position + Vector3.UP * y_offset

func _play_lock_cue() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not lock_sound_player:
		lock_sound_player = AudioStreamPlayer.new()
		lock_sound_player.name = "LockOnSound"
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		stream.stereo = false
		var sample_count := 2600
		var pcm := PackedByteArray()
		pcm.resize(sample_count * 2)
		for i in sample_count:
			var t := float(i) / 22050.0
			var freq := 920.0 if t < 0.05 else 1380.0
			var env := exp(-t * 26.0) * (1.0 if t < 0.05 else exp(-(t - 0.05) * 36.0))
			var sample := int(sin(t * TAU * freq) * env * 12000.0)
			pcm.encode_s16(i * 2, sample)
		stream.data = pcm
		lock_sound_player.stream = stream
		lock_sound_player.volume_db = -10.0
		add_child(lock_sound_player)
	if lock_sound_player and not lock_sound_player.playing:
		lock_sound_player.play()

func cycle_locked_target() -> void:
	var enemies := get_tree().get_nodes_in_group("siege_enemy")
	var valid_enemies: Array[CharacterBody3D] = []
	var mouth_pos: Vector3 = breath.mouth_position if is_instance_valid(breath) and breath.mouth_pose_cached else global_position + Vector3.UP * 1.5
	for node in enemies:
		var e := node as CharacterBody3D
		if is_instance_valid(e) and not e.dead and e.is_inside_tree() and mouth_pos.distance_to(_get_target_aim_point(e)) < 65.0:
			valid_enemies.append(e)
	if valid_enemies.size() <= 1:
		return
	var current_idx := valid_enemies.find(locked_target)
	var next_idx := (current_idx + 1) % valid_enemies.size()
	locked_target = valid_enemies[next_idx]
	target_occlusion_timer = 0.0
	_play_lock_cue()

func _update_target_lock(delta: float) -> void:
	if not lock_on_enabled:
		locked_target = null
		return
	
	var combat_node: Node = get_tree().get_first_node_in_group("siege_combat")
	var combat_active: bool = is_instance_valid(combat_node) and combat_node.has_method("is_running") and combat_node.is_running()
	var breath_firing: bool = is_instance_valid(breath) and breath.is_firing
	var should_lock: bool = combat_active or attack_mode_active or head_aim_active or breath_firing
	
	if not should_lock:
		locked_target = null
		return
	
	var mouth_pos: Vector3 = breath.mouth_position if is_instance_valid(breath) and breath.mouth_pose_cached else global_position + Vector3.UP * 1.5
	var fwd: Vector3 = -global_basis.z.normalized()
	var airborne: bool = locomotion_state != LocomotionState.GROUNDED
	var max_keep_dist: float = 115.0 if airborne else 68.0
	var max_acquire_dist: float = 95.0 if airborne else 54.0
	var max_acquire_angle: float = deg_to_rad(82.0 if airborne else 75.0)
	
	# 1. Validar objetivo actual
	if is_instance_valid(locked_target):
		if locked_target.dead or not locked_target.is_inside_tree():
			locked_target = null
		else:
			var target_pos := _get_target_aim_point(locked_target)
			var dist := mouth_pos.distance_to(target_pos)
			var to_target := (target_pos - mouth_pos).normalized()
			var angle := fwd.angle_to(to_target)
			
			# Romper fijación si se aleja demasiado (hasta que este se aleja) o queda atrás
			if dist > max_keep_dist or angle > deg_to_rad(105.0):
				locked_target = null
			else:
				var space := get_world_3d().direct_space_state
				var ray := PhysicsRayQueryParameters3D.create(mouth_pos, target_pos, 3)
				ray.exclude = [get_rid(), locked_target.get_rid()]
				var hit := space.intersect_ray(ray)
				if not hit.is_empty():
					target_occlusion_timer += delta
					if target_occlusion_timer > 0.8:
						locked_target = null
				else:
					target_occlusion_timer = 0.0
	
	# 2. Buscar nuevo objetivo si no hay ninguno fijado
	if not is_instance_valid(locked_target):
		var enemies := get_tree().get_nodes_in_group("siege_enemy")
		var best_enemy: CharacterBody3D = null
		var best_score := INF
		var space := get_world_3d().direct_space_state
		
		for node in enemies:
			var enemy := node as CharacterBody3D
			if not is_instance_valid(enemy) or enemy.dead or not enemy.is_inside_tree():
				continue
			var target_pos := _get_target_aim_point(enemy)
			var dist := mouth_pos.distance_to(target_pos)
			if dist > max_acquire_dist:
				continue
			var to_target := (target_pos - mouth_pos).normalized()
			var angle := fwd.angle_to(to_target)
			if angle > max_acquire_angle:
				continue
			
			var ray := PhysicsRayQueryParameters3D.create(mouth_pos, target_pos, 3)
			ray.exclude = [get_rid(), enemy.get_rid()]
			var hit := space.intersect_ray(ray)
			if not hit.is_empty():
				continue
			
			var score := dist + (angle / max_acquire_angle) * 16.0
			if score < best_score:
				best_score = score
				best_enemy = enemy
		
		if best_enemy != null:
			locked_target = best_enemy
			target_occlusion_timer = 0.0
			_play_lock_cue()
	
	if is_instance_valid(locked_target):
		lock_on_distance = mouth_pos.distance_to(_get_target_aim_point(locked_target))
	else:
		lock_on_distance = 0.0

func set_head_aim(yaw: float, pitch: float) -> void:
	head_aim_active = true
	head_requested_yaw = clampf(yaw, -deg_to_rad(54.0), deg_to_rad(54.0))
	head_requested_pitch = clampf(pitch, -deg_to_rad(45.0), deg_to_rad(35.0))

func _update_head_aim(delta: float) -> void:
	_update_target_lock(delta)
	
	if head_aim_active:
		if not manual_input_override:
			var horizontal := float(Input.is_key_pressed(KEY_LEFT)) - float(Input.is_key_pressed(KEY_RIGHT))
			var vertical := float(Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_DOWN))
			if horizontal != 0.0 or vertical != 0.0:
				set_head_aim(head_requested_yaw + horizontal * delta * 0.9, head_requested_pitch + vertical * delta * 0.9)
	elif is_instance_valid(locked_target) and not locked_target.dead:
		var mouth_pos: Vector3 = breath.mouth_position if is_instance_valid(breath) and breath.mouth_pose_cached else global_position + Vector3.UP * 1.5
		var target_pos := _get_target_aim_point(locked_target)
		var dir_to_target := (target_pos - mouth_pos).normalized()
		var local: Vector3 = global_basis.inverse() * dir_to_target
		var desired_yaw := atan2(-local.x, -local.z)
		var desired_pitch := asin(clampf(local.y, -1.0, 1.0))
		
		var max_yaw_limit := deg_to_rad(56.0) if locomotion_state != LocomotionState.GROUNDED else (PI / 4.0)
		var min_pitch_limit := -deg_to_rad(52.0) if locomotion_state != LocomotionState.GROUNDED else (-PI / 6.0)
		var max_pitch_limit := deg_to_rad(38.0) if locomotion_state != LocomotionState.GROUNDED else (PI / 6.0)
		var neck_yaw := clampf(desired_yaw, -max_yaw_limit, max_yaw_limit)
		var neck_pitch := clampf(desired_pitch, min_pitch_limit, max_pitch_limit)
		
		head_requested_yaw = lerp_angle(head_requested_yaw, neck_yaw, 1.0 - exp(-18.0 * delta))
		head_requested_pitch = lerpf(head_requested_pitch, neck_pitch, 1.0 - exp(-18.0 * delta))
		
		var firing_now: bool = is_instance_valid(breath) and breath.is_firing
		if not manual_input_override:
			# Guía continua de rumbo (Yaw) hacia el objetivo fijado para encararlo naturalmente
			var assist_rate := 3.5 if firing_now else 2.2
			if locomotion_state == LocomotionState.GROUNDED:
				target_yaw = rotation.y + desired_yaw * delta * assist_rate
			elif locomotion_state == LocomotionState.FLYING:
				target_yaw += desired_yaw * delta * assist_rate
			
			# Guía continua de cabeceo (Pitch) en vuelo para enfilar hacia el objetivo en tierra o aire
			if locomotion_state == LocomotionState.FLYING and (ground_proximity > 14.0 or dir_to_target.y > 0.0):
				var min_pitch := -deg_to_rad(45.0) if ground_proximity > 18.0 else -deg_to_rad(14.0)
				var wanted_flight_pitch := clampf(asin(clampf(dir_to_target.y, -1.0, 1.0)), min_pitch, deg_to_rad(28.0))
				var pitch_rate := 3.8 if firing_now else 2.2
				target_pitch = lerpf(target_pitch, wanted_flight_pitch, 1.0 - exp(-pitch_rate * delta))
	else:
		# Recentrador suave de la cabeza hacia el frente de vuelo cuando no hay objetivo
		if not head_aim_active:
			head_requested_yaw = lerpf(head_requested_yaw, 0.0, 1.0 - exp(-4.0 * delta))
			head_requested_pitch = lerpf(head_requested_pitch, 0.0, 1.0 - exp(-4.0 * delta))
	var yaw := head_requested_yaw if (head_aim_active or is_instance_valid(locked_target)) else sin(tail_wave_time * 0.43) * deg_to_rad(2.2) + smoothed_turn_rate * 0.12
	var pitch := head_requested_pitch if (head_aim_active or is_instance_valid(locked_target)) else deg_to_rad(3.0) + sin(tail_wave_time * 0.68) * deg_to_rad(1.4)
	if not (head_aim_active or is_instance_valid(locked_target)):
		var air := clampf(1.0 - ground_blend, 0.0, 1.0)
		yaw += _flight_neck_yaw() * air
		pitch += _flight_neck_pitch() * air
		if is_instance_valid(breath) and breath.is_firing and locomotion_state == LocomotionState.FLYING:
			pitch -= deg_to_rad(10.0) * air
	var response := 1.0 - exp(-12.0 * delta)
	var head_step := (Vector2(yaw, pitch) - Vector2(head_aim_yaw, head_aim_pitch)) * response
	head_step = head_step.limit_length(deg_to_rad(320.0) * delta)
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


# Cuello en vuelo (ref. Symmonds/Dragontwin): la cabeza anticipa el viraje y estabiliza la mirada.
# El cuello compensa el cabeceo de cada batido (la cabeza queda quieta mientras el cuerpo sube y baja),
# mira al horizonte al trepar, a lo largo de la trayectoria al picar y se levanta al frenar.
func _flight_neck_yaw() -> float:
	return smoothed_turn_rate * neck_lead_strength * 0.45

func _flight_neck_pitch() -> float:
	var stabilize := -flap_pitch_surge * 0.9
	var maneuver := -climb_blend * deg_to_rad(22.0) + brake_blend * deg_to_rad(10.0) + dive_fold_blend * deg_to_rad(6.0)
	# Onda cervical leve, desfasada del batido (el cuello va detrás del hombro).
	var flap_time: float = anim_player.current_animation_position if (anim_player and anim_player.is_playing() and is_flapping) else 0.0
	var neck_wave := sin(fposmod(flap_time, 1.5) / 1.5 * TAU - 1.2) * deg_to_rad(2.5) * (1.0 - glide_blend)
	return stabilize + maneuver + neck_wave

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
@export var walk_speed: float = 4.8             # Marcha pesada: patas de ~2.5 m (Froude ~0.9) en vez de galope a 7.5
@export var sprint_speed: float = 8.0           # Trote/carrera en tierra (Shift, m/s)
@export var ground_turn_speed: float = 1.6      # Tasa de giro horizontal en tierra (rad/s); permite giro y maniobra ágil
@export var ground_accel: float = 18.0          # Aceleración en tierra
@export var ground_friction: float = 14.0       # Fricción al detenerse
@export var jump_impulse: float = 16.0          # Impulso de salto / despegue (m/s)

@export_group("Aerodinámica y Modos de Vuelo")
@export var cruise_speed: float = 26.0          # Velocidad de planeo nivelado (m/s, ~95 km/h)
@export var climb_forward_speed: float = 22.0   # Velocidad horizontal al trepar
@export var min_stall_speed: float = 7.0        # Velocidad mínima antes de pérdida
@export var max_flap_speed: float = 34.0        # Velocidad máxima aleteando
@export var dive_terminal_speed: float = 46.0   # Tope de picada con alas plegadas (~165 km/h)
@export var flap_acceleration: float = 12.0     # Impulso de aceleración por aleteo
@export var air_brake_decel: float = 18.0       # Resistencia al frenar (S)
@export var normal_drag: float = 1.6            # Fricción natural del aire en planeo
@export var gravity_magnitude: float = 9.8      # Gravedad

@export_group("Física de Energía y Sustentación")
@export var drag_coefficient: float = 0.004       # Arrastre cuadrático con alas abiertas (1/m)
@export var dive_drag_coefficient: float = 0.0035 # Arrastre con alas plegadas en picada
@export var glide_drag_coefficient: float = 0.0022 # Arrastre en planeo limpio (alta eficiencia)
@export var brake_drag_coefficient: float = 0.05  # Alas en paracaídas al frenar
@export var lift_speed: float = 22.0              # Velocidad a la que la sustentación iguala el peso
@export var max_sink_rate: float = 14.0           # Hundimiento máximo sin sustentación (m/s)
@export var max_bank_angle: float = 65.0          # Alabeo máximo comandado (grados)
@export var roll_response: float = 2.2            # Rapidez de entrada/salida del alabeo (1/s)
@export var turn_gain: float = 1.9                # Agilidad sobre el viraje coordinado puro (~85°/s a 65°)
@export var max_turn_rate: float = 1.6            # Tasa de giro máxima (rad/s)
@export var flap_cycle_scale: float = 0.74        # Tempo del aleteo de crucero (~2 s por batido)

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
@export var tail_length_scale: float = 0.75         # Largo de la cola respecto del rig original
@export var wing_asymmetry_strength: float = 0.35   # Desnivel diedro entre ala interior y exterior

@export_group("Alineación del Modelo Visual (Cinemática Natural)")
# Espina dorsal, montura y cabeza perfectamente alineadas con el eje de vuelo -Z hacia el horizonte.
# El lomo/espalda mira al cielo (+Y) y el vientre/patas miran al suelo (-Y).
@export var model_pitch_offset: float = 0.0   # Ajuste fino sobre la calibración automática (grados)
@export var model_yaw_offset: float = 0.0     # Ajuste fino sobre la calibración automática (grados)
@export var model_roll_offset: float = 0.0    # Ajuste fino sobre la calibración automática (grados)
@export var model_pos_offset: Vector3 = Vector3.ZERO
@export var auto_calibrate_orientation: bool = true
@export var reverse_speed: float = 4.5         # Velocidad de marcha atrás (S mantenido, m/s); la de siempre (7.5 x 0.6)
@export var model_scale: float = 1.6           # Escala colosal del dragón (Dragón Cuadrúpedo Colosal)

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
var flap_pitch_surge: float = 0.0     # Cabeceo visual del batido, que el cuello compensa
var sway_offset_x: float = 0.0
var sway_vel_x: float = 0.0
var sway_offset_y: float = 0.0
var sway_vel_y: float = 0.0

var tail_wave_time: float = 0.0

# Detección de suelo y efecto suelo aerodinámico
var ground_proximity: float = 999.0
var is_touching_ground: bool = false
var _surface_wash_timer: float = 0.0
var _step_dust_timer: float = 0.0
var _was_in_water: bool = false

# Estabilizador dinámico de orientación y anclaje (Jonathan Symmonds & Dragontwin)
var smoothed_anchor_offset: Vector3 = Vector3.ZERO
var stabilizer_initialized: bool = false

# Referencias a nodos
@onready var anim_player: AnimationPlayer = null
@onready var visual_root: Node3D = $VisualModel
var skeleton: Skeleton3D = null
var flight_camera = null
var dragon_model_node: Node = null

func _get_flight_camera():
	if not is_instance_valid(flight_camera):
		var cam = get_viewport().get_camera_3d() if get_viewport() else null
		if cam and cam.has_method("add_trauma"):
			flight_camera = cam
		elif get_parent():
			var c = get_parent().get_node_or_null("FlightCamera")
			if c and c.has_method("add_trauma"):
				flight_camera = c
	return flight_camera

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
		visual_root.basis = (_offset_basis() * calib_basis).scaled(Vector3.ONE * model_scale)
		dragon_model_node = visual_root.get_node_or_null("DragonModel")
	if not dragon_model_node:
		dragon_model_node = find_child("DragonModel", true, false)
	
	breath = get_node_or_null("DragonBreath")
	_find_and_setup_skeleton(self)
	_find_and_setup_anim_player(self)
	
	floor_snap_length = 1.2
	floor_max_angle = deg_to_rad(50.0)
	floor_stop_on_slope = true
	safe_margin = 0.15
	max_slides = 6
	
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
	calibrating = true
	for i in range(3):
		await get_tree().process_frame
	if not skeleton or not visual_root or not anim_player or not anim_player.has_animation("Qishilong_fly2"):
		calibrating = false
		return
	var head = skeleton.find_bone("head")
	if head == -1: head = skeleton.find_bone("Bip001-Head_011")
	var tail = skeleton.find_bone("tail_06")
	if tail == -1: tail = skeleton.find_bone("Bone008_0154")
	if head == -1 or tail == -1 or bone_l_thigh == -1 or bone_r_thigh == -1:
		push_warning("Calibración de orientación: faltan huesos de referencia")
		calibrating = false
		return
	
	# Se muestrea la pose REAL de vuelo (la pose de reposo del rig no coincide con la del clip de aleteo)
	# a lo largo del ciclo completo y se promedian los ejes del cuerpo.
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
		attack_mode_active = false
		return

	# TAB: cambiar objetivo fijado si hay varios enemigos cercanos
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		cycle_locked_target()
		return

	# Captura automática de cursor al hacer clic en el juego para manejo fluido con ratón
	if event is InputEventMouseButton and event.pressed:
		if not mouse_captured and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			var mouse_over_gui := get_viewport().gui_get_hovered_control() != null
			if not mouse_over_gui:
				mouse_captured = true
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# ESC: alterna el timón con mouse (opcional)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		mouse_captured = !mouse_captured
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE)

	# Tecla G: alternar (toggle) Modo Planear
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		glide_mode_active = !glide_mode_active

	# Tecla L: Alternar Aterrizar / Despegar
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		toggle_land_takeoff()

	# Tecla X: Rugido de Dragón
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_X:
		roar()


	if event is InputEventMouseMotion:
		var cam_head := false
		var cam_active := get_viewport().get_camera_3d()
		if cam_active and "head_follow_blend" in cam_active and cam_active.head_follow_blend > 0.35:
			cam_head = true

		if mouse_captured or cam_head or head_aim_active:
			var dx: float = event.relative.x * mouse_sensitivity
			var dy: float = event.relative.y * mouse_sensitivity
			
			# Timón del dragón: orienta rumbo y cabeceo del animal directamente
			target_yaw -= dx
			if locomotion_state == LocomotionState.FLYING:
				target_pitch = clampf(target_pitch - dy, -deg_to_rad(80.0), deg_to_rad(80.0))
			elif locomotion_state == LocomotionState.GROUNDED:
				# En tierra: orientar rumbo con el ratón acumulando giro suave con límite de adelanto
				var lead := wrapf(target_yaw - rotation.y, -PI, PI)
				lead = clampf(lead, -deg_to_rad(85.0), deg_to_rad(85.0))
				target_yaw = rotation.y + lead
			
			# La cabeza/ojos lidera la mirada hacia donde se mueve el ratón
			if not is_instance_valid(locked_target):
				head_requested_yaw = clampf(head_requested_yaw - dx * 0.75, -deg_to_rad(54.0), deg_to_rad(54.0))
				head_requested_pitch = clampf(head_requested_pitch - dy * 0.75, -deg_to_rad(45.0), deg_to_rad(35.0))

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
	var pre_slide_velocity := velocity
	move_and_slide()
	ground_executed_motion = global_position-position_before_move if grounded_before_move else Vector3.ZERO
	ground_guard_snap_delta = ground_executed_motion-ground_guard_motion
	_handle_terrain_collisions(delta, pre_slide_velocity)
	_prevent_terrain_penetration()
	_check_water_entry_impact(pre_slide_velocity)
	_update_surface_effects(delta)
	if grounded_before_move and locomotion_state == LocomotionState.GROUNDED:
		var actual_motion := global_position - position_before_move
		var heading := -Basis(Vector3.UP, rotation.y).z
		ground_motion_speed = actual_motion.dot(heading) / maxf(delta, 0.0001)
		var distance_walked := Vector2(actual_motion.x, actual_motion.z).length()
		if (is_on_wall() or wing_contact.predictive_contact) and absf(ground_motion_speed) < 0.1:
			current_speed = 0.0
		var move_req := absf(manual_move_input) if manual_input_override else (1.0 if (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_S)) else 0.0)
		var nominal_advance := move_req * walk_speed * delta
		# Contra un obstáculo, agua o pared no hay marcha en el sitio: la fase sólo avanza con desplazamiento real.
		# Incluye el retroceso a la pose segura tras chocar con roca o árbol (marcado por wing_contact).
		var contact_now: bool = is_on_wall() or wing_contact.predictive_contact or shoreline_blocked or Engine.get_physics_frames() - pose_rollback_tick <= 2
		# Sólo un bloqueo sostenido congela la marcha; al arrancar desde una pared las patas
		# necesitan avanzar su fase para dar el primer paso que libera al cuerpo.
		blocked_gait_time = blocked_gait_time + delta if (contact_now and distance_walked < nominal_advance * 0.2) else 0.0
		var obstructed: bool = blocked_gait_time > 0.3
		var effective_advance := maxf(distance_walked, nominal_advance * 0.8) if ((move_req > 0.01 or absf(current_speed) > 0.1) and not obstructed) else distance_walked
		if effective_advance > 0.0005 or absf(ground_yaw_motion) > 0.0001:
			walk_cycle_phase += (effective_advance + absf(ground_yaw_motion) * 4.0) * TAU / 3.5
	_update_animations()

# --- Entrada de Teclado y Control de Modos ---
func _handle_input_keys(delta: float) -> void:
	# Actualizar blends de locomoción
	ground_blend = move_toward(ground_blend, 1.0 if locomotion_state == LocomotionState.GROUNDED else 0.0, 5.5 * delta)
	var desired_landing_blend := 1.0 if locomotion_state == LocomotionState.LANDING else 0.0
	if locomotion_state == LocomotionState.FLYING and not _over_water() and ground_proximity < 15.0 and velocity.y < -1.5 and not is_climbing:
		desired_landing_blend = clampf((15.0 - ground_proximity) / 10.0, 0.0, 0.85)
	landing_blend = move_toward(landing_blend, desired_landing_blend, 5.0 * delta)
	var safe_fold := 1.0 if (locomotion_state == LocomotionState.GROUNDED or is_diving) else 0.0
	if locomotion_state == LocomotionState.FLYING:
		# En vuelo libre las alas permanecen extendidas; sólo se pliegan en picada rápida (is_diving)
		safe_fold = 1.0 if is_diving else 0.0
	elif locomotion_state == LocomotionState.LANDING:
		# En aproximación de aterrizaje las alas se mantienen extendidas en flare aerodinámico de frenado.
		# Sólo inician el repliegue suave justo antes del contacto (altitud menor a 2.5m).
		safe_fold = clampf((2.5 - ground_proximity) / 2.0, 0.0, 1.0)
	elif locomotion_state == LocomotionState.TAKING_OFF:
		# En despegue las alas baten abiertas para producir empuje y sustentación
		safe_fold = 0.0
	safe_fold = maxf(safe_fold, contact_fold_requested)
	contact_fold_requested = move_toward(contact_fold_requested, 0.0, delta)
	wing_fold_blend = move_toward(wing_fold_blend, safe_fold, 3.2 * delta)

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
			
		# Marcha atrás con su propia velocidad (S = -0.6 de entrada); no escala con la marcha hacia adelante.
		var target_walk = (sprint_speed if is_sprint else walk_speed) * move_input if move_input >= 0.0 else reverse_speed * maxf(move_input / 0.6, -1.0)
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
			var turn_rate := ground_turn_speed * (1.25 if move_input == 0.0 else (1.15 if is_sprint else 1.0))
			target_yaw += turn_input * turn_rate * delta
			
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
		# Sin batir, el planeo se compensa con el morro levemente abajo para conservar velocidad.
		var trim := -deg_to_rad(5.0) if glide_mode_active else 0.0
		target_pitch = lerp(target_pitch, trim, 0.8 * delta)
		
	# 5. DETERMINAR MODO ACTIVO
	if is_diving:
		current_mode = FlightMode.DIVE
		target_pitch = lerp(target_pitch, -deg_to_rad(52.0), 3.8 * delta)
	elif is_braking:
		current_mode = FlightMode.BRAKE
		target_pitch = lerp(target_pitch, deg_to_rad(15.0), 4.0 * delta)
	elif is_climbing:
		current_mode = FlightMode.CLIMB
		# Trepada empinada (ref. Symmonds): cuerpo a ~55° con batidos de esfuerzo.
		target_pitch = lerp(target_pitch, deg_to_rad(55.0), 3.0 * delta)
	elif glide_mode_active:
		current_mode = FlightMode.GLIDE
	else:
		current_mode = FlightMode.NORMAL

	# Recogida natural de proximidad al suelo (Ground-Effect Pull-Out):
	# Evita clavar el cuello/cabeza (~10m hacia adelante) bajo el terreno al caer o picar cerca de tierra firme.
	if not _over_water() and ground_proximity < 25.0 and (velocity.y < -1.0 or target_pitch < 0.0):
		var flare_t := clampf((25.0 - ground_proximity) / 18.5, 0.0, 1.0)
		var min_safe_pitch := lerpf(-deg_to_rad(52.0), deg_to_rad(8.0), flare_t * flare_t)
		if target_pitch < min_safe_pitch:
			target_pitch = lerpf(target_pitch, min_safe_pitch, 1.0 - exp(-12.0 * delta))
		if ground_proximity < 13.0 and is_diving:
			is_diving = false
			ui_dive_active = false
			wings_contracted = false
			current_mode = FlightMode.BRAKE if ground_proximity < 8.5 else FlightMode.NORMAL
		
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

	# El teclado comanda alabeo; el giro sale de inclinar la sustentación (g·tan(alabeo)/v).
	# El ratón y el apuntado de ataque siguen fijando rumbo directo y el alabeo lo acompaña.
	# Sin velocidad no hay sustentación que inclinar: el alabeo máximo crece con la velocidad.
	var max_bank := deg_to_rad(max_bank_angle) * clampf((current_speed - min_stall_speed) / (lift_speed - min_stall_speed), 0.25, 1.0)
	var yaw_diff = wrapf(target_yaw - rotation.y, -PI, PI)
	var desired_bank := clampf(turn_dir * max_bank + clampf(yaw_diff * 2.0, -1.0, 1.0) * max_bank * 0.8, -max_bank, max_bank)
	target_roll = lerp_angle(target_roll, desired_bank, 1.0 - exp(-roll_response * delta))
	var bank := clampf(rotation.z, -1.35, 1.35)
	var coordinated_rate := clampf(gravity_magnitude * tan(bank) / maxf(current_speed, 8.0) * turn_gain, -max_turn_rate, max_turn_rate)
	if turn_dir != 0.0 or absf(yaw_diff) < 0.05:
		target_yaw += coordinated_rate * delta
	var yaw_rate_now := coordinated_rate + clampf(yaw_diff * 3.5, -1.0, 1.0)
	smoothed_turn_rate = lerp(smoothed_turn_rate, clampf(yaw_rate_now / 1.1, -1.0, 1.0), 8.0 * delta)

func _update_mode_blends(delta: float) -> void:
	var rate := 1.0 - exp(-5.0 * delta)
	var target_dive_fold := 1.0 if current_mode == FlightMode.DIVE and locomotion_state == LocomotionState.FLYING else 0.0
	if locomotion_state == LocomotionState.FLYING and current_mode in [FlightMode.NORMAL, FlightMode.GLIDE]:
		var pitch_dive_tuck := clampf((-rotation.x - deg_to_rad(22.0)) / deg_to_rad(30.0), 0.0, 0.85)
		target_dive_fold = maxf(target_dive_fold, pitch_dive_tuck)
	dive_fold_blend = lerpf(dive_fold_blend, target_dive_fold, rate)
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

func _get_water_height() -> float:
	if is_instance_valid(landscape) and landscape.has_method("get_water_level"):
		return landscape.get_water_level()
	return 0.7

func _over_water() -> bool:
	return is_instance_valid(landscape) and landscape.has_method("is_water_at") and landscape.is_water_at(global_position)

func _is_in_water() -> bool:
	if not _over_water():
		return false
	return global_position.y <= _get_water_height() + 1.2

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

	# Balance de energía guiado por la física (Dragontwin):
	# dv/dt = empuje - arrastre(envergadura)·v² - g·sen(trayectoria).
	# Trepar consume velocidad o convierte energía cinética de picada en trepada por inercia (Zoom Climb),
	# picar acumula energía potencial en cinética y planear la conserva con mínima resistencia inducida.
	var forward_dir := -transform.basis.z.normalized()
	var thrust := 0.0
	var drag_k := drag_coefficient
	var flap_lift := 0.0
	match current_mode:
		FlightMode.DIVE:
			drag_k = dive_drag_coefficient
			thrust = 1.5 # recogida de alas y empuje de cola hacia la picada
		FlightMode.CLIMB:
			# Batido potente: equilibrio cerca de 15 m/s con 55° de cabeceo.
			thrust = drag_coefficient * 15.0 * 15.0 + gravity_magnitude * sin(deg_to_rad(55.0))
			flap_lift = 0.35
		FlightMode.GLIDE:
			drag_k = glide_drag_coefficient
		FlightMode.BRAKE:
			drag_k = brake_drag_coefficient
			flap_lift = 0.45
		FlightMode.NORMAL:
			var sustained := max_flap_speed if w_boost else cruise_speed
			thrust = drag_coefficient * sustained * sustained
			flap_lift = 0.25
	# Envergadura dinámica según cabeceo: al inclinar el morro hacia abajo, el dragón recoge
	# progresivamente las alas reduciendo la resistencia parásita y acelerando por gravedad.
	if current_mode in [FlightMode.NORMAL, FlightMode.GLIDE] and rotation.x < -deg_to_rad(18.0):
		var pitch_sweep := clampf((-rotation.x - deg_to_rad(18.0)) / deg_to_rad(34.0), 0.0, 0.85)
		drag_k = lerpf(drag_k, dive_drag_coefficient, pitch_sweep)
	# Conversión de energía cinética en sustentación de trepada (Zoom Climb tras una picada):
	var zoom_excess := clampf((current_speed - cruise_speed) / maxf(dive_terminal_speed - cruise_speed, 1.0), 0.0, 1.0)
	var gravity_bleed := gravity_magnitude * forward_dir.y
	if forward_dir.y > 0.05 and zoom_excess > 0.01:
		gravity_bleed *= lerpf(1.0, 0.72, zoom_excess)
	# Batido de esfuerzo a baja velocidad (ref. Symmonds): sostiene casi todo el peso, para poder
	# recuperarse de una pérdida o de un roce con la ladera en vez de quedar pegado hundiéndose.
	if current_mode == FlightMode.NORMAL or current_mode == FlightMode.CLIMB:
		flap_lift += 0.7 * (1.0 - clampf(current_speed / lift_speed, 0.0, 1.0))
	var speed_rate := thrust - drag_k * current_speed * current_speed - gravity_bleed
	current_speed = clampf(current_speed + speed_rate * delta, min_stall_speed, dive_terminal_speed)

	# Resistencia fluida al atravesar el agua (Water traversal / hydrodynamic drag)
	if _is_in_water():
		# El agua reduce la velocidad máxima por fricción hidrodinámica, pero permite atravesarla libremente
		var max_water_speed := 14.0 if is_diving else 10.0
		current_speed = move_toward(current_speed, minf(current_speed, max_water_speed), 16.0 * delta)

	var wanted_velocity := forward_dir * current_speed
	if current_mode != FlightMode.DIVE:
		# Sustentación ∝ v², proyectada en vertical por cos(alabeo); el batido aporta sostén a baja velocidad.
		var lift_ratio := (current_speed / lift_speed) * (current_speed / lift_speed)
		var vertical_support := lift_ratio * cos(clampf(rotation.z, -1.4, 1.4)) + flap_lift
		wanted_velocity.y -= clampf(1.0 - vertical_support, 0.0, 1.0) * max_sink_rate
		# Si sale de una picada con exceso de velocidad e inclina el morro arriba, la presión dinámica
		# extra sobre las alas desplegadas produce sustentación ascendente real (Zoom Climb).
		if forward_dir.y > 0.04 and zoom_excess > 0.02:
			wanted_velocity.y += zoom_excess * forward_dir.y * 8.5 * (1.0 - dive_fold_blend)
	if current_mode == FlightMode.CLIMB:
		# Piso de ascenso: el batido de esfuerzo siempre gana algo de altura.
		wanted_velocity.y = maxf(wanted_velocity.y, 6.0 * climb_blend)

	# Biomecánica de vuelo pulsado acoplado al aleteo real (Sophoria Academy / Jonathan Symmonds)
	# Ciclo continuo sincronizado con la animación real (cero saltos al repetir bucle)
	if is_flapping and locomotion_state == LocomotionState.FLYING and current_mode != FlightMode.GLIDE and current_mode != FlightMode.DIVE:
		var flap_phase: float = fposmod(_get_flap_cycle_phase(), TAU)
		if flap_phase < PI:
			# Downstroke activo: elevación vertical y aceleración horizontal
			var downstroke_power := sin(flap_phase)
			wanted_velocity.y += downstroke_power * (2.6 if current_mode == FlightMode.CLIMB else 1.2)
			wanted_velocity += forward_dir * (downstroke_power * 1.0)
		else:
			# Upstroke de recobro: relajación aerodinámica y leve descenso por gravedad
			var upstroke_sink := sin(flap_phase - PI) * 0.5
			wanted_velocity.y -= upstroke_sink

	# Actualización de deformación aerodinámica de membranas alares vivas (Dragontwin)
	if dragon_model_node and dragon_model_node.has_method("update_aero_params"):
		var bank_g := clampf(1.0 / maxf(cos(rotation.z), 0.45) - 1.0, 0.0, 1.0)
		var aero_billow := clampf((current_speed / cruise_speed) * 0.72 + bank_g * 0.25 + (0.20 if is_flapping else 0.0), 0.0, 1.0) * (1.0 - ground_blend)
		var aero_flutter := clampf((current_speed - 18.0) / 18.0 + dive_fold_blend * 0.35, 0.0, 1.0) * (1.0 - ground_blend)
		dragon_model_node.update_aero_params(current_speed, aero_billow, aero_flutter)

	# Efecto suelo aerodinámico natural (Ground Effect Cushion):
	# Al descender cerca de tierra firme, el colchón de aire amortigua la caída vertical antes del contacto.
	if not _over_water() and not _is_in_water() and ground_proximity < 16.0 and wanted_velocity.y < -2.2 and not is_climbing:
		var ge_factor := clampf((16.0 - ground_proximity) / 12.0, 0.0, 1.0)
		var max_safe_sink := lerpf(24.0, 3.2, ge_factor * ge_factor)
		wanted_velocity.y = maxf(wanted_velocity.y, -max_safe_sink)

	# Dinámica en agua: permite sumergirse y nadar; flotabilidad suave solo si no está en picada activa
	if _is_in_water():
		if not is_diving:
			var water_surface := _get_water_height()
			if global_position.y < water_surface:
				# Flotabilidad hidrostática suave (sin rebotar artificialmente)
				wanted_velocity.y = maxf(wanted_velocity.y, 1.5)

	velocity = velocity.move_toward(wanted_velocity, (28.0 if current_mode == FlightMode.DIVE else 22.0) * delta)

	var centrifugal_accel = -smoothed_turn_rate * (current_speed / cruise_speed) * weight_sway_strength * 3.0
	var spring_force_x = -weight_spring_stiffness * sway_offset_x - weight_damping * sway_vel_x + centrifugal_accel
	sway_vel_x += spring_force_x * delta
	sway_offset_x += sway_vel_x * delta
	sway_offset_x = clamp(sway_offset_x, -1.8, 1.8)


func _complete_ground_touchdown(floor_n: Vector3, impact_vel: Vector3, trauma: float, dust_scale: float) -> void:
	locomotion_state = LocomotionState.GROUNDED
	GameAudio.play_dragon_slam(global_position)
	current_mode = FlightMode.NORMAL
	var horiz_vel := Vector2(impact_vel.x, impact_vel.z).length()
	current_speed = clampf(horiz_vel * 0.45, 0.0, walk_speed)
	var local_n := Basis(Vector3.UP, rotation.y).inverse() * floor_n
	target_pitch = atan2(local_n.z, local_n.y)
	target_roll = -atan2(local_n.x, local_n.y)
	rotation.x = lerp_angle(maxf(rotation.x, target_pitch - deg_to_rad(3.0)), target_pitch, 0.85)
	rotation.z = lerp_angle(rotation.z, target_roll, 0.85)
	var forward_flat := -transform.basis.z
	forward_flat.y = 0.0
	if forward_flat.length_squared() > 0.0001:
		forward_flat = forward_flat.normalized().slide(floor_n).normalized()
	velocity = forward_flat * current_speed
	ground_air_timer = 0.0
	ground_blend = maxf(ground_blend, 0.96)
	wing_fold_blend = maxf(wing_fold_blend, 0.96)
	landing_blend = 0.0
	is_diving = false
	ui_dive_active = false
	landing_target_active = false
	ground_pose.reset()
	var land_pos := global_position + Vector3.DOWN * minf(ground_proximity * 0.5, 2.2)
	CollisionEffects.spawn_impact(get_parent(), land_pos, floor_n, dust_scale, false, landscape)
	var cam = _get_flight_camera()
	if cam:
		cam.add_trauma(trauma)

# --- Respuesta Físico-Colisional con el Terreno ---
func _handle_terrain_collisions(delta: float, pre_slide_vel: Vector3 = Vector3.ZERO) -> void:
	is_touching_ground = is_on_floor()
	if locomotion_state == LocomotionState.GROUNDED:
		ground_air_timer = 0.0 if is_on_floor() else ground_air_timer + delta
		if ground_air_timer > 0.25 and ground_proximity > 6.0:
			locomotion_state = LocomotionState.FLYING
			ground_pose.reset()
		return
	if locomotion_state == LocomotionState.LANDING and is_on_floor() and get_floor_normal().dot(Vector3.UP) >= cos(floor_max_angle) and not _over_water() and ground_proximity < 5.0:
		_complete_ground_touchdown(get_floor_normal(), velocity, 0.4, 1.8)
		return
	# Si en vuelo libre toca suelo transitable descendiendo, posar naturalmente sobre las 4 patas
	if locomotion_state == LocomotionState.FLYING and is_on_floor() and get_floor_normal().dot(Vector3.UP) >= cos(floor_max_angle) and not _over_water() and not _is_in_water() and ground_proximity < 4.8 and pre_slide_vel.y <= 0.2 and not is_climbing:
		var td_speed := absf(pre_slide_vel.y)
		_complete_ground_touchdown(get_floor_normal(), pre_slide_vel, clampf(td_speed / 16.0, 0.3, 0.8), clampf(td_speed / 5.0, 1.4, 2.6))
		return
	var collision_count := get_slide_collision_count()
	if collision_count > 0:
		var incident_vel := pre_slide_vel if pre_slide_vel.length_squared() > 0.01 else velocity
		var max_impact_speed := 0.0
		var primary_normal := Vector3.UP
		var impact_pos := global_position
		for i in range(collision_count):
			var col := get_slide_collision(i)
			var n := col.get_normal()
			var impact_speed := -incident_vel.dot(n)
			if impact_speed > max_impact_speed:
				max_impact_speed = impact_speed
				primary_normal = n
				impact_pos = col.get_position()

		if max_impact_speed > 1.5:
			# Solicitar repliegue de alas por impacto
			contact_fold_requested = 1.0

			# Consecuencias de impacto: levantamiento de polvo o agua según la superficie
			var severity := clampf(max_impact_speed / 6.5, 0.7, 3.5)
			CollisionEffects.spawn_impact(get_parent(), impact_pos, primary_normal, severity, false, landscape)

			# Sacudida visceral de cámara (Screen Shake)
			var cam = _get_flight_camera()
			if cam:
				var trauma_val := clampf(max_impact_speed / 16.0, 0.35, 1.0)
				cam.add_trauma(trauma_val)

			var in_water := _is_in_water() or _over_water()
			var is_walkable_ground := primary_normal.y >= cos(floor_max_angle)

			if is_walkable_ground and not in_water and incident_vel.y < -1.5 and not is_climbing and (locomotion_state in [LocomotionState.FLYING, LocomotionState.LANDING]):
				# Aterrizaje / absorción natural sobre terreno transitable al descender o caer
				_complete_ground_touchdown(primary_normal, incident_vel, clampf(max_impact_speed / 16.0, 0.35, 0.9), clampf(max_impact_speed / 5.5, 1.6, 2.8))
				return
			elif max_impact_speed >= 7.0:
				# --- CHOQUE INELÁSTICO CONTRA ROCAS / ACANTILADOS / PAREDES ---
				var v_dot_n := incident_vel.dot(primary_normal)
				var v_normal := primary_normal * v_dot_n
				var v_tangent := incident_vel - v_normal

				var restitution := 0.04 if in_water else 0.12
				var friction_retained := 0.45
				var normal_sep := 0.2 if in_water else 1.2

				var v_rebound_normal := -v_normal * restitution + primary_normal * normal_sep
				var v_scraped_tangent := v_tangent * friction_retained

				velocity = v_scraped_tangent + v_rebound_normal
				if primary_normal.y > 0.15 and not in_water:
					# En laderas inclinadas, nunca empujar hacia abajo; desviar hacia arriba de la pendiente
					velocity.y = maxf(velocity.y, 1.8)
					target_pitch = maxf(target_pitch, deg_to_rad(6.0))
					target_roll = lerp_angle(target_roll, 0.0, 0.6)
				else:
					target_roll = lerp_angle(target_roll, 0.0, 0.4)
				current_speed = maxf(min_stall_speed, velocity.length())
			else:
				# --- ROCE / COLISIÓN LEVE O MODERADA ---
				var slow := 1.0 - clampf(current_speed / lift_speed, 0.0, 1.0)
				velocity = velocity.slide(primary_normal) + primary_normal * (1.2 + 4.5 * slow)
				current_speed = maxf(min_stall_speed, current_speed - max_impact_speed * 0.4)
				target_roll = lerp_angle(target_roll, 0.0, 0.5)
				if primary_normal.y > 0.2 and not in_water:
					velocity.y = maxf(velocity.y, 0.8)
					target_pitch = maxf(target_pitch, deg_to_rad(5.0))

func _prevent_terrain_penetration() -> void:
	if not is_instance_valid(landscape) or not landscape.has_method("ground_height"):
		return
	var ground_h: float = landscape.ground_height(global_position.x, global_position.z)
	if not ground_contact.is_empty() and ground_contact.position.y > ground_h and ground_contact.position.y < global_position.y + 1.0:
		ground_h = ground_contact.position.y
	# El colisionador SphereShape3D (radio 4.0m en y=+0.5m) tiene su base exacta en global_position.y - 3.5m.
	var min_safe_y: float = ground_h + 3.46
	if global_position.y < min_safe_y:
		global_position.y = min_safe_y
		if velocity.y < 0.0:
			velocity.y = 0.0
		if locomotion_state == LocomotionState.GROUNDED:
			ground_air_timer = 0.0
		elif not _over_water() and not _is_in_water() and not is_climbing and (ground_contact.is_empty() or ground_contact.normal.y >= cos(floor_max_angle)):
			_complete_ground_touchdown(ground_normal if not ground_contact.is_empty() else Vector3.UP, velocity, 0.35, 1.6)
		else:
			current_speed = maxf(min_stall_speed, current_speed * 0.65)

func _check_water_entry_impact(pre_slide_vel: Vector3) -> void:
	var in_water_now := _is_in_water()
	if in_water_now and not _was_in_water:
		var entry_speed := pre_slide_vel.length()
		if entry_speed > 3.5:
			var w_y := _get_water_height()
			var splash_pos := Vector3(global_position.x, w_y, global_position.z)
			var severity := clampf(entry_speed / 7.0, 1.2, 4.0)
			CollisionEffects.spawn_impact(get_parent(), splash_pos, Vector3.UP, severity, true, landscape)
			var cam = _get_flight_camera()
			if cam:
				cam.add_trauma(clampf(entry_speed / 20.0, 0.35, 0.85))
	elif not in_water_now and _was_in_water:
		var exit_speed := velocity.length()
		if exit_speed > 5.0:
			var w_y := _get_water_height()
			CollisionEffects.spawn_surface_wash(get_parent(), Vector3(global_position.x, w_y + 0.05, global_position.z), velocity, true)
	_was_in_water = in_water_now

func _update_surface_effects(delta: float) -> void:
	if locomotion_state == LocomotionState.FLYING:
		if current_speed > 10.0:
			_surface_wash_timer += delta
			if _surface_wash_timer >= 0.08:
				_surface_wash_timer = 0.0
				if _over_water():
					var w_y := _get_water_height()
					var dist_to_water := global_position.y - w_y
					if dist_to_water > -0.5 and dist_to_water < 5.0:
						CollisionEffects.spawn_surface_wash(get_parent(), Vector3(global_position.x, w_y + 0.05, global_position.z), velocity, true)
				elif ground_proximity < 4.2 and not ground_contact.is_empty():
					CollisionEffects.spawn_surface_wash(get_parent(), ground_contact.position + Vector3.UP * 0.08, velocity, false)
	elif locomotion_state == LocomotionState.GROUNDED:
		# Polvo sólo al correr y espaciado: al caminar sobre pasto formaba una nube que tapaba la cámara.
		if absf(ground_motion_speed) > walk_speed * 1.15:
			_step_dust_timer += delta
			if _step_dust_timer >= 0.6:
				_step_dust_timer = 0.0
				var step_pos := global_position + Vector3.DOWN * 0.1
				var on_water := _is_in_water() or _over_water()
				CollisionEffects.spawn_surface_wash(get_parent(), step_pos, velocity, on_water)

# --- Suavizado de Rotaciones Globales ---
func _apply_smooth_rotations(delta: float) -> void:
	var diff := wrapf(target_yaw - rotation.y, -PI, PI)
	var yaw_step := diff * minf(1.0, (14.0 if locomotion_state == LocomotionState.GROUNDED else 10.0) * delta)
	if locomotion_state == LocomotionState.GROUNDED:
		var max_ground_yaw_rate := ground_turn_speed * 1.6
		yaw_step = clampf(yaw_step, -max_ground_yaw_rate * delta, max_ground_yaw_rate * delta)
	rotation.y += yaw_step
	var pitch_rate := 12.0 if (not _over_water() and ground_proximity < 22.0 and target_pitch > rotation.x) else 8.0
	rotation.x = lerp_angle(rotation.x, target_pitch, pitch_rate * delta)
	if locomotion_state != LocomotionState.GROUNDED and not _over_water() and ground_proximity < 16.0:
		# Límite geométrico: impide que la extensión frontal del cuello/pecho (~9.5m) baje del plano del suelo
		var min_geom_pitch := -atan2(maxf(0.0, ground_proximity - 3.5), 9.5)
		if rotation.x < min_geom_pitch:
			rotation.x = lerpf(rotation.x, min_geom_pitch, 1.0 - exp(-18.0 * delta))
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
			
	var rest_pelvis_pos = skeleton.get_bone_rest(bone_pelvis).origin if (skeleton and bone_pelvis != -1) else Vector3(32.7745, 356.433, 549.343)
	
	# Orientación de referencia de la pelvis: inicio del ciclo de vuelo de Qishilong_fly2
	var pelvis_ref_rot = null
	if source_anims.has("Qishilong_fly2"):
		var fly_anim: Animation = source_anims["Qishilong_fly2"]
		var sample_t = 0.0 if fly_anim.length <= 4.0 else ANIM_SPECS["Qishilong_fly2"]["range"].x
		for t in range(fly_anim.get_track_count()):
			var p_path = str(fly_anim.track_get_path(t))
			if ("pelvis" in p_path or "Bip001_03" in p_path) and fly_anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				pelvis_ref_rot = fly_anim.rotation_track_interpolate(t, sample_t)
				break
	
	for anim_name in ANIM_SPECS:
		var spec = ANIM_SPECS[anim_name]
		var src_name = spec["source"]
		if not source_anims.has(src_name):
			continue
		var src_anim = source_anims[src_name]
		if src_anim.length <= 4.0:
			src_anim.loop_mode = Animation.LOOP_LINEAR
			continue
		var r = spec["range"]
		var new_anim = Animation.new()
		var loop_len = r.y - r.x
		new_anim.length = loop_len
		new_anim.loop_mode = Animation.LOOP_LINEAR
		
		for t in range(src_anim.get_track_count()):
			var track_type = src_anim.track_get_type(t)
			var track_path = str(src_anim.track_get_path(t))
			var is_pelvis = ("pelvis" in track_path or "Bip001_03" in track_path)
			
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
	# extraída de la pose majestuosa y perfectamente simétrica de t=40.25s de Qishilong_fly2
	if source_anims.has("Qishilong_fly2"):
		var fly_anim: Animation = source_anims["Qishilong_fly2"]
		var glide_anim = Animation.new()
		glide_anim.length = 2.0
		glide_anim.loop_mode = Animation.LOOP_LINEAR
		var t_glide = 40.25
		
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

	# Tempo pesado y acoplado a la carga física (ref. Dragontwin):
	# A menor velocidad o mayor ángulo de ascenso, el dragón bate con más cadencia para sostener su peso.
	var speed_load := clampf(1.0 - (current_speed - min_stall_speed) / maxf(cruise_speed - min_stall_speed, 1.0), 0.0, 1.0)
	match current_mode:
		FlightMode.DIVE:
			if anim_player.has_animation("Qishilong_glide"):
				target_anim = "Qishilong_glide"
			else:
				target_anim = "Qishilong_fly2"
			custom_speed = 1.0
		FlightMode.CLIMB:
			target_anim = "Qishilong_fly2"
			custom_speed = flap_cycle_scale * (1.14 + speed_load * 0.14)
		FlightMode.GLIDE:
			if anim_player.has_animation("Qishilong_glide"):
				target_anim = "Qishilong_glide"
			else:
				target_anim = "Qishilong_fly2"
			custom_speed = 1.0
		FlightMode.BRAKE:
			target_anim = "Qishilong_fly2"
			custom_speed = flap_cycle_scale * 1.12
		FlightMode.NORMAL:
			target_anim = "Qishilong_fly2"
			custom_speed = flap_cycle_scale * ((1.22 if w_boost else 1.0) + speed_load * 0.10)
		
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
		bone_pelvis = skeleton.find_bone("pelvis")
		if bone_pelvis == -1: bone_pelvis = skeleton.find_bone("Bip001_03")
		if bone_pelvis != -1:
			_cache_bone_relative_axes(bone_pelvis)
		bone_l_thigh = skeleton.find_bone("thigh_L")
		if bone_l_thigh == -1: bone_l_thigh = skeleton.find_bone("Bip001-L-Thigh_0115")
		bone_r_thigh = skeleton.find_bone("thigh_R")
		if bone_r_thigh == -1: bone_r_thigh = skeleton.find_bone("Bip001-R-Thigh_0130")
		bone_l_calf = skeleton.find_bone("shin_L")
		if bone_l_calf == -1: bone_l_calf = skeleton.find_bone("Bip001-L-Calf_0116")
		bone_r_calf = skeleton.find_bone("shin_R")
		if bone_r_calf == -1: bone_r_calf = skeleton.find_bone("Bip001-R-Calf_0131")
		bone_l_foot = skeleton.find_bone("foot_L")
		if bone_l_foot == -1: bone_l_foot = skeleton.find_bone("Bip001-L-Foot_0118")
		bone_r_foot = skeleton.find_bone("foot_R")
		if bone_r_foot == -1: bone_r_foot = skeleton.find_bone("Bip001-R-Foot_0133")
		
		bone_l_clavicle = skeleton.find_bone("wing_shoulder_L")
		if bone_l_clavicle == -1: bone_l_clavicle = skeleton.find_bone("Bip001-L-Clavicle_037")
		bone_r_clavicle = skeleton.find_bone("wing_shoulder_R")
		if bone_r_clavicle == -1: bone_r_clavicle = skeleton.find_bone("Bip001-R-Clavicle_052")
		bone_l_arm = skeleton.find_bone("wing_shoulder_L")
		if bone_l_arm == -1: bone_l_arm = skeleton.find_bone("Bip001-L-UpperArm_038")
		bone_r_arm = skeleton.find_bone("wing_shoulder_R")
		if bone_r_arm == -1: bone_r_arm = skeleton.find_bone("Bip001-R-UpperArm_053")
		bone_l_forearm = skeleton.find_bone("wing_forearm_L")
		if bone_l_forearm == -1: bone_l_forearm = skeleton.find_bone("Bip001-L-Forearm_039")
		bone_r_forearm = skeleton.find_bone("wing_forearm_R")
		if bone_r_forearm == -1: bone_r_forearm = skeleton.find_bone("Bip001-R-Forearm_054")
		
		bone_l_wing_root = skeleton.find_bone("wing_shoulder_L")
		if bone_l_wing_root == -1: bone_l_wing_root = skeleton.find_bone("Bone017(mirrored)_092")
		bone_r_wing_root = skeleton.find_bone("wing_shoulder_R")
		if bone_r_wing_root == -1: bone_r_wing_root = skeleton.find_bone("Bone017_068")
		bone_l_wing_mid = skeleton.find_bone("wing_forearm_L")
		if bone_l_wing_mid == -1: bone_l_wing_mid = skeleton.find_bone("Bone018(mirrored)_096")
		bone_r_wing_mid = skeleton.find_bone("wing_forearm_R")
		if bone_r_wing_mid == -1: bone_r_wing_mid = skeleton.find_bone("Bone018_069")
		
		bone_spine_indices.clear()
		for spine_name in ["spine_01", "chest", "Bip001-Spine_05", "Bip001-Spine1_06", "Bip001-Spine2_07"]:
			var b = skeleton.find_bone(spine_name)
			if b != -1 and not bone_spine_indices.has(b):
				bone_spine_indices.append(b)
				_cache_bone_relative_axes(b)
				
		bone_neck_indices.clear()
		for neck_name in ["neck_01", "neck_02", "neck_03", "Bip001-Neck_08", "Bip001-Neck1_09", "Bip001-Neck2_010"]:
			var b = skeleton.find_bone(neck_name)
			if b != -1 and not bone_neck_indices.has(b):
				bone_neck_indices.append(b)
				_cache_bone_relative_axes(b)
				
		bone_head_idx = skeleton.find_bone("head")
		if bone_head_idx == -1: bone_head_idx = skeleton.find_bone("Bip001-Head_011")
		if bone_head_idx != -1:
			_cache_bone_relative_axes(bone_head_idx)
			
		bone_tail_indices.clear()
		for i in range(1, 9):
			var tail_name = "tail_0%d" % i
			var b = skeleton.find_bone(tail_name)
			if b == -1:
				tail_name = "Bone%03d_01%02d" % [i, 46 + i]
				b = skeleton.find_bone(tail_name)
			if b != -1 and not bone_tail_indices.has(b):
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

func _get_flap_cycle_phase() -> float:
	if not anim_player or not anim_player.is_playing():
		return 0.0
	var pos: float = anim_player.current_animation_position
	var anim_len: float = anim_player.current_animation_length
	anim_len = maxf(anim_len, 0.5)
	var beats: float = 2.0 if anim_len >= 2.5 else 1.0
	return (pos / anim_len) * TAU * beats

# ==============================================================================
# POSTURA Y BAMBOLEO BIOMECÁNICO (Jonathan Symmonds & Dragontwin)
# ==============================================================================
func _process(delta: float) -> void:
	tail_wave_time += delta * (3.8 if is_flapping else 1.6)
	
	if dragon_model_node and dragon_model_node.has_method("update_aero_params"):
		var bank_g := clampf(1.0 / maxf(cos(rotation.z), 0.45) - 1.0, 0.0, 1.0)
		var aero_billow := clampf((current_speed / cruise_speed) * 0.72 + bank_g * 0.25 + (0.20 if is_flapping else 0.0), 0.0, 1.0) * (1.0 - ground_blend)
		var aero_flutter := clampf((current_speed - 18.0) / 18.0 + dive_fold_blend * 0.35, 0.0, 1.0) * (1.0 - ground_blend)
		dragon_model_node.update_aero_params(current_speed, aero_billow, aero_flutter)
	
	var heave: float = 0.0
	var pitch_surge: float = 0.0
	var flight_factor: float = clamp(1.0 - ground_blend, 0.0, 1.0)
	
	if anim_player and anim_player.is_playing() and has_taken_off and is_flapping:
		var phase = _get_flap_cycle_phase()
		var flap_intensity = 1.1 if current_mode == FlightMode.CLIMB else 0.28
		heave = sin(phase) * flap_intensity * flight_factor
		pitch_surge = -cos(phase) * deg_to_rad(7.0 if current_mode == FlightMode.CLIMB else 2.0) * flight_factor
		flap_pitch_surge = pitch_surge
		# Bamboleo de esfuerzo en trepada: el cuerpo se balancea de lado a lado (un ciclo por aleteo doble)
		climb_roll_wobble = sin(phase * 0.5 + 0.6) * deg_to_rad(5.0) * climb_blend * flight_factor
		# Disparo de audio de aleteo en la cresta descendente
		var flap_downstroke := sin(phase)
		if flap_downstroke > 0.82 and _prev_flap_downstroke <= 0.82:
			GameAudio.play_wing_flap(global_position, 1.2 if current_mode == FlightMode.CLIMB else 0.85)
		_prev_flap_downstroke = flap_downstroke
	else:
		climb_roll_wobble = lerp(climb_roll_wobble, 0.0, 0.1)
		flap_pitch_surge = lerpf(flap_pitch_surge, 0.0, 0.1)
		
	if visual_root:
		var step_weight := _gait_weight()
		if ground_blend > 0.4 and step_weight > 0.2:
			var step_s := sin(walk_cycle_phase * 2.0)
			if (_prev_step_phase <= 0.0 and step_s > 0.0) or (_prev_step_phase >= 0.0 and step_s < 0.0):
				GameAudio.play_dragon_footstep(global_position, current_speed > (walk_speed + 0.5))
			_prev_step_phase = step_s
		var lateral_sway = sway_offset_x * 0.30 * flight_factor + sin(walk_cycle_phase) * 0.14 * step_weight * ground_blend
		var ground_pitch_bob = -sin(walk_cycle_phase * 2.0) * deg_to_rad(2.6) * step_weight * ground_blend
		var surge_basis = Basis.from_euler(Vector3(pitch_surge + ground_pitch_bob, 0.0, climb_roll_wobble))
		visual_root.basis = (surge_basis * _offset_basis() * calib_basis).scaled(Vector3.ONE * model_scale)
		
		if skeleton and bone_pelvis != -1:
			# Centrar suavemente el núcleo del cuerpo sobre el CharacterBody3D sin interferir en los virajes
			var anchor_world = _body_core_world()
			var y_offset = lerp(-0.3 + heave, -0.65 + cos(walk_cycle_phase * 2.0) * 0.16 * step_weight, ground_blend)
			var target_center = global_position + Vector3(lateral_sway, y_offset+body_clearance_lift*ground_blend, 0.0)
			var desired_offset = target_center - anchor_world
			if not stabilizer_initialized:
				smoothed_anchor_offset = desired_offset
				stabilizer_initialized = true
			else:
				smoothed_anchor_offset = smoothed_anchor_offset.lerp(desired_offset, 1.0 - exp(-15.0 * delta))
				if ground_proximity < 8.0 and not _over_water():
					smoothed_anchor_offset.y = maxf(smoothed_anchor_offset.y, desired_offset.y)
			visual_root.global_position += smoothed_anchor_offset
		else:
			visual_root.position = model_pos_offset + Vector3(lateral_sway, heave, 0.0)

	# --- Sincronización continua de Audio con Físicas y Entorno ---
	if GameAudio.instance:
		var in_flight: bool = has_taken_off and (locomotion_state in [LocomotionState.FLYING, LocomotionState.TAKING_OFF, LocomotionState.LANDING])
		var active_airspeed: float = velocity.length() if in_flight else 0.0
		var is_near_water: bool = _over_water() or _is_in_water()
		var water_dist: float = absf(global_position.y - _get_water_height()) if is_near_water else 999.0
		GameAudio.instance.update_flight_physics_audio(
			delta,
			active_airspeed,
			in_flight,
			int(current_mode),
			ground_proximity,
			global_position.y,
			is_near_water,
			water_dist
		)

# Peso del vaivén de marcha (pelvis, columna, cola) según la velocidad real.
func _gait_weight() -> float:
	return clampf(absf(ground_motion_speed) / walk_speed, 0.0, 1.0)

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
	
	# 1. PELVIS / CADERA (Oscilación rítmica de transferencia de peso en marcha terrestre y elevación en aleteo)
	if bone_pelvis != -1:
		var rest_pelvis_pos = sk.get_bone_rest(bone_pelvis).origin
		if ground_blend > 0.01:
			var step_weight := _gait_weight()
			var cycle := walk_cycle_phase
			# Dinámica de masa pélvica inspirada en el ciclo de marcha de Sophocleous:
			# Contrarotación en Yaw, inclinación en Roll hacia la pata de apoyo y doble bombeo vertical (heave)
			var pel_yaw = cos(cycle) * deg_to_rad(7.0) * step_weight * ground_blend
			var pel_roll = sin(cycle) * deg_to_rad(4.5) * step_weight * ground_blend
			var pel_rot = Quaternion(bone_yaw_axes[bone_pelvis], pel_yaw) if bone_yaw_axes.has(bone_pelvis) else Quaternion(Vector3.UP, pel_yaw)
			var roll_axis = bone_roll_axes[bone_pelvis] if bone_roll_axes.has(bone_pelvis) else Vector3.FORWARD
			pel_rot = Quaternion(roll_axis, pel_roll) * pel_rot
			sk.set_bone_pose_rotation(bone_pelvis, pel_rot * sk.get_bone_pose_rotation(bone_pelvis))
			
			# Traslación pélvica tridimensional de masa (heave rítmico y sway lateral hacia la pata de apoyo)
			var pel_heave = (sin(cycle * 2.0) * 0.055 - 0.02) * step_weight * ground_blend
			var pel_sway = sin(cycle) * 0.13 * step_weight * ground_blend
			sk.set_bone_pose_position(bone_pelvis, rest_pelvis_pos + Vector3(pel_sway, pel_heave, 0.0))
		elif flight_factor > 0.01:
			var flap_phase: float = _get_flap_cycle_phase()
			var fly_heave = sin(flap_phase) * 0.12 * flight_factor * (1.0 - glide_blend) * (1.0 - dive_fold_blend)
			sk.set_bone_pose_position(bone_pelvis, rest_pelvis_pos + Vector3(0.0, fly_heave, 0.0))
		else:
			sk.set_bone_pose_position(bone_pelvis, rest_pelvis_pos)


	# 2. COLUMNA DORSAL (Arco orgánico en virajes aéreos + Ondulación serpentina en S con onda viajera en tierra)
	var spine_weights = [0.08, 0.14, 0.18]
	for i in range(bone_spine_indices.size()):
		var b = bone_spine_indices[i]
		if b != -1 and bone_yaw_axes.has(b):
			var flight_yaw = turn * spine_curve_strength * spine_weights[min(i, spine_weights.size() - 1)] * flight_factor
			var flight_pitch = ((brake_blend * 0.12) - (climb_blend * 0.08)) * flight_factor
			
			var ground_wave_phase = walk_cycle_phase - float(i) * 0.45
			var step_weight := _gait_weight()
			var ground_spine_yaw = -sin(ground_wave_phase) * deg_to_rad(7.2) * step_weight * ground_blend
			var ground_spine_roll = -cos(ground_wave_phase) * deg_to_rad(3.5) * step_weight * ground_blend
			var ground_spine_pitch = deg_to_rad(2.5) * ground_blend
			
			var spine_yaw_q = Quaternion(bone_yaw_axes[b], flight_yaw + ground_spine_yaw)
			var spine_pitch_q = Quaternion(bone_pitch_axes[b], flight_pitch + ground_spine_pitch)
			var spine_roll_q = Quaternion(bone_roll_axes[b], ground_spine_roll) if bone_roll_axes.has(b) else Quaternion.IDENTITY
			sk.set_bone_pose_rotation(b, spine_yaw_q * spine_roll_q * spine_pitch_q * sk.get_bone_pose_rotation(b))

	# 3. ALAS: ASIMETRÍA EN VIRAJES + PLANEO DIEDRO + PLEGADO EN PICADA + APERTURA EN TREPADA + AEROELASTICIDAD
	var fold = clamp(dive_fold_blend, 0.0, 1.0) * (1.0 - ground_blend)
	# Diedro: más marcado en planeo y creciente con la carga del viraje (n = 1/cos(alabeo)).
	var bank_load: float = clampf(1.0 / maxf(cos(rotation.z), 0.35) - 1.0, 0.0, 1.5) * flight_factor
	var glide_dihedral = glide_blend * deg_to_rad(8.0) + bank_load * deg_to_rad(4.5)
	var glide_breathe = sin(tail_wave_time * 1.8) * deg_to_rad(1.5) * glide_blend
	
	# Carrera de potencia en trepada (power downstroke amplitude + forward reach)
	var flap_cycle_phase = _get_flap_cycle_phase()
	var climb_wing_forward = deg_to_rad(12.0) * climb_blend
	# Carrera de potencia amplia (bajada) y recuperación más corta (subida), con alas hacia adelante
	var climb_downstroke_boost = (max(0.0, sin(flap_cycle_phase)) * deg_to_rad(20.0) - max(0.0, -sin(flap_cycle_phase)) * deg_to_rad(8.0)) * climb_blend
	# Flexión del ala media en la subida (la punta se arrastra por la resistencia del aire) + retraso de fase aeroelástico
	var climb_wing_flex = max(0.0, -sin(flap_cycle_phase)) * deg_to_rad(18.0) * climb_blend
	var aero_tip_lag = cos(flap_cycle_phase) * deg_to_rad(8.5) * flight_factor * (1.0 - glide_blend) * (1.0 - fold)
	
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
		var mid_l_pitch = -fold * 0.55 + (glide_breathe * 1.5) - climb_wing_flex + aero_tip_lag
		var mid_l = Quaternion(bone_pitch_axes[bone_l_wing_mid], mid_l_pitch)
		sk.set_bone_pose_rotation(bone_l_wing_mid, mid_l * sk.get_bone_pose_rotation(bone_l_wing_mid))

	if bone_r_wing_mid != -1 and bone_pitch_axes.has(bone_r_wing_mid):
		var mid_r_pitch = -fold * 0.55 + (glide_breathe * 1.5) - climb_wing_flex + aero_tip_lag
		var mid_r = Quaternion(bone_pitch_axes[bone_r_wing_mid], mid_r_pitch)
		sk.set_bone_pose_rotation(bone_r_wing_mid, mid_r * sk.get_bone_pose_rotation(bone_r_wing_mid))

	# The source's held frame is asymmetric. Level equivalent distal joints in body space,
	# rather than assuming mirrored imported quaternion axes have mirrored poses.
	if glide_blend > 0.01 and sk.get_bone_count() > 132:
		var held_weight := glide_blend * (1.0 - wing_fold_blend)
		_aim_bone_direction(sk, 96, 108, global_basis * Vector3(-1.0, 0.075, 0.08), held_weight)
		_aim_bone_direction(sk, 120, 132, global_basis * Vector3(1.0, 0.075, 0.08), held_weight)

	if glide_blend > 0.95 and wing_fold_blend < 0.01 and sk.get_bone_count() > 132:
		if glide_pose_probe.samples.is_empty():
			glide_pose_probe.configure(self, sk, 12)
			glide_pose_probe.samples = glide_pose_probe.samples.filter(func(sample): return sample.wing)
			glide_pose_probe.prepare_coordinates()
		for level_pass in 2:
			var left := Vector3.ZERO
			var right := Vector3.ZERO
			for local in glide_pose_probe.coordinates(sk, self):
				if local.x < left.x: left = local
				if local.x > right.x: right = local
			var center_y := (left.y + right.y) * 0.5
			_aim_bone_skin_point(sk, 96, to_global(left), to_global(Vector3(left.x,center_y,left.z)))
			_aim_bone_skin_point(sk, 120, to_global(right), to_global(Vector3(right.x,center_y,right.z)))

	# A folded wing doubles back at the elbow and long finger joints.
	# Directions are measured on the live rig, independent of imported bone axes.

	# 4. COLA MULTIVERTEBRAL (8 Vértebras: látigo en virajes + contrapeso inercial fluido en marcha terrestre)
	for i in range(bone_tail_indices.size()):
		var b = bone_tail_indices[i]
		if b != -1 and bone_yaw_axes.has(b):
			var idx_ratio = float(i + 1) / float(bone_tail_indices.size())
			var tail_lag_yaw = -turn * (0.022 + 0.018 * idx_ratio) * tail_lag_strength * flight_factor
			var wave_amp = (0.015 + 0.020 * idx_ratio) * (0.12 if fold > 0.5 else 1.0) * flight_factor
			var tail_wave_yaw = sin(tail_wave_time - (i * 0.45)) * wave_amp
			var tail_flap_lag = sin(flap_cycle_phase - (i + 1) * 0.5) * deg_to_rad(1.2 + idx_ratio * 1.5) * climb_blend * flight_factor
			var tail_flight_pitch = ((climb_blend * -0.16 * idx_ratio) + \
							 (brake_blend * -0.14 * idx_ratio) + \
							 (dive_fold_blend * 0.04 * idx_ratio) + \
							 (glide_blend * 0.04 * idx_ratio)) * flight_factor

			# Onda serpentina inercial en marcha terrestre: amplitud natural anatómica
			var step_weight := _gait_weight()
			var ground_tail_phase = walk_cycle_phase - float(i) * 0.55
			# Onda viajera amplia en marcha (ref. Sophocleous): la cola contrapesa cada paso.
			var ground_tail_yaw = sin(ground_tail_phase) * deg_to_rad(2.5 + idx_ratio * 5.5) * step_weight * ground_blend
			var ground_tail_pitch = (ground_blend * -0.08 * idx_ratio) + cos(walk_cycle_phase * 2.0 - float(i) * 0.3) * deg_to_rad(3.0) * step_weight * ground_blend

			# Límites fisiológicos intervertebrales (rango de movimiento según osteología caudal)
			var tail_yaw_limit := deg_to_rad(lerpf(4.5, 7.0, ground_blend))
			var final_tail_yaw = clampf(tail_lag_yaw + tail_wave_yaw + ground_tail_yaw, -tail_yaw_limit, tail_yaw_limit)
			# En vuelo la cola cuelga y latiguea más (trepada); en tierra conserva el rango osteológico.
			var tail_pitch_limit := deg_to_rad(lerpf(5.5, 9.0, flight_factor))
			var final_tail_pitch = clampf(tail_flight_pitch + tail_flap_lag + ground_tail_pitch, -tail_pitch_limit, tail_pitch_limit)

			var t_rot = Quaternion(bone_yaw_axes[b], final_tail_yaw) * \
						Quaternion(bone_pitch_axes[b], final_tail_pitch)
			sk.set_bone_pose_rotation(b, t_rot * sk.get_bone_pose_rotation(b))

	# Recover parents before solving any descendant pose or stance contact.
	# Cola proporcionada: el rig original la trae de ~17 m (casi el doble del torso). Escalar la raíz
	# acorta y afina toda la cadena sin deformarla; las envolventes de contacto siguen siendo conservadoras.
	if bone_tail_indices.size() > 0 and not is_equal_approx(tail_length_scale, 1.0):
		sk.set_bone_pose_scale(bone_tail_indices[0], Vector3.ONE * tail_length_scale)
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
	if not support_ik and rear_preparation <= 0.01:
		var flap_leg_kick = sin(_get_flap_cycle_phase()) * deg_to_rad(3.0) if (is_flapping and anim_player) else 0.0
		# En vuelo, planeo y picada (ref. Dragontwin), las patas traseras se pliegan de forma aerodinámica bajo la base de la cola
		var speed_tuck := clampf(current_speed / cruise_speed, 0.0, 1.2) * deg_to_rad(4.5)
		var leg_pitch = clampf(speed_tuck + (dive_fold_blend * 0.20) + (climb_blend * -0.10) + (glide_blend * 0.06) + flap_leg_kick, -deg_to_rad(10.0), deg_to_rad(15.0))
		if bone_l_thigh != -1 and bone_pitch_axes.has(bone_l_thigh):
			sk.set_bone_pose_rotation(bone_l_thigh, Quaternion(bone_pitch_axes[bone_l_thigh], leg_pitch) * sk.get_bone_pose_rotation(bone_l_thigh))
		if bone_r_thigh != -1 and bone_pitch_axes.has(bone_r_thigh):
			sk.set_bone_pose_rotation(bone_r_thigh, Quaternion(bone_pitch_axes[bone_r_thigh], leg_pitch) * sk.get_bone_pose_rotation(bone_r_thigh))
	var rear_cache: Dictionary = get_meta("air_rear_joint_pose",{})
	var recovering: bool = get_meta("air_rear_prepared",false) and locomotion_state == LocomotionState.FLYING
	var current_tick := Engine.get_physics_frames()
	if sk.get_bone_count() > 82 and (rear_preparation>.01 or recovering):
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
	elif sk.get_bone_count() > 82:
		for b in [5,6,7,20,21,22,39,40,80,81]:
			rear_cache[b]={"rotation":(global_basis.inverse()*sk.global_basis*sk.get_bone_global_pose(b).basis).get_rotation_quaternion(),"tick":current_tick}
		set_meta("air_rear_joint_pose",rear_cache)

	var sample_started := Time.get_ticks_usec() if PoseProbe.profiling else 0
	wing_contact.sample_final(self, sk)
	wing_contact.guard_body_pose(self,sk)
	PoseProbe.record("wing_total",sample_started)


func _refit_compact_wings(sk: Skeleton3D) -> void:
	if sk.get_bone_count() <= 139:
		return
	# El plegado completo compacto es EXCLUSIVO de suelo y aproximación final;
	# en picada aérea las alas usan la postura delta halcón nativa.
	var compact_blend := wing_fold_blend if locomotion_state in [LocomotionState.LANDING, LocomotionState.GROUNDED] else 0.0
	if compact_blend <= 0.001:
		return

	var shoulder_w: float = smoothstep(0.0, 0.85, compact_blend)
	var elbow_w: float = smoothstep(0.08, 0.95, compact_blend)
	var digit_w: float = smoothstep(0.18, 1.0, compact_blend)

	var up: Vector3 = global_basis.y.normalized()
	var right: Vector3 = global_basis.x.normalized()
	var fwd: Vector3 = -global_basis.z.normalized()

	# Rebote secundario elástico en las puntas al caminar (ref. ciclo de marcha Sophocleous)
	var wing_bounce := sin(walk_cycle_phase * 2.0 - 0.4) * deg_to_rad(3.0) * _gait_weight() * compact_blend

	# Ala Izquierda: repliegue anatómico elevado y horizontal a lo largo del lomo/flancos
	_rotate_bone_world(sk, 96, up, deg_to_rad(68.0) * shoulder_w)
	_rotate_bone_world(sk, 96, fwd, deg_to_rad(-28.0) * shoulder_w)
	_rotate_bone_world(sk, 96, right, deg_to_rad(-12.0) * shoulder_w)
	sk.force_update_all_bone_transforms()

	_rotate_bone_world(sk, 97, up, deg_to_rad(-62.0) * elbow_w)
	_rotate_bone_world(sk, 97, right, (deg_to_rad(28.0) + wing_bounce) * elbow_w)
	sk.force_update_all_bone_transforms()

	for dig in [98, 104, 111, 117]:
		_rotate_bone_world(sk, dig, up, deg_to_rad(26.0) * digit_w)
		_rotate_bone_world(sk, dig, right, (deg_to_rad(36.0) + wing_bounce * 1.5) * digit_w)
	sk.force_update_all_bone_transforms()

	# Ala Derecha: simetría bilateral idéntica invertida sobre el plano sagital
	_rotate_bone_world(sk, 120, up, deg_to_rad(-68.0) * shoulder_w)
	_rotate_bone_world(sk, 120, fwd, deg_to_rad(28.0) * shoulder_w)
	_rotate_bone_world(sk, 120, right, deg_to_rad(-12.0) * shoulder_w)
	sk.force_update_all_bone_transforms()

	_rotate_bone_world(sk, 121, up, deg_to_rad(62.0) * elbow_w)
	_rotate_bone_world(sk, 121, right, (deg_to_rad(28.0) + wing_bounce) * elbow_w)
	sk.force_update_all_bone_transforms()

	for dig in [122, 128, 135, 141]:
		_rotate_bone_world(sk, dig, up, deg_to_rad(-26.0) * digit_w)
		_rotate_bone_world(sk, dig, right, (deg_to_rad(36.0) + wing_bounce * 1.5) * digit_w)
	sk.force_update_all_bone_transforms()

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
