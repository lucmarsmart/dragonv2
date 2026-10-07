extends RefCounted

## Gestor cinematográfico de consecuencias colisionales e impactos.
## Genera nubes de polvo volumétricas, géiseres de agua blanca, ondas de choque,
## esquirlas de roca y efectos sonoros sintetizados en tiempo real.

static var _dust_material: ShaderMaterial
static var _shockwave_material: ShaderMaterial
static var _water_material: ShaderMaterial
static var _debris_material: StandardMaterial3D
static var _earth_sound_stream: AudioStreamWAV
static var _water_sound_stream: AudioStreamWAV

static func _get_dust_material() -> ShaderMaterial:
	if _dust_material:
		return _dust_material
	_dust_material = ShaderMaterial.new()
	_dust_material.shader = preload("res://shaders/dust_particle.gdshader")
	return _dust_material

static func _get_shockwave_material() -> ShaderMaterial:
	if _shockwave_material:
		return _shockwave_material
	_shockwave_material = ShaderMaterial.new()
	_shockwave_material.shader = preload("res://shaders/shockwave_ring.gdshader")
	return _shockwave_material

static func _get_water_material() -> ShaderMaterial:
	if _water_material:
		return _water_material
	_water_material = ShaderMaterial.new()
	_water_material.shader = preload("res://shaders/water_splash.gdshader")
	return _water_material

static func _get_debris_material() -> StandardMaterial3D:
	if _debris_material:
		return _debris_material
	_debris_material = StandardMaterial3D.new()
	_debris_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_debris_material.albedo_color = Color(0.42, 0.36, 0.28)
	_debris_material.roughness = 0.92
	return _debris_material

# --- SÍNTESIS DE AUDIO PROCEDURAL (Cero archivos externos requeridos) ---
static func _get_earth_sound() -> AudioStreamWAV:
	if _earth_sound_stream:
		return _earth_sound_stream
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var sample_count := 16000 # ~0.72 segundos
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = 4921
	var lp := 0.0
	for i in sample_count:
		var t := float(i) / 22050.0
		var env := exp(-t * 9.5)
		# Sub-bass thump (frecuencia decreciente de 75Hz a 30Hz)
		var freq := lerpf(75.0, 30.0, clampf(t * 4.0, 0.0, 1.0))
		var sub := sin(t * TAU * freq) * 19000.0 * env
		# Ruido de impacto y escombros (filtrado paso-bajo)
		var raw_noise := noise_rng.randf_range(-1.0, 1.0)
		lp = lp * 0.72 + raw_noise * 0.28
		var crunch := lp * 11000.0 * exp(-t * 14.0)
		var val := clampi(roundi(sub + crunch), -32000, 32000)
		pcm.encode_s16(i * 2, val)
	stream.data = pcm
	_earth_sound_stream = stream
	return _earth_sound_stream

static func _get_water_sound() -> AudioStreamWAV:
	if _water_sound_stream:
		return _water_sound_stream
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var sample_count := 22050 # 1.0 segundo
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = 8834
	var lp := 0.0
	for i in sample_count:
		var t := float(i) / 22050.0
		var slap_env := exp(-t * 22.0)
		var hiss_env := exp(-t * 4.5) * (1.0 - exp(-t * 40.0))
		# Golpe inicial de agua (slap)
		var slap := sin(t * TAU * 110.0) * 16000.0 * slap_env
		# Espuma y turbulencia de agua pulverizada
		var raw_n := noise_rng.randf_range(-1.0, 1.0)
		lp = lp * 0.55 + raw_n * 0.45
		var hiss := lp * 14000.0 * hiss_env
		var val := clampi(roundi(slap + hiss), -32000, 32000)
		pcm.encode_s16(i * 2, val)
	stream.data = pcm
	_water_sound_stream = stream
	return _water_sound_stream

