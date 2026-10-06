# UX GATE — Dragon Simulator

Usuario desktop nuevo: volar, cambiar altura, aterrizar, caminar, exhalar y despegar. Modo: juego 3D nativo Godot, sin web ni móvil. Se aplican N1/N2/N3/N5/N6/N10, CW1–4, DV1/2/3/5/8/10/12 y teclado/foco. Axe, Lighthouse, formularios y servicios remotos no aplican; runtime es completamente local. No se certifica WCAG de un juego 3D.

Recorrido real automatizado con motor ejecutándose: G desde teclado; clic GUI SUBIR; L aproxima/cancela; aterrizaje físico seco; caminar/retroceder/correr/girar; F y botón mantenido; soltar fuera del botón; agotamiento y recuperación; despegue y fuego en vuelo. Entradas mediante Input.parse_input_event y Viewport.push_input, además de controles de simulación en maniobras largas. Capturas Metal de cada estado y vídeo continuo en docs/validation.

Medición: `test_render_quality.gd` a 1280×720 y 960×540, verifica botones visibles con dimensiones ≥44×44, foco individual y panel de ayuda dentro de viewport; barra no solapa telemetría. Código de salida 0, todos los controles comprobados. Cinco tamaños tipográficos (14/16/18/20/22), una familia nativa; mensajes en español y estado escrito, no solo color. F responde antes de 100ms (5 ticks60Hz); recurso deshabilita botón al agotarse. Controles de vuelo se deshabilitan durante estados incompatibles. H/F1 oculta ayuda.

Hallazgos corregidos: los targets al bajar a960px quedaban físicamente a36px con canvas_items; se cambió a HUD que conserva dimensiones nativas y ajusta layout. Ayuda desbordada corregida con autowrap. Cursor sobre botón de fuego al soltar fuera ahora cancela. Zoom ya no se restablece al valor anterior. ESPACIO conserva el mando de ascenso tras enfocar un botón: no activa accidentalmente aterrizaje; ENTER permite activar el botón enfocado.

Evidencia: render-quality.json/log, 10-desktop.png, 11-desktop-help.png y 12-ui-1280x720.png/12-ui-960x540.png. Capturas de maniobras 01–09 y dragon-demo.mp4. Rendimiento medido en este equipo, no extrapolado a otros.

Veredicto: passed sobre el lote y las resoluciones medidas. La evaluación visual trata un juego nativo, no el modo PRODUCT/EXPRESSIVE de ui para aplicaciones web.
