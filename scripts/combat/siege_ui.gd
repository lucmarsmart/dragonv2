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

# Compatibilidad y estado
var credits_visible := false
var paused_menu := false
var credit_links: HFlowContainer

# Componentes nuevos de la Pantalla de Inicio y Prólogo
var main_layout: HBoxContainer
var story_panel: PanelContainer
var actions_panel: PanelContainer

var story_tex_rect: TextureRect
var story_tag_label: Label
var story_title_label: Label
var story_text_label: Label
var story_hint_label: Label

var tab_buttons: Array[Button] = []
var dot_buttons: Array[Button] = []
var btn_prev: Button
var btn_next: Button
var btn_auto: Button

var btn_free_flight: Button
var btn_difficulty: Button
var btn_guide: Button
var btn_roar: Button
var btn_return_menu: Button

var controls_modal: PanelContainer
var controls_visible := false

var story_textures: Array[Texture2D] = []
var current_slide := 0
var auto_slide_enabled := false
var slide_timer := 0.0
const SLIDE_DURATION := 7.0

const INK := Color(0.024, 0.038, 0.048, 0.96)
const INK_CARD := Color(0.035, 0.052, 0.065, 0.92)
const GOLD := Color(1.0, 0.78, 0.36)
const GOLD_DIM := Color(0.72, 0.58, 0.30)
const WHITE := Color(0.95, 0.95, 0.90)
const EMBER := Color(0.95, 0.42, 0.16)
const TEAL := Color(0.24, 0.68, 0.62)

const STORY_DATA := [
	{
		"tab": "I. EL DRAGÓN",
		"tag": "✦ EL GUARDIÁN ANCESTRAL",
		"title": "EL DESPERTAR DEL DRAGÓN DE OBSIDIANA",
		"text": "Durante eones, el Valle de Ceniza gozó de paz bajo las alas del Gran Dragón de Obsidiana. Sus corrientes gobernaban los vientos de las cumbres sagradas y su fuego mantenía el equilibrio milenario.\n\nMas un letargo de décadas sumió a la bestia en un sueño profundo... permitiendo que una sombra de acero avanzara sobre las cordilleras.",
		"hint": "◆ HABILIDADES DE VUELO:\n• W: Batir alas y acelerar  • G: Planear sin perder altura\n• ESPACIO: Ascender al cielo  • C o L: Picada rápida / Aterrizar\n• A / D: Guiñada y virajes suaves"
	},
	{
		"tab": "II. LA INVASIÓN",
		"tag": "⚔ LA ORDEN DEL HIERRO",
		"title": "EL ASEDIO Y EL NIDO EN CADENAS",
		"text": "Aprovechando tu ausencia, la temible Orden del Hierro marchó sobre el paso de Cuervo Gris. Sus caballeros han levantado tres colosales balistas de guerra en los riscos y aprisionado el nido sagrado bajo pesadas cadenas forjadas.\n\nEn el centro del nido duerme el último huevo del linaje. Si la fortaleza no cae, los dragones desaparecerán de la tierra para siempre.",
		"hint": "◆ ALERTA DE COMBATE:\n• Las balistas disparan virotes perforantes a gran distancia.\n• ¡Atento al destello rojo de advertencia antes de cada disparo para esquivarlos a tiempo!"
	},
	{
		"tab": "III. LA MISIÓN",
		"tag": "🔥 ALIENTO DE GUERRA",
		"title": "LIBERA EL VALLE — TU MISIÓN",
		"text": "¡Despierta, guardián! Es hora de reclamar tu dominio:\n\n1. Destruye las 3 Balistas de asedio con tu aliento de fuego.\n2. Derrota al Capitán del Hierro que defiende el puente del nido.\n3. Rompe las cadenas del Nido Sagrado (acércate y usa fuego o pulsa E).\n4. Escapa por el Paso del Sur hacia la libertad con la cría a salvo.",
		"hint": "◆ FUEGO DEVASTADOR:\n• Mantén Clic Izquierdo o F para escupir una llamarada continua.\n• Tu aliento fija y calcina automáticamente las balistas y caballeros cercanos."
	}
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 4
	_load_story_textures()
	if get_parent() and get_parent().has_node("SiegeCombat"):
		combat = get_parent().get_node("SiegeCombat")
	elif not combat:
		combat = SiegeCombat.new()
		add_child(combat)

	var root_ui := Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ui)

	damage_overlay = ColorRect.new()
	damage_overlay.color = Color(0.6, 0.03, 0.015, 0)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.add_child(damage_overlay)

	# Barra de salud en batalla
	var health_box := VBoxContainer.new()
	health_box.position = Vector2(24, 400)
	health_box.name = "Health"
	root_ui.add_child(health_box)

	health_text = _label("INTEGRIDAD DEL GUARDIÁN", 15)
	health_box.add_child(health_text)

	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(240, 16)
	health_bar.max_value = combat.max_health
	health_bar.show_percentage = false
	health_bar.add_theme_stylebox_override("background", _box(Color(0.08, 0.08, 0.075, 0.85), Color(0.25, 0.30, 0.28)))
	health_bar.add_theme_stylebox_override("fill", _box(Color(0.85, 0.32, 0.12), Color(1.0, 0.65, 0.25)))
	health_box.add_child(health_bar)

	# Objetivo y eventos
	objective = _label("", 18)
	objective.name = "Objective"
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.size = Vector2(440, 72)
	root_ui.add_child(objective)

	event_label = _label("", 19)
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_label.size = Vector2(620, 70)
	root_ui.add_child(event_label)

	waypoint = _label("◆", 26)
	waypoint.modulate = GOLD
	waypoint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(waypoint)

	# Contenedor ficticio para no romper ninguna referencia antigua
	credit_links = HFlowContainer.new()
	credit_links.visible = false
	root_ui.add_child(credit_links)

	# Pantalla de inicio / Pausa / Fin de misión
	overlay = ColorRect.new()
	overlay.color = Color(0.015, 0.022, 0.03, 0.72)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(INK, Color(0.85, 0.68, 0.32, 0.9), 10, 2))
	center.add_child(panel)

	_build_ui_content()

	if is_instance_valid(combat) and not combat.state_changed.is_connected(_refresh):
		combat.state_changed.connect(_refresh)
	if get_viewport() and not get_viewport().size_changed.is_connected(_resize):
		get_viewport().size_changed.connect(_resize)
	_resize()
	_refresh()