static func _play_audio(parent: Node, pos: Vector3, stream: AudioStreamWAV, vol_db: float = 0.0) -> void:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(parent):
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.unit_size = 28.0
	player.max_distance = 320.0
	player.volume_db = vol_db
	player.finished.connect(player.queue_free)
	parent.add_child(player)
	player.global_position = pos
	player.play()

## Determina con precisión si una posición de impacto corresponde a una masa de agua
static func is_water_surface(point: Vector3, landscape: Node = null) -> bool:
	if is_instance_valid(landscape):
		if landscape.has_method("is_water_at") and landscape.is_water_at(point):
			var w_level: float = landscape.get_water_level() if landscape.has_method("get_water_level") else 0.7
			if point.y <= w_level + 1.4:
				return true
		if landscape.has_method("get_water_level"):
			var water_y: float = landscape.get_water_level()
			if point.y <= water_y + 0.75:
				return true
	return point.y <= 1.25

## Despacha el impacto correspondiente (polvo o agua) según la superficie
static func spawn_impact(parent: Node, point: Vector3, normal: Vector3, severity: float = 1.0, is_hot: bool = false, landscape: Node = null) -> void:
	if not is_instance_valid(parent):
		return
	var on_water := is_water_surface(point, landscape)
	if on_water:
		spawn_water_splash(parent, point, normal, severity, is_hot)
	else:
		spawn_dust_impact(parent, point, normal, severity, is_hot)

## =========================================================================
## 1. LEVANTAMIENTO DE POLVO Y ESCOMBROS (Tierra, Rocas, Murallas, Patio)
## =========================================================================
static func spawn_dust_impact(parent: Node, point: Vector3, normal: Vector3, severity: float = 1.0, is_hot: bool = false) -> void:
	if not is_instance_valid(parent):
		return
	var s := clampf(severity, 0.4, 4.5)

	# Audio contundente de impacto en roca/tierra
	_play_audio(parent, point, _get_earth_sound(), clampf(-12.0 + s * 3.5, -20.0, 4.0))

	# --- A. Nube volumétrica central envolvente (Billowing Dust Core) ---
	var dust := CPUParticles3D.new()
	dust.amount = clampi(roundi(32.0 * s), 16, 75)
	dust.lifetime = clampf(1.4 + s * 0.4, 1.2, 3.2)
	dust.one_shot = true
	dust.explosiveness = 0.90
	dust.direction = (normal * 0.5 + Vector3.UP * 0.85).normalized()
	dust.spread = 75.0
	dust.initial_velocity_min = 4.0 * s
	dust.initial_velocity_max = 13.0 * s
	dust.damping_min = 5.0
	dust.damping_max = 10.0
	dust.gravity = Vector3(0, 0.65, 0) # Ascenso térmico natural de la polvareda
	dust.scale_amount_min = 2.2 * s
	dust.scale_amount_max = 5.8 * s

	var s_curve := Curve.new()
	s_curve.add_point(Vector2(0.0, 0.35))
	s_curve.add_point(Vector2(0.3, 1.4))
	s_curve.add_point(Vector2(1.0, 2.5))
	dust.scale_amount_curve = s_curve

	var ramp := Gradient.new()
	var base_col := Color(0.95, 0.55, 0.22) if is_hot else Color(0.70, 0.62, 0.50)
	ramp.colors = PackedColorArray([
		Color(base_col.r, base_col.g, base_col.b, 0.0),
		Color(base_col.r, base_col.g, base_col.b, 0.95),
		Color(base_col.r * 0.95, base_col.g * 0.95, base_col.b * 0.92, 0.75),
		Color(base_col.r * 0.9, base_col.g * 0.9, base_col.b * 0.88, 0.0)
	])
	ramp.offsets = PackedFloat32Array([0.0, 0.08, 0.48, 1.0])
	dust.color_ramp = ramp

	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	dust.mesh = quad
	dust.material_override = _get_dust_material()
	parent.add_child(dust)
	dust.global_position = point + normal * 0.25
	dust.emitting = true
	dust.finished.connect(dust.queue_free)

	# --- B. Anillo expansivo de onda de choque rasante (Ground Shockwave Ring) ---
	if s >= 0.8:
		var ring := CPUParticles3D.new()
		ring.amount = clampi(roundi(32.0 * s), 20, 75)
		ring.lifetime = clampf(0.85 + s * 0.25, 0.75, 1.8)
		ring.one_shot = true
		ring.explosiveness = 0.98
		ring.direction = Vector3.UP
		ring.spread = 90.0
		ring.flatness = 0.96 # Máxima planaridad horizontal a ras de suelo
		ring.initial_velocity_min = 12.0 * s
		ring.initial_velocity_max = 24.0 * s
		ring.damping_min = 8.0
		ring.damping_max = 15.0
		ring.gravity = Vector3(0, -0.2, 0)
		ring.scale_amount_min = 1.0 * s
		ring.scale_amount_max = 2.4 * s
		ring.scale_amount_curve = s_curve
		ring.color_ramp = ramp
		ring.mesh = quad
		ring.material_override = _get_shockwave_material()
		parent.add_child(ring)
		ring.global_position = point + normal * 0.15
		ring.emitting = true
		ring.finished.connect(ring.queue_free)

	# --- C. Esquirlas pétreas y guijarros balísticos (Debris Chunks) ---
	if s >= 0.9:
		var debris := CPUParticles3D.new()
		debris.amount = clampi(roundi(24.0 * s), 12, 50)
		debris.lifetime = 1.1
		debris.one_shot = true
		debris.explosiveness = 0.98
		debris.direction = (normal * 0.7 + Vector3.UP * 0.5).normalized()
		debris.spread = 65.0
		debris.initial_velocity_min = 10.0 * s
		debris.initial_velocity_max = 24.0 * s
		debris.angular_velocity_min = -720.0
		debris.angular_velocity_max = 720.0
		debris.gravity = Vector3(0, -28.0, 0) # Fuerte gravedad balística
		debris.scale_amount_min = 0.25 * s
		debris.scale_amount_max = 0.75 * s

		var cube := BoxMesh.new()
		cube.size = Vector3(0.6, 0.5, 0.55)
		debris.mesh = cube
		debris.material_override = _get_debris_material()
		parent.add_child(debris)
		debris.global_position = point + normal * 0.35
		debris.emitting = true
		debris.finished.connect(debris.queue_free)

