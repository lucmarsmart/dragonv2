# Cámara: superficies físicas y suavizado

Ejecutado en Godot 4.7.2, headless, con la `FlightCamera` original de `scenes/main.tscn`: **144/144**, rc=0, sin `SCRIPT ERROR`, `SHADER ERROR` ni `ERROR`. Se observaron **1845 frames en 132 ventanas**. En todos: 0 transformaciones no finitas, 0 contenciones en caja, 0 solapes de esfera de 0.2 m, 0 impactos en segmento montura→cámara y 0 impactos en segmento cámara anterior→actual.

El test congela el movimiento y la misión, conserva los cuerpos físicos activos y ejecuta el `_physics_process` y entradas originales de cámara. Usa teclas 2/3/4, rueda, clic derecho y movimientos de ratón reales. No sustituye cámara, no modifica código productivo, máscara 3 ni margen 0.8 m.

- Muro físico layer 2: aproximación frontal con suavizado, vistas laterales, recorrido paralelo de 48 m, zoom y 120 pasos de órbita libre, retorno automático. Margen frontal medido **0.80000019 m**.
- Control negativo: una `Camera3D` finita dentro del muro produce contención, solape y segmento bloqueado; el instrumento la rechaza.
- Segundo control: con vista frontal asentada y cámara deliberadamente dentro, el lerp sin el segundo rayo daría z=**0.421329**, dentro de la caja. El primer frame productivo entrega z=**1.79999995**, sin contención, solape ni segmento bloqueado. Esto ejerce explícitamente el rayo posterior al suavizado. El desplazamiento intencional del control negativo se excluye del sweep positivo.
- Retirada del obstáculo: recupera la distancia elegida (24 m) sin cambiar cámara o máscara.
- Fortaleza real: trimesh del `wall_thick_straight_01` importado, identificado por la identidad de malla compartida, padre `SiegeEnvironment` y layer 2. Se ejercen frente, lateral y regreso durante suavizado. Distancia física final **13.1463 m** frente a distancia solicitada **22 m**, sin las cinco clases de violación. La sonda permanece por debajo del muro, no pasa sobre él.

La consulta independiente usa las mismas superficies layer 1/2 y máscara 3 que el juego. La esfera de 0.2 m es una verificación de espacio próximo de cámara; no representa un volumen convexo de todo el frustum. El interior de una malla cóncava se controla con segmento montura→cámara y proximidad a superficies; sólo la caja de calibración dispone de contención analítica. Es una regresión determinista de colisión, no un benchmark nativo ni una captura visual.

Los rojos conservados corresponden a configuración de fixture: altura de primera sonda sobre el muro, expectativa de mínimo zoom 5 m en vuelo (el comportamiento actual es 7 m), y nombres automáticos de módulos duplicados. El runtime no presentó un bug reproducido ni recibió cambios.

Comando:

```sh
./tools/godot.sh --headless --path . --script scripts/test_camera_surfaces.gd > docs/validation/v2/camera-surfaces.log 2>&1
```

Hashes SHA-256:

- Cámara: `2e737f1c4e1f26bb93b9b899421818d3c810dca44d1f99a598a05f19c3001abc`.
- Entorno: `b11a6fc0303ce458171aa147ed92178ceca743d22a280442b33f180f02be8606`.
- Driver: `4a99c185215756d5e433753d051e900e3c3b257985cdc137d9cc5885a9151278`.

Datos completos en `camera-surfaces.json`, log en `camera-surfaces.log` y recibo en `camera-surfaces-run.json`. Root debe integrar el driver al launcher y repetir sobre fuentes congeladas; estos archivos registran esta ejecución de desarrollo.
