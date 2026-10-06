extends Camera3D
class_name FlightCamera

# ==============================================================================
# CÁMARA CINEMÁTICA EN 3ª PERSONA (Perspectiva de Jinete / Sobre el Lomo)
# Por defecto detrás del dragón. Vistas rápidas (V / 1-4) y órbita libre (clic derecho + arrastrar).
# ==============================================================================

enum ViewPreset { BACK, FRONT, RIGHT, LEFT }

@export var target_node: Node3D
@export var distance: float = 16.0              # Distancia óptima detrás del dragón
@export var height: float = 5.0                  # Altura sobre el lomo
@export var follow_smoothness: float = 16.0     # Suavidad y firmeza de seguimiento de posición
@export var rotation_smoothness: float = 14.0   # Respuesta ágil de la orientación
@export var base_fov: float = 74.0              # FOV base inmersivo
@export var max_fov_boost: float = 14.0         # Aumento de FOV en picada a alta velocidad
@export var orbit_sensitivity: float = 0.006    # Sensibilidad de la órbita con el mouse
@export var orbit_return_delay: float = 2.0     # Segundos tras soltar el clic derecho para volver a la vista elegida
@export var orbit_smoothness: float = 8.0       # Suavidad de los cambios de vista

# Rango de zoom interactivo con la rueda del ratón
var target_distance: float = 16.0
var zoom_offset: float = 0.0
var min_distance: float = 5.0
var max_distance: float = 24.0

# Estado de la vista: ángulos orbitales respecto de la vista trasera (rad)
var view_preset: ViewPreset = ViewPreset.BACK
var orbit_yaw_target: float = 0.0
var orbit_pitch_target: float = 0.0
var orbit_yaw: float = 0.0
var orbit_pitch: float = 0.0
var orbiting: bool = false
var return_timer: float = -1.0
var head_follow_blend := 0.0
var collision_probe := SphereShape3D.new()
var collision_pivot_world := Vector3.ZERO

func _sweep_camera(from: Vector3, to: Vector3, excluded: Array[RID]) -> Vector3:
	# Keep the whole near-camera volume clear during the smoothed transition.
	if from.distance_squared_to(to) < 0.000001:
		return to
	collision_probe.radius = 0.2
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision_probe
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.exclude = excluded
	query.collision_mask = 3
	query.margin = 0.0
	# An invalid old pose is repaired by the pivot ray below, rather than retained.
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return to
	query.motion = to - from
	var fractions := get_world_3d().direct_space_state.cast_motion(query)
	if fractions.size() == 2 and fractions[0] < 1.0:
		return from + query.motion * maxf(0.0, fractions[0] - 0.002)
	return to

const PRESET_YAW = {
	ViewPreset.BACK: 0.0,
	ViewPreset.FRONT: PI,
	ViewPreset.RIGHT: PI / 2.0,
	ViewPreset.LEFT: -PI / 2.0,
}

func _ready() -> void:
	fov = base_fov
	target_distance = distance
	if target_node:
		var forward = -target_node.global_transform.basis.z.normalized()
		var up = target_node.global_transform.basis.y.normalized()
		var saddle = target_node.global_position + (up * 0.5)
		global_position = saddle - (forward * distance) + (up * height)
		var look_target = saddle + (forward * 20.0) + (up * 0.2)
		var cam_up = up.slerp(Vector3.UP, 0.35).normalized()
		look_at(look_target, cam_up)

func set_view(preset: ViewPreset) -> void:
	view_preset = preset
	orbit_yaw_target = PRESET_YAW[preset]
	orbit_pitch_target = 0.0
	return_timer = -1.0

