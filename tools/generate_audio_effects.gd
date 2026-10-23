extends SceneTree

const SAMPLE_RATE := 44100

class DSP:
	static func clamp_s16(val: float) -> int:
		return clampi(roundi(val * 32760.0), -32767, 32767)
	
	static func soft_clip(x: float) -> float:
		# Soft saturation curve
		return tanh(x) if absf(x) < 3.0 else signf(x)

	static func biquad_filter(samples: PackedFloat32Array, filter_type: String, cutoff: float, q: float) -> PackedFloat32Array:
		var n := samples.size()
		var out := PackedFloat32Array()
		out.resize(n)
		var omega := TAU * cutoff / float(SAMPLE_RATE)
		var sn := sin(omega)
		var cs := cos(omega)
		var alpha := sn / (2.0 * q)
		
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

	static func save_wav(path: String, samples: PackedFloat32Array, loop: bool = false) -> void:
		var count := samples.size()
		var pcm := PackedByteArray()
		pcm.resize(count * 2)
		for i in count:
			var s := clamp_s16(samples[i])
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
		print("Saved ", path, " -> result: ", err, " (samples: ", count, ")")

func _init():
	print("--- INICIANDO GENERACIÓN DE AUDIO PROCEDURAL CINEMATOGRÁFICO ---")
	generate_all()
	print("--- GENERACIÓN FINALIZADA CON ÉXITO ---")
	quit()

func generate_all():
	generate_dragon_roar("res://assets/audio/dragon/dragon_roar.wav")
	generate_dragon_wing_flap("res://assets/audio/dragon/dragon_wing_flap.wav")
	generate_dragon_footstep("res://assets/audio/dragon/dragon_footstep.wav")
	generate_dragon_fire_breath("res://assets/audio/dragon/dragon_fire_breath.wav")
	generate_dragon_hurt("res://assets/audio/dragon/dragon_hurt.wav")
	
	generate_knight_attack("res://assets/audio/knights/knight_attack.wav")
	generate_knight_footstep("res://assets/audio/knights/knight_footstep.wav")
	generate_knight_death("res://assets/audio/knights/knight_death.wav")
	generate_ballista_fire("res://assets/audio/knights/ballista_fire.wav")
	generate_ballista_impact("res://assets/audio/knights/ballista_impact.wav")
	
	generate_ambient_wind("res://assets/audio/ambient/ambient_wind.wav")
	generate_flight_wind_rush("res://assets/audio/ambient/flight_wind_rush.wav")
	generate_ambient_water("res://assets/audio/ambient/ambient_water.wav")
	generate_water_splash("res://assets/audio/ambient/water_splash.wav")

