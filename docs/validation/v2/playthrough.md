# Validación de misión por controles reales

El driver `scripts/combat/play_siege_validation.gd` instancia la escena pública, pulsa Enter desde el briefing y usa eventos reales de teclado y mouse mediante `Input.parse_input_event`. Lee las posiciones para navegar/apuntar; no llama métodos de daño, apuntado, rescate ni cambio de fase. No modifica vida, gracia, combustible, locomoción, posición ni AI. El reset oficial del juego al iniciar precede a la medición de continuidad.

Controles: T activa apuntado independiente; L inicia aterrizaje; W/A/S/D y Shift caminan, retroceden, giran y corren; mouse apunta dentro de los límites normales; F dispara; E libera el nido. Las ballistas y los guardias usan su AI, proyectiles, colisiones y daños normales. Se sigue la ruta de entrada sur, ballista sureste → noreste → noroeste, capitán, nido y salida sur.

Reproducción determinista:

```sh
tools/godot.sh --headless --path . --fixed-fps 60 --script scripts/combat/play_siege_validation.gd
tools/godot.sh --path . --fixed-fps 60 --script scripts/combat/play_siege_validation.gd
```

Cada ejecución escribe `playthrough-headless|native|metal.jsonl`, `-report.json` y capturas PNG si hay renderer. El PASS exige la fase VICTORY real. Se registra cada transición, vida, gracia, combustible, impactos, disparos, input observado, poses y colisiones. Una discontinuidad mayor a 3 m por paso físico o un atasco de 5 s durante la entrada produce FAIL. `--fixed-fps 60` controla el tiempo de simulación; no es un benchmark de rendimiento.

Resultados previos preservados:

| Intento | Resultado real | Causa/evidencia |
|---|---|---|
| 1 | DEFEAT, 47.73 s | Driver giró en el umbral sur y quedó contra la estructura. Corrección de ruta: entrar al centro z150 antes de ir al flanco. |
| 2 | DEFEAT, 41.57 s | Llegó caminando a (330,27.5,150); F consumió combustible sin bajar vida de ballista. Clip global por plano infinito de una cara lateral del plinto. Root corrigió la oclusión para distinguir contacto exterior y eje del fuego. |
| 3 | Cancelado; sin PASS | Tras introducir hulls corporales completos, la marcha quedó bloqueada en suelo plano. Diagnóstico inicial sobre Shift descartado por prueba de input real. |
| 4 | Cancelado; sin PASS | W observado como presionado, shoreline false, speed0. Instrumentación ampliada. |
| 5 | FAIL, 16.62 s | W real, sin manual override; posición (300,27.50045,245.5097). Única colisión: terreno con normal (0,1,0). Predicción del hull confundía presión vertical de suelo con barrera. 4 proyectiles AI, 1 daño, vida222, paso máximo0.4333m. |
| 6 | DEFEAT, 60.35 s | Dos ballistas destruidas con fuego real. Tercer waypoint dejaba el hocico 0.7m fuera de alcance; corregido el driver. |
| 7 | Cancelado; sin PASS | Tres ballistas y capitán muertos. Entrada al nido bloqueada a12.54m por rocas, fuera de interacción12m; corregido acceso físico sur en runtime de entorno. |
| 8 | DEFEAT, 106.57 s | Defensas, capitán y rescate completos. Driver paraba en z199 porque radio de llegada5m impedía cumplir condición z≥202. Corregido flag del waypoint; no se alteró el checkpoint del juego. |

La corrección de colisión pertenece al runtime de anatomía y la del fuego al runtime de combate; este driver no las implementa. Las repeticiones del baseline completaron la misión con Victoria real. Los resultados fallidos se conservan para evitar confundir fixtures aislados con una partida completa.


## Baseline comprobado

| Métrica | Headless | Metal nativo M5 |
|---|---:|---:|
| Resultado | PASS, Victoria real | PASS, Victoria real |
| Tiempo activo |72.983s|70.933s|
| Vida restante |36/240|62/240|
| Ballistas destruidas |3|3|
| Capitán muerto |Sí|Sí|
| Fases por gameplay |1→2→3→4→5|1→2→3→4→5|
| Proyectiles AI disparados |18|15|
| Eventos de daño al jugador |15|16|
| Aplicaciones de daño por fuego real |906|897|
| Recorrido continuo |556.398m|555.918m|
| Paso físico máximo |0.433281m|0.433281m|
| Teleports después de Enter |0|0|
| Llamadas de daño/aim/phase API desde driver |0|0|
| Overrides de vida, gracia, AI o movimiento |0|0|

`playthrough-baseline-headless-report.json` y `playthrough-baseline-metal-report.json` contienen los SHA256 de16 fuentes principales al comenzar cada ejecución. El driver quedó congelado durante ambas pasadas del baseline y no hubo errores de script en sus logs. El runtime de combate recibió calentamiento de la sonda antes del briefing entre ambas pasadas, por eso los hashes de ese archivo difieren; el juego de Metal usa la revisión del baseline con dicho calentamiento.

