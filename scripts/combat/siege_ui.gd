extends CanvasLayer

var combat: SiegeCombat
var overlay: ColorRect
var panel: PanelContainer
var title: Label
var story: Label
var action: Button
var secondary: Button
var objective: Label
var health_bar: ProgressBar
var health_text: Label
var event_label: Label
var damage_overlay: ColorRect
var waypoint: Label
var credits_visible := false
var paused_menu := false
var credit_links: HFlowContainer
const INK := Color(0.026,0.042,0.047,0.94)
const GOLD := Color(1.0,0.76,0.36)
const WHITE := Color(0.94,0.94,0.87)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 4
	combat = get_parent().get_node("SiegeCombat")
	var root_ui := Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ui)
	damage_overlay = ColorRect.new()
	damage_overlay.color = Color(0.6,0.03,0.015,0)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.add_child(damage_overlay)
	var health_box := VBoxContainer.new()
	health_box.position = Vector2(24,400)
	health_box.name = "Health"
	root_ui.add_child(health_box)
	health_text = _label("INTEGRIDAD DEL GUARDIÁN",15)
	health_box.add_child(health_text)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(220,14)
	health_bar.max_value = combat.max_health
	health_bar.show_percentage = false
	health_bar.add_theme_stylebox_override("background",_box(Color(0.08,0.08,0.075,0.8),Color(0.25,0.30,0.28)))
	health_bar.add_theme_stylebox_override("fill",_box(Color(0.65,0.24,0.1),Color(0.85,0.45,0.2)))
	health_box.add_child(health_bar)
	objective = _label("",18)
	objective.name = "Objective"
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.size = Vector2(420,72)
	root_ui.add_child(objective)
	event_label = _label("",18)
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_label.size = Vector2(600,70)
	root_ui.add_child(event_label)
	waypoint = _label("◆",26)
	waypoint.modulate = GOLD
	waypoint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(waypoint)
	overlay = ColorRect.new()
	overlay.color = Color(0.01,0.02,0.025,0.58)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",_box(INK,Color(0.7,0.55,0.28,0.8)))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["margin_left","margin_right","margin_top","margin_bottom"]:
		margin.add_theme_constant_override(edge,24)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	margin.add_child(column)
	var eyebrow := _label("CRÓNICAS DEL VALLE DE CENIZA",14)
	eyebrow.modulate = GOLD
	column.add_child(eyebrow)
	title = _label("EL ÚLTIMO GUARDIÁN",32)
	column.add_child(title)
	story = _label("",18)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(story)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	column.add_child(row)
	action = _button("INICIAR ASEDIO [ENTER]")
	row.add_child(action)
	action.pressed.connect(_activate)
	secondary = _button("CRÉDITOS")
	row.add_child(secondary)
	secondary.pressed.connect(func(): credits_visible = not credits_visible; _refresh())
	credit_links = HFlowContainer.new()
	credit_links.add_theme_constant_override("h_separation",12)
	credit_links.add_theme_constant_override("v_separation",8)
	column.add_child(credit_links)
	for entry in [["ARMADURA", "https://github.com/SaschaWillems/Vulkan-Assets/tree/a27c0e584434d59b7c7a714e9180eefca6f0ec4b/models/armor"], ["BALLISTA", "https://github.com/Hidencod/tge-assets/blob/1f7dee9076ee848773f08fd632ab4e4e73357777/packs/castle-kit/siege-ballista.glb"], ["VIROTE", "https://opengameart.org/content/ballista-bolt"], ["ENTORNO", "https://polyhaven.com/models"], ["CC BY 3.0", "https://creativecommons.org/licenses/by/3.0/"], ["CC0", "https://creativecommons.org/publicdomain/zero/1.0/"]]:
		var link := _button(entry[0])
		link.custom_minimum_size.x = 150
		var url: String = entry[1]
		link.pressed.connect(func(): OS.shell_open(url))
		credit_links.add_child(link)
	combat.state_changed.connect(_refresh)
	get_viewport().size_changed.connect(_resize)
	_resize()
	_refresh()

