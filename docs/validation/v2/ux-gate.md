# Revisión de interfaz nativa — Dragon v2

> REABIERTO por los fallos de descenso y atasco reportados por el usuario. Las inspecciones y cifras anteriores describen el candidato previo; faltan las capturas y mediciones nativas sobre la corrección actual. No acreditan el cierre de estos fallos.


Fecha:5 octubre2026. Entorno:Godot4.7.2, Metal4/Forward+, AppleM5. Superficie:briefing, créditos, gameplay/apuntado/ayuda, pausa, derrota y victoria;1280×720 y960×540. Herramienta real:`scripts/combat/capture_siege_ui.gd`, entradas de mouse/teclado y lectura de controles del motor. Es una aplicación nativa sinDOM: axe/Lighthouse/CSS no son aplicables. No se declara conformidadWCAG.

Referencias de criterios:[catálogo ux](/Users/fede/.codex/skills/ux/references/criterios.md), NielsenN1–N10, walkthroughCW1–CW4, DV8/DV10/DV11/DV12 y bloqueE. No existeDESIGN/tokens declarados en el repo;DV7 no aplica. No hay formularios móviles/servicio externo/contenido web indexable; las sondas específicas no aplican.

| Criterio | Método y evidencia | Resultado |
|---|---|---|
| N1/CW4 | Objetivo actual, contador de ballistas, salud, reserva de fuego, apuntado, pausa y resultado visibles; partida completa real llega aVictoria | Ver capturas UI y playthrough, no inferir victoria de fixture |
| N2/N6/N10/CW1–3 | Español; cada botón contiene su atajo; ayuda distingue vuelo/tierra y cuello/cuerpo; objetivo cambia por fases | Texto legible en ambas resoluciones; nido requiereE tras capitán |
| N3/N7 | Teclado+clic para iniciar/repetir, pausaP, ayudaH, T y flechas como alternativa a mouse | Tab/Enter defectuosos fueron reproducidos y corregidos; pasada nativa final alcanza2/2,8/8 y7/7 controles en ambas resoluciones |
| N5/N9 | Controles de vuelo deshabilitados en suelo; derrota explica virotes/apuntado y ofrece reintentar | Replay restituye escena/AI/salud/nido, comprobado en suite de combate |
| DV1/3/4/5/6 | Capturas nativas reales; contenedor centrado, máximo800px; paneles ocultanHUD; estadosdisabled/focus diferenciados | Ayuda tenía solapes con objetivo; se corrigió y volvió a capturar |
| DV8 | Rectángulos de todos los botones visibles por estado | Cero botones menores44×44 o fuera de viewport;48px alto |
| DV10 | Inventario de controles visibles, fuentes/tamaños/colores | Nativo final:1familia Open Sans SemiBold, máximo7tamaños y17colores; inventario en ui-measurements.json |
| DV11 | Espaciado UI declarado:8/12/16/24px y6px entre botones HUD | Valores en escala del catálogo; posiciones responsivas no equivalen a espaciado arbitrario |
| DV12/bloqueD | Foco con borde dorado y recorrido Tab real; texto no justificado | Teclado permite todos2/8/7 botones en briefing/créditos/acción; foco no se suprime |
| bloqueE/N1 | Clic izquierdo real press/release hasta primerframe presentado; teclado medido aparte | Clic22.002ms a1280 y21.074ms a960; Enter45.925/19.485ms; umbral100ms |

Los fixtures de victoria/derrota de UI comprueban presentación solamente. Combate verifica derrota por virote vivo y reintento; el playthrough realiza victoria por fases y controles reales. Las pruebas de estilo/teclado se registran separadamente del benchmark deGPU y no lo sustituyen.

Estado actual: nueva pasada nativa posterior a la limpieza de partículas, EPA de aterrizaje y preparación de metadatos aprobada, sin fallos. Inicio por clic presentado a 22,002 ms en 1280×720 y 21,074 ms en 960×540 (Enter separado:45,925/19,485 ms); Tab 2/2, 8/8 y 7/7; botones de 48 px, ninguno fuera de pantalla. Una familia, máximo siete tamaños y 17 colores. Fuentes, comandos, rc0 y ausencia de cambios durante ejecución en native-gates-run.json.

Root abrió personalmente briefing, ayuda y créditos a 960×540 de esta campaña: textos completos, controles legibles, foco dorado visible. La presentación de victoria/derrota de UI usa fixtures; la misión nativa completa valida por separado esas fases mediante controles reales. Las métricas 32,683/18,613 y 33,752/18,686 ms pertenecen a pasadas históricas anteriores.

Cierre D06 tras C3 ronda1: el timer empieza inmediatamente antes del par de eventos izquierdos reales de Viewport.push_input; espera process_frame y RenderingServer.frame_post_draw. Hover/warp y su asentamiento quedan fuera. Cada medición exige misión corriendo, overlay oculto y <100ms. La preparación de retry usa clic real y restaura BRIEFING; no hay llamada directa al handler de inicio. Dos mediciones nativas first_frame_presented=true. El headless de desarrollo se guarda aparte y no acredita presentación. Root volvió a abrir las capturas960 de briefing, ayuda y créditos de esta ejecución.
