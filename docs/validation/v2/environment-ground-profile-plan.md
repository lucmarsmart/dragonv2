# Diagnóstico pendiente del rendimiento en suelo

Revisión estática del 2026-10-05. Se leyeron fuentes e informes; no se ejecutó Godot, Blender, benchmarks ni pruebas de CPU/GPU, y no se modificó runtime. El perfil de anatomía tiene prioridad. Este documento propone medidas para después de su congelamiento; no atribuye la regresión al entorno ni autoriza bajar su calidad.

## Evidencia disponible

La pasada `playthrough-preoptimization-ground-red-native-report.json` alcanzó Victoria real. Excluye calentamiento y escritura de PNG; registra 59.889 FPS en defensas/aire, 42.646 en defensas/suelo, 33.532 en capitán/suelo, 9.943 en rescate/suelo y 42.927 en escape/suelo. Rescate tiene p95 de 596.448 ms, frente a 24.609–32.795 ms en los otros tramos de suelo. Conviene investigar por separado el coste continuo de marcha y estos bloqueos largos. Los promedios por fase no localizan la llamada responsable.

El perfil corto anterior `environment-profile-optimized-clean-fire.json` dio 64.63 FPS desde vuelo. No prueba rendimiento de suelo. Los timestamps GPU devolvieron cero en Metal: se consideran no disponibles. El tiempo de render CPU no cubre el trabajo GPU; `TIME_PROCESS` tampoco demuestra CPU pura, pues puede incluir esperas. Los contadores de primitivas incluyen índices/vértices y pases de profundidad/sombra; no equivalen a triángulos únicos.

## Candidatos del entorno, todavía sin causalidad demostrada

| Candidato | Lectura de la implementación | Cómo comprobarlo |
|---|---|---|
| Árboles cercanos | LOD0: 43,349 triángulos, hasta 32 m de distancia 3D entre cámara y centro de copa; LOD1: 1,017, hasta 75 m. Sólo estos dos proyectan sombra. | Registrar cámara activa, población por LOD/celda y llamadas/primitivas por frame. Comparar el mismo encuadre con bosque oculto sólo en diagnóstico. |
| Rescate dentro del patio | La dispersión excluye árboles en X185–415/Z10–230, además del acceso. Las posiciones de cuerpo del rescate están dentro de esa zona. La cámara no está en la traza. | No culpar a LOD0 sin comprobar la posición de cámara. Si LOD0/1 tienen cero instancias activas, quedan descartados para ese tramo. |
| Suelo PBR | El shader declara aproximadamente 33 muestras de textura por fragmento: 15 de albedo, nueve de rugosidad y nueve de normales. También evalúa cuatro ruidos. Evalúa las tres familias de material aunque su peso sea cero, incluso en el patio. | Comparar resolución manteniendo escena/cámara/entrada; después una variante diagnóstica de material barato sobre la misma geometría. Una mejora por sí sola no justifica reemplazar el acabado definitivo. |
| Pasto global | `PhotographicMeadowTufts` agrupa hasta 2,450 instancias en un MultiMesh. Su rango de 210 m actúa sobre el lote, sin selección por instancia. | Registrar AABB, visibilidad/rango, instancias y contadores de dibujo con la cámara real. Si participa, ocultar sólo este nodo en una comparación. |
| Rocas globales | `ScatteredBoulders` agrupa hasta 190 instancias escaneadas en un MultiMesh, sin distancia/culling por instancia. | Registrar visibilidad y contadores; comparar sólo este lote. Conservar todos los cuerpos físicos. |
| Actualización del bosque | Cada 0.2 s recorre todos los árboles, construye 64 listas y sube cada transform activo mediante llamadas individuales. | Medir duración y cantidad de transforms enviados. Buscar periodicidad de 0.2 s en los stalls. La prueba anterior `freeze_lod` tuvo carga CPU concurrente y no sirve para concluir. |
| Posprocesado/sombras | SSAO, SSIL y sombras siguen activos; el ángulo rasante puede cambiar cobertura y carga. | Sólo después de las medidas anteriores, separar una comparación de SSIL, otra de sombras, conservando el encuadre. No apilar cambios. |