func _box(fill: Color,border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style

func _label(content: String,font_size: int) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_color_override("font_color",WHITE)
	label.add_theme_color_override("font_outline_color",Color(0.01,0.02,0.02,0.9))
	label.add_theme_constant_override("outline_size",3)
	label.add_theme_font_size_override("font_size",font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(content: String) -> Button:
	var button := Button.new()
	button.text = content
	button.custom_minimum_size = Vector2(210,48)
	button.add_theme_font_size_override("font_size",16)
	for state in ["normal","hover","pressed","focus"]:
		button.add_theme_stylebox_override(state,_box(Color(0.14,0.19,0.17,1),GOLD if state != "normal" else Color(0.4,0.48,0.40)))
	button.add_theme_color_override("font_color",WHITE)
	return button

func _resize() -> void:
	var size := get_viewport().get_visible_rect().size
	panel.custom_minimum_size.x = minf(800,size.x-48)
	panel.size = Vector2(panel.custom_minimum_size.x,0)
	title.add_theme_font_size_override("font_size",28 if size.x < 1000 else 32)
	story.add_theme_font_size_override("font_size",16 if size.x < 1000 else 18)
	var root_ui: Control = damage_overlay.get_parent()
	root_ui.get_node("Health").position = Vector2(24,size.y-110)
	objective.position = Vector2(maxf(300,size.x-440),98)
	objective.size.x = minf(420,size.x*0.43)
	event_label.position = Vector2((size.x-minf(600,size.x-48))/2,size.y-148)
	event_label.size.x = minf(600,size.x-48)

func _refresh() -> void:
	var popup := combat.phase == combat.Phase.BRIEFING or combat.phase == combat.Phase.VICTORY or combat.phase == combat.Phase.DEFEAT or paused_menu
	overlay.visible = popup
	health_bar.get_parent().visible = not popup
	objective.visible = not popup
	event_label.visible = not popup
	credit_links.visible = popup and credits_visible
	get_parent().get_node("HUD").visible = not popup
	if not popup:
		credits_visible = false
		return
	if credits_visible:
		title.text = "CRÉDITOS Y PROCEDENCIA"
		story.text = "Armadura: piacenti · CC BY 3.0; versión PBR de Sascha Willems en GitHub. Rig y animaciones propios.\nBallista: Kenney · CC0; modelo de GitHub, mecanismo y materiales adaptados.\nVirote: Kutejnikov / drumdorf · CC BY 3.0.\nCastillo, rocas, árboles y materiales: autores de Poly Haven · CC0.\nFaroles: Microsoft / sbtron · CC0.\nLos botones abren las fuentes originales."
		secondary.text = "VOLVER"
	else:
		secondary.text = "CRÉDITOS"
		title.text = "EL ÚLTIMO GUARDIÁN"
		if paused_menu:
			story.text = "El valle espera.\n\nPulsa T una vez para entrar o salir del ataque.\nW/S te mueven; ratón apunta y gira el cuerpo; clic izquierdo exhala.\nLa cámara se coloca sobre la cabeza.\nL aterriza/despega; P cierra esta pausa; H muestra los controles."
			action.text = "CONTINUAR [P]"
		elif combat.phase == combat.Phase.BRIEFING:
			story.text = "La Orden del Hierro ha ocupado el paso de Cuervo Gris. Sus ballistas dominan el cielo; sus caballeros custodian el último nido del valle.\n\nEres su antiguo guardián. Destruye las tres ballistas, derrota al capitán y rompe las cadenas del nido. Después escapa por el paso del sur.\n\nT: activar/desactivar ataque con una pulsación\nW/S: moverse · Ratón: apuntar/girar · Clic izquierdo: fuego\nEspacio: subir · L: aterrizar/despegar · H: ayuda · P: pausa"
			action.text = "INICIAR ASEDIO [ENTER]"
		elif combat.phase == combat.Phase.VICTORY:
			story.text = "La Orden pierde su dominio sobre el cielo. La última cría vuelve a sentir el calor de su guardián. El valle no olvida a quien regresó.\n\nAsedio completado en %d:%02d. Ballistas destruidas: %d.\nPuedes volver a jugar desde el inicio." % [int(combat.active_time)/60,int(combat.active_time)%60,combat.turrets_destroyed]
			action.text = "VOLVER A JUGAR [R]"
		else:
			story.text = "El guardián ha caído, pero el nido sigue esperando.\n\nEvita los virotes: el destello rojo anuncia el disparo. Acércate a las defensas por los flancos y dirige el fuego con T.\n\nReintenta el asedio con el valle, los enemigos y tu salud restaurados."
			action.text = "REINTENTAR [R]"
	action.disabled = not combat.initialized
	var focused := get_viewport().gui_get_focus_owner()
	if popup and (not focused is Button or not panel.is_ancestor_of(focused) or not focused.is_visible_in_tree()):
		action.grab_focus()
	call_deferred("_resize")

func _activate() -> void:
	if paused_menu:
		paused_menu = false
		get_tree().paused = false
		_refresh()
	elif combat.phase == combat.Phase.BRIEFING:
		combat.start_mission()
	else:
		combat.retry()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_P and combat.is_running():
		paused_menu = not paused_menu
		get_tree().paused = paused_menu
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if paused_menu else (Input.MOUSE_MODE_CAPTURED if combat.dragon.mouse_captured else Input.MOUSE_MODE_VISIBLE))
		_refresh()
		get_viewport().set_input_as_handled()
	elif overlay.visible and event.keycode == KEY_R:
		_activate()
		get_viewport().set_input_as_handled()
	elif overlay.visible and event.keycode in [KEY_ENTER,KEY_KP_ENTER]:
		# Start/retry responds on key-down; other focused controls retain normal GUI activation.
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button and focused != action and focused.is_visible_in_tree():
			return
		_activate()
		get_viewport().set_input_as_handled()
	elif overlay.visible and event.keycode not in [KEY_TAB,KEY_SPACE,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not is_instance_valid(combat) or not combat.initialized:
		return
	var help_open: bool = get_parent().get_node("HUD").controls_panel.visible
	var unobscured: bool = not overlay.visible and not help_open
	health_bar.get_parent().visible = unobscured
	objective.visible = unobscured
	event_label.visible = unobscured
	health_bar.value = combat.health
	health_text.text = "GUARDIÁN  %d / %d" % [ceil(combat.health),combat.max_health]
	objective.text = combat.objective_text()
	damage_overlay.color.a = combat.hit_flash * 1.4
	event_label.text = combat.event_text if combat.event_life > 0 else ""
	waypoint.visible = combat.is_running() and unobscured
	var camera := get_viewport().get_camera_3d()
	if waypoint.visible and camera:
		var target := combat.objective_position()
		var point := camera.unproject_position(target)
		var size := get_viewport().get_visible_rect().size
		if camera.is_position_behind(target):
			point = Vector2(size.x/2,size.y-200)
			waypoint.text = "▼ OBJETIVO DETRÁS"
		else:
			waypoint.text = "◆ %d m" % roundi(target.distance_to(combat.dragon.global_position))
		waypoint.position = point.clamp(Vector2(24,190),size-Vector2(220,190))