func _load_story_textures() -> void:
	story_textures.clear()
	var paths := [
		"res://assets/story/story_1_dragon.jpg",
		"res://assets/story/story_2_mission.jpg",
		"res://assets/story/story_3_action.jpg"
	]
	for p in paths:
		var tex: Texture2D = null
		if ResourceLoader.exists(p):
			tex = load(p) as Texture2D
		if not tex:
			var global_path := ProjectSettings.globalize_path(p)
			if FileAccess.file_exists(global_path):
				var img := Image.load_from_file(global_path)
				if img and not img.is_empty():
					tex = ImageTexture.create_from_image(img)
		story_textures.append(tex)

func _build_ui_content() -> void:
	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 20)
	outer_margin.add_theme_constant_override("margin_right", 20)
	outer_margin.add_theme_constant_override("margin_top", 12)
	outer_margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(outer_margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	outer_margin.add_child(root_vbox)

	# Encabezado épico
	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 1)
	root_vbox.add_child(header_box)

	var eyebrow := _label("◆  CRÓNICAS DE CUERVO GRIS  ·  EL DESPERTAR DEL FUEGO ANCESTRAL  ◆", 12)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.modulate = GOLD
	header_box.add_child(eyebrow)

	title = _label("EL ÚLTIMO GUARDIÁN", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_box.add_child(title)

	# Label de texto estándar para compatibilidad con pausas y fin de juego
	story = _label("", 15)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.visible = false
	root_vbox.add_child(story)

	# Contenedor principal de dos columnas (Prólogo a la izquierda, Acciones a la derecha)
	main_layout = HBoxContainer.new()
	main_layout.add_theme_constant_override("separation", 16)
	root_vbox.add_child(main_layout)

	# --- COLUMNA IZQUIERDA: VISOR DE HISTORIA Y PRÓLOGO ---
	story_panel = PanelContainer.new()
	story_panel.add_theme_stylebox_override("panel", _box(INK_CARD, Color(0.4, 0.45, 0.42, 0.6), 8, 1))
	story_panel.custom_minimum_size = Vector2(620, 490)
	main_layout.add_child(story_panel)

	var story_margin := MarginContainer.new()
	story_margin.add_theme_constant_override("margin_left", 12)
	story_margin.add_theme_constant_override("margin_right", 12)
	story_margin.add_theme_constant_override("margin_top", 10)
	story_margin.add_theme_constant_override("margin_bottom", 10)
	story_panel.add_child(story_margin)

	var story_vbox := VBoxContainer.new()
	story_vbox.add_theme_constant_override("separation", 7)
	story_margin.add_child(story_vbox)

	# Pestañas de capítulos (Capítulo 1, 2, 3)
	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 6)
	story_vbox.add_child(tabs_row)

	tab_buttons.clear()
	for i in STORY_DATA.size():
		var tab_btn := _button(STORY_DATA[i]["tab"], Vector2(190, 32), 12)
		var idx := i
		tab_btn.pressed.connect(func(): _set_slide(idx))
		tabs_row.add_child(tab_btn)
		tab_buttons.append(tab_btn)

	# Marco con la imagen cinematográfica 16:9
	var img_frame := PanelContainer.new()
	img_frame.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.9), GOLD_DIM, 6, 2))
	img_frame.custom_minimum_size = Vector2(590, 215)
	story_vbox.add_child(img_frame)

	story_tex_rect = TextureRect.new()
	story_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	story_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	story_tex_rect.custom_minimum_size = Vector2(590, 215)
	img_frame.add_child(story_tex_rect)

	# Etiqueta sobre la imagen
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	story_vbox.add_child(title_row)

	story_tag_label = _label("✦ EL GUARDIÁN ANCESTRAL", 12)
	story_tag_label.modulate = GOLD
	title_row.add_child(story_tag_label)

	story_title_label = _label("EL DESPERTAR DEL DRAGÓN DE OBSIDIANA", 16)
	story_title_label.add_theme_color_override("font_color", WHITE)
	title_row.add_child(story_title_label)

	story_text_label = _label("", 13)
	story_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_text_label.custom_minimum_size.y = 54
	story_vbox.add_child(story_text_label)

	# Caja de consejo jugable
	var hint_frame := PanelContainer.new()
	hint_frame.add_theme_stylebox_override("panel", _box(Color(0.06, 0.1, 0.11, 0.9), TEAL, 6, 1))
	story_vbox.add_child(hint_frame)

	var hint_margin := MarginContainer.new()
	hint_margin.add_theme_constant_override("margin_left", 8)
	hint_margin.add_theme_constant_override("margin_right", 8)
	hint_margin.add_theme_constant_override("margin_top", 6)
	hint_margin.add_theme_constant_override("margin_bottom", 6)
	hint_frame.add_child(hint_margin)

	story_hint_label = _label("", 12)
	story_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_margin.add_child(story_hint_label)

	# Controles de navegación del carrusel
	var nav_row := HBoxContainer.new()
	nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_row.add_theme_constant_override("separation", 10)
	story_vbox.add_child(nav_row)

	btn_prev = _button("◄ ANTERIOR", Vector2(110, 30), 12)
	btn_prev.pressed.connect(func(): _change_slide(-1))
	nav_row.add_child(btn_prev)

	dot_buttons.clear()
	for i in STORY_DATA.size():
		var dot_btn := _button("●" if i == 0 else "○", Vector2(28, 28), 13)
		var idx := i
		dot_btn.pressed.connect(func(): _set_slide(idx))
		nav_row.add_child(dot_btn)
		dot_buttons.append(dot_btn)

	btn_next = _button("SIGUIENTE ►", Vector2(110, 30), 12)
	btn_next.pressed.connect(func(): _change_slide(1))
	nav_row.add_child(btn_next)

	btn_auto = _button("⏸ AUTO", Vector2(80, 30), 11)
	btn_auto.pressed.connect(_toggle_auto_slide)
	nav_row.add_child(btn_auto)

	# --- COLUMNA DERECHA: PANEL DE ACCIÓN Y JUGABILIDAD ---
	actions_panel = PanelContainer.new()
	actions_panel.add_theme_stylebox_override("panel", _box(INK_CARD, Color(0.7, 0.55, 0.28, 0.8), 8, 1))
	actions_panel.custom_minimum_size = Vector2(330, 490)
	main_layout.add_child(actions_panel)

	var act_margin := MarginContainer.new()
	act_margin.add_theme_constant_override("margin_left", 14)
	act_margin.add_theme_constant_override("margin_right", 14)
	act_margin.add_theme_constant_override("margin_top", 12)
	act_margin.add_theme_constant_override("margin_bottom", 12)
	actions_panel.add_child(act_margin)

	var act_vbox := VBoxContainer.new()
	act_vbox.add_theme_constant_override("separation", 9)
	act_margin.add_child(act_vbox)

	var act_header := _label("◆ MODOS Y COMBATE ◆", 14)
	act_header.modulate = GOLD
	act_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	act_vbox.add_child(act_header)

	# Botón Principal: Iniciar Asedio
	action = _button("▶ INICIAR ASEDIO [ENTER]", Vector2(290, 48), 15, true)
	act_vbox.add_child(action)
	action.pressed.connect(_activate)

	# Botón Secundario: Modo Vuelo Libre / Práctica
	btn_free_flight = _button("✈ MODO VUELO LIBRE", Vector2(290, 40), 13)
	act_vbox.add_child(btn_free_flight)
	btn_free_flight.pressed.connect(_start_free_flight)
	secondary = btn_free_flight

	# Selector interactivo de dificultad
	btn_difficulty = _button("⚙ DIFICULTAD: NORMAL (240 HP)", Vector2(290, 36), 12)
	act_vbox.add_child(btn_difficulty)
	btn_difficulty.pressed.connect(_cycle_difficulty)

	# Guía rápida de controles interactiva
	btn_guide = _button("📖 CONTROLES Y MANIOBRAS", Vector2(290, 36), 12)
	act_vbox.add_child(btn_guide)
	btn_guide.pressed.connect(_toggle_controls_modal)

	# Botón para probar rugido
	btn_roar = _button("🔊 PROBAR RUGIDO (R)", Vector2(290, 36), 12)
	act_vbox.add_child(btn_roar)
	btn_roar.pressed.connect(_test_roar)

	# Resumen visual permanente de controles básicos en el panel derecho
	var quick_keys_frame := PanelContainer.new()
	quick_keys_frame.add_theme_stylebox_override("panel", _box(Color(0.015, 0.025, 0.03, 0.8), Color(0.3, 0.35, 0.33, 0.6), 6, 1))
	act_vbox.add_child(quick_keys_frame)

	var qk_margin := MarginContainer.new()
	qk_margin.add_theme_constant_override("margin_left", 8)
	qk_margin.add_theme_constant_override("margin_right", 8)
	qk_margin.add_theme_constant_override("margin_top", 8)
	qk_margin.add_theme_constant_override("margin_bottom", 8)
	quick_keys_frame.add_child(qk_margin)

	var quick_keys := _label("RESUMEN DE TECLAS:\n• W / A / S / D : Vuelo y giros\n• ESPACIO : Ascenso / Despegue\n• C o L : Picada / Aterrizaje\n• Clic Izq o F : Aliento de fuego\n• G : Modo planeo veloz\n• P : Pausa / Opciones", 11)
	quick_keys.modulate = Color(0.85, 0.88, 0.86)
	qk_margin.add_child(quick_keys)

	# Botón de volver al menú (usado en pausa, victoria y derrota)
	btn_return_menu = _button("VOLVER AL MENÚ DE INICIO", Vector2(290, 40), 13)
	btn_return_menu.visible = false
	act_vbox.add_child(btn_return_menu)
	btn_return_menu.pressed.connect(_return_to_main_menu)

	# Modal desplegable de controles detallados
	controls_modal = PanelContainer.new()
	controls_modal.add_theme_stylebox_override("panel", _box(INK, GOLD, 8, 2))
	controls_modal.visible = false
	controls_modal.custom_minimum_size = Vector2(580, 260)
	outer_margin.add_child(controls_modal)

	var modal_margin := MarginContainer.new()
	for edge in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		modal_margin.add_theme_constant_override(edge, 16)
	controls_modal.add_child(modal_margin)

	var modal_vbox := VBoxContainer.new()
	modal_vbox.add_theme_constant_override("separation", 10)
	modal_margin.add_child(modal_vbox)

	var modal_title := _label("GUÍA COMPLETA DE MANIOBRAS Y COMBATE", 16)
	modal_title.modulate = GOLD
	modal_vbox.add_child(modal_title)

	var modal_desc := _label(
		"• EN VUELO: W acelerar/aletear · S frenar · A / D timón de cola · ESPACIO ascender · C picada.\n" +
		"• PLANEANDO: Pulsa G para extender las alas. Mantienes velocidad con caída mínima.\n" +
		"• EN TIERRA: Pulsa L para aterrizar o despegar. W / S para caminar, SHIFT para trotar, ESPACIO para saltar y remontar el vuelo.\n" +
		"• COMBATE: Clic Izquierdo o tecla F para lanzar fuego continuo. Cuenta con fijación asistida de objetivos aéreos y terrestres.\n" +
		"• RUGIDO: Pulsa R en cualquier momento para atemorizar a los enemigos con un rugido ensordecedor.\n" +
		"• CÁMARA: V cambia la perspectiva (orbital, primera persona, cinemática). Clic Derecho + arrastre para girar la cámara.", 13)
	modal_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_vbox.add_child(modal_desc)

	var btn_close_modal := _button("ENTENDIDO · CERRAR GUÍA", Vector2(220, 36), 13)
	btn_close_modal.pressed.connect(func(): controls_modal.visible = false; controls_visible = false)
	modal_vbox.add_child(btn_close_modal)

	_update_slide_display()

