extends CanvasLayer

@export var dragon: CharacterBody3D
@onready var speed_label: Label = $VBoxContainer/SpeedLabel
@onready var alt_label: Label = $VBoxContainer/AltLabel
@onready var state_label: Label = $VBoxContainer/StateLabel
@onready var breath_label: Label = $VBoxContainer/BreathLabel
@onready var controls_panel: PanelContainer = $ControlsPanel
@onready var action_bar: PanelContainer = $ActionBar
@onready var buttons: HBoxContainer = $ActionBar/HBoxContainer
@onready var btn_normal: Button = $ActionBar/HBoxContainer/BtnNormal
@onready var btn_climb: Button = $ActionBar/HBoxContainer/BtnClimb
@onready var btn_glide: Button = $ActionBar/HBoxContainer/BtnGlide
@onready var btn_dive: Button = $ActionBar/HBoxContainer/BtnDive
@onready var btn_land: Button = $ActionBar/HBoxContainer/BtnLand
@onready var btn_fire: Button = $ActionBar/HBoxContainer/BtnFire
var breath: DragonBreath
var btn_aim: Button
const ArceusReticle = preload("res://scripts/combat/arceus_reticle.gd")
var reticle: ArceusReticle
var aim_preview_point := Vector3.ZERO
var aim_preview_distance := 26.0
var aim_preview_collider_id := 0
var aim_preview_tick := -1
const INK := Color(0.035,0.055,0.065,0.87)
const TEXT := Color(0.95,0.94,0.85)
const GOLD := Color(1.0,0.76,0.36)

func _ready() -> void:
	breath = dragon.get_node("DragonBreath") as DragonBreath
	btn_aim = Button.new()
	btn_aim.name = "BtnAim"
	btn_aim.text = "ATAQUE [T]"
	buttons.add_child(btn_aim)
	btn_aim.pressed.connect(func():
		# Share the controller's one-pulse transition for button and keyboard.
		var event := InputEventKey.new()
		event.keycode = KEY_T
		event.physical_keycode = KEY_T
		event.pressed = true
		Input.parse_input_event(event)
		var release_event := InputEventKey.new()
		release_event.keycode = KEY_T
		release_event.physical_keycode = KEY_T
		release_event.pressed = false
		Input.parse_input_event(release_event))
	reticle = ArceusReticle.new()
	reticle.name = "ArceusReticle"
	add_child(reticle)
	btn_normal.pressed.connect(dragon.trigger_normal)
	btn_climb.pressed.connect(dragon.trigger_climb)
	btn_glide.pressed.connect(dragon.toggle_glide)
	btn_dive.pressed.connect(dragon.toggle_dive)
	btn_land.pressed.connect(dragon.toggle_land_takeoff)
	btn_fire.button_down.connect(func(): breath.set_firing(true))
	btn_fire.button_up.connect(func(): breath.set_firing(false))
	var panel := _box(INK, Color(0.35,0.4,0.38,0.55))
	action_bar.add_theme_stylebox_override("panel", panel)
	controls_panel.add_theme_stylebox_override("panel", panel)
	for button: Button in buttons.get_children():
		button.custom_minimum_size = Vector2(120,48)
		button.add_theme_font_size_override("font_size",14)
		button.add_theme_stylebox_override("normal", _box(Color(0.075,0.105,0.11,0.95), Color(0.28,0.34,0.32)))
		button.add_theme_stylebox_override("hover", _box(Color(0.14,0.20,0.19,1), GOLD))
		button.add_theme_stylebox_override("pressed", _box(Color(0.23,0.27,0.18,1), GOLD))
		button.add_theme_stylebox_override("focus", _box(Color(0,0,0,0), GOLD, 2))
		button.add_theme_color_override("font_color", TEXT)
		button.add_theme_color_override("font_disabled_color", Color(0.53,0.58,0.57))
		button.add_theme_stylebox_override("disabled", _box(Color(0.05,0.07,0.075,0.8), Color(0.17,0.21,0.22)))
	for label: Label in $VBoxContainer.get_children():
		label.add_theme_color_override("font_color", TEXT)
		label.add_theme_color_override("font_shadow_color", Color(0.015,0.02,0.02,0.95))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.add_theme_constant_override("outline_size", 3)
		label.add_theme_color_override("font_outline_color", Color(0.015,0.025,0.03,0.7))
	btn_normal.text = "VUELO [W]"
	btn_climb.text = "SUBIR [ESP]"
	btn_glide.text = "PLANEAR [G]"
	btn_dive.text = "PICADA [C]"
	btn_fire.text = "FUEGO [F]"
	$ControlsPanel/MarginContainer/HelpLabel.add_theme_color_override("font_color", TEXT)
	$HintLabel.add_theme_color_override("font_color", TEXT)
	$HintLabel.add_theme_color_override("font_shadow_color", Color.BLACK)
	$HintLabel.add_theme_constant_override("shadow_offset_y",2)
	$HintLabel.text = "Auto-fijación de enemigos estilo Arceus · TAB cambiar objetivo · T ataque · F fuego · W/S mover · L aterrizar · H ayuda"
	$ControlsPanel/MarginContainer/HelpLabel.text = "SISTEMA DE BATALLA Y FIJACIÓN (ESTILO POKÉMON LEYENDAS: ARCEUS)\n• La mira se fija automáticamente en el enemigo más cercano en combate y lo sigue\n• TAB: Alternar / cambiar al siguiente enemigo cercano\n• El dragón orienta su cabeza y fuego hacia el objetivo fijado hasta que este se aleja o muere\n• T: Activar / desactivar modo ataque libre y rotación con ratón\n• F o Clic izquierdo: Exhalar fuego directo al objetivo\n\nVUELO\nW/Shift acelerar · S frenar · Espacio/R subir · C/Ctrl picada · G planear\nL aterrizar/cancelar/despegar\n\nOTROS CONTROLES\nA/D girar · Flechas apuntar · Shift correr en tierra\n\nCÁMARA Y MISIÓN\nV/1–4 vista · Botón derecho orbitar · Rueda zoom · E liberar nido\nH/F1 ayuda · P pausa · Esc alterna cursor"
	get_viewport().size_changed.connect(_resize)
	_resize()

