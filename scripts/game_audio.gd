extends Node
class_name GameAudio

# ==============================================================================
# GESTOR CENTRAL DE AUDIO DEL JUEGO (Dragon Simulator)
# Efectos de sonido reales de código abierto (GitHub) + Bucles Ambientales Aprobados.
# Soporta selección contextual y multi-variante inteligente.
# ==============================================================================

# --- SONIDOS DEL DRAGÓN ---
static var ROAR_FIRE_1: AudioStreamOggVorbis
static var ROAR_FIRE_2: AudioStreamOggVorbis
static var ROAR_WYVERN: AudioStreamOggVorbis
static var ROAR_DRAKE: AudioStreamOggVorbis

static var SFX_DRAGON_FLAP: AudioStreamOggVorbis
static var SFX_DRAGON_SLAM: AudioStreamOggVorbis
static var SFX_DRAGON_HURT_HEAVY: AudioStreamOggVorbis
static var SFX_DRAGON_HURT_LIGHT: AudioStreamOggVorbis

# --- SONIDOS DE CABALLEROS Y COMBATE ---
static var SFX_SWORD_SWIFT: AudioStreamOggVorbis
static var SFX_SWORD_HEAVY: AudioStreamOggVorbis
static var SFX_KNIGHT_STEP: AudioStreamOggVorbis
static var SFX_KNIGHT_DEATH: AudioStreamOggVorbis
static var SFX_BALLISTA_FIRE_1: AudioStreamOggVorbis
static var SFX_BALLISTA_FIRE_2: AudioStreamOggVorbis
static var SFX_BALLISTA_IMPACT: AudioStreamOggVorbis

# --- SONIDOS DE AGUA ---
static var SFX_WATER_SPLASH: AudioStreamOggVorbis
static var SFX_WATER_BLAST: AudioStreamWAV

# --- AMBIENTES APROBADOS ---
static var SFX_AMBIENT_WIND: AudioStreamWAV
static var SFX_FLIGHT_RUSH: AudioStreamWAV
static var SFX_AMBIENT_WATER: AudioStreamWAV

static var _initialized: bool = false
static var instance: GameAudio
static var _last_roar_idx: int = -1

var ambient_wind_player: AudioStreamPlayer
var flight_rush_player: AudioStreamPlayer
var ambient_water_player: AudioStreamPlayer

# Carga de WAV sin dependencia de .import
static func load_wav(path: String, loop: bool = false) -> AudioStreamWAV:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("No se pudo cargar audio WAV en: " + path)
		return null
	var bytes := file.get_buffer(file.get_length())
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	var pcm := bytes.slice(44)
	stream.data = pcm
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = pcm.size() / 2
	return stream

# Carga de OGG sin dependencia de .import
static func load_ogg(path: String, loop: bool = false) -> AudioStreamOggVorbis:
	if not FileAccess.file_exists(path):
		push_error("No existe archivo OGG en: " + path)
		return null
	var stream := AudioStreamOggVorbis.load_from_file(path)
	if stream and loop:
		stream.loop = true
	return stream

static func init_audio_resources() -> void:
	if _initialized:
		return
	
	# 4 Rugidos aprobados
	ROAR_FIRE_1 = load_ogg("res://assets/audio/github_sources/draconis_roar_1.ogg")
	ROAR_FIRE_2 = load_ogg("res://assets/audio/github_sources/draconis_roar_2.ogg")
	ROAR_WYVERN = load_ogg("res://assets/audio/github_sources/veloren_wyvern_roar.ogg")
	ROAR_DRAKE  = load_ogg("res://assets/audio/github_sources/wesnoth_drake_roar.ogg")

	# Acciones Dragón
	SFX_DRAGON_FLAP = load_ogg("res://assets/audio/github_sources/draconis_wing_flap.ogg")
	SFX_DRAGON_SLAM = load_ogg("res://assets/audio/github_sources/draconis_dragon_slam.ogg")
	SFX_DRAGON_HURT_HEAVY = load_ogg("res://assets/audio/github_sources/veloren_wyvern_hurt.ogg")
	SFX_DRAGON_HURT_LIGHT = load_ogg("res://assets/audio/github_sources/wesnoth_drake_hit.ogg")

	# Caballeros y Combate
	SFX_SWORD_SWIFT = load_ogg("res://assets/audio/github_sources/veloren_sword_swing.ogg")
	SFX_SWORD_HEAVY = load_ogg("res://assets/audio/github_sources/flare_sword_attack.ogg")
	SFX_KNIGHT_STEP = load_ogg("res://assets/audio/github_sources/flare_step_metal.ogg")
	SFX_KNIGHT_DEATH = load_ogg("res://assets/audio/github_sources/flare_knight_death.ogg")
	SFX_BALLISTA_FIRE_1 = load_ogg("res://assets/audio/github_sources/veloren_arrow_shot.ogg")
	SFX_BALLISTA_FIRE_2 = load_ogg("res://assets/audio/github_sources/wesnoth_crossbow.ogg")
	SFX_BALLISTA_IMPACT = load_ogg("res://assets/audio/github_sources/veloren_impact_klonk.ogg")

	# Agua
	SFX_WATER_SPLASH = load_ogg("res://assets/audio/github_sources/veloren_splash_big.ogg")
	SFX_WATER_BLAST = load_wav("res://assets/audio/github_sources/wesnoth_water_blast.wav")

	# Ambientes aprobados
	SFX_AMBIENT_WIND = load_wav("res://assets/audio/ambient/ambient_wind.wav", true)
	SFX_FLIGHT_RUSH = load_wav("res://assets/audio/ambient/flight_wind_rush.wav", true)
	SFX_AMBIENT_WATER = load_wav("res://assets/audio/ambient/ambient_water.wav", true)

	_initialized = true

