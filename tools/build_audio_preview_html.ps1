$audioFiles = @(
    @{
        id = "dragon_roar";
        name = "Rugido de Dragón (Dragon Roar)";
        category = "dragon";
        catName = "Dragón";
        color = "amber";
        icon = "🐲";
        duration = "3.2s";
        desc = "Rugido profundo y gutural con ataque amenazante, ascenso armónico feroz, resonancia sub-grave de pecho y raspado vocal.";
        file = "assets\audio\dragon\dragon_roar.wav"
    },
    @{
        id = "dragon_wing_flap";
        name = "Aleteo de Alas (Wing Flap)";
        category = "dragon";
        catName = "Dragón";
        color = "amber";
        icon = "🪽";
        duration = "1.0s";
        desc = "Golpe potente de aire a baja frecuencia con crujido elástico de membrana coriácea al abrir y batir las alas.";
        file = "assets\audio\dragon\dragon_wing_flap.wav"
    },
    @{
        id = "dragon_footstep";
        name = "Pisada Masiva / Impacto (Dragon Stomp)";
        category = "dragon";
        catName = "Dragón";
        color = "amber";
        icon = "🐾";
        duration = "0.6s";
        desc = "Impacto pesado en tierra con caída sub-grave (55Hz -> 26Hz), crujido de roca y tierra bajo el peso colosal.";
        file = "assets\audio\dragon\dragon_footstep.wav"
    },
    @{
        id = "dragon_fire_breath";
        name = "Aliento de Fuego (Fire Breath)";
        category = "dragon";
        catName = "Dragón";
        color = "amber";
        icon = "🔥";
        duration = "2.6s";
        desc = "Llamarada continua de combustión a alta presión, rugido térmico, turbulencia de fuego y chispas chisporroteantes.";
        file = "assets\audio\dragon\dragon_fire_breath.wav"
    },
    @{
        id = "dragon_hurt";
        name = "Quejido / Daño (Dragon Hurt)";
        category = "dragon";
        catName = "Dragón";
        color = "amber";
        icon = "💥";
        duration = "0.65s";
        desc = "Gruñido gutural seco de quejido y esfuerzo al recibir daño por proyectiles o colisión.";
        file = "assets\audio\dragon\dragon_hurt.wav"
    },
    @{
        id = "knight_attack";
        name = "Ataque con Espada (Sword Slash)";
        category = "knights";
        catName = "Caballeros";
        color = "blue";
        icon = "⚔️";
        duration = "0.42s";
        desc = "Silbido aerodinámico rápido de espada cortando el aire con repiqueteo metálico agudo de acero.";
        file = "assets\audio\knights\knight_attack.wav"
    },
    @{
        id = "knight_footstep";
        name = "Paso con Armadura (Armor Clank)";
        category = "knights";
        catName = "Caballeros";
        color = "blue";
        icon = "🛡️";
        duration = "0.38s";
        desc = "Paso de bota con tintineo de placas metálicas y hebillas de hierro superpuestas.";
        file = "assets\audio\knights\knight_footstep.wav"
    },
    @{
        id = "knight_death";
        name = "Derrota de Caballero (Armor Collapse)";
        category = "knights";
        catName = "Caballeros";
        color = "blue";
        icon = "☠️";
        duration = "1.25s";
        desc = "Caída pesada de caballero: impacto de cuerpo contra el suelo y estruendo de piezas de armadura y cota de malla rodando.";
        file = "assets\audio\knights\knight_death.wav"
    },
    @{
        id = "ballista_fire";
        name = "Disparo de Balista (Ballista Fire)";
        category = "knights";
        catName = "Caballeros";
        color = "blue";
        icon = "🏹";
        duration = "0.75s";
        desc = "Liberación del gatillo de madera maciza, vibración metálica de cuerda tensada y silbido de salida de saeta.";
        file = "assets\audio\knights\ballista_fire.wav"
    },
    @{
        id = "ballista_impact";
        name = "Impacto de Saeta (Ballista Impact)";
        category = "knights";
        catName = "Caballeros";
        color = "blue";
        icon = "🎯";
        duration = "0.75s";
        desc = "Impacto cinético destructivo con golpe sordo sub-grave y astillamiento de madera o piedra.";
        file = "assets\audio\knights\ballista_impact.wav"
    },
    @{
        id = "ambient_wind";
        name = "Viento de Montaña (Ambient Wind)";
        category = "ambient";
        catName = "Ambiente";
        color = "emerald";
        icon = "💨";
        duration = "6.0s (Loop)";
        desc = "Atmósfera continua de viento de montaña en altitud, barridos de ráfagas suaves y silbido sutil de cumbres.";
        file = "assets\audio\ambient\ambient_wind.wav"
    },
    @{
        id = "flight_wind_rush";
        name = "Ráfaga de Vuelo y Picada (Wind Rush)";
        category = "ambient";
        catName = "Ambiente";
        color = "emerald";
        icon = "🌪️";
        duration = "4.0s (Loop)";
        desc = "Turbulencia aerodinámica intensa al volar a gran velocidad o descender en picada rasante.";
        file = "assets\audio\ambient\flight_wind_rush.wav"
    },
    @{
        id = "ambient_water";
        name = "Arroyo / Río Fluyendo (Ambient Water)";
        category = "ambient";
        catName = "Ambiente";
        color = "emerald";
        icon = "🌊";
        duration = "6.0s (Loop)";
        desc = "Corriente fluvial relajante con textura de burbujas líquidas, goteo suave y murmullo continuo.";
        file = "assets\audio\ambient\ambient_water.wav"
    },
    @{
        id = "water_splash";
        name = "Salpicadura de Agua (Water Splash)";
        category = "ambient";
        catName = "Ambiente";
        color = "emerald";
        icon = "💦";
        duration = "1.45s";
        desc = "Golpe hidrodinámico en la superficie del lago, colapso de cavidad acuática y lluvia de espuma pulverizada.";
        file = "assets\audio\ambient\water_splash.wav"
    }
)