# -------------------------------------------------------------
# DRAGON SOUNDS
# -------------------------------------------------------------
func generate_dragon_roar(path: String) -> void:
	var duration := 3.2
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 9821
	
	var throat_phase := 0.0
	var low_noise := 0.0
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		
		# Envelope
		var env := 0.0
		if t < 0.4:
			# Inhale / growl rise
			env = lerpf(0.05, 0.4, t / 0.4)
		elif t < 0.9:
			# Explosive roar surge
			env = lerpf(0.4, 1.0, (t - 0.4) / 0.5)
		elif t < 2.2:
			# Sustained mighty roar with organic tremor
			var tremor := 1.0 + 0.12 * sin(t * TAU * 11.5) + 0.08 * sin(t * TAU * 6.2)
			env = 1.0 * tremor
		else:
			# Long rumbling chest exhale
			var decay := (t - 2.2) / 1.0
			env = exp(-decay * 3.2)
		
		# Fundamental pitch contour (Hz)
		var f0 := 62.0
		if t < 0.4:
			f0 = lerpf(55.0, 72.0, t / 0.4)
		elif t < 0.9:
			f0 = lerpf(72.0, 138.0, (t - 0.4) / 0.5)
		elif t < 2.0:
			var pitch_wobble := sin(t * TAU * 4.5) * 6.0 + sin(t * TAU * 9.0) * 4.0
			f0 = lerpf(138.0, 112.0, (t - 0.9) / 1.1) + pitch_wobble
		else:
			f0 = lerpf(112.0, 48.0, (t - 2.0) / 1.2)
		
		# Vocal cord pulse + rich harmonics
		throat_phase += f0 / float(SAMPLE_RATE)
		if throat_phase > 1.0:
			throat_phase -= 1.0
		
		var p := throat_phase * TAU
		# Multi-harmonic vocal glottal model
		var vocal := sin(p) * 0.55 + sin(p * 2.0) * 0.42 + sin(p * 3.0) * 0.32 + sin(p * 4.0) * 0.22 + sin(p * 5.0) * 0.15
		
		# Throat rasp AM (beastly vocal growl vibration ~32 Hz)
		var growl_am := 0.75 + 0.25 * sin(t * TAU * 28.0)
		vocal *= growl_am
		
		# Chest sub-bass resonance (52 Hz fundamental reinforcement)
		var sub := sin(t * TAU * 50.0) * 0.45 * (0.8 if t > 0.6 else 0.3)
		
		# Throat breath/friction noise
		var raw_n := rng.randf_range(-1.0, 1.0)
		low_noise = low_noise * 0.75 + raw_n * 0.25
		var friction := low_noise * (0.35 + 0.25 * sin(p)) # AM-modulated breath turbulence
		
		# Combine and apply beastly saturation
		var raw_signal := (vocal * 0.75 + sub * 0.45 + friction * 0.55) * env * 1.5
		var saturated := DSP.soft_clip(raw_signal) * 0.82
		samples[i] = saturated
	
	# Formant pass: resonant vocal cavity filter ~520 Hz & 1450 Hz
	var filtered := DSP.biquad_filter(samples, "lp", 2800.0, 0.8)
	DSP.save_wav(path, filtered)

func generate_dragon_wing_flap(path: String) -> void:
	var duration := 0.95
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 3311
	var noise_filter := 0.0
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		
		# Air stroke envelope: fast attack, rounded crest, air release
		var env := 0.0
		if t < 0.15:
			env = pow(t / 0.15, 1.8)
		else:
			env = exp(-(t - 0.15) * 4.5)
		
		# Low frequency air displacement whoosh (sweeping 85 Hz down to 35 Hz)
		var freq := lerpf(85.0, 32.0, clampf(t / 0.8, 0.0, 1.0))
		var sub_whoosh := sin(t * TAU * freq) * 0.7
		
		# Leathery wing flutter: band-filtered noise modulated with 14 Hz ripple
		var raw_n := rng.randf_range(-1.0, 1.0)
		noise_filter = noise_filter * 0.82 + raw_n * 0.18
		var flutter := noise_filter * (1.0 + 0.4 * sin(t * TAU * 16.0)) * 0.5
		
		# Leather sail tension pop at apex (t ~ 0.14)
		var snap := 0.0
		if t >= 0.11 and t <= 0.22:
			var st := (t - 0.11) / 0.11
			snap = sin(st * PI) * sin((t - 0.11) * TAU * 160.0) * 0.35
		
		var val := (sub_whoosh * 0.65 + flutter * 0.45 + snap * 0.3) * env * 1.6
		samples[i] = DSP.soft_clip(val) * 0.88
	
	var smoothed := DSP.biquad_filter(samples, "lp", 1100.0, 0.7)
	DSP.save_wav(path, smoothed)

func generate_dragon_footstep(path: String) -> void:
	var duration := 0.6
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 5712
	var lp := 0.0
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 9.0)
		
		# Massive ground impact punch (sub-bass drop 55 Hz -> 26 Hz)
		var freq := lerpf(55.0, 26.0, clampf(t * 5.0, 0.0, 1.0))
		var sub := sin(t * TAU * freq) * 0.75 * env
		
		# Dirt, sand & rock crush transient
		var raw_n := rng.randf_range(-1.0, 1.0)
		lp = lp * 0.65 + raw_n * 0.35
		var crunch_env := exp(-t * 18.0)
		var crunch := lp * crunch_env * 0.45
		
		# Heavy claw contact click at t < 0.03
		var click := 0.0
		if t < 0.03:
			click = sin(t * TAU * 480.0) * exp(-t * 120.0) * 0.35
		
		var total := (sub + crunch + click) * 1.4
		samples[i] = DSP.soft_clip(total) * 0.85
	
	var out := DSP.biquad_filter(samples, "lp", 1600.0, 0.7)
	DSP.save_wav(path, out)

