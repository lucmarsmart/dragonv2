# Vuelo natural (referencia Dragontwin) — spec breve

Fuente: pedido del usuario del 15 de octubre de 2026. Referencia: video "Dragontwin Exclusive Look | New Game+ Showcase 2026" (https://www.youtube.com/watch?v=GmVc6Ym68vc, 2:22, Draconic Interactive). Objetivo: un vuelo, una física y unos ambientes más naturales y realistas, sin rehacer el juego ni copiar sus assets ni su código.

## Observaciones del video (cuadros extraídos a 2 fps)

- Aleteo lento y pesado: un ciclo completo tarda unos 2–2,5 s, con mucha amplitud. Las alas suben por encima del lomo y la punta se queda atrás respecto del brazo.
- Al planear, las alas quedan abiertas en una V suave (diedro) y la membrana se nota cargada.
- Los virajes se hacen alabeando: inclinaciones de 60–90° y el dragón gira porque inclina la sustentación, no porque rote sobre su eje vertical.
- Las picadas pliegan las alas y ganan mucha velocidad. Después, esa velocidad se cambia por altura.
- Cámara de jinete: pegada detrás del lomo, acompaña buena parte del alabeo (el horizonte se inclina), llega con algo de retraso y tiene un FOV amplio.
- Ambiente: macizos montañosos grandes con nieve, perspectiva aérea marcada (neblina azulada que aumenta con la distancia), capa de nubes por debajo de la altura de vuelo y un sol fuerte con resplandor.
- Según la prensa, Dragontwin mueve al dragón con un modelo físico y no con animaciones prefabricadas, y busca que se sienta "heavy, physical, dangerous". No hay datos públicos de su modelo de vuelo; lo que sigue es una interpretación propia.

## Criterios verificables

V-01 Energía: trepar cuesta velocidad y picar la gana (aceleración = empuje − arrastre − g·sen(trayectoria)). Si se trepa sin batir, la velocidad baja de forma medible. Una picada sostenida supera la velocidad de crucero en un 30 % o más.
V-02 Sustentación: por debajo de la velocidad de sustentación el dragón se hunde. En un alabeo la sustentación vertical cae con cos(alabeo): sin tirar del morro, un viraje cerrado pierde altura.
V-03 Viraje alabeado: A/D comandan el alabeo (hasta unos 65°) y la tasa de giro sale de g·tan(alabeo)/v. El giro llega después del alabeo, no antes.
V-04 Ritmo de aleteo: ciclo de crucero ≥ 1,9 s. El empuje se concentra en el golpe descendente (ya acoplado a la fase de la animación).
V-05 Cámara: acompaña el alabeo con retraso, mira hacia la trayectoria y no hace volteos bruscos al trepar o picar (mismo contrato que E-06).
V-06 Ambiente: perspectiva aérea visible (montañas lejanas desaturadas hacia el color del cielo), cielo con nubes procedurales y sol, y neblina de altura en los valles. Sin assets de terceros nuevos.
V-07 Sin regresiones: `VALIDAR_DRAGON.command` completo en verde. Se conservan los contratos existentes: trepada > 20 m en 3 s con vy > 8; picada > 35 m en 3 s con vy < −15 y velocidad > 32; Δv < 3 m/s por tick a 60 Hz; el freno nunca hace volar hacia atrás; el aterrizaje toca a < 5 m/s.

## Ampliación del 15 de octubre (pedido del usuario durante la ejecución)

- "Lo peor es cuando camina": en el video, el dragón camina como un cuadrúpedo pesado, con el cuerpo bajo entre las patas abiertas, el cuello extendido y bajo, la cabeza estable y las alas plegadas altas.
- "La cola tapa al dragón desde la cámara": la cámara estaba a 21,6 m detrás y a 5,4 m de altura, casi a la altura de la punta de la cola (17,4 m detrás, curvada hacia arriba +4 m). El video usa una cámara de jinete sobre el lomo.

V-08 Cámara de jinete: la vista trasera en vuelo y en tierra va a 9 m detrás de la montura y 7,5 m arriba (en tierra, 11 m y 6,5 m), con la cola fuera del encuadre. La vista sobre la cabeza queda sólo para el modo ataque. Las vistas lateral y frontal (V, 1–4) no cambian.
V-09 Marcha: la velocidad corresponde al largo de las patas (caminata 4,8 m/s y carrera 8 m/s, antes 7,5 y 14 m/s, lo que equivalía a un galope). Cada pata pasa el 24 % del ciclo en el aire (antes el 36 %: cuatro pasos sumaban 1,44 ciclos, no entraban en uno y el cuerpo avanzaba a tirones entre 0 y 5,5 m/s). Contra un obstáculo, la fase de la marcha no avanza, así que el dragón no pisa en el lugar.
V-10 Colisión de árboles: el alto y el radio del tronco salen de la malla real de cada especie. Antes, `18.96 × escala` aplicado a pinos con escala ~7,5 creaba troncos invisibles de ~180 m de alto y 4 m de radio, que frenaban al dragón en pleno vuelo hasta 7 m/s y bloqueaban la caminata.

## Evidencia

`scripts/capture_flight_feel.gd` captura la cámara real con entradas reales (crucero, viraje, trepada, picada, planeo), antes y después, y registra velocidad, vy, altura, cabeceo y alabeo. `scripts/test_flight_physics.gd` verifica V-01 a V-04 con ticks reales.

## Límites

No se replica el juego de referencia. La física es arcade-simulada: no hay CFD ni aerodinámica real de membranas. No se mide rendimiento fuera del Mac de desarrollo.