$targetDir = "C:\Users\lucma\.gemini\antigravity\brain\369e7588-475e-422b-bf79-d61fc3218a19"
if (!(Test-Path $targetDir)) { New-Item -ItemType Directory -Force -Path $targetDir }

Write-Host "Procesando audios y convirtiendo a Base64..."
$itemsHtml = ""
foreach ($item in $audioFiles) {
    $bytes = [System.IO.File]::ReadAllBytes($item.file)
    $b64 = [System.Convert]::ToBase64String($bytes)
    $audioUri = "data:audio/wav;base64," + $b64
    
    $badgeClass = switch ($item.category) {
        "dragon" { "bg-amber-500/20 text-amber-300 border-amber-500/30" }
        "knights" { "bg-blue-500/20 text-blue-300 border-blue-500/30" }
        default { "bg-emerald-500/20 text-emerald-300 border-emerald-500/30" }
    }
    
    $itemsHtml += @"
    <div class="audio-card p-4 rounded-xl border border-[var(--border)] bg-[var(--card)] hover:border-slate-500/50 transition-all shadow-sm flex flex-col justify-between" data-category="$($item.category)">
      <div>
        <div class="flex items-center justify-between mb-2">
          <div class="flex items-center gap-2">
            <span class="text-2xl">$($item.icon)</span>
            <span class="text-xs px-2 py-0.5 rounded-full border font-medium $badgeClass">$($item.catName)</span>
          </div>
          <span class="text-xs text-[var(--muted-foreground)] font-mono">$($item.duration)</span>
        </div>
        <h3 class="font-semibold text-base text-[var(--foreground)] mb-1">$($item.name)</h3>
        <p class="text-xs text-[var(--muted-foreground)] leading-relaxed mb-4">$($item.desc)</p>
      </div>
      <div class="pt-2 border-t border-[var(--border)]">
        <audio controls class="w-full h-9 rounded" preload="metadata">
          <source src="$audioUri" type="audio/wav">
          Tu navegador no soporta el reproductor de audio.
        </audio>
      </div>
    </div>
"@
}

$fullHtml = @"
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <title>Estudio de Sonidos - Dragón, Caballeros y Ambiente</title>
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
            <span class="text-3xl">🐲🔊</span>
            <h1 class="text-xl sm:text-2xl font-bold tracking-tight text-[var(--foreground)]">Estudio de Sonidos de Dragon Simulator</h1>
          </div>
          <p class="text-sm text-[var(--muted-foreground)] mt-1">
            Audición previa de efectos sintetizados para el dragón, combate con caballeros y atmósfera ambiental.
          </p>
        </div>
        
        <!-- Filtros Rápidos -->
        <div class="flex items-center gap-2 flex-wrap" id="filter-buttons">
          <button onclick="filterSounds('all')" class="filter-btn active px-3 py-1.5 rounded-lg text-xs font-semibold bg-indigo-600 text-white transition-all shadow-sm">Todos (14)</button>
          <button onclick="filterSounds('dragon')" class="filter-btn px-3 py-1.5 rounded-lg text-xs font-semibold bg-[var(--secondary)] text-[var(--foreground)] hover:bg-[var(--border)] transition-all">Dragón (5)</button>
          <button onclick="filterSounds('knights')" class="filter-btn px-3 py-1.5 rounded-lg text-xs font-semibold bg-[var(--secondary)] text-[var(--foreground)] hover:bg-[var(--border)] transition-all">Caballeros (5)</button>
          <button onclick="filterSounds('ambient')" class="filter-btn px-3 py-1.5 rounded-lg text-xs font-semibold bg-[var(--secondary)] text-[var(--foreground)] hover:bg-[var(--border)] transition-all">Ambiente (4)</button>
        </div>
      </div>
      
      <!-- Aviso de confirmación -->
      <div class="mt-4 p-3 rounded-lg bg-indigo-500/10 border border-indigo-500/20 text-xs text-[var(--muted-foreground)] flex items-center justify-between gap-3">
        <span>🎧 <strong>Instrucciones:</strong> Haz clic en el botón de reproducción de cada tarjeta para escucharlo directamente aquí.</span>
      </div>
    </div>

    <!-- Cuadrícula de Sonidos -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4" id="audio-grid">
      $itemsHtml
    </div>
    
  </div>

  <script>
    function filterSounds(category) {
      const cards = document.querySelectorAll(".audio-card");
      cards.forEach(card => {
        if (category === "all" || card.getAttribute("data-category") === category) {
          card.style.display = "flex";
        } else {
          card.style.display = "none";
        }
      });
      
      document.querySelectorAll(".filter-btn").forEach(btn => {
        btn.classList.remove("bg-indigo-600", "text-white");
        btn.classList.add("bg-[var(--secondary)]", "text-[var(--foreground)]");
      });
      event.target.classList.remove("bg-[var(--secondary)]", "text-[var(--foreground)]");
      event.target.classList.add("bg-indigo-600", "text-white");
    }
  </script>
</body>
</html>
"@

$outputPath = Join-Path $targetDir "audio_preview.html"
[System.IO.File]::WriteAllText($outputPath, $fullHtml, [System.Text.Encoding]::UTF8)
Write-Host "Generado exitosamente en: $outputPath"