## =========================================================================
## 2. LEVANTAMIENTO DE AGUA Y SALPICADURAS (Río, Lago, Riachuelos)
## =========================================================================
static func spawn_water_splash(parent: Node, point: Vector3, normal: Vector3, severity: float = 1.0, is_hot: bool = false) -> void:
	if not is_instance_valid(parent):
		return
	var s := clampf(severity, 0.4, 4.5)

	# Audio violento de entrada al agua / splashdown
	_play_audio(parent, point, _get_water_sound(), clampf(-10.0 + s * 3.5, -18.0, 5.0))

	# --- A. Géiser central de espuma blanca vertical (Foam Geyser Spikes) ---
	var geyser := CPUParticles3D.new()
	geyser.amount = clampi(roundi(36.0 * s), 20, 95)
	geyser.lifetime = clampf(1.1 + s * 0.25, 0.9, 2.0)
	geyser.one_shot = true
	geyser.explosiveness = 0.96
	geyser.direction = Vector3.UP
	geyser.spread = 26.0 # Columna vertical afilada y concentrada
	geyser.particle_flag_align_y = true # Estiramiento hidrodinámico por trayectoria
	geyser.initial_velocity_min = 10.0 * s
	geyser.initial_velocity_max = 25.0 * s
	geyser.gravity = Vector3(0, -32.0, 0) # Arcos parabólicos pesados
	geyser.scale_amount_min = 1.0 * s
	geyser.scale_amount_max = 3.0 * s

	var s_curve := Curve.new()
	s_curve.add_point(Vector2(0.0, 0.4))
	s_curve.add_point(Vector2(0.2, 1.5))
	s_curve.add_point(Vector2(1.0, 0.3))
	geyser.scale_amount_curve = s_curve

	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.98),
		Color(0.92, 0.98, 1.0, 0.92),
		Color(0.65, 0.88, 0.96, 0.65),
		Color(0.4, 0.75, 0.9, 0.0)
	])
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.65, 1.0])
	geyser.color_ramp = ramp

	var drop_quad := QuadMesh.new()
	drop_quad.size = Vector2(0.35, 1.6) # Gotas hidrodinámicas esbeltas
	geyser.mesh = drop_quad
	geyser.material_override = _get_water_material()
	parent.add_child(geyser)
	geyser.global_position = point
	geyser.emitting = true
	geyser.finished.connect(geyser.queue_free)

	# --- B. Corona radial de salpicadura y gotas (Radial Splash Crown) ---
	var crown := CPUParticles3D.new()
	crown.amount = clampi(roundi(30.0 * s), 16, 70)
	crown.lifetime = clampf(0.85 + s * 0.2, 0.7, 1.5)
	crown.one_shot = true
	crown.explosiveness = 0.92
	crown.direction = Vector3.UP * 0.6 + (normal * 0.4 if normal != Vector3.ZERO else Vector3.UP * 0.4)
	crown.spread = 70.0
	crown.particle_flag_align_y = true
	crown.initial_velocity_min = 8.0 * s
	crown.initial_velocity_max = 20.0 * s
	crown.gravity = Vector3(0, -28.0, 0)
	crown.scale_amount_min = 0.6 * s
	crown.scale_amount_max = 1.8 * s
	crown.scale_amount_curve = s_curve
	crown.color_ramp = ramp

	var crown_quad := QuadMesh.new()
	crown_quad.size = Vector2(0.3, 1.1)
	crown.mesh = crown_quad
	crown.material_override = _get_water_material()
	parent.add_child(crown)
	crown.global_position = point + Vector3.UP * 0.1
	crown.emitting = true
	crown.finished.connect(crown.queue_free)

	# --- C. Vaho y neblina de pulverización acuática (Water Mist Foam Layer) ---
	var mist := CPUParticles3D.new()
	mist.amount = clampi(roundi(22.0 * s), 12, 55)
	mist.lifetime = clampf(1.6 + s * 0.35, 1.3, 2.6)
	mist.one_shot = true
	mist.explosiveness = 0.85
	mist.direction = Vector3.UP
	mist.spread = 85.0
	mist.initial_velocity_min = 3.0 * s
	mist.initial_velocity_max = 8.0 * s
	mist.damping_min = 4.0
	mist.damping_max = 8.5
	mist.gravity = Vector3(0, 0.3, 0)
	mist.scale_amount_min = 1.2 * s
	mist.scale_amount_max = 2.8 * s

	var mist_ramp := Gradient.new()
	var mist_col := Color(0.98, 0.94, 0.88) if is_hot else Color(0.92, 0.97, 1.0)
	mist_ramp.colors = PackedColorArray([
		Color(mist_col.r, mist_col.g, mist_col.b, 0.0),
		Color(mist_col.r, mist_col.g, mist_col.b, 0.65),
		Color(mist_col.r, mist_col.g, mist_col.b, 0.0)
	])
	mist_ramp.offsets = PackedFloat32Array([0.0, 0.18, 1.0])
	mist.color_ramp = mist_ramp

	var mist_quad := QuadMesh.new()
	mist_quad.size = Vector2(1.5, 1.5)
	mist.mesh = mist_quad
	mist.material_override = _get_water_material()
	parent.add_child(mist)
	mist.global_position = point + Vector3.UP * 0.3
	mist.emitting = true
	mist.finished.connect(mist.queue_free)