La grabación nativa usa Godot4.7.2, Metal4.0, Forward+, AppleM5,1280×720. `playthrough-baseline-metal.avi` conserva íntegros los71s capturados con Movie Maker. `playthrough-baseline-metal.mp4` contiene la misma grabación completa en H.264/AAC, precedida por2s de la captura real del briefing y seguida por3s de la captura real de Victoria, para poder leer ambos paneles. No se cortaron ni reconstruyeron acciones del recorrido.

Hay15PNG nativos del briefing, secuencias y transiciones, incluido `playthrough-metal-04252-victory.png`. El manifiesto `playthrough-baseline-manifest.json` registra tamaños y SHA256 del driver, informes, trazas y medios del baseline. Los archivos AVI y MP4 son evidencia de gameplay; la simulación a60FPS y la velocidad de Movie Maker no representan FPS de rendimiento. El benchmark de rendimiento se ejecuta por separado sin grabación.

Tras esta victoria, root solicitó una revisión adicional del LOD del paisaje y de los candidatos de colisión para mejorar la fidelidad visual. El baseline positivo está preservado con prefijo `playthrough-baseline-*` y su manifiesto; la conducción del driver permanece sin cambios. Se añadió instrumentación de rendimiento por autorización de root. La validación final se repetirá al congelar dicha revisión. No se afirma que un vídeo de la revisión anterior valide automáticamente los archivos nuevos.


## Medición final de tiempo real

Antes de grabar MovieMaker se ejecuta la misma misión nativa sin `--write-movie`, con ventana1280×720 y vsync desactivado. `--fixed-fps 60` fija el paso de simulación; los FPS reportados se calculan con deltas de `Time.get_ticks_usec()` entre señales `process_frame`, sin derivarlos del tiempo de misión. Se descartan los primeros5s de reloj real y se agrupan los intervalos restantes por fase y estado suelo/aire del frame anterior.

```sh
tools/godot.sh --path . --fixed-fps 60 --windowed --resolution 1280x720 --script scripts/combat/play_siege_validation.gd
```

El informe `playthrough-native-report.json` incluye renderer, GPU, resolución, cantidad de muestras, duración de pared, FPS medios y p95 en ms. Conserva tanto todos los intervalos posteriores al warmup como los intervalos sin I/O de captura. Los intervalos que incluyen espera de `frame_post_draw`, lectura del viewport y escritura PNG se marcan explícitamente y se excluyen del segundo conjunto; no se eliminan otros stalls. El umbral de referencia60FPS/p95≤25ms se informa también por fase/estado con al menos60 muestras; no cambia el resultado de gameplay. Se reportan el modo vsync efectivo y Engine.max_fps para detectar topes de presentación.

La bandera MovieMaker se obtiene de Engine si está disponible, o del argumento `--write-movie`. Los informes headless y MovieMaker indican `valid_runtime_fps_measurement=false`; sus deltas no prueban rendimiento gráfico normal. La misión completa añade evidencia de navegación y combate en suelo; no sustituye el benchmark D04 de60s de vuelo con AI y fuego. Los informes nuevos registran28 SHA256, incluidos el propio driver, el helper de contacto en suelo, los extremos geométricos y soportes afines usados por las colisiones y los ocho shaders del runtime. Al terminar se vuelven a calcular los hashes y se registran los archivos que cambiaron durante la pasada, si los hubiera.

La primera pasada nativa de esta revisión logró Victoria real a71.383s y48 de vida, con26 hashes estables. El rendimiento de suelo quedó rojo:32.265FPS globales, p9531.375ms; en rescate9.943FPS y p95596.448ms. Informe, traza y capturas están preservados como `playthrough-preoptimization-ground-red-native-*`; el análisis está en `playthrough-ground-red-analysis.md`. Root reabrió el runtime para optimizar anatomía y aplazó la grabación final. Este resultado funcional no oculta el fallo de rendimiento.

La siguiente pasada (intento11) mejoró defensas/capitán/rescate a101.20/95.48/109.05FPS, con p95≤11.446ms y28 hashes estables. Falló en escape: tras E a53.15s con velocidad12.8m/s, la frenada llegó a(300.0296,27.50014,89.30162); S+Shift dejó velocidad0 y se produjo derrota a66.70s. La fase Escape registró12.744FPS/p9596.682ms. `contact_normal` era un valor anterior en la rama nueva y no identifica el collider causante; sólo la cápsula reportaba slide contra suelo. Evidencia preservada como `playthrough-attempt11-escape-red-native-*`. Root reabrió el diagnóstico del controlador antes de cambiar la conducción. El trace siguiente añade poses, contactos del guard y razones de recuperación, sin modificar inputs.
