# Validación integrada de Dragon v2

Estado: integración ronda2 aprobada por ejecución; doble C3 independiente pendiente. Launcher completo rc0, cero errores y fuentes/imports sin cambios. UI por clic 22.002/21.074ms. Benchmark activo 85.66FPS/p95 14.210ms; misión completa 67.34FPS/p95 17.013ms, todas las fases verdes. Victoria con entradas reales y salud76/240. C3 ronda1 tuvo cinco carencias de comprobación, ahora cubiertas por nuevas pruebas; ningún runtime cambió. El cierre espera ambos revisores sobre un nuevo snapshot.

## Implementación y fuentes
Se incorporaron a la escena activa modelos descargados de GitHub: armadura Knight de piacenti vía SaschaWillems/Vulkan-Assets, ballista Kenney vía Hidencod/tge-assets, acantilado Poly Haven vía Papyszoo/CC0-Public-Domain-Models y farol vía Khronos. Origen, commits, autores, licencias, SHA y adaptaciones están en assets/LICENSES.md. La armadura tiene rig y animaciones propios; ballista con pivotes, cuerda, manivela y salida física del virote. Fortaleza, rocas, hierba y abetos usan modelos/materiales fotográficos.

La marcha combina zancada por distancia y apoyos de garras, FABRIK con longitudes originales, transferencia de peso y preparación de patas antes de tocar. Pies cambian rumbo durante swing y quedan plantados durante apoyo. Alas compactadas antes del suelo y planeo equilibrado. T activa cabeza independiente; ratón/flechas dirigen el hocico y F exhala desde la boca renderizada. Cuerpo/cuello/alas usan 18 piezas convexas; sus caras de frontera conservan esquinas completas. Se recuperan rotaciones seguras ante contacto sin estirar los huesos.

El asedio tiene tres ballistas, caballeros, capitán, rescate, escape, daño, derrota y reinicio. La historia del guardián del valle se expresa en briefing, objetivos y nido encadenado. Fuego y virotes respetan obstáculos.

## Método
Godot 4.7.2.stable.official.ed1daf0bf, Metal4/Forward+, Apple M5; 1280×720 y UI adicional 960×540. FPS por tiempo de pared, calentamiento de cinco segundos, sin otro Godot ni trabajos pesados simultáneos. MovieMaker es evidencia visual, nunca medidor de FPS. Sonda Skin final de 25.603 vértices con bind/pesos originales, observada en modification_processed; no se sustituyen vértices por huesos. El escenario y el juego mantienen sus superficies físicas.

## Resultados previos de ronda1 (conservados)
| Criterio | Evidencia y resultado |
|---|---|
| D01 | Alas: 1.088 índices originales; hulls emitidos pasan 33 poses frescas, incluidas 12 independientes, máximo exterior 0,521 mm. Selección verificada en 213 poses; negativos preservados. |
| D02 | Zancada 3,5 m, ≥3 apoyos lentos; neutral 1,611–5,485°, idle 4,823°. Cuatro objetivos ±20° seguidos dentro de 3° a 0,7 s. Pies: giro real 93,583°, orientación final error 0°, deslizamiento 1,848 mm. |
| D08 | Planeo 20 s: torso 0°, diferencia de toda la membrana 0,21442 m/envergadura 35,82477 m. Tres vistas y vídeo, geometría final revalidada. |
| D10 | BODY: 19.993 caras completas/14 poses, error de enclosure 0,111 mm. Terreno: 508 cuadros, 13.006.324 vértices, mínimo +0,557 mm; antebrazo/árbol profundidad 0,395 mm. Muro frontal/lateral/estacionario/corporal con todos los 25.603 puntos; retirada real. Huevo: 7/7, penetración cero, retirada 23,589 m. |
| D03/D09 | GitHub y materiales CC/PBR con créditos accesibles; vistas de montaña/ribera/pino/fortaleza inspeccionadas. Relieve multiescala determinista, sombras y agua sinuosa; límites de LOD y relieve procedural declarados. |
| D04 | Benchmark 60,006891 s: 89,773023 FPS/p95 13,698 ms, 39 disparos AI, fuego 20,0297 %, combate 100 %. Misión nativa: 71,872989 FPS/p95 15,617 ms; todas las fases cumplen. |
| D05 | 19/19 nativos: detección/LOS, fuego, proyectil 220 m/s contra muro fino, derrota por virote, clic de retry y segunda partida. Impact lifecycle 3/3, sin error al cerrar. |
| D06 | UI 1280/960, todos los controles ≥48 px y dentro; foco/Tab 2/2, 8/8, 7/7; inicio 43,603/19,597 ms. Pantallas inspeccionadas directamente. |
| D07 | Launcher rc0, fuentes/imports sin cambios ni errores; misión nativa con Enter/T/L/W/A/S/D/Shift/F/E, victoria sin daño/progreso/teleport forzados. Victoria nativa final a 71,417 s, salud 62/240, 17 disparos AI y 16 eventos de daño. Película final aprobada; doble C3 en curso. |

