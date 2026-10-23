extends SceneTree

const SAMPLE_RATE := 44100

class DSP:
	static func clamp_s16(val: float) -> int:
		return clampi(roundi(val * 32760.0), -32767, 32767)
	
	static func warm_clip(x: float, drive: float = 1.0) -> float:
		# Asymmetric tube-style non-linear saturation for organic beastly timbre
		var x_driven := x * drive
		# Asymmetric second-order harmonic enrichment
		var asym := x_driven + 0.18 * x_driven * x_driven
		return tanh(asym)

	static func biquad_filter(samples: PackedFloat32Array, filter_type: String, cutoff: float, q: float) -> PackedFloat32Array:
		var n := samples.size()
		var out := PackedFloat32Array()
		out.resize(n)
		var omega := TAU * clampf(cutoff, 20.0, float(SAMPLE_RATE) * 0.49) / float(SAMPLE_RATE)
		var sn := sin(omega)
		var cs := cos(omega)
		var alpha := sn / (2.0 * maxf(q, 0.05))
		
		var b0 := 0.0
		var b1 := 0.0
		var b2 := 0.0
		var a0 := 1.0 + alpha
		var a1 := -2.0 * cs
		var a2 := 1.0 - alpha
		
		if filter_type == "lp":
			b0 = (1.0 - cs) * 0.5
			b1 = 1.0 - cs
			b2 = (1.0 - cs) * 0.5
		elif filter_type == "hp":
			b0 = (1.0 + cs) * 0.5
			b1 = -(1.0 + cs)
			b2 = (1.0 + cs) * 0.5
		elif filter_type == "bp":
			b0 = alpha
			b1 = 0.0
			b2 = -alpha
		
		b0 /= a0
		b1 /= a0
		b2 /= a0
		a1 /= a0
		a2 /= a0
		
		var x1 := 0.0
		var x2 := 0.0
		var y1 := 0.0
		var y2 := 0.0
		
		for i in n:
			var x0 := samples[i]
			var y0 := b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
			out[i] = y0
			x2 = x1
			x1 = x0
			y2 = y1
			y1 = y0
		return out

	static func normalize_and_save(path: String, samples: PackedFloat32Array, target_peak: float = 0.92, loop: bool = false) -> void:
		var count := samples.size()
		var peak := 0.0001
		for i in count:
			var a := absf(samples[i])
			if a > peak:
				peak = a
		
		var gain := target_peak / peak
		var pcm := PackedByteArray()
		pcm.resize(count * 2)
		for i in count:
			var s := clamp_s16(samples[i] * gain)
			pcm.encode_s16(i * 2, s)
		
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = SAMPLE_RATE
		stream.stereo = false
		stream.data = pcm
		if loop:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = count
		var err := stream.save_to_wav(path)
		print("Guardado: ", path, " -> pico orig: ", snappedf(peak, 0.01), " -> gain: ", snappedf(gain, 0.01), " (res: ", err, ")")

func _init():
	print("=== EXPRIMIENDO AL MÁXIMO LOS 11 SONIDOS CORREGIDOS (CALIDAD CINEMATOGRÁFICA) ===")
	rework_all()
	print("=== SONIDOS GENERADOS Y ACTUALIZADOS CON ÉXITO ===")
	quit()

func rework_all():
	generate_dragon_roar_v2("res://assets/audio/dragon/dragon_roar.wav")
	generate_dragon_wing_flap_v2("res://assets/audio/dragon/dragon_wing_flap.wav")
	generate_dragon_footstep_v2("res://assets/audio/dragon/dragon_footstep.wav")
	generate_dragon_fire_breath_v2("res://assets/audio/dragon/dragon_fire_breath.wav")
	generate_dragon_hurt_v2("res://assets/audio/dragon/dragon_hurt.wav")
	
	generate_knight_attack_v2("res://assets/audio/knights/knight_attack.wav")
	generate_knight_footstep_v2("res://assets/audio/knights/knight_footstep.wav")
	generate_knight_death_v2("res://assets/audio/knights/knight_death.wav")
	generate_ballista_fire_v2("res://assets/audio/knights/ballista_fire.wav")
	generate_ballista_impact_v2("res://assets/audio/knights/ballista_impact.wav")
	
	generate_water_splash_v2("res://assets/audio/ambient/water_splash.wav")