func generate_dragon_fire_breath(path: String) -> void:
	var duration := 2.6
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 6614
	var low_n := 0.0
	var mid_n := 0.0
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		
		# Fire blast envelope: quick ignite burst, sustained roar, release
		var env := 0.0
		if t < 0.12:
			env = pow(t / 0.12, 1.5)
		elif t < 2.0:
			env = 1.0 + 0.08 * sin(t * TAU * 8.5)
		else:
			env = exp(-(t - 2.0) * 5.0)
		
		# Sub combustor rumble (65-120 Hz)
		var raw_1 := rng.randf_range(-1.0, 1.0)
		low_n = low_n * 0.88 + raw_1 * 0.12
		var flame_rumble := low_n * (0.8 + 0.2 * sin(t * TAU * 18.0))
		
		# Roaring combustion turbulence (300-900 Hz)
		var raw_2 := rng.randf_range(-1.0, 1.0)
		mid_n = mid_n * 0.62 + raw_2 * 0.38
		
		# Occasional sizzling sparks
		var spark := 0.0
		if rng.randf() < 0.003:
			spark = rng.randf_range(0.4, 0.9)
		
		var raw_flame := (flame_rumble * 0.55 + mid_n * 0.45 + spark * 0.25) * env * 1.8
		samples[i] = DSP.soft_clip(raw_flame) * 0.8
	
	var shaped := DSP.biquad_filter(samples, "lp", 3400.0, 0.7)
	DSP.save_wav(path, shaped)

func generate_dragon_hurt(path: String) -> void:
	var duration := 0.65
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 4410
	var throat_phase := 0.0
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 6.5) * (1.0 - exp(-t * 40.0))
		
		# Pained guttural pitch dive: 130 Hz down to 50 Hz
		var f0 := lerpf(130.0, 48.0, clampf(t / 0.6, 0.0, 1.0))
		throat_phase += f0 / float(SAMPLE_RATE)
		if throat_phase > 1.0:
			throat_phase -= 1.0
		var p := throat_phase * TAU
		
		var vocal := (sin(p) * 0.5 + sin(p * 2.0) * 0.35 + sin(p * 3.0) * 0.2)
		var rasp := rng.randf_range(-1.0, 1.0) * 0.25
		var grunt := (vocal + rasp) * env * 1.8
		samples[i] = DSP.soft_clip(grunt) * 0.85
	
	var out := DSP.biquad_filter(samples, "lp", 2200.0, 0.8)
	DSP.save_wav(path, out)

# -------------------------------------------------------------
# KNIGHTS & SIEGE SOUNDS
# -------------------------------------------------------------
func generate_knight_attack(path: String) -> void:
	# Sharp sword slash whoosh + steel edge ring
	var duration := 0.42
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 2011
	var lp := 0.0
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		
		# Whoosh envelope: parabolic velocity peaking at t = 0.15
		var env := sin(clampf(t / duration, 0.0, 1.0) * PI)
		
		# Air whoosh bandpass sweep (1400 Hz -> 380 Hz)
		var raw_n := rng.randf_range(-1.0, 1.0)
		var sweep_f := lerpf(1400.0, 380.0, t / duration)
		var filt_coeff := clampf(sweep_f / float(SAMPLE_RATE) * 2.0, 0.05, 0.85)
		lp = lp * (1.0 - filt_coeff) + raw_n * filt_coeff
		var whoosh := lp * env * 0.65
		
		# Steel blade chime ringing
		var steel_env := exp(-t * 9.0)
		var steel := (sin(t * TAU * 2150.0) * 0.45 + sin(t * TAU * 4320.0) * 0.25) * steel_env
		
		var combined := (whoosh + steel) * 1.5
		samples[i] = DSP.soft_clip(combined) * 0.82
	
	DSP.save_wav(path, samples)

