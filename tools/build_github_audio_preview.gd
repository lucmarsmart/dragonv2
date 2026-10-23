extends SceneTree

func _init():
	var sources = [
		# --- RUGIDOS DE DRAGÓN ---
		{
			"id": "roar_draconis_1",
			"name": "Rugido Feroz de Dragón (Opción A)",
			"category": "dragon_roar",
			"catName": "Rugido Dragón",
			"repo": "ElCeejo/draconis",
			"source": "Minetest Draconis Mod",
			"icon": "🐲",
			"file": "res://assets/audio/github_sources/draconis_roar_1.ogg",
			"mime": "audio/ogg",
			"desc": "Rugido auténtico de dragón de fuego con garganta resonante y bramido salvaje."
		},
		{
			"id": "roar_draconis_2",
			"name": "Berrido Profundo de Dragón (Opción B)",
			"category": "dragon_roar",
			"catName": "Rugido Dragón",
			"repo": "ElCeejo/draconis",
			"source": "Minetest Draconis Mod",
			"icon": "🐲",
			"file": "res://assets/audio/github_sources/draconis_roar_2.ogg",
			"mime": "audio/ogg",
			"desc": "Tono más grave y amenazante, gruñido gutural pesado de dragón anciano."
		},
		{
			"id": "roar_veloren_wyvern",
			"name": "Rugido de Wyvern / Dragón Alado (Opción C)",
			"category": "dragon_roar",
			"catName": "Rugido Dragón",
			"repo": "veloren/veloren",
			"source": "Veloren RPG Engine",
			"icon": "🐉",
			"file": "res://assets/audio/github_sources/veloren_wyvern_roar.ogg",
			"mime": "audio/ogg",
			"desc": "Grito de dragón depredador aéreo con silbido y desgarro agudo de amenaza."
		},
		{
			"id": "roar_wesnoth_drake",
			"name": "Rugido de Dragón / Drake (Opción D)",
			"category": "dragon_roar",
			"catName": "Rugido Dragón",
			"repo": "wesnoth/wesnoth",
			"source": "Battle for Wesnoth",
			"icon": "🦁",
			"file": "res://assets/audio/github_sources/wesnoth_drake_roar.ogg",
			"mime": "audio/ogg",
			"desc": "Rugido orgánico clásico (león de estudio ralentizado y procesado para dragón)."
		},

		# --- ACCIONES DEL DRAGÓN ---
		{
			"id": "dragon_flap",
			"name": "Aleteo de Alas de Dragón",
			"category": "dragon_actions",
			"catName": "Dragón Acciones",
			"repo": "ElCeejo/draconis",
			"source": "Minetest Draconis Mod",
			"icon": "🪽",
			"file": "res://assets/audio/github_sources/draconis_wing_flap.ogg",
			"mime": "audio/ogg",
			"desc": "Sonido real de golpe de membrana alar gigante desplazando masa de aire."
		},
		{
			"id": "dragon_slam",
			"name": "Pisada / Golpe en Tierra (Slam)",
			"category": "dragon_actions",
			"catName": "Dragón Acciones",
			"repo": "ElCeejo/draconis",
			"source": "Minetest Draconis Mod",
			"icon": "🐾",
			"file": "res://assets/audio/github_sources/draconis_dragon_slam.ogg",
			"mime": "audio/ogg",
			"desc": "Impacto seco y pesado contra el suelo para aterrizajes y pisadas colosales."
		},
		{
			"id": "dragon_fire_draconis",
			"name": "Llamarada de Dragón (Draconis)",
			"category": "dragon_actions",
			"catName": "Dragón Acciones",
			"repo": "ElCeejo/draconis",
			"source": "Minetest Draconis Mod",
			"icon": "🔥",
			"file": "res://assets/audio/github_sources/draconis_fire_breath.ogg",
			"mime": "audio/ogg",
			"desc": "Chorro continuo de fuego y llamas abrasadoras."
		},
		{
			"id": "dragon_fire_veloren",
			"name": "Llamarada de Combustión (Veloren)",
			"category": "dragon_actions",
			"catName": "Dragón Acciones",
			"repo": "veloren/veloren",
			"source": "Veloren RPG Engine",
			"icon": "🔥",
			"file": "res://assets/audio/github_sources/veloren_fire_breath.ogg",
			"mime": "audio/ogg",
			"desc": "Ráfaga de fuego densa con rugido de ignición a alta presión."
		},
		{
			"id": "dragon_hurt_wyvern",
			"name": "Quejido / Daño de Dragón (Wyvern)",
			"category": "dragon_actions",
			"catName": "Dragón Acciones",
			"repo": "veloren/veloren",
			"source": "Veloren RPG Engine",
			"icon": "🩸",
			"file": "res://assets/audio/github_sources/veloren_wyvern_hurt.ogg",
			"mime": "audio/ogg",
			"desc": "Chirrido de dolor visceral de reptil gigante al recibir daño."
		},
		{
			"id": "dragon_hurt_drake",
			"name": "Quejido / Daño de Drake (Wesnoth)",
			"category": "dragon_actions",
			"catName": "Dragón Acciones",
			"repo": "wesnoth/wesnoth",
			"source": "Battle for Wesnoth",
			"icon": "🩸",
			"file": "res://assets/audio/github_sources/wesnoth_drake_hit.ogg",
			"mime": "audio/ogg",
			"desc": "Gruñido seco y contenido de impacto en dragón."
		},

		# --- CABALLEROS Y COMBATE ---
		{
			"id": "sword_swing_veloren",
			"name": "Ataque de Espada Rápido (Veloren)",
			"category": "knights",
			"catName": "Caballeros",
			"repo": "veloren/veloren",
			"source": "Veloren RPG Engine",
			"icon": "⚔️",
			"file": "res://assets/audio/github_sources/veloren_sword_swing.ogg",
			"mime": "audio/ogg",
			"desc": "Silbido de hoja de espada rápida cortando el aire con nitidez."
		},
		{
			"id": "sword_attack_flare",
			"name": "Tajo de Espada de Combate (Flare)",
			"category": "knights",
			"catName": "Caballeros",
			"repo": "flareteam/flare-game",
			"source": "Flare Action RPG",
			"icon": "⚔️",
			"file": "res://assets/audio/github_sources/flare_sword_attack.ogg",
			"mime": "audio/ogg",
			"desc": "Golpe y hendidura de espada cuerpo a cuerpo medieval."
		},
		{
			"id": "knight_step_flare",
			"name": "Paso con Armadura de Placas (Flare)",
			"category": "knights",
			"catName": "Caballeros",
			"repo": "flareteam/flare-game",
			"source": "Flare Action RPG",
			"icon": "🛡️",
			"file": "res://assets/audio/github_sources/flare_step_metal.ogg",
			"mime": "audio/ogg",
			"desc": "Paso real de bota y greba de acero metálico sobre suelo firme."
		},
		{
			"id": "knight_death_flare",
			"name": "Derrota de Caballero (Flare)",
			"category": "knights",
			"catName": "Caballeros",
			"repo": "flareteam/flare-game",
			"source": "Flare Action RPG",
			"icon": "☠️",
			"file": "res://assets/audio/github_sources/flare_knight_death.ogg",
			"mime": "audio/ogg",
			"desc": "Lamento humano de agonía y desplome de guerrero con armadura."
		},
		{
			"id": "ballista_fire_veloren",
			"name": "Disparo de Balista / Flecha Pesada",
			"category": "knights",
			"catName": "Caballeros",
			"repo": "veloren/veloren",
			"source": "Veloren RPG Engine",
			"icon": "🏹",
			"file": "res://assets/audio/github_sources/veloren_arrow_shot.ogg",
			"mime": "audio/ogg",
			"desc": "Zumbido agudo de lanzamiento de proyectil de alta tensión."
		},
		{
			"id": "ballista_fire_wesnoth",
			"name": "Mecanismo de Ballesta Pesada",
			"category": "knights",
			"catName": "Caballeros",
			"repo": "wesnoth/wesnoth",
			"source": "Battle for Wesnoth",
			"icon": "🏹",
			"file": "res://assets/audio/github_sources/wesnoth_crossbow.ogg",
			"mime": "audio/ogg",
			"desc": "Disparo mecánico de gatillo y cuerda de asedio."
		},
		{
			"id": "ballista_impact_veloren",
			"name": "Impacto Contundente (Klonk)",
			"category": "knights",
			"catName": "Caballeros",
			"repo": "veloren/veloren",
			"source": "Veloren RPG Engine",
			"icon": "🎯",
			"file": "res://assets/audio/github_sources/veloren_impact_klonk.ogg",
			"mime": "audio/ogg",
			"desc": "Golpe metálico/sólido seco contra armadura o fortificación."
		},

		# --- AGUA Y SALPICADURAS ---
		{
			"id": "water_splash_veloren",
			"name": "Gran Salpicadura de Agua (Veloren)",
			"category": "water",
			"catName": "Agua / Splash",
			"repo": "veloren/veloren",
			"source": "Veloren RPG Engine",
			"icon": "🌊",
			"file": "res://assets/audio/github_sources/veloren_splash_big.ogg",
			"mime": "audio/ogg",
			"desc": "Impacto masivo de agua con espuma y chapoteo líquido."
		},
		{
			"id": "water_blast_wesnoth",
			"name": "Explosión / Estallido de Agua (Wesnoth)",
			"category": "water",
			"catName": "Agua / Splash",
			"repo": "wesnoth/wesnoth",
			"source": "Battle for Wesnoth",
			"icon": "💦",
			"file": "res://assets/audio/github_sources/wesnoth_water_blast.wav",
			"mime": "audio/wav",
			"desc": "Ruptura violenta de superficie acuática con oleaje."
		},

		# --- LOS 3 APROBADOS ---
		{
			"id": "ambient_wind",
			"name": "Viento de Montaña (Aprobado)",
			"category": "approved",
			"catName": "⭐ Aprobados",
			"repo": "Sintetizado Proyecto",
			"source": "Dragon Simulator",
			"icon": "💨",
			"file": "res://assets/audio/ambient/ambient_wind.wav",
			"mime": "audio/wav",
			"desc": "Sonido ambiental aprobado por ti en la ronda anterior."
		},
		{
			"id": "flight_wind_rush",
			"name": "Ráfaga de Vuelo y Picada (Aprobado)",
			"category": "approved",
			"catName": "⭐ Aprobados",
			"repo": "Sintetizado Proyecto",
			"source": "Dragon Simulator",
			"icon": "🌪️",
			"file": "res://assets/audio/ambient/flight_wind_rush.wav",
			"mime": "audio/wav",
			"desc": "Sonido de velocidad aprobado por ti en la ronda anterior."
		},
		{
			"id": "ambient_water",
			"name": "Arroyo Fluyendo (Aprobado)",
			"category": "approved",
			"catName": "⭐ Aprobados",
			"repo": "Sintetizado Proyecto",
			"source": "Dragon Simulator",
			"icon": "💧",
			"file": "res://assets/audio/ambient/ambient_water.wav",
			"mime": "audio/wav",
			"desc": "Sonido de río/arroyo aprobado por ti en la ronda anterior."
		}
	]

	var cards_html := ""
	for item in sources:
		var file_path: String = item["file"]
		var bytes := FileAccess.get_file_as_bytes(file_path)
		var b64 := Marshalls.raw_to_base64(bytes)
		var mime: String = item["mime"]
		var audio_uri := "data:" + mime + ";base64," + b64
		
		var category: String = item["category"]
		var cat_badge := "bg-indigo-500/20 text-indigo-300 border-indigo-500/30"
		if category == "dragon_roar":
			cat_badge = "bg-amber-500/20 text-amber-300 border-amber-500/30"
		elif category == "dragon_actions":
			cat_badge = "bg-orange-500/20 text-orange-300 border-orange-500/30"
		elif category == "knights":
			cat_badge = "bg-blue-500/20 text-blue-300 border-blue-500/30"
		elif category == "water":
			cat_badge = "bg-cyan-500/20 text-cyan-300 border-cyan-500/30"
		elif category == "approved":
			cat_badge = "bg-emerald-500/20 text-emerald-300 border-emerald-500/30 font-bold"
		
		cards_html += """
    <div class="audio-card p-4 rounded-xl border border-[var(--border)] bg-[var(--card)] hover:border-indigo-500/60 transition-all shadow-sm flex flex-col justify-between" data-category="%s">
      <div>
        <div class="flex items-center justify-between mb-2">
          <div class="flex items-center gap-2">
            <span class="text-2xl">%s</span>
            <span class="text-xs px-2 py-0.5 rounded-full border font-medium %s">%s</span>
          </div>
          <span class="text-xs text-[var(--muted-foreground)] font-mono bg-[var(--secondary)] px-2 py-0.5 rounded">%s</span>
        </div>
        <h3 class="font-semibold text-base text-[var(--foreground)] mb-0.5">%s</h3>
        <p class="text-xs text-indigo-400 font-medium mb-1.5 flex items-center gap-1">
          <span>📦 Repositorio:</span> <code>%s</code>
        </p>
        <p class="text-xs text-[var(--muted-foreground)] leading-relaxed mb-4">%s</p>
      </div>
      <div class="pt-2 border-t border-[var(--border)]">
        <audio controls class="w-full h-9 rounded" preload="metadata">
          <source src="%s" type="%s">
          Tu navegador no soporta el reproductor de audio.
        </audio>
      </div>
    </div>
""" % [category, item["icon"], cat_badge, item["catName"], item["source"], item["name"], item["repo"], item["desc"], audio_uri, mime]

	var full_html := """<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <title>Sonidos Descargados de GitHub · Dragon Simulator</title>
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
            <span class="text-3xl">🐙🔊</span>
            <h1 class="text-xl sm:text-2xl font-bold tracking-tight text-[var(--foreground)]">Sonidos Descargados desde GitHub</h1>
          </div>
          <p class="text-sm text-[var(--muted-foreground)] mt-1">
            Audios reales extraídos de repositorios de juegos de código abierto (<strong>Veloren</strong>, <strong>Battle for Wesnoth</strong>, <strong>Flare RPG</strong> y <strong>Draconis</strong>).
          </p>
        </div>
        
        <!-- Filtros Rápidos -->
        <div class="flex items-center gap-2 flex-wrap" id="filter-buttons">
          <button onclick="filterSounds('all', event)" class="filter-btn px-3 py-1.5 rounded-lg text-xs font-semibold bg-indigo-600 text-white transition-all shadow-sm">Todos (23)</button>
          <button onclick="filterSounds('dragon_roar', event)" class="filter-btn px-3 py-1.5 rounded-lg text-xs font-semibold bg-[var(--secondary)] text-[var(--foreground)] hover:bg-[var(--border)] transition-all">🐲 Rugidos Dragón (5)</button>
          <button onclick="filterSounds('dragon_actions', event)" class="filter-btn px-3 py-1.5 rounded-lg text-xs font-semibold bg-[var(--secondary)] text-[var(--foreground)] hover:bg-[var(--border)] transition-all">🪽 Dragón Acciones (6)</button>
          <button onclick="filterSounds('knights', event)" class="filter-btn px-3 py-1.5 rounded-lg text-xs font-semibold bg-[var(--secondary)] text-[var(--foreground)] hover:bg-[var(--border)] transition-all">⚔️ Caballeros (7)</button>
          <button onclick="filterSounds('water', event)" class="filter-btn px-3 py-1.5 rounded-lg text-xs font-semibold bg-[var(--secondary)] text-[var(--foreground)] hover:bg-[var(--border)] transition-all">🌊 Salpicaduras (2)</button>
          <button onclick="filterSounds('approved', event)" class="filter-btn px-3 py-1.5 rounded-lg text-xs font-semibold bg-emerald-600/30 text-emerald-200 border border-emerald-500/40 hover:bg-emerald-600/50 transition-all">⭐ Tus 3 Aprobados</button>
        </div>
      </div>
      
      <!-- Aviso -->
      <div class="mt-4 p-3 rounded-lg bg-indigo-500/10 border border-indigo-500/20 text-xs text-[var(--muted-foreground)] flex items-center justify-between gap-3">
        <span>🎧 <strong>Instrucciones:</strong> Dale Play a las distintas opciones (especialmente a los 5 rugidos diferentes en la pestaña <em>🐲 Rugidos Dragón</em>) para elegir cuál te gusta más para cada acción.</span>
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
        if (!btn.classList.contains('bg-emerald-600/30')) {
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
  </script>
</body>
</html>
""" % cards_html

	var out_path := "C:/Users/lucma/.gemini/antigravity/brain/369e7588-475e-422b-bf79-d61fc3218a19/audio_preview.html"
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(full_html)
		f.close()
		print("GENERADO HTML DE REPOS GITHUB EN: ", out_path)
	else:
		print("ERROR ABRIENDO ARCHIVO: ", out_path)
	quit()