Suites de anatomía: 42/11/7/8/3/54/79, todos rc0. Receipts, comandos, SHA y negativos: anatomy-manifest.json, launcher-final-run.json, native-gates-run.json y archivos de campaña. Las cifras previas 987/184, 87,846 FPS y escape 12,744 FPS son históricas; sus rojos se conservan. La corrección de partículas reemplaza una lambda de temporizador por finished.queue_free; se volvió a correr launcher y los tres gates nativos.

## Inspección visual y límites
Root abrió las capturas actuales de interfaz, entorno y aterrizaje/marcha sobre la ladera; cinco cuadros del vídeo final complementan los puntos de contacto. El entorno se acepta como paisaje de juego PBR con mejora visible, sujeto a revisión independiente; no se afirma fotogrametría integral ni calidad AAA garantizada. El cliff real de GitHub convive con terreno procedural.

Las pruebas cubren casos enumerados de este rig y Mac, no toda deformación o geometría futura. Skin/hulls tienen error float medido, no identidad bit a bit. Avisos de cierre: siete TextureRID; MovieMaker del fixture también reporta dos ObjectDB. Se conservan sin inferir coste GPU cero de timestamps no disponibles. No hay errores de scripts en las pasadas aceptadas. UI nativa no declara certificación WCAG/axe/Lighthouse. PDF y trabajo ajeno preservados, sin publicación ni push.

## Misión nativa previa por fase (ronda1)

Sin MovieMaker, sin readback de PNG ni exclusiones de intervalos de captura. La subclase sólo desactiva capture(); conserva el driver y todos los controles del juego. Fuentes/imports iguales antes/después, cero errores, cero teleports, llamadas directas de daño u overrides. Recorrido 560,837 m, cinco fases [1,2,3,4,5], 896 contactos de fuego.

| Fase / locomoción | Cuadros | FPS de pared | p95 ms |
|---|---:|---:|---:|
| 1/air | 493 | 77.796 | 15.849 |
| 1/grounded | 2148 | 71.054 | 15.441 |
| 2/grounded | 389 | 68.319 | 16.083 |
| 3/grounded | 420 | 72.557 | 15.017 |
| 4/grounded | 1308 | 72.065 | 15.554 |

La omisión de EPA durante LANDING elimina una normal sin consumidor; los 18 hulls, casteos, clipping y plegado siguen activos. La preparación inicial reutiliza sólo metadatos de pies; contactos y matrices se calculan con la pose real. Sus negativos y regresiones se conservan.

## Grabación de la misión final