func generate_knight_footstep(path: String) -> void:
	# Boot heel impact + metallic armor plate rattle
	var duration := 0.38
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 7182
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 16.0)
		
		# Boot step tap
		var step := sin(t * TAU * 115.0) * exp(-t * 28.0) * 0.5
		
		# Armor plate high resonances (metal clink)
		var armor1 := sin(t * TAU * 1280.0) * exp(-t * 22.0) * 0.3
		var armor2 := sin(t * TAU * 2450.0) * exp(-t * 30.0) * 0.2
		var armor3 := sin(t * TAU * 3600.0) * exp(-t * 45.0) * 0.15
		
		# Secondary rattle at t > 0.08
		var rattle := 0.0
		if t > 0.08:
			var rt := t - 0.08
			rattle = sin(rt * TAU * 1820.0) * exp(-rt * 28.0) * 0.22
		
		var gravel := rng.randf_range(-1.0, 1.0) * exp(-t * 25.0) * 0.15
		
		var total := (step + armor1 + armor2 + armor3 + rattle + gravel) * 1.4
		samples[i] = DSP.soft_clip(total) * 0.82
	
	DSP.save_wav(path, samples)

func generate_knight_death(path: String) -> void:
	# Heavy armored knight falling to ground: armor crash, metal plates clattering
	var duration := 1.25
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 9931
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		
		# 1. Main body impact (t = 0.05)
		var s1 := 0.0
		if t >= 0.04:
			var dt1 := t - 0.04
			var thump := sin(dt1 * TAU * 80.0) * exp(-dt1 * 12.0) * 0.55
			var metal := (sin(dt1 * TAU * 820.0) + sin(dt1 * TAU * 1650.0) * 0.6) * exp(-dt1 * 14.0) * 0.4
			var noise_burst := rng.randf_range(-1.0, 1.0) * exp(-dt1 * 20.0) * 0.3
			s1 = thump + metal + noise_burst
		
		# 2. Secondary shield / sword bounce (t = 0.28)
		var s2 := 0.0
		if t >= 0.28:
			var dt2 := t - 0.28
			var ping := (sin(dt2 * TAU * 1420.0) + sin(dt2 * TAU * 2840.0) * 0.5) * exp(-dt2 * 18.0) * 0.35
			s2 = ping
		
		# 3. Chainmail / plate slide rattle (t = 0.45 to 0.9)
		var s3 := 0.0
		if t >= 0.45:
			var dt3 := t - 0.45
			var clink := sin(dt3 * TAU * 2100.0) * exp(-dt3 * 8.0) * 0.15
			var scrape := rng.randf_range(-1.0, 1.0) * exp(-dt3 * 10.0) * 0.12
			s3 = clink + scrape
		
		var sum := (s1 + s2 + s3) * 1.3
		samples[i] = DSP.soft_clip(sum) * 0.85
	
	DSP.save_wav(path, samples)

func generate_ballista_fire(path: String) -> void:
	# Heavy wooden release "thunk", steel cable twang, arrow launch whoosh
	var duration := 0.75
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 8123
	var whoosh_lp := 0.0
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		
		# Heavy wood lever release transient
		var wood := sin(t * TAU * 145.0) * exp(-t * 22.0) * 0.65
		
		# Taut steel cable twang (starts at 310 Hz, decays with metal ringing)
		var twang_f := lerpf(310.0, 220.0, clampf(t * 4.0, 0.0, 1.0))
		var cable := (sin(t * TAU * twang_f) * 0.5 + sin(t * TAU * twang_f * 2.2) * 0.25) * exp(-t * 8.5)
		
		# Bolt fast launch whoosh
		var whoosh_env := sin(clampf(t / 0.4, 0.0, 1.0) * PI)
		var raw_n := rng.randf_range(-1.0, 1.0)
		whoosh_lp = whoosh_lp * 0.8 + raw_n * 0.2
		var bolt_whoosh := whoosh_lp * whoosh_env * 0.4
		
		var total := (wood + cable + bolt_whoosh) * 1.4
		samples[i] = DSP.soft_clip(total) * 0.84
	
	DSP.save_wav(path, samples)