func _init() -> void:
	instance = self

func _enter_tree() -> void:
	instance = self
	init_audio_resources()
	_setup_ambient_loops()

func _ready() -> void:
	if ambient_wind_player and not ambient_wind_player.playing:
		ambient_wind_player.play()
	if flight_rush_player and not flight_rush_player.playing:
		flight_rush_player.play()
	if ambient_water_player and not ambient_water_player.playing:
		ambient_water_player.play()

func _setup_ambient_loops() -> void:
	init_audio_resources()
	# Viento de montaña / alta atmósfera (comienza inaudible hasta que el dragón vuele alto)
	if SFX_AMBIENT_WIND and not ambient_wind_player:
		ambient_wind_player = AudioStreamPlayer.new()
		ambient_wind_player.name = "AmbientWind"
		ambient_wind_player.stream = SFX_AMBIENT_WIND
		ambient_wind_player.volume_db = -80.0
		add_child(ambient_wind_player)
		if is_inside_tree():
			ambient_wind_player.play()

	# Ráfaga de viento por velocidad aerodinámica (inicia en silencio)
	if SFX_FLIGHT_RUSH and not flight_rush_player:
		flight_rush_player = AudioStreamPlayer.new()
		flight_rush_player.name = "FlightWindRush"
		flight_rush_player.stream = SFX_FLIGHT_RUSH
		flight_rush_player.volume_db = -80.0
		add_child(flight_rush_player)
		if is_inside_tree():
			flight_rush_player.play()

	# Arroyo / Agua ambiental cuando el dragón sobrevuela o se acerca a masas de agua
	if SFX_AMBIENT_WATER and not ambient_water_player:
		ambient_water_player = AudioStreamPlayer.new()
		ambient_water_player.name = "AmbientWater"
		ambient_water_player.stream = SFX_AMBIENT_WATER
		ambient_water_player.volume_db = -80.0
		add_child(ambient_water_player)
		if is_inside_tree():
			ambient_water_player.play()