Los árboles lejanos conservan geometría volumétrica; las comparaciones diagnósticas no deben convertirse en una vuelta a tarjetas cruzadas. La exclusión del patio se refiere a bases de árbol; copas y cámara pueden cruzar sus límites. Las esferas de culling y las instancias enviadas no prueban que todas hayan sido rasterizadas.

## Secuencia mínima después del congelamiento de anatomía

1. Confirmar hashes de anatomía, entorno, shaders y driver; ejecutar un solo Godot nativo, sin otros perfiles, MovieMaker ni compilaciones. Mantener 1280×720, renderer y criterio existentes. Calentamiento y PNG deben quedar fuera de la medida.
2. Registrar por frame tiempo de pared, fase/locomoción, cuerpo y cámara activa, entrada de cabeza/F, contacto, `TIME_PHYSICS_PROCESS`, `TIME_PROCESS`, tiempo de render CPU y GPU con indicador de disponibilidad, draws/primitivas, compilaciones de pipeline y poblaciones LOD. Añadir los tiempos/cuentas de neck/hull/yaw que produzca anatomía. Guardar muestras en memoria; escribir después de cada tramo.
3. Repetir el driver normal hasta los mismos tramos de suelo. Anotar qué ocurrió durante cada frame superior a 100 ms. Comparar cabeza quieta y giro/pitch cerca del nido dentro del harness aprobado, preservando físicas y posición de cámara. Si el tiempo de guard explica la cola, corregir y volver a medir antes de intervenir render.
4. Para el coste restante de suelo, comparar un encuadre reproducible a resolución completa y a mitad de ancho/alto. Es una prueba de sensibilidad a píxeles, no una rebaja de aceptación. Mantener relación de aspecto, entradas, sombras, IA y físicos. Una respuesta marcada apunta a coste GPU/píxel; ausencia de respuesta no identifica por sí sola CPU.
5. Elegir **una** comparación según los contadores: material de terreno barato, bosque oculto, pasto oculto o rocas ocultas. Los cuerpos de colisión permanecen. Si hay stalls periódicos, instrumentar actualización/upload de LOD antes de congelarlos como prueba. El harness corto de vuelo actual no reproduce la marcha y requiere adaptación del responsable de QA.
6. Aplicar sólo la corrección respaldada por esas diferencias, conservar superficies/accesos y revisar una captura del mismo encuadre. Repetir la misión nativa completa con tiempos por fase y el benchmark integrado; no aceptar rendimiento de vuelo como evidencia de suelo. Mantener el criterio vigente de 60 FPS / p95 ≤25 ms y declarar cualquier fase que siga roja.

La serie por frame debe conservar la relación temporal: los monitores y los contadores de render pueden describir el frame anterior. El driver actual ya asigna el intervalo a la fase y estado de suelo previos; la instrumentación debe respetar esa convención. Una media de `TIME_PHYSICS_PROCESS` podría ocultar los bloqueos del rescate: hacen falta máximos, percentiles y muestras de los frames lentos.

## Fuentes congeladas leídas

| Archivo | SHA256 |
|---|---|
| `scripts/terrain.gd` | `c63fe70bcc2cd8624fd32081580ad6830eb69e57101b1302654074983dc2c2c8` |
| `shaders/terrain.gdshader` | `a6da0cc3ef71402c57cbc7454af652c7fbf5ceb80d0f7cae733480af6832fe5e` |
| `scripts/siege_environment.gd` | `2a4bd5a691732bcb7e2693a7bceeb621d87201a9bfec0a5b8c0827b2e2904659` |

Referencias locales: `playthrough-ground-red-analysis.md`, `playthrough-preoptimization-ground-red-native-report.json`, `scripts/combat/play_siege_validation.gd`, `scripts/profile_siege_environment.gd` y `environment-profile-summary.md`. Semántica de los contadores: [Godot Performance](https://docs.godotengine.org/en/stable/classes/class_performance.html) y [Godot RenderingServer](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html). Las fuentes primarias ya utilizadas por el perfil anterior se enlazan como referencia; esta revisión no verificó de nuevo documentación remota.

Idea 10× con aproximadamente 2× esfuerzo: conservar esta instrumentación por fase en el driver normal de victoria. Cada cambio futuro de assets tendría evidencia conjunta de gameplay, calidad visual y rendimiento de suelo, sin depender de un benchmark aislado de vuelo.