# ==============================================================================
# 1. RUGIDO DE DRAGÓN V2 (Colosal, orgánico, gutural con subharmónicos caóticos)
# ==============================================================================
func generate_dragon_roar_v2(path: String) -> void:
	var duration := 3.6
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 8492
	
	var phase_main := 0.0
	var phase_sub := 0.0
	var phase_growl := 0.0
	var throat_noise := 0.0
	
	# Comb filter delay line buffer para resonancia de garganta cavernosa
	var comb_size := int(0.018 * SAMPLE_RATE) # ~18ms
	var comb_buf := PackedFloat32Array()
	comb_buf.resize(comb_size)
	var comb_idx := 0
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		
		# --- Curva de envolvente cinematográfica (3 fases dramáticas) ---
		var env := 0.0
		if t < 0.55:
			# Fase 1: Inhalación amenazante y gruñido de advertencia en sub-graves
			var p1 := t / 0.55
			env = pow(p1, 2.2) * 0.45
		elif t < 2.3:
			# Fase 2: Apertura explosiva de fauces y rugido atronador
			var p2 := (t - 0.55) / 1.75
			var tremor := 1.0 + 0.15 * sin(t * TAU * 13.5) + 0.08 * sin(t * TAU * 7.2)
			env = (0.45 + 0.55 * sin(p2 * PI * 0.95)) * tremor
		else:
			# Fase 3: Exhalación cavernosa caliente, gárgaras y disipación sísmica
			var p3 := (t - 2.3) / 1.3
			env = 0.55 * exp(-p3 * 3.4)
		
		# --- Contorno de tono orgánico (Frecuencia fundamental f0) ---
		var f0 := 58.0
		if t < 0.55:
			f0 = lerpf(48.0, 72.0, t / 0.55)
		elif t < 1.3:
			f0 = lerpf(72.0, 142.0, (t - 0.55) / 0.75)
		elif t < 2.3:
			var pitch_drift := sin(t * TAU * 3.8) * 8.0 + sin(t * TAU * 8.5) * 5.0
			f0 = lerpf(142.0, 95.0, (t - 1.3) / 1.0) + pitch_drift
		else:
			f0 = lerpf(95.0, 36.0, (t - 2.3) / 1.3)
		
		# Progresión de fases
		var dt_main := f0 / float(SAMPLE_RATE)
		phase_main = fmod(phase_main + dt_main, 1.0)
		# Subharmónico caótico (período doble f0 / 2) característico de rugidos de grandes bestias
		phase_sub = fmod(phase_sub + dt_main * 0.5, 1.0)
		# Modulación de garganta (vocal fry y raspado ~26 Hz)
		phase_growl = fmod(phase_growl + 26.0 / float(SAMPLE_RATE), 1.0)
		
		var p := phase_main * TAU
		var ps := phase_sub * TAU
		
		# Cuerdas vocales y armónicos de tracto vocal
		var v1 := sin(p) * 0.45
		var v2 := sin(p * 2.0) * 0.38
		var v3 := sin(p * 3.0) * 0.28
		var v4 := sin(p * 4.0) * 0.20
		var v5 := sin(p * 5.0) * 0.14
		var v_sub := sin(ps) * 0.40 # Subharmónico añade profundidad masiva
		
		var vocal_fold := v1 + v2 + v3 + v4 + v5 + v_sub
		
		# Modulación de garganta: vibración áspera de cartílago
		var rasp_am := 0.65 + 0.35 * sin(phase_growl * TAU)
		vocal_fold *= rasp_am
		
		# Cimiento sub-grave sísmico (38 - 52 Hz)
		var sub_bass := sin(t * TAU * clampf(f0 * 0.6, 35.0, 55.0)) * 0.65
		
		# Fricción turbulenta de aire caliente (ruido rosa filtrado modulado por la boca)
		var white := rng.randf_range(-1.0, 1.0)
		throat_noise = throat_noise * 0.78 + white * 0.22
		var breath := throat_noise * (0.35 + 0.35 * sin(p))
		
		# Señal combinada con distorsión analógica cálida
		var pre_sat := (vocal_fold * 0.85 + sub_bass * 0.75 + breath * 0.6) * env * 2.2
		var saturated := DSP.warm_clip(pre_sat, 1.35)
		
		# Resonancia de cavidad torácica (comb filter con realimentación)
		var delayed := comb_buf[comb_idx]
		var throat_res := saturated + delayed * 0.38
		comb_buf[comb_idx] = saturated
		comb_idx = (comb_idx + 1) % comb_size
		
		samples[i] = throat_res
	
	# Formante vocal: filtrado pasa-bajos cálido a 2600 Hz
	var filtered := DSP.biquad_filter(samples, "lp", 2600.0, 0.75)
	DSP.normalize_and_save(path, filtered, 0.94)