func _box(fill: Color, border: Color, radius: int = 6, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style

func _label(content: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_color_override("font_color", WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.02, 0.95))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(content: String, min_size: Vector2 = Vector2(210, 44), font_size: int = 14, is_primary: bool = false) -> Button:
	var button := Button.new()
	button.text = content
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", font_size)
	var normal_bg := Color(0.18, 0.22, 0.20, 1.0) if not is_primary else Color(0.55, 0.22, 0.08, 1.0)
	var normal_border := Color(0.45, 0.52, 0.45) if not is_primary else GOLD
	var hover_border := GOLD if not is_primary else EMBER

	for state in ["normal", "hover", "pressed", "focus"]:
		var border := hover_border if state in ["hover", "focus"] else normal_border
		var fill := normal_bg
		if state == "hover":
			fill = Color(0.24, 0.30, 0.28, 1.0) if not is_primary else Color(0.70, 0.28, 0.10, 1.0)
		elif state == "pressed":
			fill = Color(0.12, 0.16, 0.14, 1.0) if not is_primary else Color(0.45, 0.18, 0.06, 1.0)
		button.add_theme_stylebox_override(state, _box(fill, border, 6, 2 if (is_primary or state in ["hover", "focus"]) else 1))

	button.add_theme_color_override("font_color", WHITE)
	return button

func _resize() -> void:
	if not get_viewport():
		return
	var size := get_viewport().get_visible_rect().size
	var target_w := minf(1060.0, size.x - 48.0)
	panel.custom_minimum_size.x = target_w
	panel.size = Vector2(target_w, 0)

	title.add_theme_font_size_override("font_size", 28 if size.x < 1000 else 34)

	var root_ui: Control = damage_overlay.get_parent()
	root_ui.get_node("Health").position = Vector2(24, size.y - 110)
	objective.position = Vector2(maxf(300, size.x - 460), 98)
	objective.size.x = minf(440, size.x * 0.43)
	event_label.position = Vector2((size.x - minf(620, size.x - 48)) / 2, size.y - 148)
	event_label.size.x = minf(620, size.x - 48)

func _set_slide(index: int) -> void:
	current_slide = posmod(index, STORY_DATA.size())
	slide_timer = 0.0
	_update_slide_display()

func _change_slide(delta: int) -> void:
	_set_slide(current_slide + delta)

func _toggle_auto_slide() -> void:
	auto_slide_enabled = not auto_slide_enabled
	btn_auto.text = "⏸ AUTO" if auto_slide_enabled else "▶ AUTO"

func _update_slide_display() -> void:
	if current_slide >= 0 and current_slide < story_textures.size() and story_textures[current_slide]:
		story_tex_rect.texture = story_textures[current_slide]

	var data: Dictionary = STORY_DATA[current_slide]
	story_tag_label.text = data["tag"]
	story_title_label.text = data["title"]
	story_text_label.text = data["text"]
	story_hint_label.text = data["hint"]

	for i in tab_buttons.size():
		var btn := tab_buttons[i]
		if i == current_slide:
			btn.add_theme_color_override("font_color", GOLD)
			btn.add_theme_stylebox_override("normal", _box(Color(0.24, 0.18, 0.10, 1.0), GOLD, 6, 2))
		else:
			btn.add_theme_color_override("font_color", Color(0.78, 0.8, 0.78))
			btn.add_theme_stylebox_override("normal", _box(Color(0.12, 0.16, 0.16, 0.8), Color(0.35, 0.4, 0.38), 6, 1))

	for i in dot_buttons.size():
		dot_buttons[i].text = "●" if i == current_slide else "○"
		dot_buttons[i].modulate = GOLD if i == current_slide else Color(0.6, 0.6, 0.6)

func _refresh() -> void:
	var popup := combat.phase == combat.Phase.BRIEFING or combat.phase == combat.Phase.VICTORY or combat.phase == combat.Phase.DEFEAT or paused_menu
	overlay.visible = popup
	health_bar.get_parent().visible = not popup
	objective.visible = not popup
	event_label.visible = not popup
	if get_parent() and get_parent().has_node("HUD"):
		get_parent().get_node("HUD").visible = not popup

	if not popup:
		controls_modal.visible = false
		return

	if combat.phase == combat.Phase.BRIEFING:
		# PANTALLA DE INICIO COMPLETA
		story_panel.visible = true
		story.visible = false
		title.text = "EL ÚLTIMO GUARDIÁN"
		action.text = "▶ INICIAR ASEDIO [ENTER]"
		btn_free_flight.visible = true
		btn_difficulty.visible = true
		btn_guide.visible = true
		btn_roar.visible = true
		btn_return_menu.visible = false
		_update_slide_display()
	elif paused_menu:
		# MENÚ DE PAUSA
		story_panel.visible = false
		story.visible = true
		title.text = "JUEGO EN PAUSA"
		story.text = "El asedio aguarda en las corrientes del valle.\n\nControles Rápidos:\n• W / A / S / D: Desplazamiento y maniobras  • ESPACIO: Ascenso\n• C o L: Picada / Aterrizaje  • Clic Izquierdo o F: Fuego directo\n• P: Reanudar partida  • R: Reiniciar misión"
		action.text = "CONTINUAR [P]"
		btn_free_flight.visible = false
		btn_difficulty.visible = false
		btn_guide.visible = true
		btn_roar.visible = false
		btn_return_menu.visible = true
	elif combat.phase == combat.Phase.VICTORY:
		# PANTALLA DE VICTORIA
		story_panel.visible = false
		story.visible = true
		title.text = "¡VICTORIA DEL GUARDIÁN!"
		story.text = "La Orden del Hierro pierde su dominio sobre el cielo. La última cría vuelve a sentir el calor de su guardián. El valle no olvida a quien regresó.\n\nAsedio completado en %d:%02d. Ballistas destruidas: %d.\n¡El linaje de los dragones vivirá para siempre!" % [int(combat.active_time)/60, int(combat.active_time)%60, combat.turrets_destroyed]
		action.text = "VOLVER A JUGAR [R]"
		btn_free_flight.visible = false
		btn_difficulty.visible = false
		btn_guide.visible = false
		btn_roar.visible = false
		btn_return_menu.visible = true
	elif combat.phase == combat.Phase.DEFEAT:
		# PANTALLA DE DERROTA
		story_panel.visible = false
		story.visible = true
		title.text = "EL GUARDIÁN HA CAÍDO"
		story.text = "El fuego cruzado de las defensas te ha derribado, pero el nido sigue esperando ser liberado.\n\nConsejo táctico:\n• Evita los virotes esquivando cuando veas el destello rojo en la balista.\n• Ataca desde las alturas en picada (C) y dispara fuego con Clic Izquierdo o F."
		action.text = "REINTENTAR ASEDIO [R]"
		btn_free_flight.visible = false
		btn_difficulty.visible = false
		btn_guide.visible = false
		btn_roar.visible = false
		btn_return_menu.visible = true

	action.disabled = not combat.initialized
	if get_viewport():
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
		if combat.dragon:
			GameAudio.play_roar(combat.dragon.global_position, "takeoff")
		combat.start_mission(false)
	else:
		combat.retry()

func _start_free_flight() -> void:
	if combat.dragon:
		GameAudio.play_wing_flap(combat.dragon.global_position, 1.2)
	combat.start_mission(true)

func _cycle_difficulty() -> void:
	match combat.difficulty:
		"normal":
			combat.set_difficulty("hard")
			btn_difficulty.text = "⚙ DIFICULTAD: FEROZ (160 HP)"
		"hard":
			combat.set_difficulty("easy")
			btn_difficulty.text = "⚙ DIFICULTAD: FÁCIL (360 HP)"
		_:
			combat.set_difficulty("normal")
			btn_difficulty.text = "⚙ DIFICULTAD: NORMAL (240 HP)"

func _toggle_controls_modal() -> void:
	controls_visible = not controls_visible
	controls_modal.visible = controls_visible

func _test_roar() -> void:
	if combat.dragon:
		GameAudio.play_roar(combat.dragon.global_position, "general")
	event_label.text = "¡ROOOAARR! El rugido resuena en las montañas."
	event_label.visible = true
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_callback(func(): event_label.visible = not overlay.visible)

func _return_to_main_menu() -> void:
	paused_menu = false
	get_tree().paused = false
	combat.return_to_briefing()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	if event.keycode == KEY_P and combat.is_running():
		paused_menu = not paused_menu
		get_tree().paused = paused_menu
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if paused_menu else (Input.MOUSE_MODE_CAPTURED if combat.dragon.mouse_captured else Input.MOUSE_MODE_VISIBLE))
		_refresh()
		get_viewport().set_input_as_handled()
		return

	if not overlay.visible:
		return

	# Si el modal de guía está abierto, ESC o H lo cierra
	if controls_modal.visible and event.keycode in [KEY_ESCAPE, KEY_H]:
		controls_modal.visible = false
		controls_visible = false
		get_viewport().set_input_as_handled()
		return

	# Navegación del carrusel con flechas de dirección en la pantalla de inicio
	if combat.phase == combat.Phase.BRIEFING and not paused_menu:
		if event.keycode in [KEY_LEFT, KEY_A]:
			_change_slide(-1)
			get_viewport().set_input_as_handled()
			return
		elif event.keycode in [KEY_RIGHT, KEY_D]:
			_change_slide(1)
			get_viewport().set_input_as_handled()
			return

	if event.keycode == KEY_R:
		if combat.phase == combat.Phase.BRIEFING:
			_test_roar()
		else:
			_activate()
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button and focused != action and focused.is_visible_in_tree():
			return
		_activate()
		get_viewport().set_input_as_handled()
	elif event.keycode not in [KEY_TAB, KEY_SPACE, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if overlay.visible and combat.phase == combat.Phase.BRIEFING and auto_slide_enabled:
		slide_timer += delta
		if slide_timer >= SLIDE_DURATION:
			slide_timer = 0.0
			_change_slide(1)

	if not is_instance_valid(combat) or not combat.initialized:
		return

	var help_open: bool = (get_parent().get_node("HUD").controls_panel.visible) if (get_parent() and get_parent().has_node("HUD")) else false
	var unobscured: bool = not overlay.visible and not help_open
	health_bar.get_parent().visible = unobscured
	objective.visible = unobscured
	event_label.visible = unobscured

	health_bar.value = combat.health
	health_text.text = "GUARDIÁN  %d / %d" % [ceil(combat.health), combat.max_health]
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
			point = Vector2(size.x / 2, size.y - 200)
			waypoint.text = "▼ OBJETIVO DETRÁS"
		else:
			waypoint.text = "◆ %d m" % roundi(target.distance_to(combat.dragon.global_position))
		waypoint.position = point.clamp(Vector2(24, 190), size - Vector2(220, 190))