## Sincronización continua de audio con la física de vuelo y el entorno
func update_flight_physics_audio(
	delta: float,
	airspeed: float,
	is_in_flight: bool,
	flight_mode: int,
	height_agl: float,
	world_altitude: float,
	is_over_water: bool,
	dist_to_water: float
) -> void:
	if not flight_rush_player or not ambient_wind_player:
		return

	# Tasas de amortiguamiento exponencial independientes de los FPS
	var rush_blend_rate := 9.0
	var wind_blend_rate := 3.5
	var water_blend_rate := 5.0

	# -------------------------------------------------------------------------
	# 1. RÁFAGA DE AIRE AERODINÁMICO SEGÚN VELOCIDAD RELATIVA (flight_rush_player)
	# -------------------------------------------------------------------------
	var target_rush_db := -80.0
	var target_rush_pitch := 1.0

	if is_in_flight and airspeed > 7.0:
		# Mapeo no-lineal según velocidad física:
		#  7 m/s  -> -38.0 dB (susurro apenas audible)
		# 26 m/s (crucero) -> -16.0 dB (brisa aerodinámica limpia)
		# 46 m/s (picada máxima) -> +2.0 dB (rugido sónico intenso)
		if airspeed <= 26.0:
			var t := clampf((airspeed - 7.0) / 19.0, 0.0, 1.0)
			target_rush_db = lerpf(-38.0, -16.0, t)
			target_rush_pitch = lerpf(0.92, 1.0, t)
		else:
			var t := clampf((airspeed - 26.0) / 20.0, 0.0, 1.0)
			target_rush_db = lerpf(-16.0, 2.0, t)
			target_rush_pitch = lerpf(1.0, 1.28, t)

		# Modulaciones contextuales según el modo aerodinámico
		match flight_mode:
			3: # FlightMode.DIVE (Picada)
				target_rush_db += 2.5
				target_rush_pitch = clampf(target_rush_pitch * 1.08, 1.0, 1.35)
				rush_blend_rate = 14.0 # Ataque rápido al picar
			4: # FlightMode.BRAKE (Frenado aerodinámico)
				# Resistencia turbulenta y arrastre de las alas extendidas
				target_rush_pitch = 0.84
				target_rush_db = maxf(target_rush_db, -18.0) + 1.5
				rush_blend_rate = 12.0
			1: # FlightMode.GLIDE (Planeo)
				target_rush_pitch = 0.95
				target_rush_db = minf(target_rush_db, -17.0)
			2: # FlightMode.CLIMB (Trepada)
				target_rush_pitch = 0.97
				target_rush_db = minf(target_rush_db, -19.0)
	else:
		target_rush_db = -80.0
		target_rush_pitch = 1.0
		rush_blend_rate = 12.0 # Desvanecimiento rápido si aterriza o se detiene

	var rush_weight := 1.0 - exp(-rush_blend_rate * delta)
	flight_rush_player.volume_db = lerpf(flight_rush_player.volume_db, target_rush_db, rush_weight)
	flight_rush_player.pitch_scale = lerpf(flight_rush_player.pitch_scale, target_rush_pitch, rush_weight)

	# -------------------------------------------------------------------------
	# 2. VIENTO AMBIENTAL DE MONTAÑA / ALTA ATMÓSFERA (ambient_wind_player)
	# -------------------------------------------------------------------------
	# En tierra o en valles protegidos (cerca del suelo) el viento es imperceptible.
	# Sólo emerge a gran altitud respecto al terreno (AGL > 40m) y en cotas altas de montaña.
	var target_wind_db := -80.0
	if is_in_flight and height_agl > 40.0 and world_altitude > 145.0:
		var agl_factor := clampf((height_agl - 40.0) / 80.0, 0.0, 1.0)
		var alt_factor := clampf((world_altitude - 145.0) / 110.0, 0.0, 1.0)
		var combined_intensity := agl_factor * alt_factor
		if combined_intensity > 0.03:
			target_wind_db = lerpf(-30.0, -13.0, combined_intensity)

	var wind_weight := 1.0 - exp(-wind_blend_rate * delta)
	ambient_wind_player.volume_db = lerpf(ambient_wind_player.volume_db, target_wind_db, wind_weight)

	# -------------------------------------------------------------------------
	# 3. AMBIENTE DE AGUA / RÍO / LAGO (ambient_water_player)
	# -------------------------------------------------------------------------
	if ambient_water_player:
		var target_water_db := -80.0
		if is_over_water and dist_to_water < 45.0:
			var water_factor := clampf(1.0 - (dist_to_water / 45.0), 0.0, 1.0)
			# Volumen proporcional a la proximidad vertical a la superficie
			target_water_db = lerpf(-34.0, -5.0, water_factor)

		var water_weight := 1.0 - exp(-water_blend_rate * delta)
		ambient_water_player.volume_db = lerpf(ambient_water_player.volume_db, target_water_db, water_weight)

## Compatibilidad hacia atrás
func update_flight_audio(speed_ratio: float, altitude: float) -> void:
	update_flight_physics_audio(0.016, speed_ratio * 26.0, speed_ratio > 0.1, 0, 50.0, altitude, false, 999.0)

# --- REPRODUCTOR 3D ESPACIAL EFÍMERO ---

static func play_3d(stream: AudioStream, pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0, max_dist: float = 240.0) -> void:
	if DisplayServer.get_name() == "headless" or not instance or not stream:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = vol_db
	player.pitch_scale = pitch
	player.max_distance = max_dist
	player.unit_size = 28.0
	player.finished.connect(player.queue_free)
	instance.add_child(player)
	player.global_position = pos
	player.play()

# ==============================================================================
# DISPARADORES CONTEXTUALES E INTELIGENTES (MULTI-OPCIÓN)
# ==============================================================================