# ==============================================================================
# 2. ALETEO DE ALAS V2 (Empuje de aire infrasónico y crujido coriáceo)
# ==============================================================================
func generate_dragon_wing_flap_v2(path: String) -> void:
	var duration := 1.15
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 4920
	var air_lp := 0.0
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		
		# Envolvente: ataque veloz con descenso dinámico
		var env := 0.0
		if t < 0.18:
			env = pow(t / 0.18, 1.6)
		else:
			env = exp(-(t - 0.18) * 3.8)
		
		# 1. Empuje de aire infrasónico (45 Hz descendiendo a 22 Hz)
		var freq := lerpf(46.0, 22.0, clampf(t / 0.9, 0.0, 1.0))
		var infrasound := sin(t * TAU * freq) * 0.85
		
		# 2. Turbulencia de aire masivo desplazado (ruido con envolvente de batido)
		var white := rng.randf_range(-1.0, 1.0)
		air_lp = air_lp * 0.82 + white * 0.18
		var air_flow := air_lp * (1.0 + 0.35 * sin(t * TAU * 14.0)) * 0.7
		
		# 3. Tensión y crujido coriáceo de membrana alar (micro-chasquidos de cuero)
		var leather_snap := 0.0
		if t >= 0.12 and t <= 0.32:
			var st := (t - 0.12) / 0.20
			var flex := sin(st * PI)
			var snap_osc := sin((t - 0.12) * TAU * 185.0) * 0.6 + sin((t - 0.12) * TAU * 340.0) * 0.35
			leather_snap = snap_osc * flex * 0.55
		
		# 4. Segundo aletazo residual suave al final del recorrido (t ~ 0.45)
		var flutter := 0.0
		if t >= 0.38 and t <= 0.65:
			var ft := (t - 0.38) / 0.27
			flutter = sin(ft * PI) * sin((t - 0.38) * TAU * 62.0) * 0.3
		
		var raw := (infrasound * 0.8 + air_flow * 0.7 + leather_snap * 0.6 + flutter * 0.4) * env * 2.0
		samples[i] = DSP.warm_clip(raw, 1.1)
	
	var out := DSP.biquad_filter(samples, "lp", 1400.0, 0.65)
	DSP.normalize_and_save(path, out, 0.92)

