# Victoria funcional y regresión de rendimiento en suelo

La primera pasada nativa de la revisión final alcanza Victoria por gameplay normal a71.383s de simulación, vida48/240, tres ballistas y capitán eliminados, rescate por E y escape por marcha continua. Dispara15 proyectiles AI, aplica18 eventos de daño y698 impactos de fuego. Recorre559.825m; paso físico máximo0.433281m. Los26 hashes de fuentes, driver, JSON de extremos y shaders coinciden al inicio y al final. El driver no altera runtime ni estados de juego.

Godot4.7.2, Metal Forward+, AppleM5,1280×720, vsync desactivado, sin MovieMaker. Se descartan5s iniciales de reloj real y11 intervalos de captura PNG. Los3984 intervalos restantes cubren123.478s reales:32.265FPS, p9531.375ms. El gate funcional y el umbral informativo de rendimiento son independientes: Victoria es real, el rendimiento de suelo queda rojo.

| Fase/estado | Frames | Pared s | FPS reales | Media ms | p95 ms |
|---|---:|---:|---:|---:|---:|
| Defensas/aire |394|6.579|59.889|16.697|19.794|
| Defensas/suelo |1813|42.513|42.646|23.449|24.651|
| Capitán/suelo |342|10.199|33.532|29.823|32.795|
| Rescate/suelo |398|40.029|9.943|100.576|596.448|
| Escape/suelo |1037|24.158|42.927|23.296|24.609|

Observación de la traza: rescate comienza a47.383s en(266.326,27.501,109.004). A50.083s el cuerpo está en(292.627,27.501,106.128) y se solicita yaw+45°/pitch+30°. A52.083s está en(298.978,27.499,105.086) girando con A; pitch sigue+30°. La traza muestra contacto predictivo false y normal de suelo(0,1,0). A54.05s se pulsa E en(299.909,27.501,93.346) y el juego cambia a Escape; contacto predictivo pasa a true con normal(.514,.642,.568). Estos muestreos no localizan cada stall: no se registró una serie por frame de contadores internos.

Lectura estática del guard en esta revisión: `_neck_contact` obtiene todos los puntos skinned del cuello y reconstruye `ConvexPolygonShape3D.points` en cada evaluación. Si el broadphase `_obstacle_near` y el contacto preciso activan la bisección, hay una evaluación inicial y ocho adicionales por apply. La rotación corporal tiene otra bisección de ocho pasos, con consultas de hasta cuatro hulls y dos máscaras. Esto ofrece candidatos para perfil, no demuestra cuál dominó: la traza no contiene contadores de esas llamadas ni tiempo interno de skinning/QuickHull/Jolt. Las primeras cuatro fases ya cuestan más en suelo que en aire, pero el rescate presenta una cola muy distinta.

Se preservan informe, log, traza y15PNG con prefijo `playthrough-preoptimization-ground-red-native-*`; el manifiesto `playthrough-preoptimization-ground-red-manifest.json` registra SHA256 y tamaños. El proceso sale0 y no hay errores de script; hay una advertencia de siete Texture RIDs al apagar la escena, que no explica los stalls previos. Root reabrió el runtime para perfil/optimización de anatomía. La grabación final se aplaza hasta repetir la pasada nativa.

Perfil posterior de anatomía: el tramo caro lo dominaba `wing_constrain`, especialmente el sweep del hull corporal2; `head_total` era despreciable en ese tramo. El hull corporal duplicaba el cuello y llenaba el espacio torso→hocico, aumentando el contacto contra el nido. Root informó una optimización de soporte exacto del cuello7810→2127 puntos y anclas de garra de un vértice: el repro local bajó de34s por30renders a~0.5s, constrain máximo1.94ms. Son resultados del perfil de anatomía; la misión completa debe repetirse tras sus pruebas y el nuevo freeze. El nuevo soporte `scripts/dragon_affine_support.json` se incorpora al SHA del driver por autorización de root.