func cycle_view() -> void:
	set_view(((view_preset + 1) % 4) as ViewPreset)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Ajuste dinámico de distancia con la rueda del ratón (Zoom In / Out)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_offset = clampf(zoom_offset - 1.0, min_distance - 16.0, max_distance - 16.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_offset = clampf(zoom_offset + 1.0, min_distance - 16.0, max_distance - 16.0)
		# Clic derecho: órbita libre (el cursor se oculta mientras se arrastra)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			orbiting = event.pressed
			if orbiting:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				return_timer = -1.0
			else:
				# Respeta el modo de timón con mouse del dragón (ESC) si está activo
				var steer = target_node != null and "mouse_captured" in target_node and target_node.mouse_captured
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if steer else Input.MOUSE_MODE_VISIBLE)
				return_timer = orbit_return_delay
	elif event is InputEventMouseMotion and orbiting:
		orbit_yaw_target = wrapf(orbit_yaw_target - event.relative.x * orbit_sensitivity, -PI, PI)
		orbit_pitch_target = clamp(orbit_pitch_target + event.relative.y * orbit_sensitivity, -deg_to_rad(60.0), deg_to_rad(75.0))
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_V:
				cycle_view()
			KEY_1:
				set_view(ViewPreset.BACK)
			KEY_2:
				set_view(ViewPreset.FRONT)
			KEY_3:
				set_view(ViewPreset.RIGHT)
			KEY_4:
				set_view(ViewPreset.LEFT)