func generate_ballista_impact(path: String) -> void:
	# Iron-tipped bolt slamming into stone/wood: sharp crack, deep thud, debris splinter
	var duration := 0.75
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 6321
	var crunch_lp := 0.0
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		
		# Heavy kinetic shockwave
		var shock := sin(t * TAU * 68.0) * exp(-t * 12.0) * 0.7
		
		# Wood splinter / stone shatter high crunch
		var raw_n := rng.randf_range(-1.0, 1.0)
		crunch_lp = crunch_lp * 0.68 + raw_n * 0.32
		var crunch := crunch_lp * exp(-t * 24.0) * 0.55
		
		# Iron tip metallic impact click
		var iron_click := sin(t * TAU * 1850.0) * exp(-t * 60.0) * 0.4
		
		var total := (shock + crunch + iron_click) * 1.45
		samples[i] = DSP.soft_clip(total) * 0.85
	
	DSP.save_wav(path, samples)

# -------------------------------------------------------------
# AMBIENT SOUNDS (WIND, WATER, FLIGHT)
# -------------------------------------------------------------
func generate_ambient_wind(path: String) -> void:
	# Atmospheric mountain wind (smooth 6.0-second seamless loop)
	var duration := 6.0
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 1042
	
	# Pre-generate pink noise buffer
	var raw := PackedFloat32Array()
	raw.resize(count)
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	for i in count:
		var white := rng.randf_range(-1.0, 1.0)
		b0 = 0.99886 * b0 + white * 0.0555179
		b1 = 0.99332 * b1 + white * 0.0750759
		b2 = 0.96900 * b2 + white * 0.1538520
		raw[i] = b0 + b1 + b2 + white * 0.5362
	
	# Dynamic filter modulation: sweeping wind gusts
	var lp := 0.0
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		# Cyclic gust LFO (seamless loop)
		var gust1 := sin(t / duration * TAU * 1.0) * 0.5 + 0.5
		var gust2 := sin(t / duration * TAU * 2.0 + 0.8) * 0.3 + 0.3
		var gust := clampf(gust1 * 0.65 + gust2 * 0.35, 0.1, 1.0)
		
		# Modulate cutoff between 160 Hz and 620 Hz
		var cutoff := lerpf(160.0, 620.0, gust)
		var coeff := clampf(cutoff / float(SAMPLE_RATE) * 2.0, 0.005, 0.35)
		lp = lp * (1.0 - coeff) + raw[i] * coeff
		
		# Gentle high whistle gust peak
		var whistle := sin(t * TAU * (410.0 + gust * 70.0)) * 0.04 * pow(gust, 2.0)
		
		samples[i] = (lp * 0.32 + whistle) * 0.85
	
	# Ensure seamless loop crossfade (first 0.3s crossfaded with last 0.3s)
	var fade_samples := int(0.35 * SAMPLE_RATE)
	for i in fade_samples:
		var weight := float(i) / float(fade_samples)
		var last_idx := count - fade_samples + i
		var blended := samples[last_idx] * (1.0 - weight) + samples[i] * weight
		samples[i] = blended
		samples[last_idx] = blended
	
	DSP.save_wav(path, samples, true)