[Partida completa](playthrough-metal.mp4): 4.315 cuadros, 1280×720/60Hz, 71,917 s de vídeo. Victoria real a 71,85 s de misión, salud 55/240, 17 disparos AI y 17 eventos de daño. El adaptador de evidencia sólo clasifica MovieMaker antes de la primera captura; no modifica ningún control ni estado del juego. Receipt fresco/source-bound, rc0, ningún error ni cambio de fuentes/imports. MovieMaker invalida deliberadamente FPS; sus tiempos no se usan para aceptar rendimiento. Root inspeccionó directamente combate terrestre con fuego (02400), liberación/escape (03199) y victoria (04307).

[Vista frontal llana](anatomy-flat-front.mp4), [contacto](anatomy-flat-front-touchdown.png) y [marcha](anatomy-flat-front-walk.png) complementan el lateral de ladera. Prueba original motion-only y cámara frontal, fuentes actuales/rc0/sin errores, receipt anatomy-flat-front-final-run.json. La vista frontal de ladera también fue regrabada y pasa la sonda física, pero árboles y cresta ocultan parte de las patas. Esa oclusión se declara, no se eliminan props del juego.

## Integración actual tras ampliar cobertura (ronda2)

- D02: cuatro patas,16ciclos completos cada una, mínimo3,374992m a velocidad real7,5m/s. Control negativo demuestra el falso positivo de mezclar patas.
- D08: cuerpo y eje de piel originales congruentes a izquierda/derecha; cambio máximo0,552°/cuadro, recuperación≤2° en1,45s; sin reiniciar pose entre giros. Prueba headless24/24 y prueba nativa con cuatro capturas de giro/recuperación, inspeccionadas personalmente.
- D04/D10: cámara144/144;1845cuadros sin intersección de esfera0,2m/segmentos/sweeps/contención de caja. Negativo dentro del muro y recuperación por segundo rayo post-lerp; pared trimesh de fortaleza real.
- D05: IA activa11/11. Caballero y ballista ocluidos360cuadros cada uno sin adquisición/ataques/daño. Al retirar sólo la pared, mismo caballero3golpes/21HP y misma ballista3virotes/36HP; no daño ni proyectiles manuales.
- D06: clic real→primer cuadro presentado22,002/21,074ms a1280/960; Enter separado45,925/19,485ms. Misión corriendo y overlay oculto; actual UI nativa inspeccionada.

Launcher integra los tres drivers nuevos: locomotion-contract24, camera-surfaces144 y active-ai-los11; conserva las suites anteriores. Receipts actuales: launcher-final-run.json, native-gates-run.json, anatomy-bank-native-run.json y playthrough-native-final-run.json. Todos rc0, sin errores ni cambios de fuente durante ejecución. Envolventes revalidadas:1088/33/213, BODY19993caras/14poses y huevo6144caras; resultados geométricos idénticos.

Benchmark actual: 60.007505s/5140cuadros, 30disparosAI, fuego20.467%, combate100%. Misión actual: victoria71.483s, salud76/240, 17disparosAI/14eventos de daño/904contactos de fuego; recorrido561.062m. Sin capturas durante medición, sin overrides, teleports o llamadas directas de daño.

| Fase/locomoción | Cuadros | FPS | p95ms |
|---|---:|---:|---:|
| 1/air | 479 | 75.177 | 16.901 |
| 1/grounded | 2016 | 66.695 | 17.037 |
| 2/grounded | 361 | 63.436 | 17.730 |
| 3/grounded | 389 | 66.443 | 16.907 |
| 4/grounded | 1217 | 67.169 | 16.722 |

La película aceptada de ronda1 y los vídeos de aterrizaje conservan sus receipts originales. Todos los scripts de producción, driver de misión, shaders y configuraciones de importación coinciden con los SHA actuales (integration-round2.json); el rig y la geometría no cambiaron. Se declara esa reutilización, no una nueva grabación ni identidad de los tests ampliados. Las cuatro capturas de bank sí son nativas nuevas sobre el test actual. Un intento de regrabación fue rechazado antes de arrancar por otra instancia Godot abierta; no se cerró una partida ajena ni se inventó una ejecución. Las mediciones válidas anteriores terminaron antes de esa instancia.