## Rugido de dragón: selecciona el timbre óptimo según la situación de vuelo
static func play_roar(pos: Vector3, situation: String = "general") -> void:
	init_audio_resources()
	var roars: Array[AudioStreamOggVorbis] = [ROAR_FIRE_1, ROAR_FIRE_2, ROAR_WYVERN, ROAR_DRAKE]
	var stream: AudioStreamOggVorbis = null
	
	match situation:
		"dive", "high_speed":
			# Alarido estridente y penetrante de wyvern al volar en picada
			stream = ROAR_WYVERN
		"ground", "stand":
			# Berrido profundo y gutural en tierra
			stream = ROAR_FIRE_2
		"climb", "takeoff":
			# Rugido feroz y enérgico de fuego
			stream = ROAR_FIRE_1
		_:
			# Selección aleatoria sin repetir el último inmediatamente
			var candidates: Array[int] = [0, 1, 2, 3]
			if _last_roar_idx >= 0 and candidates.has(_last_roar_idx):
				candidates.erase(_last_roar_idx)
			var chosen_idx: int = candidates[randi() % candidates.size()]
			_last_roar_idx = chosen_idx
			stream = roars[chosen_idx]
	
	if stream:
		play_3d(stream, pos, 4.0, randf_range(0.96, 1.04), 480.0)

## Aleteo de alas en el batido descendente
static func play_wing_flap(pos: Vector3, intensity: float = 1.0) -> void:
	init_audio_resources()
	if not SFX_DRAGON_FLAP:
		return
	var vol := lerpf(-6.0, 1.5, clampf(intensity, 0.0, 1.5))
	var pitch := randf_range(0.94, 1.06)
	play_3d(SFX_DRAGON_FLAP, pos, vol, pitch, 280.0)

## Pisada de dragón o golpe seco en tierra
static func play_dragon_footstep(pos: Vector3, sprint: bool = false) -> void:
	init_audio_resources()
	if not SFX_DRAGON_SLAM:
		return
	var vol := -4.0 if sprint else -7.0
	var pitch := randf_range(0.88, 1.05)
	play_3d(SFX_DRAGON_SLAM, pos, vol, pitch, 180.0)

## Impacto pesado en tierra / Aterrizaje
static func play_dragon_slam(pos: Vector3) -> void:
	init_audio_resources()
	if not SFX_DRAGON_SLAM:
		return
	play_3d(SFX_DRAGON_SLAM, pos, 3.0, randf_range(0.92, 1.02), 320.0)

## Quejido o daño recibido por el dragón
static func play_dragon_hurt(pos: Vector3, damage: float = 10.0) -> void:
	init_audio_resources()
	# Daño fuerte: alarido wyvern / daño leve: gruñido drake
	var stream: AudioStreamOggVorbis = SFX_DRAGON_HURT_HEAVY if damage >= 12.0 else SFX_DRAGON_HURT_LIGHT
	if stream:
		play_3d(stream, pos, 3.5, randf_range(0.94, 1.06), 340.0)

## Ataque con espada: Capitán (tajo pesado) vs Guardia (hoja veloz)
static func play_knight_attack(pos: Vector3, is_captain: bool = false) -> void:
	init_audio_resources()
	var stream: AudioStreamOggVorbis = SFX_SWORD_HEAVY if is_captain else SFX_SWORD_SWIFT
	var vol := 2.0 if is_captain else -1.0
	if stream:
		play_3d(stream, pos, vol, randf_range(0.94, 1.06), 180.0)

## Paso con armadura metálica de caballero
static func play_knight_step(pos: Vector3) -> void:
	init_audio_resources()
	if not SFX_KNIGHT_STEP:
		return
	play_3d(SFX_KNIGHT_STEP, pos, -7.0, randf_range(0.90, 1.10), 110.0)

## Derrota / muerte de caballero con armadura
static func play_knight_death(pos: Vector3) -> void:
	init_audio_resources()
	if not SFX_KNIGHT_DEATH:
		return
	play_3d(SFX_KNIGHT_DEATH, pos, 3.0, randf_range(0.96, 1.04), 220.0)

## Disparo de balista: alternancia entre mecanismo y silbido
static func play_ballista_fire(pos: Vector3) -> void:
	init_audio_resources()
	var stream: AudioStreamOggVorbis = SFX_BALLISTA_FIRE_2 if (randi() % 2 == 0) else SFX_BALLISTA_FIRE_1
	if stream:
		play_3d(stream, pos, 4.0, randf_range(0.95, 1.05), 360.0)

## Impacto de proyectil de balista
static func play_ballista_impact(pos: Vector3) -> void:
	init_audio_resources()
	if not SFX_BALLISTA_IMPACT:
		return
	play_3d(SFX_BALLISTA_IMPACT, pos, 3.0, randf_range(0.92, 1.08), 280.0)

## Salpicadura en el agua: impacto normal vs entrada a gran velocidad
static func play_water_splash(pos: Vector3, is_big: bool = false) -> void:
	init_audio_resources()
	if is_big and SFX_WATER_BLAST:
		play_3d(SFX_WATER_BLAST, pos, 4.0, randf_range(0.94, 1.06), 340.0)
	elif SFX_WATER_SPLASH:
		play_3d(SFX_WATER_SPLASH, pos, 1.0, randf_range(0.92, 1.08), 280.0)
