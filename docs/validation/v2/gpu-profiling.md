# Rendimiento: diagnóstico y candidato final

El objetivo se mantiene:60s de combate activo a1280×720 después5s de calentamiento, promedio≥60FPS y p95≤25ms enAppleM5. No se sustituye por MovieMaker a60FPS simulados ni por benchmark del rig en escenario vacío.

La primera escena con árboles volumétricos dio26.38FPS/p9555.07ms, conF real20% yAI activa. Perfil10s sinF reprodujo26.20FPS/p9554.81ms. Ocultar solamente bosque, como diagnóstico, dio65.31FPS/p9516.34ms. Se atribuye el cuello principal al bosque; las partículas no se redujeron sin evidencia. Ningún override de diagnóstico queda en runtime de juego.

Hallazgos:LOD0/1 tenían43,349tri cada árbol, distanciaXZ consideraba cerca árboles bajo el dragón en vuelo y el material fotográfico de ramitas usabaalphaBLEND. Se probaronLOD volumétricos de menor geometría, distancia3D a copa y culling por frustum dentro de los MultiMesh. Primer candidato mejoró55.18FPS/p9519.45ms y aún fue rechazado por no alcanzar60.

Fuentes primarias aplicadas:[optimización3D de Godot](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html), [HLOD/rangos](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html) y [GPU/overdraw](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html). Material de hojas con corte alfa conserva su fotografía y volumen, permite profundidad y evita transparencias mezcladas superpuestas.

El perfil registraPerformance de físicas, proceso, draws/primitivas y `viewport_set_measure_render_time`. Este backendMetal devuelve0 para tiempoGPU medido: se declara dato no disponible, nunca costeGPU nulo. Son diagnósticos de10s; la aceptación final viene del benchmark60s y del recorrido nativo de misión sin captura de película. La grabación completa es evidencia visual aparte.

Aceptación histórica, anterior a los cambios posteriores del rig y terreno:60.010465s,3720frames,61.989188FPS,p9518.012ms,40disparosAI, combate100%,F20.16%;1280×720 Metal4 AppleM5, sin otroGodot activo. Los archivos combat-performance-final.log/json se actualizan al repetir el gate; no se les atribuye esta medición histórica como si fuera la vigente. LOD1017/513/218 triángulos; índices/primitivas del contador del renderer no equivalen a triángulos. Perfil limpio previo10s64.63FPS/p9516.59ms es diagnóstico.

## Benchmark posterior al freeze 987/FABRIK/arrays
Native aislado,60.002747s tras5s:87.845978FPS,p9513.773ms,5271frames,40disparosAI,F19.939%,combate100%,Metal4/Forward+AppleM5/1280×720. UI y19casos nativos también verdes. Fuente y command/rc en native-gates-run.json de esa ejecución; todos .gd/JSONruntime/shaders/project/main iguales al inicio y fin. Es benchmark aéreo anterior al nuevo collider del huevo, la recuperación del torso y el relieve; aún se exige repetir la secuencia nativa completa sobre el freeze final. La primera medición87.949FPS no se usa: gateSHA la rechazó por metadata modificada durante ejecución.

## Misión posterior: fases terrestres y escape
La misión nativa siguiente llegó a ESCAPE tras tres ballistas, capitán y rescate. Defensa terrestre: 101,20 FPS/p95 11,064 ms; capitán: 95,48/11,446; rescate: 109,05/10,086. Estos resultados cierran el diagnóstico anterior de rescate lento, pero no aceptan la misión completa. Escape: 12,744 FPS/p95 96,682 ms, dragón bloqueado y derrotado. Causa reproducida: cuello frente al collider cóncavo del huevo, nueve consultas del guard por cuadro (~159 ms). Se corrige collider/pose y se exige repetir todas las fases con victoria real, sin usar FPS de MovieMaker.

## Benchmark histórico posterior a limpieza de partículas
Tras corregir el temporizador de impactos, UI, 19 casos de combate y benchmark nativos se ejecutaron de nuevo en secuencia: todos rc0, sin errores de motor ni cambios de .gd/JSON/shaders/escena/imports. Benchmark: 60,007498 s después del calentamiento, 5.363 cuadros, **89,372165 FPS/p95 13,787 ms**, 30 disparos AI, F activo 19,9515 %, combate activo 100 %. Renderer Metal4/Forward+, Apple M5, 1280×720; draw calls máximo 320. Fuentes y receipt en native-gates-run.json.

El primer intento de 89,668 FPS no se acepta por el error al cerrar partículas, aunque los FPS eran suficientes; su log y SHA se conservan como particle-exit-red. La regresión específica ahora verifica liberación del emisor y cierre durante impacto, tres comprobaciones y cero errores. Queda pendiente la misión nativa completa por fases; MovieMaker no sustituye esa medición.

## Benchmark final tras EPA y preparación de patas

Pasada aislada actual: 60,006891 s, 5.387 cuadros, **89,773023 FPS/p95 13,698 ms**, 39 disparos AI, fuego activo 20,0297 %, combate 100 %, máximo 324 draws. Godot 4.7.2 Metal4/Forward+, Apple M5, 1280×720. UI y 19 casos nativos también pasan sin errores ni cambios de fuentes/imports; native-gates-run.json vincula los tres comandos. Esta cifra es rendimiento de pared real; no representa una medición interna de tiempo GPU. La misión nativa por fases se registra separadamente.

## Misión nativa final aprobada

Enter desde briefing, aterrizaje, tres defensas, capitán, rescate y escape reales: victoria a 71,45 s con salud 62/240, 17 disparos y 16 eventos de daño. 4.741 cuadros medidos tras cinco segundos: **71,569636 FPS/p95 15,702 ms**. Aproximación 77,599/15,824; defensas terrestres 70,767/15,522; capitán 67,306/16,246; rescate 71,511/15,764; escape 72,159/15,303. Todos los grupos ≥60 cuadros cumplen ≥60 FPS/p95≤25 ms. No MovieMaker, sin PNG/readback, sin exclusiones de captura; subclase sólo desactiva capture(). Fuentes y artefactos vinculados en playthrough-native-final-run.json. Cierra los rojos de escape y aproximación, preservados como historia.

Repetición final tras separar clasificación MovieMaker: 4.758 cuadros, 66,200113 s medidos, **71,872989 FPS/p95 15,617 ms**. Grupos aire 77,796/15,849; defensa terrestre71,054/15,441; capitán68,319/16,083; rescate72,557/15,017; escape72,065/15,554. Victoria a71,417s, salud62/240. Recibos prueban salida recién creada, hashes internos actuales y clasificación MovieMaker=false. La película posterior declara MovieMaker=true y valid_runtime_fps_measurement=false; ninguna de sus cifras reemplaza FPS nativos.

## Ronda2, fuentes congeladas
Benchmark real60,007505s: 85.656FPS/p9514.210ms,30disparosAI y20,467%fuego. Misión sin captura: 67.338FPS/p9517.013ms; grupos mínimos63,436FPS y p95 máximo17,730ms, todos verdes. No otra instancia ni trabajo pesado durante medición. Receipts actuales native-gates-run.json y playthrough-native-final-run.json; datos completos integration-round2.json. No GPU timestamp disponible; FPS de pared, nunca MovieMaker.