# ==============================================================================
# 3. PISADA / IMPACTO DE DRAGÓN V2 (Colapso sísmico y fractura granular de roca)
# ==============================================================================
func generate_dragon_footstep_v2(path: String) -> void:
	var duration := 0.75
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 6194
	var soil_lp := 0.0
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		
		# Envolvente de golpe seco masivo
		var thud_env := exp(-t * 9.5)
		
		# 1. Golpe sub-grave sísmico de peso colosal (52 Hz -> 20 Hz)
		var f_impact := lerpf(54.0, 20.0, clampf(t * 6.5, 0.0, 1.0))
		var sub_thud := sin(t * TAU * f_impact) * 0.95 * thud_env
		
		# 2. Fractura de roca y compresión de tierra: síntesis granular estocástica
		var white := rng.randf_range(-1.0, 1.0)
		soil_lp = soil_lp * 0.68 + white * 0.32
		var soil_env := exp(-t * 16.0)
		var soil_crunch := soil_lp * soil_env * 0.65
		
		# Micro-crujidos de piedra quebrándose bajo la garra
		var rock_fracture := 0.0
		if t < 0.18 and rng.randf() < 0.04:
			rock_fracture = rng.randf_range(-0.8, 0.8) * exp(-t * 22.0)
		
		# 3. Impacto de garras en el lecho duro (transitorio inicial afilado)
		var claw_click := 0.0
		if t < 0.04:
			claw_click = sin(t * TAU * 580.0) * exp(-t * 110.0) * 0.45
		
		# 4. Resonancia del terreno (retumbe de suelo a 36 Hz)
		var ground_hum := sin(t * TAU * 36.0) * exp(-t * 6.0) * 0.35
		
		var total := (sub_thud + soil_crunch + rock_fracture + claw_click + ground_hum) * 1.6
		samples[i] = DSP.warm_clip(total, 1.15)
	
	var out := DSP.biquad_filter(samples, "lp", 1800.0, 0.7)
	DSP.normalize_and_save(path, out, 0.95)

# ==============================================================================
# 4. ALIENTO DE FUEGO V2 (Vórtice de combustión violenta, soplete y chispas)
# ==============================================================================
func generate_dragon_fire_breath_v2(path: String) -> void:
	var duration := 2.8
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 7351
	
	var low_combust := 0.0
	var mid_flame := 0.0
	var high_hiss := 0.0
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		
		# Envolvente: deflagración inicial violenta (whoof), llamarada sostenida, corte térmico
		var env := 0.0
		if t < 0.15:
			env = pow(t / 0.15, 1.4) * 1.25 # Pico de ignición
		elif t < 2.2:
			var flame_tremor := 1.0 + 0.12 * sin(t * TAU * 9.5) + 0.08 * sin(t * TAU * 19.0)
			env = 1.0 * flame_tremor
		else:
			env = exp(-(t - 2.2) * 4.8)
		
		# 1. Deflagración de gas a baja frecuencia (70 - 130 Hz vortex rumble)
		var r1 := rng.randf_range(-1.0, 1.0)
		low_combust = low_combust * 0.88 + r1 * 0.12
		var flame_bass := low_combust * (0.8 + 0.25 * sin(t * TAU * 24.0)) * 0.7
		
		# 2. Rugido de fuego a presión (soplete de gas turbulento 300 - 900 Hz)
		var r2 := rng.randf_range(-1.0, 1.0)
		mid_flame = mid_flame * 0.62 + r2 * 0.38
		
		# 3. Silbido de combustión de alta presión (3 kHz - 6 kHz)
		var r3 := rng.randf_range(-1.0, 1.0)
		high_hiss = high_hiss * 0.35 + r3 * 0.65
		
		# 4. Estallidos y chasquidos de chispas incandescentes
		var spark_pop := 0.0
		if rng.randf() < 0.004:
			spark_pop = rng.randf_range(-0.9, 0.9) * 0.5
		
		# Golpe de ignición en t < 0.18s
		var ignition_thump := 0.0
		if t < 0.18:
			ignition_thump = sin(t * TAU * 78.0) * exp(-t * 22.0) * 0.5
		
		var raw := (flame_bass * 0.75 + mid_flame * 0.55 + high_hiss * 0.28 + spark_pop + ignition_thump) * env * 1.8
		samples[i] = DSP.warm_clip(raw, 1.2)
	
	var out := DSP.biquad_filter(samples, "lp", 3600.0, 0.7)
	DSP.normalize_and_save(path, out, 0.94)

