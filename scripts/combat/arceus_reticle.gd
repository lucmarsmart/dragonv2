extends Control
class_name ArceusReticle

# ==============================================================================
# MIRA DE FIJACIÓN DE OBJETIVO ESTILO POKÉMON LEYENDAS: ARCEUS
# Sistema de retícula con auto-lock sobre el enemigo más cercano, corchetes
# dinámicos, tarjeta de objetivo con salud y seguimiento en pantalla.
# ==============================================================================

var text: String = "+" # Compatibilidad con API previa
var current_screen_pos := Vector2.ZERO
var target_screen_pos := Vector2.ZERO
var is_locked := false
var locked_enemy: CharacterBody3D = null
var current_radius := 34.0
var target_radius := 34.0
var lock_snap_anim := 0.0
var fire_pulse := 0.0
var hit_flash := 0.0
var last_enemy_health := -1.0
var target_distance := 0.0

# Colores estilo Arceus
const COLOR_FREE := Color(1.0, 0.92, 0.78, 0.88)
const COLOR_LOCKED := Color(1.0, 0.45, 0.12, 0.98)
const COLOR_FIRING := Color(1.0, 0.88, 0.25, 1.0)
const COLOR_HIT := Color(1.0, 0.20, 0.10, 1.0)
const COLOR_GOLD := Color(1.0, 0.76, 0.36, 1.0)
const COLOR_SHADOW := Color(0.02, 0.03, 0.04, 0.85)

# Elementos de interfaz sobre la mira
var info_root: Control
var badge_panel: PanelContainer
var badge_label: Label
var health_bar: ProgressBar

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(240, 240)
	size = custom_minimum_size
	
	info_root = Control.new()
	info_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info_root)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)
	vbox.position = Vector2(-70, -66)
	vbox.custom_minimum_size = Vector2(140, 48)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_root.add_child(vbox)
	
	badge_panel = PanelContainer.new()
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_box := StyleBoxFlat.new()
	bg_box.bg_color = Color(0.035, 0.05, 0.06, 0.92)
	bg_box.border_color = Color(1.0, 0.65, 0.25, 0.9)
	bg_box.set_border_width_all(1)
	bg_box.set_corner_radius_all(5)
	bg_box.content_margin_left = 8
	bg_box.content_margin_right = 8
	bg_box.content_margin_top = 2
	bg_box.content_margin_bottom = 2
	badge_panel.add_theme_stylebox_override("panel", bg_box)
	vbox.add_child(badge_panel)
	
	badge_label = Label.new()
	badge_label.text = "◆ OBJETIVO · 0m"
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size", 12)
	badge_label.add_theme_color_override("font_color", COLOR_GOLD)
	badge_label.add_theme_constant_override("outline_size", 2)
	badge_label.add_theme_color_override("font_outline_color", Color.BLACK)
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_panel.add_child(badge_label)
	
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(130, 6)
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.12, 0.05, 0.05, 0.85)
	hp_bg.border_color = Color(0.35, 0.15, 0.15, 0.9)
	hp_bg.set_border_width_all(1)
	hp_bg.set_corner_radius_all(3)
	health_bar.add_theme_stylebox_override("background", hp_bg)
	
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.92, 0.24, 0.12, 1.0)
	hp_fill.set_corner_radius_all(2)
	health_bar.add_theme_stylebox_override("fill", hp_fill)
	vbox.add_child(health_bar)
	
	info_root.visible = false

func update_tracking(screen_pos: Vector2, enemy: CharacterBody3D, is_firing: bool, dist: float, delta: float) -> void:
	target_screen_pos = screen_pos
	target_distance = dist
	
	if current_screen_pos == Vector2.ZERO:
		current_screen_pos = target_screen_pos
	else:
		# Suavizado cinemático al seguir al objetivo en pantalla
		var follow_speed := 30.0 if enemy != null else 22.0
		current_screen_pos = current_screen_pos.lerp(target_screen_pos, 1.0 - exp(-follow_speed * delta))
	
	position = current_screen_pos
	
	var was_locked := is_locked
	is_locked = (enemy != null and not enemy.dead and enemy.is_inside_tree())
	locked_enemy = enemy if is_locked else null
	
	# Transición al fijar objetivo (snap elástico de Arceus)
	if is_locked and not was_locked:
		lock_snap_anim = 1.0
		current_radius = 48.0 # Comienza amplio y se cierra con rapidez
	
	target_radius = 21.0 if is_locked else 34.0
	var radius_speed := 20.0
	current_radius = lerpf(current_radius, target_radius, 1.0 - exp(-radius_speed * delta))
	
	if lock_snap_anim > 0.0:
		lock_snap_anim = maxf(0.0, lock_snap_anim - delta * 4.0)
	
	if is_firing:
		fire_pulse = minf(1.0, fire_pulse + delta * 12.0)
	else:
		fire_pulse = maxf(0.0, fire_pulse - delta * 6.0)
		
	# Detección de daño al enemigo para flash visual
	if is_locked:
		var current_hp: float = enemy.health
		if last_enemy_health >= 0.0 and current_hp < last_enemy_health:
			hit_flash = 0.35
		last_enemy_health = current_hp
	else:
		last_enemy_health = -1.0
		
	hit_flash = maxf(0.0, hit_flash - delta * 3.0)
	
	# Actualizar tarjeta de información superior
	info_root.visible = is_locked
	if is_locked:
		var enemy_name := "BALLISTA"
		var kind: String = enemy.kind if "kind" in enemy else ""
		if kind == "captain":
			enemy_name = "CAPITÁN DEL HIERRO"
		elif kind == "knight":
			enemy_name = "GUARDIA"
		
		badge_label.text = "◆ %s · %dm" % [enemy_name, roundi(target_distance)]
		health_bar.max_value = enemy.max_health if "max_health" in enemy else 100.0
		health_bar.value = enemy.health
		
		# Feedback de color en la tarjeta si está recibiendo daño
		var panel_style: StyleBoxFlat = badge_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if panel_style:
			if hit_flash > 0.05:
				panel_style.border_color = Color(1.0, 0.3, 0.1, 1.0)
			else:
				panel_style.border_color = Color(1.0, 0.65, 0.25, 0.9)
	
	queue_redraw()