func _box(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_border_width_all(width)
	style.border_color = border
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style

func _resize() -> void:
	var view_size := get_viewport().get_visible_rect().size
	var bar_width := minf(1032, view_size.x - 32)
	action_bar.offset_left = -bar_width / 2
	action_bar.offset_right = bar_width / 2
	buttons.add_theme_constant_override("separation", 6)
	controls_panel.offset_left = -minf(720, view_size.x - 32)
	controls_panel.offset_top = -minf(380, view_size.y - 150)

func _input(event: InputEvent) -> void:
	# SPACE is the flight control even after a mouse click gives a button focus.
	# ENTER remains the explicit GUI activation key.
	if event is InputEventKey and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and breath:
		breath.set_firing(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H or event.keycode == KEY_F1:
			controls_panel.visible = not controls_panel.visible

func _physics_process(_delta: float) -> void:
	_update_aim_preview()

func _update_aim_preview() -> void:
	if not dragon or not breath or not dragon.head_aim_active:
		return
	# Aim preview is independent of fuel/fire; the last fired impact is stale
	# whenever the player turns the head or moves without exhaling.
	var origin: Vector3 = breath.mouth_position
	var direction: Vector3 = breath.breath_direction.normalized()
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + direction * breath.max_reach, 7)
	ray.exclude = [dragon.get_rid()]
	var hit := dragon.get_world_3d().direct_space_state.intersect_ray(ray)
	aim_preview_point = hit.position if not hit.is_empty() else origin + direction * breath.max_reach
	aim_preview_distance = origin.distance_to(aim_preview_point)
	aim_preview_collider_id = int(hit.collider_id) if not hit.is_empty() else 0
	aim_preview_tick = Engine.get_physics_frames()

func _process(_delta: float) -> void:
	if not dragon:
		return
	# Render pose may have completed after the physics callback. Project the
	# same final mouth that emits the visible flame, including silent aiming.
	_update_aim_preview()
	var grounded: bool = dragon.locomotion_state == dragon.LocomotionState.GROUNDED
	var landing: bool = dragon.locomotion_state == dragon.LocomotionState.LANDING
	var taking_off: bool = dragon.locomotion_state == dragon.LocomotionState.TAKING_OFF
	speed_label.text = "VELOCIDAD  %d km/h" % int(dragon.velocity.length() * 3.6)
	alt_label.text = "SOBRE TERRENO  %d m" % int(maxf(0, dragon.ground_proximity - 3.5)) if dragon.ground_proximity < 900 else "ALTITUD  %d m" % int(dragon.global_position.y)
	var state := "VUELO"
	if grounded:
		state = "CAMINANDO" if absf(dragon.current_speed) > 0.2 else "EN TIERRA"
	elif landing:
		state = "ATERRIZANDO · L para cancelar"
	elif taking_off:
		state = "DESPEGANDO"
	else:
		state = ["VUELO", "PLANEO", "ASCENSO", "PICADA", "FRENADO"][dragon.current_mode]
	if dragon.recovery_message != "":
		state += " · " + dragon.recovery_message
	state_label.text = state
	state_label.modulate = GOLD
	breath_label.text = "FUEGO  %d%% · %s" % [roundi(breath.fuel * 100), "RECUPERANDO" if breath.exhausted else ("EXHALANDO" if breath.is_firing else "LISTO")]
	breath_label.modulate = Color(1,0.66,0.33) if breath.is_firing else TEXT
	btn_fire.disabled = breath.exhausted
	if breath.exhausted:
		breath.set_firing(false)
	btn_climb.disabled = grounded or landing or taking_off
	btn_dive.disabled = grounded or landing or taking_off
	btn_glide.disabled = grounded or landing or taking_off
	btn_normal.disabled = grounded or landing or taking_off
	btn_land.disabled = taking_off
	btn_land.text = "DESPEGAR [L]" if grounded else ("CANCELAR [L]" if landing else "ATERRIZAR [L]")
	for b: Button in [btn_normal,btn_climb,btn_glide,btn_dive]:
		b.modulate = TEXT
	if not grounded and not landing and not taking_off:
		var active: Button = [btn_normal,btn_glide,btn_climb,btn_dive,btn_normal][dragon.current_mode]
		active.modulate = GOLD
	btn_fire.modulate = GOLD if breath.is_firing else TEXT
	btn_aim.modulate = GOLD if dragon.head_aim_active else TEXT
	var combat_node: Node = get_parent().get_node_or_null("SiegeCombat")
	var in_combat: bool = is_instance_valid(combat_node) and combat_node.has_method("is_running") and combat_node.is_running()
	reticle.visible = (dragon.head_aim_active or dragon.attack_mode_active or in_combat) and not controls_panel.visible
	if reticle.visible:
		var camera := get_viewport().get_camera_3d()
		var locked_enemy: CharacterBody3D = dragon.get_locked_target() if dragon.has_method("get_locked_target") else null
		var target: Vector3 = aim_preview_point
		var target_dist: float = aim_preview_distance
		if is_instance_valid(locked_enemy):
			target = dragon._get_target_aim_point(locked_enemy) if dragon.has_method("_get_target_aim_point") else (locked_enemy.global_position + Vector3.UP)
			var mouth: Vector3 = breath.mouth_position if (breath and breath.mouth_pose_cached) else dragon.global_position
			target_dist = mouth.distance_to(target)
		if camera and not camera.is_position_behind(target):
			var screen_pos := camera.unproject_position(target)
			reticle.update_tracking(screen_pos, locked_enemy, breath.is_firing if breath else false, target_dist, _delta)
			var contact := instance_from_id(aim_preview_collider_id) if aim_preview_collider_id else null
			reticle.modulate = Color(1.0, 0.45, 0.16) if (is_instance_valid(contact) and contact.is_in_group("siege_enemy")) or is_instance_valid(locked_enemy) else Color.WHITE
		else:
			reticle.visible = false
