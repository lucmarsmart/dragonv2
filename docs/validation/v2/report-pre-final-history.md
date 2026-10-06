# Validación integrada de Dragon v2

Estado: trabajo en curso. La regresión del bloqueo del cuello contra el huevo ya pasa; la integración todavía no se acepta. Una aproximación continua en el relieve nuevo reprodujo 203 vértices de una pata dentro de un árbol, hasta 63,87 cm; además, el convexo corporal anterior podía bloquear la retirada aunque la piel estuviera fuera del terreno. La partición de cuerpo y recuperación de miembros están en validación. Faltan la misión nativa completa y los gates finales. No hay película final ni C3 final aprobados. Este informe distingue resultados vigentes de intentos históricos conservados como evidencia roja.

## Implementación y fuentes
Se incorporaron a la escena activa modelos descargados de GitHub: armadura Knight de piacenti vía SaschaWillems/Vulkan-Assets; ballista Kenney vía Hidencod/tge-assets; acantilado Poly Haven vía Papyszoo/CC0-Public-Domain-Models; farol vía Khronos. Los originales, autores, commits, licencias específicas y adaptaciones están en assets/LICENSES.md. La armadura recibió rig y animaciones; la ballista tiene pivotes, cuerda, mecanismo y salida física del virote. Fortaleza, vegetación y materiales fotográficos completan el escenario. Las laderas usan Rock Face CC0 de Poly Haven con albedo/normal/roughness 2K completos y relieve determinista de varias escalas, con crestas y hombros irregulares. Render y colisión comparten los mismos triángulos; el patio, río y acceso conservan exactamente sus alturas float32 previas. Bosque final: 2.728 árboles, dentro del presupuesto de 2.771.

El dragón usa marcha por distancia, pies plantados con FABRIK, plegado de alas, pose de cuello con apuntado independiente y fuego desde el hocico renderizado. El asedio tiene tres defensas, capitán, rescate del nido, escape, daño, derrota y reinicio. T activa apuntado de cabeza; ratón/flechas orientan la mirada y F lanza fuego.

## Equipo y método
Godot 4.7.2.stable.official.ed1daf0bf, Metal 4, Forward+, Apple M5; ventana 1280×720 y comprobación de interfaz 960×540. Mediciones de rendimiento por tiempo de pared después de cinco segundos de calentamiento, sin otro Godot ni trabajos pesados simultáneos. MovieMaker no se usa como medidor de FPS. Sonda de piel en callback final del SkeletonModifier, con pesos y bind del GLB; no se acepta posición de huesos como sustituto de la superficie visible.

## Evidencia vigente antes del arreglo del huevo
| Criterio | Evidencia | Resultado |
|---|---|---|
| D01 | Todas las membranas, negativo deliberado, plano/pendiente/transiciones; anatomy-report.md | 987 extremos de 184 poses; verificación independiente de 5.412 vértices en 16 poses reales, máximo fuera del hull 0,315 mm |
| D02 | Garras, apoyo, zancada, mirada y vídeos de marcha/aterrizaje | Zancada ≈3,5 m, al menos tres apoyos lentos, deslizamiento ≈2,52 mm/tick; neutral 1,611–4,921°, idle 4,830°, seguimiento ±20° con error ≤3° a 0,7 s |
| D08 | Planeo 20 s, tres vistas y piel completa | Torso 0°; diferencia de membranas 0,2145 m sobre 35,825 m de envergadura |
| D10 | Piel completa contra pared y terreno, giro y cabeza parado | Terreno: 110 cuadros, 1.953.710 puntos corporales, mínimo −2,035 cm; pared: 8/8 y retirada 12 m. Abierto por huevo: máximo 7,117 cm y retirada bloqueada |
| D03/D09 | Imágenes cercanas y vistas de paisaje inspeccionadas, assets y visual-gate.md | Armadura, mecanismo, mampostería, árboles volumétricos, roca y ribera con PBR; aprobación visual final pendiente de C3 |
| D04 | combat-performance.json y native-gates-run.json | Vuelo activo 60,003 s: 87,846 FPS, p95 13,773 ms, 40 disparos AI, F 19,94 %. Defensa/capitán/rescate 95–109 FPS; escape 12,744 FPS: rojo |
| D05 | combat-native-final.log | 19/19: enemigos activos, fuego/LOS, virote 220 m/s contra muro fino, derrota por virote real, retry y segunda partida |
| D06 | ui-measurements.json y ux-gate.md | 1280/960: botones ≥48 px, ninguno fuera; Tab 2/2, 8/8 y 7/7; latencia 32,683/18,613 ms |
| D07 | Partida real con inputs y 28 fuentes SHA al inicio/fin | Llegó a escape y murió por bloqueo. Pendientes partida aceptada, película, launcher completo y doble C3 |

## Límites
Los resultados prueban escenarios concretos de este rig y Mac. Las hulls trasladan una pose entre consultas; no constituyen prueba universal de cualquier deformación o geometría futura. La compresión afín conserva índices originales y grupos de pesos/binds; equivalencia runtime tiene error de coma flotante medido, no identidad bit a bit de coordenadas. Regenerar extremos y pruebas al cambiar rig o clips.

El paisaje combina modelos/materiales fotográficos con colinas procedurales y LOD lejano simplificado. No se presenta como fotogrametría integral ni calidad AAA garantizada. Metal registra siete TextureRID al cerrar; se conserva esa advertencia y no se infiere coste GPU cero de timestamps no disponibles. La interfaz nativa no declara certificación WCAG, axe ni Lighthouse. PDF y trabajo ajeno preservados; sin publicación ni push.

## Corrección del huevo: regresión posterior
El convexo denso conservaba la superficie, pero empeoraba el coste. El collider final usa 272 puntos, contiene todos los 6.144 triángulos originales y difiere como máximo 3,14494 cm de la superficie. Broadphase de caja y rechazo positivo mediante un punto original dentro del collider real evitan EPA innecesario; se conserva la consulta física para cruces sin vértice interior.

Aceptación 7/7: 274 cuadros y 7.015.222 vértices, penetración cero, retirada de 23,589 m, salto angular máximo 3,99974° y cero cambio de traslación de los enlaces respecto a la pose authored del mismo cuadro. Perfil del guard bloqueado: aproximadamente 0,53 ms. Strict 42/42, stationary 11/11, cola 8/8 y legado 54/54 posteriores al arreglo están verdes. Falta revalidar terreno/hulls tras el ajuste del paisaje y confirmar escape con victoria y FPS nativos. Estas pruebas aisladas usan un fixture colocado deliberadamente; no sustituyen una misión jugada con entradas reales.