func _draw() -> void:
	var r := current_radius
	var center := Vector2.ZERO
	
	# Determinar color según estado
	var col := COLOR_FREE
	if is_locked:
		if hit_flash > 0.05:
			col = COLOR_HIT
		elif fire_pulse > 0.1:
			col = COLOR_LOCKED.lerp(COLOR_FIRING, fire_pulse)
		else:
			col = COLOR_LOCKED
	
	var thickness := 2.8 if is_locked else 2.0
	
	# Sombra suave exterior para legibilidad sobre cualquier fondo
	_draw_arceus_brackets(center, r + 1.0, COLOR_SHADOW, thickness + 2.0)
	
	# Corchetes estilizados principales de Leyendas Arceus
	_draw_arceus_brackets(center, r, col, thickness)
	
	if is_locked:
		# Puntas de enfoque triangulares apuntando al centro (▲ ▼ ◀ ▶)
		var arrow_len := 5.0
		var arrow_half := 3.5
		
		# Superior (apunta abajo)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-arrow_half, -r + 2),
			Vector2(arrow_half, -r + 2),
			Vector2(0, -r + 2 + arrow_len)
		]), col)
		
		# Inferior (apunta arriba)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-arrow_half, r - 2),
			Vector2(arrow_half, r - 2),
			Vector2(0, r - 2 - arrow_len)
		]), col)
		
		# Izquierda (apunta derecha)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-r + 2, -arrow_half),
			Vector2(-r + 2, arrow_half),
			Vector2(-r + 2 + arrow_len, 0)
		]), col)
		
		# Derecha (apunta izquierda)
		draw_colored_polygon(PackedVector2Array([
			Vector2(r - 2, -arrow_half),
			Vector2(r - 2, arrow_half),
			Vector2(r - 2 - arrow_len, 0)
		]), col)
		
		# Rombo central focal (◆)
		var d := 3.5
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -d),
			Vector2(d, 0),
			Vector2(0, d),
			Vector2(-d, 0)
		]), col)
		
		# Anillo de energía pulsante al exhalar fuego
		if fire_pulse > 0.02:
			var ring_r := r + 5.0 + fire_pulse * 3.0
			draw_arc(center, ring_r, 0, TAU, 36, Color(col.r, col.g, col.b, 0.45 * fire_pulse), 1.5, true)
	else:
		# Mira libre: cruz mínima con punto central
		var dot_r := 2.2
		draw_circle(center, dot_r, col)
		var cross_gap := 4.0
		var cross_len := 5.0
		draw_line(Vector2(-cross_gap - cross_len, 0), Vector2(-cross_gap, 0), col, 1.4, true)
		draw_line(Vector2(cross_gap, 0), Vector2(cross_gap + cross_len, 0), col, 1.4, true)
		draw_line(Vector2(0, -cross_gap - cross_len), Vector2(0, -cross_gap), col, 1.4, true)
		draw_line(Vector2(0, cross_gap), Vector2(0, cross_gap + cross_len), col, 1.4, true)

func _draw_arceus_brackets(center: Vector2, radius: float, color: Color, width: float) -> void:
	# 4 arcos esquineros separados a 90 grados entre sí (aspecto circular segmentado)
	var sweep := deg_to_rad(54.0)
	
	# Arriba-Derecha (295° a 349°)
	draw_arc(center, radius, deg_to_rad(293.0), deg_to_rad(293.0) + sweep, 14, color, width, true)
	# Abajo-Derecha (25° a 79°)
	draw_arc(center, radius, deg_to_rad(23.0), deg_to_rad(23.0) + sweep, 14, color, width, true)
	# Abajo-Izquierda (115° a 169°)
	draw_arc(center, radius, deg_to_rad(113.0), deg_to_rad(113.0) + sweep, 14, color, width, true)
	# Arriba-Izquierda (205° a 259°)
	draw_arc(center, radius, deg_to_rad(203.0), deg_to_rad(203.0) + sweep, 14, color, width, true)