# ==============================================================================
# 5. QUEJIDO / DAÑO DE DRAGÓN V2 (Gruñido gutural reptiliano visceral)
# ==============================================================================
func generate_dragon_hurt_v2(path: String) -> void:
	var duration := 0.75
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 5129
	var phase := 0.0
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		
		# Ataque seco de impacto y dolor con decaimiento rápido
		var env := exp(-t * 6.8) * (1.0 - exp(-t * 60.0))
		
		# Caída brusca de tono pained: 155 Hz a 45 Hz
		var f0 := lerpf(155.0, 42.0, pow(clampf(t / 0.7, 0.0, 1.0), 0.8))
		phase = fmod(phase + f0 / float(SAMPLE_RATE), 1.0)
		var p := phase * TAU
		
		# Cuerdas vocales sofocadas con armónicos pares e impares
		var vocal := sin(p) * 0.5 + sin(p * 2.0) * 0.4 + sin(p * 3.0) * 0.3 + sin(p * 4.0) * 0.18
		
		# Rugosidad vocal caótica (choque en la laringe ~34 Hz)
		var choke := 0.7 + 0.3 * sin(t * TAU * 34.0)
		vocal *= choke
		
		# Expulsión de aire áspero por el golpe
		var rasp := rng.randf_range(-1.0, 1.0) * exp(-t * 10.0) * 0.4
		
		# Impacto seco en pecho (golpe sordo)
		var chest_thump := sin(t * TAU * 65.0) * exp(-t * 24.0) * 0.6
		
		var raw := (vocal * 0.8 + rasp + chest_thump) * env * 2.2
		samples[i] = DSP.warm_clip(raw, 1.3)
	
	var out := DSP.biquad_filter(samples, "lp", 2400.0, 0.75)
	DSP.normalize_and_save(path, out, 0.94)

# ==============================================================================
# 6. ATAQUE DE ESPADA V2 (Silbido veloz de hoja de acero y canto de filo)
# ==============================================================================
func generate_knight_attack_v2(path: String) -> void:
	var duration := 0.45
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 3381
	var lp := 0.0
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		
		# Curva de velocidad Doppler del tajo (aceleración -> pico a t=0.14s -> salida)
		var swing_progress := clampf(t / 0.35, 0.0, 1.0)
		var env := sin(swing_progress * PI)
		
		# Barrido aerodinámico rápido de la hoja (1800 Hz -> 360 Hz)
		var sweep_freq := lerpf(1800.0, 360.0, pow(swing_progress, 1.5))
		var coeff := clampf(sweep_freq / float(SAMPLE_RATE) * 2.0, 0.04, 0.85)
		var white := rng.randf_range(-1.0, 1.0)
		lp = lp * (1.0 - coeff) + white * coeff
		var blade_whoosh := lp * env * 0.75
		
		# Resonancia metálica del acero forjado (modos armónicos puros que cantan)
		var steel_env := exp(-t * 10.0)
		var m1 := sin(t * TAU * 2380.0) * 0.42
		var m2 := sin(t * TAU * 4760.0) * 0.22
		var m3 := sin(t * TAU * 7140.0) * 0.12
		var steel_ring := (m1 + m2 + m3) * steel_env
		
		var raw := (blade_whoosh + steel_ring) * 1.8
		samples[i] = DSP.warm_clip(raw, 1.1)
	
	DSP.normalize_and_save(path, samples, 0.94)

# ==============================================================================
# 7. PASO CON ARMADURA V2 (Bota sobre piedra, placas articuladas y cota de malla)
# ==============================================================================
func generate_knight_footstep_v2(path: String) -> void:
	var duration := 0.42
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 8821
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		
		# 1. Tacón de bota sobre adoquín o tierra compacta
		var boot_thud := sin(t * TAU * 125.0) * exp(-t * 32.0) * 0.55
		var boot_gravel := rng.randf_range(-1.0, 1.0) * exp(-t * 28.0) * 0.25
		
		# 2. Choque de placas de acero (grebas y escarpines chocando en micro-desfases)
		var p1 := sin(t * TAU * 1150.0) * exp(-t * 24.0) * 0.35
		var p2 := sin(t * TAU * 2240.0) * exp(-t * 36.0) * 0.25
		
		# Placa secundaria desfasada (8ms después)
		var p3 := 0.0
		if t >= 0.008:
			var dt := t - 0.008
			p3 = sin(dt * TAU * 1780.0) * exp(-dt * 26.0) * 0.28
		
		# 3. Tintineo sutil de cota de malla (anillas de hierro entrechocándose ~4 kHz)
		var mail := 0.0
		if t >= 0.015:
			var mt := t - 0.015
			mail = (sin(mt * TAU * 3900.0) + sin(mt * TAU * 5200.0) * 0.6) * exp(-mt * 20.0) * 0.18
		
		var total := (boot_thud + boot_gravel + p1 + p2 + p3 + mail) * 1.7
		samples[i] = DSP.warm_clip(total, 1.05)
	
	DSP.normalize_and_save(path, samples, 0.93)

