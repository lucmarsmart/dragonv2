# Dragon v2 — El último guardián

Juego local en Godot 4.7.2. El dragón debe aterrizar junto a una fortaleza, destruir sus tres ballistas, derrotar al capitán, liberar el nido y escapar. Caballeros y virotes causan daño; la derrota permite volver a empezar.

En macOS abre **JUGAR_DRAGON.command**. Usa Godot oficial instalado en `~/Library/Application Support/Dragonv2/Godot.app`; también admite una instalación en Applications o `DRAGON_GODOT_BIN`. En otros sistemas abre `project.godot` con Godot 4.7.x y ejecuta F5. Las mediciones de rendimiento corresponden exclusivamente al Mac M5 de desarrollo.

| Acción | Control |
|---|---|
| Iniciar / repetir tras victoria o derrota | Enter / R; también botones |
| Batir y acelerar / caminar | W; Shift corre en tierra |
| Frenar / retroceder en tierra | S |
| Girar el cuerpo | A / D |
| Ascender / picar / planear | Espacio / C o Ctrl / G |
| Aterrizar, cancelar aproximación o despegar | L |
| Activar/desactivar ataque con cámara sobre cabeza | Una pulsación T; después ratón para apuntar y girar |
| Disparar en modo ataque | Mantener clic izquierdo mientras W/S mueve y el ratón apunta; F y botón FUEGO también disponibles |
| Liberar el nido | E cerca del nido, después del capitán |
| Cámara / órbita / zoom | V o 1–4; botón derecho + arrastrar; rueda |
| Ayuda / pausa / alternar cursor | H o F1 / P / Esc |

El fuego consume y recupera reserva. La retícula sigue el hocico real; Una pulsación T activa la cámara sobre la cabeza tanto en tierra como en vuelo. W/S mueve, el ratón apunta dentro de los límites del cuello y gira el cuerpo al excederlos, y el clic izquierdo dispara; no hace falta mantener T ni combinar A/D y F. El giro terrestre conserva su límite de velocidad y recoloca los apoyos. Alas, cuello y cuerpo usan colisiones predictivas; el plegado empieza antes de tocar suelo. La marcha combina apoyos de garras, zancada por distancia recorrida y transferencia de peso. Las cuatro patas no proceden de una animación de marcha original: se resuelven mediante cinemática inversa sobre el rig de vuelo.

Modelos reales de GitHub: armadura de piacenti distribuida por Vulkan-Assets, ballista derivada del Castle Kit de Kenney, acantilado de Poly Haven distribuido por CC0-Public-Domain-Models y farol de Khronos. Se integran además escaneos de mampostería, rocas, hierba y abetos con materiales PBR. Autorías, licencias, modificaciones y huellas de archivos: **assets/LICENSES.md**; también están disponibles los créditos dentro del juego.

## Validación reproducible

`./VALIDAR_DRAGON.command` importa recursos y ejecuta las suites de vuelo/fuego, anatomía, zancada por cada pata, alabeo y recuperación, cámara contra muros, terreno, IA activa con obstáculos, combate y partida completa con entradas reales. Detecta errores de scripts y shaders aunque Godot termine con código cero. Las pruebas aisladas usan fixtures; la partida completa conserva enemigos, daño y combustible normales y no teletransporta ni fuerza la victoria.

Las capturas y grabaciones requieren renderer real, no `--headless`. `scripts/combat/benchmark_siege.gd` mide 60 segundos de combate después de 5 segundos de calentamiento a 1280×720. `scripts/combat/capture_siege_ui.gd` recorre la interfaz nativa a 1280×720 y 960×540. Evidencia actual: `docs/validation/v2/`; contrato: `docs/plans/dragon-siege.md`; investigación: `docs/references-v2.md` y `docs/validation/v2/environment-research.md`.

No se extraen modelos de los juegos investigados. La criatura es ficticia y las pruebas cubren escenarios concretos; no certifican biomecánica real, calidad universal ni rendimiento en otros equipos. El modelo original del dragón conserva su procedencia heredada: no se le asigna una licencia inventada.

Ejecución final en Mac M5: pendiente. La campaña de validación se está repitiendo después de corregir anatomía y controles. Los vídeos y cifras anteriores son históricos hasta regenerar sus receipts. El resultado vigente se documenta en `docs/validation/v2/report.md`. MovieMaker es evidencia visual y no mide FPS.
