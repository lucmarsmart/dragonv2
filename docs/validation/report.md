# Verificación — 4 octubre 2026

Se ejecutó Godot oficial 4.7.2 en macOS/AppleM5, renderer Metal Mobile. No se delega la primera prueba al usuario. El juego se importó, ejecutó y recorrió con controles reales y simulación reproducible, se inspeccionaron capturas y se grabó vídeo continuo del renderer.

## Cambios observables

- E01: velocidad con inercia/aceleración acotada; subida sincroniza cabeceo y batido; picada compacta alas y gana rapidez. Frenar no produce marcha atrás aérea.
- E02: solo suelo transitable completa aterrizaje; paredes no cuentan. Aproximación desde agua busca suelo seco. Orilla frena marcha para evitar caminar sumergido. Despegue gradual y recuperación en el perímetro.
- E03: cuatro cadenas articuladas con CCD y contactos en coordenadas mundo. Paso por distancia, giro lento con pasos adaptativos, alas estables en reposo. El GLB solo trae clips de vuelo; esta marcha es procedural.
- E04: F y botón mantenido; emisor en la punta real del hocico tras modificar la postura; cuello guía la exhalación y mandíbula abre. Capas de fuego/humo/brasas, luz y audio local. Recurso recuperable, rayos y barridos volumétricos de oclusión y recorte contra distancia/plano físico de impacto. Funciona en tierra y vuelo.
- E05: suelo/roca PBR2K CC0 con mipmaps, río/bancos sinuosos colisionables, costa y cordillera, 6500 árboles con agujas/viento/LOD, 500 rocas, hierba, cielo con nubes y bruma. Pool cercano acotado192troncos+64rocas da colisión a los obstáculos sin crear 7000 cuerpos. El fuego detecta estas capas.
- E06: cámara estable, zoom persistente, colisión con terreno/props, HUD español y ayuda, targets y foco verificados en dos resoluciones.

## Evidencia

`acceptance.log/json`: 53/53 comprobaciones sobre ticks reales del motor; incluye GUI, teclado (incluido ESPACIO con foco en aterrizaje), tronco fino entre rayos y tronco lejano fuera del eje, marcha bloqueada por pared, oclusión, agotamiento/recuperación, caminar/correr/reversa/girar, tierra/pared/agua, despegue/perímetro y cámara. No se invoca manualmente _physics_process sobre el procesamiento automático. Al fallar un check la suite devuelve exit1.

Máximo cambio vectorial de velocidad en vuelo0.467m/s por tick60Hz; contacto vertical de aterrizaje1.4m/s; error del solver IK en aceptación <1cm. Suite extendida de locomoción: marcha150ticks+giro90ticks en pendiente real, error máximo5.4mm y deslizamiento máximo9.1mm por tick en fase de apoyo (registrado dentro del SkeletonModifier, donde existe la pose renderizada). Fuente: locomotion-regression.log.

`render-quality.log/json`: render GPU real, botones y foco1280×720/960×540 sin fallos. Última sonda de escena completa:120FPS después calentamiento, 75drawcalls, ~2.30Mprimitivas. CPU physics3.39ms. Sonda de entorno fija independiente119.36FPS. Son mediciones en AppleM5 con estas vistas; no garantía para todo hardware/escena.

`render.log`: recorrido renderizado normal/subida/picada/fuego aéreo/aterrizaje/marcha/fuego terrestre/despegue/ayuda. Vídeo60FPS, 1425frames/23.75s; se inspeccionan también secuencias consecutivas y capturas del bosque/suelo. `dragon-demo.mp4` es salida real del motor, no una ilustración del resultado.

Comandos reproducibles: `./VALIDAR_DRAGON.command`; `./tools/godot.sh --path . --script res://scripts/test_render_quality.gd`; `./tools/godot.sh --path . --script res://scripts/capture_acceptance.gd --write-movie /tmp/dragon-demo.avi --fixed-fps 60`.

## Límites

No hay animación de marcha creada por un animador ni simulación fisiológica certificable de una criatura ficticia. El contacto usa cuatro cadenas del rig original. El error IK mide el hueso de muñeca/tobillo contra su objetivo calibrado; no certifica apoyo de cada vértice de garra sobre todas las pendientes. La detección del fuego usa cuatro barridos esféricos conservativos del volumen de partículas: puede recortar el chorro antes del núcleo cerca de superficies laterales o del suelo. Al cambiar el plano se reinician partículas residuales para evitar su reaparición detrás del obstáculo. El fuego impacta y produce efecto/luz, pero no incendia persistentemente ni destruye vegetación. El follaje se representa con tarjetas alpha y LOD; colliders cercanos cubren troncos y rocas, no cada aguja/ramita. No se probó Windows ni otro hardware. No se publica, exporta ni modifica el GLB original.

Corrección de materiales: el GLB exportó IOR1000, que volvía metálicas las alas. Se normalizó la respuesta especular de piel y se aplicó el normal map secundario con UV2/reconstrucción RG, sin reescribir el GLB. Capturas posteriores muestran piel orgánica sin el destello azul/plata. Audio/teardown se libera y espera antes de salir: aceptación, locomoción y render final se revisan sin errores nuevos.

Revisión independiente de spec: la primera ronda encontró2bloqueantes (marcha contra obstáculo y radio insuficiente del fuego), reparados con regresiones. La revisión final focalizada y la revisión aislada de reglas se guardan junto al manifest de archivos.

Cierre: ambas revisiones independientes FINPASS sobre los cambios finales (review-spec-final.md y review-rules.md). Captura final 01–09 regenerada después de reparar los bloqueantes e inspeccionada en secuencias de subida/picada/marcha/despegue y fuego terrestre. Aceptación53/53, locomoción y entorno0fallos; logs finales revisados sin ERROR/WARNING. Fuente registrada en manifest.json; cambios aislados en codex/natural-dragon, sin commit/push/publicación.