# ==============================================================================
# 8. DERROTA DE CABALLERO V2 (Colapso realista, golpe de coraza, rebote de armas)
# ==============================================================================
func generate_knight_death_v2(path: String) -> void:
	var duration := 1.45
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 4172
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		
		# 1. Rodillas y cuerpo cayendo en tierra (t = 0.06s)
		var body_drop := 0.0
		if t >= 0.05:
			var dt1 := t - 0.05
			body_drop = sin(dt1 * TAU * 85.0) * exp(-dt1 * 14.0) * 0.55
		
		# 2. Peto de acero estrellándose contra el suelo (t = 0.18s) - IMPACTO MAYOR
		var armor_crash := 0.0
		if t >= 0.18:
			var dt2 := t - 0.18
			var thud := sin(dt2 * TAU * 95.0) * exp(-dt2 * 12.0) * 0.65
			var metal1 := (sin(dt2 * TAU * 780.0) + sin(dt2 * TAU * 1450.0) * 0.7) * exp(-dt2 * 15.0) * 0.5
			var metal2 := sin(dt2 * TAU * 2800.0) * exp(-dt2 * 25.0) * 0.35
			var debris := rng.randf_range(-1.0, 1.0) * exp(-dt2 * 18.0) * 0.35
			armor_crash = thud + metal1 + metal2 + debris
		
		# 3. Escudo y espada soltándose y rebotando (t = 0.38s y t = 0.62s)
		var weapon_bounce := 0.0
		if t >= 0.38:
			var dt3 := t - 0.38
			weapon_bounce += (sin(dt3 * TAU * 1680.0) + sin(dt3 * TAU * 3360.0) * 0.5) * exp(-dt3 * 16.0) * 0.4
		if t >= 0.62:
			var dt4 := t - 0.62
			weapon_bounce += sin(dt4 * TAU * 2150.0) * exp(-dt4 * 20.0) * 0.25
		
		# 4. Cota de malla desparramándose y asentándose (t = 0.45s a 1.1s)
		var mail_settle := 0.0
		if t >= 0.45 and t <= 1.2:
			var dt5 := t - 0.45
			var jingle := (sin(dt5 * TAU * 4100.0) + sin(dt5 * TAU * 5600.0) * 0.5) * exp(-dt5 * 6.0) * 0.16
			var friction := rng.randf_range(-1.0, 1.0) * exp(-dt5 * 7.5) * 0.14
			mail_settle = jingle + friction
		
		var raw := (body_drop + armor_crash + weapon_bounce + mail_settle) * 1.55
		samples[i] = DSP.warm_clip(raw, 1.1)
	
	DSP.normalize_and_save(path, samples, 0.94)

# ==============================================================================
# 9. DISPARO DE BALISTA V2 (Madera maciza, chasquido de cuerda de torsión y silbido)
# ==============================================================================
func generate_ballista_fire_v2(path: String) -> void:
	var duration := 0.85
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 9214
	var whoosh_lp := 0.0
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		
		# 1. Golpe seco del tope de madera maciza (brazo de roble impactando el marco)
		var wood_impact := sin(t * TAU * 135.0) * exp(-t * 26.0) * 0.85
		var wood_crack := sin(t * TAU * 480.0) * exp(-t * 40.0) * 0.45
		
		# 2. Chasquido violento de cuerda de torsión (vibración tensada 360 Hz -> 190 Hz)
		var twang_f := lerpf(360.0, 195.0, clampf(t * 5.0, 0.0, 1.0))
		var cable_env := exp(-t * 9.5)
		var cable_twang := (sin(t * TAU * twang_f) * 0.65 + sin(t * TAU * twang_f * 2.3) * 0.35 + sin(t * TAU * twang_f * 4.1) * 0.18) * cable_env
		
		# 3. Proyectil pesado de 2 metros cortando el aire a gran velocidad
		var whoosh_env := sin(clampf(t / 0.45, 0.0, 1.0) * PI)
		var white := rng.randf_range(-1.0, 1.0)
		whoosh_lp = whoosh_lp * 0.78 + white * 0.22
		var bolt_launch := whoosh_lp * whoosh_env * 0.55
		
		var raw := (wood_impact + wood_crack + cable_twang + bolt_launch) * 1.6
		samples[i] = DSP.warm_clip(raw, 1.15)
	
	DSP.normalize_and_save(path, samples, 0.94)