## =========================================================================
## 3. REMOLINO DE POLVO O ESTELA DE AGUA POR VUELO RASANTE (Surface Skimming)
## =========================================================================
static func spawn_surface_wash(parent: Node, point: Vector3, flight_velocity: Vector3, on_water: bool) -> void:
	if not is_instance_valid(parent):
		return
	var horizontal_dir := Vector3(flight_velocity.x, 0, flight_velocity.z).normalized()
	var speed := flight_velocity.length()

	# --- 1. Pluma volumétrica aerada (Spray / Dust Wash) ---
	var wash := CPUParticles3D.new()
	wash.amount = 32 if on_water else 24
	wash.lifetime = 1.2
	wash.one_shot = true
	wash.explosiveness = 0.65
	wash.direction = -horizontal_dir * 0.75 + Vector3.UP * 0.45
	wash.spread = 75.0
	wash.initial_velocity_min = 3.5
	wash.initial_velocity_max = 9.0
	wash.damping_min = 4.0
	wash.damping_max = 8.0
	wash.gravity = Vector3(0, 0.2 if on_water else 0.4, 0)
	wash.scale_amount_min = 2.5
	wash.scale_amount_max = 5.5

	var s_curve := Curve.new()
	s_curve.add_point(Vector2(0.0, 0.4))
	s_curve.add_point(Vector2(0.3, 1.2))
	s_curve.add_point(Vector2(1.0, 2.2))
	wash.scale_amount_curve = s_curve

	var ramp := Gradient.new()
	if on_water:
		ramp.colors = PackedColorArray([
			Color(0.96, 0.98, 1.0, 0.0),
			Color(0.94, 0.97, 1.0, 0.85),
			Color(0.85, 0.94, 0.98, 0.50),
			Color(0.70, 0.88, 0.95, 0.0)
		])
		ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.55, 1.0])
	else:
		ramp.colors = PackedColorArray([
			Color(0.72, 0.64, 0.52, 0.0),
			Color(0.70, 0.62, 0.50, 0.75),
			Color(0.66, 0.58, 0.46, 0.40),
			Color(0.62, 0.54, 0.42, 0.0)
		])
		ramp.offsets = PackedFloat32Array([0.0, 0.10, 0.50, 1.0])
	wash.color_ramp = ramp

	var quad := QuadMesh.new()
	quad.size = Vector2(2.5, 2.5)
	wash.mesh = quad
	wash.material_override = _get_water_material() if on_water else _get_dust_material()

	parent.add_child(wash)
	wash.global_position = point
	wash.finished.connect(wash.queue_free)

	# --- 2. En agua: Disco expansivo de espuma y perturbación superficial (Surface Foam Disk) ---
	if on_water and speed > 8.0:
		var surface_foam := CPUParticles3D.new()
		surface_foam.amount = 18
		surface_foam.lifetime = 1.4
		surface_foam.one_shot = true
		surface_foam.explosiveness = 0.80
		surface_foam.direction = -horizontal_dir
		surface_foam.spread = 80.0
		surface_foam.flatness = 0.95 # Completamente plano en la superficie del agua
		surface_foam.initial_velocity_min = 2.0
		surface_foam.initial_velocity_max = 6.0
		surface_foam.damping_min = 3.0
		surface_foam.damping_max = 6.0
		surface_foam.gravity = Vector3.ZERO
		surface_foam.scale_amount_min = 3.0
		surface_foam.scale_amount_max = 6.5
		surface_foam.scale_amount_curve = s_curve
		surface_foam.color_ramp = ramp
		surface_foam.mesh = quad
		surface_foam.material_override = _get_water_material()

		parent.add_child(surface_foam)
		surface_foam.global_position = point + Vector3.UP * 0.04
		surface_foam.finished.connect(surface_foam.queue_free)