func generate_flight_wind_rush(path: String) -> void:
	# Fast aerodynamic wind rush for high-speed dive and flight (4.0s seamless loop)
	var duration := 4.0
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 2244
	var lp := 0.0
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		# High speed turbulent air modulation (6-12 Hz fluttering)
		var flutter := 1.0 + 0.18 * sin(t / duration * TAU * 8.0) + 0.12 * sin(t / duration * TAU * 14.0)
		
		var raw_n := rng.randf_range(-1.0, 1.0)
		lp = lp * 0.78 + raw_n * 0.22
		
		var val := lp * flutter * 0.65
		samples[i] = DSP.soft_clip(val) * 0.82
	
	var fade_samples := int(0.3 * SAMPLE_RATE)
	for i in fade_samples:
		var weight := float(i) / float(fade_samples)
		var last_idx := count - fade_samples + i
		var blended := samples[last_idx] * (1.0 - weight) + samples[i] * weight
		samples[i] = blended
		samples[last_idx] = blended
	
	var out := DSP.biquad_filter(samples, "bp", 680.0, 0.9)
	DSP.save_wav(path, out, true)

func generate_ambient_water(path: String) -> void:
	# Flowing mountain stream / river water with bubbly textures (6.0s seamless loop)
	var duration := 6.0
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 4519
	
	# Continuous liquid bed: low filtered noise
	var lp := 0.0
	for i in count:
		var raw_n := rng.randf_range(-1.0, 1.0)
		lp = lp * 0.86 + raw_n * 0.14
		samples[i] = lp * 0.45
	
	# Overlay hundreds of bubbling resonances (liquid minnaert bubbles)
	var num_bubbles := 120
	for b in num_bubbles:
		var start_t := (float(b) / float(num_bubbles)) * duration + rng.randf_range(-0.02, 0.02)
		start_t = fmod(start_t + duration, duration)
		var bubble_dur := rng.randf_range(0.015, 0.038)
		var bubble_f := rng.randf_range(380.0, 1250.0)
		var b_amp := rng.randf_range(0.08, 0.24)
		
		var b_samples := int(bubble_dur * SAMPLE_RATE)
		var start_idx := int(start_t * SAMPLE_RATE)
		for s in b_samples:
			var idx := (start_idx + s) % count
			var bt := float(s) / float(SAMPLE_RATE)
			# Minnaert bubble frequency rises slightly as bubble forms
			var f_rise := bubble_f * (1.0 + bt * 2.0)
			var b_env := exp(-bt * 110.0) * sin(bt / bubble_dur * PI)
			var bubble_val := sin(bt * TAU * f_rise) * b_amp * b_env
			samples[idx] += bubble_val
	
	# Soft saturation to prevent any clipping
	for i in count:
		samples[i] = DSP.soft_clip(samples[i] * 1.3) * 0.8
	
	# Seamless loop crossfade
	var fade_samples := int(0.4 * SAMPLE_RATE)
	for i in fade_samples:
		var weight := float(i) / float(fade_samples)
		var last_idx := count - fade_samples + i
		var blended := samples[last_idx] * (1.0 - weight) + samples[i] * weight
		samples[i] = blended
		samples[last_idx] = blended
	
	DSP.save_wav(path, samples, true)

func generate_water_splash(path: String) -> void:
	# Heavy water impact: slap transient, sub-cavity surge, falling spray and sizzle
	var duration := 1.45
	var count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 8872
	var spray_lp := 0.0
	
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		
		# 1. Surface slap (t < 0.15)
		var slap := 0.0
		if t < 0.12:
			slap = sin(t * TAU * 110.0) * exp(-t * 32.0) * 0.75
		
		# 2. Deep hydrodynamic cavity collapse (sub-bass surge 55 Hz)
		var sub := sin(t * TAU * 52.0) * exp(-t * 7.5) * 0.6
		
		# 3. Spray turbulence and cascading froth sizzle
		var raw_n := rng.randf_range(-1.0, 1.0)
		spray_lp = spray_lp * 0.72 + raw_n * 0.28
		var spray_env := exp(-t * 3.8) * (1.0 - exp(-t * 25.0))
		var spray := spray_lp * spray_env * 0.6
		
		var total := (slap + sub + spray) * 1.5
		samples[i] = DSP.soft_clip(total) * 0.84
	
	DSP.save_wav(path, samples)
