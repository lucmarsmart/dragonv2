extends SceneTree

func _init():
	var audio_files = [
		{
			"id": "dragon_roar",
			"name": "Rugido de Dragón (Dragon Roar)",
			"category": "dragon",
			"catName": "Dragón",
			"status": "v2",
			"statusText": "🔥 V2 Mejorado",
			"statusClass": "bg-red-500/20 text-red-300 border-red-500/30",
			"icon": "🐲",
			"duration": "3.6s",
			"desc": "Ataque gutural amenazante, apertura de fauces con armónicos caóticos de período doble, retumbe torácico a 38-52 Hz y resonancia de garganta.",
			"file": "res://assets/audio/dragon/dragon_roar.wav"
		},
		{
			"id": "dragon_wing_flap",
			"name": "Aleteo de Alas (Wing Flap)",
			"category": "dragon",
			"catName": "Dragón",
			"status": "v2",
			"statusText": "🔥 V2 Mejorado",
			"statusClass": "bg-red-500/20 text-red-300 border-red-500/30",
			"icon": "🪽",
			"duration": "1.15s",
			"desc": "Empuje de aire infrasónico (46 Hz -> 22 Hz), flexión elástica de cuero alar a alta presión y estela de turbulencia residual.",
			"file": "res://assets/audio/dragon/dragon_wing_flap.wav"
		},
		{
			"id": "dragon_footstep",
			"name": "Pisada Masiva / Impacto (Dragon Stomp)",
			"category": "dragon",
			"catName": "Dragón",
			"status": "v2",
			"statusText": "🔥 V2 Mejorado",
			"statusClass": "bg-red-500/20 text-red-300 border-red-500/30",
			"icon": "🐾",
			"duration": "0.75s",
			"desc": "Golpe de coloso sísmico (54 Hz -> 20 Hz), micro-crujidos de roca granular partiéndose bajo las garras y retumbe del lecho rocoso.",
			"file": "res://assets/audio/dragon/dragon_footstep.wav"
		},
		{
			"id": "dragon_fire_breath",
			"name": "Aliento de Fuego (Fire Breath)",
			"category": "dragon",
			"catName": "Dragón",
			"status": "v2",
			"statusText": "🔥 V2 Mejorado",
			"statusClass": "bg-red-500/20 text-red-300 border-red-500/30",
			"icon": "🔥",
			"duration": "2.8s",
			"desc": "Ignición volcánica violenta (whoof de gas), rugido térmico de combustión a presión, silbido de soplete y chispas chisporroteantes.",
			"file": "res://assets/audio/dragon/dragon_fire_breath.wav"
		},
		{
			"id": "dragon_hurt",
			"name": "Quejido / Daño (Dragon Hurt)",
			"category": "dragon",
			"catName": "Dragón",
			"status": "v2",
			"statusText": "🔥 V2 Mejorado",
			"statusClass": "bg-red-500/20 text-red-300 border-red-500/30",
			"icon": "💥",
			"duration": "0.75s",
			"desc": "Reacción reptiliana visceral: espasmo pained que cae de 155 Hz a 42 Hz, sofocación en laringe y choque en caja torácica.",
			"file": "res://assets/audio/dragon/dragon_hurt.wav"
		},
		{
			"id": "knight_attack",
			"name": "Ataque con Espada (Sword Slash)",
			"category": "knights",
			"catName": "Caballeros",
			"status": "v2",
			"statusText": "🔥 V2 Mejorado",
			"statusClass": "bg-red-500/20 text-red-300 border-red-500/30",
			"icon": "⚔️",
			"duration": "0.45s",
			"desc": "Tajo rápido con aceleración Doppler (1800 Hz -> 360 Hz) y vibración resonante de acero forjado cantando a 2380 Hz y 4760 Hz.",
			"file": "res://assets/audio/knights/knight_attack.wav"
		},
		{
			"id": "knight_footstep",
			"name": "Paso con Armadura (Armor Clank)",
			"category": "knights",
			"catName": "Caballeros",
			"status": "v2",
			"statusText": "🔥 V2 Mejorado",
			"statusClass": "bg-red-500/20 text-red-300 border-red-500/30",
			"icon": "🛡️",
			"duration": "0.42s",
			"desc": "Tacón sobre adoquín, tintineo de placas de grebas desfasadas 8ms y fricción metálica de cota de malla a ~4 kHz.",
			"file": "res://assets/audio/knights/knight_footstep.wav"
		},
		{
			"id": "knight_death",
			"name": "Derrota de Caballero (Armor Collapse)",
			"category": "knights",
			"catName": "Caballeros",
			"status": "v2",
			"statusText": "🔥 V2 Mejorado",
			"statusClass": "bg-red-500/20 text-red-300 border-red-500/30",
			"icon": "☠️",
			"duration": "1.45s",
			"desc": "Caída en rodillas (0.05s), estruendo del peto estrellándose (0.18s), rebotes de escudo y espada (0.38s/0.62s) y malla disipándose.",
			"file": "res://assets/audio/knights/knight_death.wav"
		},
		{
			"id": "ballista_fire",
			"name": "Disparo de Balista (Ballista Fire)",
			"category": "knights",
			"catName": "Caballeros",
			"status": "v2",
			"statusText": "🔥 V2 Mejorado",
			"statusClass": "bg-red-500/20 text-red-300 border-red-500/30",
			"icon": "🏹",
			"duration": "0.85s",
			"desc": "Golpe seco del brazo de roble contra el marco, chasquido violento de cuerda de torsión (360 Hz -> 195 Hz) y silbido de saeta.",
			"file": "res://assets/audio/knights/ballista_fire.wav"
		},
		{
			"id": "ballista_impact",
			"name": "Impacto de Saeta (Ballista Impact)",
			"category": "knights",
			"catName": "Caballeros",
			"status": "v2",
			"statusText": "🔥 V2 Mejorado",
			"statusClass": "bg-red-500/20 text-red-300 border-red-500/30",
			"icon": "🎯",
			"duration": "0.85s",
			"desc": "Penetración de punta de hierro, onda de choque destructiva (68 Hz -> 26 Hz) y astillamiento masivo de madera y mampostería.",
			"file": "res://assets/audio/knights/ballista_impact.wav"
		},
		{
			"id": "ambient_wind",
			"name": "Viento de Montaña (Ambient Wind)",
			"category": "ambient",
			"catName": "Ambiente",
			"status": "approved",
			"statusText": "⭐ Aprobado",
			"statusClass": "bg-emerald-500/20 text-emerald-300 border-emerald-500/30",
			"icon": "💨",
			"duration": "6.0s (Loop)",
			"desc": "Atmósfera continua de viento de montaña en altitud, ráfagas suaves y silbido sutil en cumbres rocosas (aprobado por el usuario).",
			"file": "res://assets/audio/ambient/ambient_wind.wav"
		},
		{
			"id": "flight_wind_rush",
			"name": "Ráfaga de Vuelo y Picada (Wind Rush)",
			"category": "ambient",
			"catName": "Ambiente",
			"status": "approved",
			"statusText": "⭐ Aprobado",
			"statusClass": "bg-emerald-500/20 text-emerald-300 border-emerald-500/30",
			"icon": "🌪️",
			"duration": "4.0s (Loop)",
			"desc": "Turbulencia aerodinámica intensa al volar a gran velocidad o descender en picada rasante (aprobado por el usuario).",
			"file": "res://assets/audio/ambient/flight_wind_rush.wav"
		},
		{
			"id": "ambient_water",
			"name": "Arroyo / Río Fluyendo (Ambient Water)",
			"category": "ambient",
			"catName": "Ambiente",
			"status": "approved",
			"statusText": "⭐ Aprobado",
			"statusClass": "bg-emerald-500/20 text-emerald-300 border-emerald-500/30",
			"icon": "🌊",
			"duration": "6.0s (Loop)",
			"desc": "Corriente fluvial relajante con textura de burbujas líquidas, goteo suave y murmullo continuo (aprobado por el usuario).",
			"file": "res://assets/audio/ambient/ambient_water.wav"
		},
		{
			"id": "water_splash",
			"name": "Salpicadura de Agua (Water Splash)",
			"category": "ambient",
			"catName": "Ambiente",
			"status": "v2",
			"statusText": "🔥 V2 Mejorado",
			"statusClass": "bg-red-500/20 text-red-300 border-red-500/30",
			"icon": "💦",
			"duration": "1.75s",
			"desc": "Palmada de tensión superficial (130 Hz), colapso cavernoso de cavidad subacuática ('K-BLOOMP' a 48 Hz), penacho de espuma y lluvia de gotas pesadas.",
			"file": "res://assets/audio/ambient/water_splash.wav"
		}
	]

	var cards_html := ""
	for item in audio_files:
		var file_path: String = item["file"]
		var bytes := FileAccess.get_file_as_bytes(file_path)
		var b64 := Marshalls.raw_to_base64(bytes)
		var audio_uri := "data:audio/wav;base64," + b64
		
		var category: String = item["category"]
		var cat_badge := ""
		if category == "dragon":
			cat_badge = "bg-amber-500/20 text-amber-300 border-amber-500/30"
		elif category == "knights":
			cat_badge = "bg-blue-500/20 text-blue-300 border-blue-500/30"
		else:
			cat_badge = "bg-teal-500/20 text-teal-300 border-teal-500/30"
		
		var status_badge: String = item["statusText"]
		var status_class: String = item["statusClass"]
		
		cards_html += """
    <div class="audio-card p-4 rounded-xl border border-[var(--border)] bg-[var(--card)] hover:border-indigo-500/50 transition-all shadow-sm flex flex-col justify-between" data-category="%s" data-status="%s">
      <div>
        <div class="flex items-center justify-between mb-2">
          <div class="flex items-center gap-2">
            <span class="text-2xl">%s</span>
            <span class="text-xs px-2 py-0.5 rounded-full border font-medium %s">%s</span>
            <span class="text-xs px-2 py-0.5 rounded-full border font-bold %s">%s</span>
          </div>
          <span class="text-xs text-[var(--muted-foreground)] font-mono">%s</span>
        </div>
        <h3 class="font-semibold text-base text-[var(--foreground)] mb-1">%s</h3>
        <p class="text-xs text-[var(--muted-foreground)] leading-relaxed mb-4">%s</p>
      </div>
      <div class="pt-2 border-t border-[var(--border)]">
        <audio controls class="w-full h-9 rounded" preload="metadata">
          <source src="%s" type="audio/wav">
          Tu navegador no soporta el reproductor de audio.
        </audio>
      </div>
    </div>
""" % [category, item["status"], item["icon"], cat_badge, item["catName"], status_class, status_badge, item["duration"], item["name"], item["desc"], audio_uri]

	var full_html := """<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <title>Estudio de Sonidos V2 · Dragon Simulator</title>
  <script src="https://www.gstatic.com/antigravity/web/dev/tailwindcss.min.js"></script>
  <style>
    audio::-webkit-media-controls-panel {
      background-color: var(--secondary, #1e293b);
    }
  </style>
</head>
<body class="bg-transparent text-[var(--foreground)] antialiased p-3 sm:p-5">
  <div class="max-w-6xl mx-auto space-y-5">
    
    <!-- Encabezado Principal -->
    <div class="bg-[var(--card)] border border-[var(--border)] rounded-2xl p-5 shadow-lg">
      <div class="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div class="flex items-center gap-3">
            <span class="text-3xl">🐲⚡🔊</span>
            <h1 class="text-xl sm:text-2xl font-bold tracking-tight text-[var(--foreground)]">Estudio de Sonidos V2 · Edición Mejorada</h1>
          </div>
          <p class="text-sm text-[var(--muted-foreground)] mt-1">
            Se mantuvieron intactos los <strong>3 aprobados</strong> (Viento de Montaña, Ráfaga de Vuelo y Arroyo) y se <strong>exprimieron al máximo los 11 sonidos restantes</strong> con síntesis física no-lineal y armónicos orgánicos.
          </p>
        </div>
        
        <!-- Filtros Rápidos -->
        <div class="flex items-center gap-2 flex-wrap" id="filter-buttons">
          <button onclick="filterSounds('all', event)" class="filter-btn px-3 py-1.5 rounded-lg text-xs font-semibold bg-indigo-600 text-white transition-all shadow-sm">Todos (14)</button>
          <button onclick="filterSounds('dragon', event)" class="filter-btn px-3 py-1.5 rounded-lg text-xs font-semibold bg-[var(--secondary)] text-[var(--foreground)] hover:bg-[var(--border)] transition-all">Dragón V2 (5)</button>
          <button onclick="filterSounds('knights', event)" class="filter-btn px-3 py-1.5 rounded-lg text-xs font-semibold bg-[var(--secondary)] text-[var(--foreground)] hover:bg-[var(--border)] transition-all">Caballeros V2 (5)</button>
          <button onclick="filterSounds('ambient', event)" class="filter-btn px-3 py-1.5 rounded-lg text-xs font-semibold bg-[var(--secondary)] text-[var(--foreground)] hover:bg-[var(--border)] transition-all">Ambiente (4)</button>
          <button onclick="filterByStatus('v2', event)" class="filter-btn px-3 py-1.5 rounded-lg text-xs font-semibold bg-red-600/30 text-red-200 border border-red-500/40 hover:bg-red-600/50 transition-all">Solo Nuevos V2 (11)</button>
        </div>
      </div>
      
      <!-- Aviso de confirmación -->
      <div class="mt-4 p-3 rounded-lg bg-indigo-500/10 border border-indigo-500/20 text-xs text-[var(--muted-foreground)] flex items-center justify-between gap-3">
        <span>🎧 <strong>Instrucciones:</strong> Dale Play a cada sonido para evaluar los nuevos matices de cuerpo, sub-graves, crujido orgánico y transitorios de impacto.</span>
      </div>
    </div>

    <!-- Cuadrícula de Sonidos -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4" id="audio-grid">
%s
    </div>
    
  </div>

  <script>
    function resetBtnStyles() {
      document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.classList.remove('bg-indigo-600', 'text-white');
        if (!btn.classList.contains('bg-red-600/30')) {
          btn.classList.add('bg-[var(--secondary)]', 'text-[var(--foreground)]');
        }
      });
    }

    function filterSounds(category, ev) {
      const cards = document.querySelectorAll('.audio-card');
      cards.forEach(card => {
        if (category === 'all' || card.getAttribute('data-category') === category) {
          card.style.display = 'flex';
        } else {
          card.style.display = 'none';
        }
      });
      resetBtnStyles();
      if (ev && ev.target) {
        ev.target.classList.remove('bg-[var(--secondary)]', 'text-[var(--foreground)]');
        ev.target.classList.add('bg-indigo-600', 'text-white');
      }
    }

    function filterByStatus(status, ev) {
      const cards = document.querySelectorAll('.audio-card');
      cards.forEach(card => {
        if (card.getAttribute('data-status') === status) {
          card.style.display = 'flex';
        } else {
          card.style.display = 'none';
        }
      });
      resetBtnStyles();
      if (ev && ev.target) {
        ev.target.classList.add('bg-indigo-600', 'text-white');
      }
    }
  </script>
</body>
</html>
""" % cards_html

	var out_path := "C:/Users/lucma/.gemini/antigravity/brain/369e7588-475e-422b-bf79-d61fc3218a19/audio_preview.html"
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(full_html)
		f.close()
		print("GENERADO HTML V2 EN: ", out_path)
	else:
		print("ERROR ABRIENDO ARCHIVO: ", out_path)
	quit()
