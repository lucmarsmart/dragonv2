extends CanvasLayer

@export var dragon: CharacterBody3D

@onready var speed_label: Label = $VBoxContainer/SpeedLabel
@onready var alt_label: Label = $VBoxContainer/AltLabel
@onready var state_label: Label = $VBoxContainer/StateLabel
@onready var controls_panel: PanelContainer = $ControlsPanel

# Botones de modo interactivos en pantalla
@onready var btn_normal: Button = get_node_or_null("ActionBar/HBoxContainer/BtnNormal")
@onready var btn_climb: Button = get_node_or_null("ActionBar/HBoxContainer/BtnClimb")
@onready var btn_glide: Button = get_node_or_null("ActionBar/HBoxContainer/BtnGlide")
@onready var btn_dive: Button = get_node_or_null("ActionBar/HBoxContainer/BtnDive")
@onready var btn_land: Button = get_node_or_null("ActionBar/HBoxContainer/BtnLand")

func _ready() -> void:
	if btn_normal:
		btn_normal.pressed.connect(_on_normal_pressed)
	if btn_climb:
		btn_climb.pressed.connect(_on_climb_pressed)
	if btn_glide:
		btn_glide.pressed.connect(_on_glide_pressed)
	if btn_dive:
		btn_dive.pressed.connect(_on_dive_pressed)
	if btn_land:
		btn_land.pressed.connect(_on_land_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H or event.keycode == KEY_F1:
			if controls_panel:
				controls_panel.visible = !controls_panel.visible

func _on_normal_pressed() -> void:
	if dragon and dragon.has_method("trigger_normal"):
		dragon.trigger_normal()

func _on_climb_pressed() -> void:
	if dragon and dragon.has_method("trigger_climb"):
		dragon.trigger_climb()

func _on_glide_pressed() -> void:
	if dragon and dragon.has_method("toggle_glide"):
		dragon.toggle_glide()

func _on_dive_pressed() -> void:
	if dragon and dragon.has_method("toggle_dive"):
		dragon.toggle_dive()

func _on_land_pressed() -> void:
	if dragon and dragon.has_method("toggle_land_takeoff"):
		dragon.toggle_land_takeoff()

func _process(_delta: float) -> void:
	if not dragon:
		return
		
	var speed_kmh = dragon.current_speed * 3.6
	var altitude = dragon.global_position.y
	
	if speed_label:
		speed_label.text = "VELOCIDAD: %d km/h" % int(speed_kmh)
	if alt_label:
		alt_label.text = "ALTITUD: %d m" % int(altitude)
		
	if state_label:
		var state_str = "VUELO NORMAL (CICLO SYMMONDS)"
		var state_color = Color(0.4, 0.75, 1.0, 1.0)
		
		if "locomotion_state" in dragon:
			match dragon.locomotion_state:
				dragon.LocomotionState.GROUNDED:
					if abs(dragon.current_speed) > 0.2:
						state_str = "🐾 EN TIERRA: CAMINANDO (%s)" % ("CARRERA" if Input.is_key_pressed(KEY_SHIFT) else "PASO")
					else:
						state_str = "🐾 EN TIERRA: REPOSO (ALAS PLEGADAS)"
					state_color = Color(0.4, 0.95, 0.4, 1.0)
				dragon.LocomotionState.LANDING:
					state_str = "⬇ ATERRIZANDO (FLARE / APROXIMACIÓN)"
					state_color = Color(1.0, 0.7, 0.2, 1.0)
				dragon.LocomotionState.TAKING_OFF:
					state_str = "⬆ DESPEGANDO (IMPULSO VERTICAL)"
					state_color = Color(0.3, 0.9, 1.0, 1.0)
				dragon.LocomotionState.FLYING:
					if "is_touching_ground" in dragon and dragon.is_touching_ground:
						state_str = "RASANTE / CONTACTO CON TERRENO"
						state_color = Color(1.0, 0.6, 0.2, 1.0)
					elif "ground_proximity" in dragon and dragon.ground_proximity < 12.0:
						state_str = "EFECTO SUELO (%d m) - COJÍN DE AIRE" % int(dragon.ground_proximity)
						state_color = Color(0.3, 0.9, 0.6, 1.0)
					elif "current_mode" in dragon:
						match dragon.current_mode:
							dragon.FlightMode.CLIMB:
								state_str = "▲ SUBIENDO (CLIMB / TREPADA)"
								state_color = Color(0.2, 0.95, 0.5, 1.0)
							dragon.FlightMode.GLIDE:
								state_str = "✈ MODO PLANEO (GLIDE)"
								state_color = Color(1.0, 0.85, 0.25, 1.0)
							dragon.FlightMode.DIVE:
								state_str = "▼ EN PICADA (DIVE CONTROLADO)"
								state_color = Color(1.0, 0.45, 0.35, 1.0)
							dragon.FlightMode.BRAKE:
								state_str = "■ FRENADO AERODINÁMICO (AIRBRAKE)"
								state_color = Color(0.9, 0.3, 0.3, 1.0)
							dragon.FlightMode.NORMAL:
								state_str = "● VUELO NORMAL (CICLO SYMMONDS)"
								state_color = Color(0.4, 0.75, 1.0, 1.0)
					
		state_label.text = "ESTADO: " + state_str
		state_label.modulate = state_color

	# Actualizar resaltado de los botones de la barra de acciones
	if "current_mode" in dragon and "locomotion_state" in dragon:
		var mode = dragon.current_mode
		var is_ground = dragon.locomotion_state == dragon.LocomotionState.GROUNDED
		var is_landing = dragon.locomotion_state == dragon.LocomotionState.LANDING
		
		if btn_normal:
			btn_normal.modulate = Color(1.3, 1.3, 1.3) if (mode == dragon.FlightMode.NORMAL and not is_ground) else Color(0.75, 0.75, 0.75, 0.9)
		if btn_climb:
			btn_climb.modulate = Color(0.4, 1.4, 0.6) if mode == dragon.FlightMode.CLIMB else Color(0.75, 0.75, 0.75, 0.9)
		if btn_glide:
			btn_glide.modulate = Color(1.4, 1.25, 0.3) if mode == dragon.FlightMode.GLIDE else Color(0.75, 0.75, 0.75, 0.9)
		if btn_dive:
			btn_dive.modulate = Color(1.4, 0.5, 0.4) if mode == dragon.FlightMode.DIVE else Color(0.75, 0.75, 0.75, 0.9)
		if btn_land:
			btn_land.modulate = Color(1.4, 1.2, 0.4) if (is_ground or is_landing) else Color(0.75, 0.75, 0.75, 0.9)
			btn_land.text = " ⬆ DESPEGAR [L] " if is_ground else " ⬇ ATERRIZAR [L] "