func _physics_process(delta: float) -> void:
	if not target_node:
		return
		
	# Vuelta automática a la vista elegida tras soltar el clic derecho
	if return_timer >= 0.0:
		return_timer -= delta
		if return_timer < 0.0:
			orbit_yaw_target = PRESET_YAW[view_preset]
			orbit_pitch_target = 0.0
	
	# Interpolar suavemente zoom y ángulos de órbita
	# Adaptación dinámica de altura y distancia al estar en tierra
	var is_ground = target_node and "locomotion_state" in target_node and target_node.locomotion_state == 2 # GROUNDED
	var is_landing = "locomotion_state" in target_node and target_node.locomotion_state == 1
	var attack_view: bool = "attack_mode_active" in target_node and target_node.attack_mode_active
	var head_view = attack_view or ((is_ground or is_landing) and view_preset == ViewPreset.BACK and not orbiting)
	var back_amount = 1.0 - clampf((absf(orbit_yaw) + absf(orbit_pitch)) / 0.6, 0.0, 1.0)
	head_follow_blend = lerpf(head_follow_blend, (1.0 if attack_view else back_amount) if head_view else 0.0, 1.0 - exp(-4.0 * delta))
	var target_h = 3.2 if is_ground else 5.0
	var target_d = clampf((14.0 if is_ground else 18.0) + zoom_offset, min_distance, max_distance)
	height = lerp(height, target_h, 3.0 * delta)
	target_distance = lerp(target_distance, target_d, 3.0 * delta)

	distance = lerp(distance, target_distance, 10.0 * delta)
	var k = 1.0 - exp(-orbit_smoothness * delta)
	orbit_yaw = lerp_angle(orbit_yaw, orbit_yaw_target, k)
	orbit_pitch = lerp(orbit_pitch, orbit_pitch_target, k)
	
	# 1. Vectores de orientación del dragón
	var forward = -target_node.global_transform.basis.z.normalized()
	var up = target_node.global_transform.basis.y.normalized()
	var right = target_node.global_transform.basis.x.normalized()
	
	# 2. Punto pivote: la cruz / montura del dragón (entre las alas)
	var saddle = target_node.global_position + (up * 0.5)
	collision_pivot_world = saddle
	
	# 3. Dirección de cámara: parte desde "detrás" y se orbita (giro sobre el eje arriba y luego elevación)
	var back_dir = -forward
	var orbit_dir = back_dir.rotated(up, orbit_yaw)
	var orbit_right = right.rotated(up, orbit_yaw)
	orbit_dir = orbit_dir.rotated(orbit_right, -orbit_pitch)
	var desired_pos = saddle + (orbit_dir * distance) + (up * height * cos(orbit_pitch))
	var chase_target = saddle + (forward * 20.0) + (up * 0.2)
	var breath = target_node.get_node_or_null("DragonBreath")
	if breath and head_follow_blend > 0.001 and breath.mouth_pose_cached:
		# Stay above the front of the skull: the old shoulder position let the
		# folded or beating wings cover soldiers while retreating or attacking.
		var mouth: Vector3 = target_node.to_global(breath.mouth_actor_local)
		var head_direction: Vector3 = (target_node.global_basis*breath.direction_actor_local).normalized()
		var skull_back := clampf(0.7 + zoom_offset * 0.15, 0.25, 1.9)
		var skull_height := clampf(2.2 + zoom_offset * 0.12, 1.5, 3.2)
		var head_camera: Vector3 = mouth - head_direction * skull_back + Vector3.UP * skull_height
		desired_pos = desired_pos.lerp(head_camera, head_follow_blend)
		chase_target = chase_target.lerp(mouth + head_direction * 14.0, head_follow_blend)
		collision_pivot_world = saddle.lerp(mouth + Vector3.UP * 0.2, head_follow_blend)
	
	# 4. Prevención de colisión con el terreno (No atravesar montañas ni suelo)
	var space_state = get_world_3d().direct_space_state
	var ray_query = PhysicsRayQueryParameters3D.create(collision_pivot_world, desired_pos, 3)
	if target_node is CollisionObject3D:
		ray_query.exclude = [(target_node as CollisionObject3D).get_rid()]
	
	var ray_hit = space_state.intersect_ray(ray_query)
	if ray_hit:
		desired_pos = ray_hit.position + (ray_hit.normal * 0.8)
		
	# Clamp de altura mínima sobre el suelo absoluto
	desired_pos.y = max(desired_pos.y, 2.0)
	
	var excluded: Array[RID] = []
	excluded.assign(ray_query.exclude)
	desired_pos = _sweep_camera(collision_pivot_world, desired_pos, excluded)
	var previous := global_position
	global_position = _sweep_camera(previous, previous.lerp(desired_pos, 1.0 - exp(-follow_smoothness * delta)), excluded)
	# Recheck the smoothed path: the interpolation itself must not cut through hills.
	var final_ray = PhysicsRayQueryParameters3D.create(collision_pivot_world, global_position, 3)
	final_ray.exclude = ray_query.exclude
	var final_hit = space_state.intersect_ray(final_ray)
	if final_hit:
		global_position = final_hit.position + final_hit.normal * 0.8
	
	# 5. Orientación: en la vista trasera mira al horizonte; al orbitar mira al dragón
	var orbit_amount = 0.0 if attack_view else clamp((absf(orbit_yaw) + absf(orbit_pitch)) / 0.6, 0.0, 1.0)
	var look_target = chase_target.lerp(saddle, orbit_amount)
	
	# El vector UP de la cámara acompaña el alabeo (bank roll) del dragón para un manejo intuitivo
	var pitch_steepness = clamp(absf(forward.y), 0.0, 1.0)
	var cam_up = up.lerp(Vector3.UP, lerp(0.35, 0.90, pitch_steepness)).normalized()
	if attack_view or absf(orbit_pitch) > 0.5 or cam_up.length_squared() < 0.5:
		cam_up = Vector3.UP
	
	var current_transform = global_transform
	var to_look = look_target - global_position
	if to_look.length_squared() > 0.01:
		var look_dir = to_look.normalized()
		if absf(cam_up.dot(look_dir)) > 0.92 or cam_up.length_squared() < 0.1:
			cam_up = Vector3.UP if absf(look_dir.y) < 0.95 else Vector3.FORWARD
		var target_transform = current_transform.looking_at(look_target, cam_up)
		global_transform = current_transform.interpolate_with(target_transform, 1.0 - exp(-rotation_smoothness * delta))
	
	# 6. Efecto dinámico de FOV según velocidad
	if target_node and "current_speed" in target_node:
		var speed_ratio = clamp((target_node.current_speed - 20.0) / 40.0, 0.0, 1.0)
		var target_fov = base_fov + (speed_ratio * max_fov_boost)
		fov = lerp(fov, target_fov, 4.0 * delta)