# ==============================================================================
# 10. IMPACTO DE SAETA V2 (Impacto cinético brutal, astillamiento y onda de choque)
# ==============================================================================
func generate_ballista_impact_v2(path: String) -> void:
	var duration := 0.85
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 6650
	var shatter_lp := 0.0
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		
		# 1. Transitorio inicial hipersónico (punta de hierro macizo clavándose)
		var iron_snap := sin(t * TAU * 2400.0) * exp(-t * 90.0) * 0.65
		
		# 2. Onda expansiva sub-grave (penetración balística 65 Hz -> 28 Hz)
		var shock_f := lerpf(68.0, 26.0, clampf(t * 7.0, 0.0, 1.0))
		var sub_shock := sin(t * TAU * shock_f) * exp(-t * 11.0) * 0.9
		
		# 3. Astillamiento violento de madera y fractura de mampostería
		var white := rng.randf_range(-1.0, 1.0)
		shatter_lp = shatter_lp * 0.62 + white * 0.38
		var debris_crunch := shatter_lp * exp(-t * 20.0) * 0.75
		
		# Astillas individuales de madera quebrándose a presión
		var splinter_pop := 0.0
		if t < 0.22 and rng.randf() < 0.05:
			splinter_pop = rng.randf_range(-0.8, 0.8) * exp(-t * 26.0)
		
		var raw := (iron_snap + sub_shock + debris_crunch + splinter_pop) * 1.65
		samples[i] = DSP.warm_clip(raw, 1.2)
	
	DSP.normalize_and_save(path, samples, 0.95)

# ==============================================================================
# 11. SALPICADURA DE AGUA V2 (Explosión acuática, colapso de cavidad y lluvia)
# ==============================================================================
func generate_water_splash_v2(path: String) -> void:
	var duration := 1.75
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 9183
	var spray_lp := 0.0
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		
		# 1. Golpe de tensión superficial (palmada hidrodinámica masiva a t < 0.08s)
		var slap := 0.0
		if t < 0.09:
			slap = sin(t * TAU * 130.0) * exp(-t * 42.0) * 0.95
		
		# 2. Colapso de la cavidad de aire sumergida (sub-grave profundo "K-BLOOMP" 48 Hz)
		var cavity := 0.0
		if t >= 0.02:
			var ct := t - 0.02
			cavity = sin(ct * TAU * 50.0) * exp(-ct * 8.5) * 0.85
		
		# 3. Penacho de agua pulverizada y turbulencia de espuma (spray explosivo)
		var white := rng.randf_range(-1.0, 1.0)
		spray_lp = spray_lp * 0.65 + white * 0.35
		var spray_env := exp(-t * 3.4) * (1.0 - exp(-t * 30.0))
		var spray := spray_lp * spray_env * 0.7
		
		# 4. Caída estocástica de cientos de gotas pesadas rebotando en el lago (t > 0.3s)
		var droplets := 0.0
		if t > 0.25 and rng.randf() < 0.025:
			var drop_f := rng.randf_range(550.0, 1600.0)
			droplets = sin(t * TAU * drop_f) * rng.randf_range(0.2, 0.6) * exp(-(t - 0.25) * 2.8)
		
		var raw := (slap + cavity + spray + droplets) * 1.6
		samples[i] = DSP.warm_clip(raw, 1.1)
	
	var out := DSP.biquad_filter(samples, "lp", 3200.0, 0.7)
	DSP.normalize_and_save(path, out, 0.94)
