# Movimiento, puntería y fuego simultáneos

El driver `scripts/combat/test_simultaneous_controls.gd` ejecuta seis ventanas de 120 ticks con el controlador, modelo, modificadores de esqueleto, emisores y colisiones de producción. Envía eventos reales de teclado y ratón; `manual_input_override` y `manual_override` permanecen desactivados. No llama a `walk_forward`, `set_head_aim`, `set_firing` ni a métodos de daño. Las únicas colocaciones/reset ocurren antes de cada ventana.

Comando de desarrollo ejecutado:

```sh
./tools/godot.sh --headless --path . --script scripts/combat/test_simultaneous_controls.gd
```

Resultado: **44/44 comprobaciones, código 0, sin errores de script/shader/engine y sin cambios de los 18 archivos de fuente/modelo/shader/configuración vinculados durante la ejecución**. Recibo: `simultaneous-controls-development-run.json`; métricas completas: `simultaneous-controls.json`; log: `simultaneous-controls-development.log`. Estos archivos describen su ejecución concreta; el launcher final debe repetirla si cambia una dependencia.

| Entradas mantenidas simultáneamente | Resultado en 2 segundos |
|---|---|
| T activo + W + ratón + F | Avanza 13,5 m; yaw corporal 0° mientras cambia la cabeza |
| T activo + A + flecha derecha + F | Gira el cuerpo +76,87° y orienta la cabeza por separado |
| T activo + S + ratón + F | Retrocede 8,475 m |
| T activo + S + D + flecha izquierda + F | Recorre 8,475 m hacia atrás siguiendo el rumbo real y gira −76,87° |
| T activo + W + A + ratón + F en vuelo | Recorre 47,586 m y gira +230,616°; conserva estado FLYING |
| T activo + W + ratón + clic izquierdo | Avanza 13,5 m y dispara sin interrumpir el movimiento |

Las seis ventanas registran **120/120 ticks con los controles mantenidos, puntería independiente y fuego activo**, 120/120 con los tres emisores de fuego activos y consumo de combustible de 0,38. El cambio de orientación de la cabeza respecto del cuerpo supera 8° en cada ventana. La boca final permanece unida al extremo del hocico y el eje del fuego coincide con la cabeza final: error medido 0 m / 0°. Al liberar teclas y botón, cesa el fuego solicitado y se liberan los controles.

El primer rojo, conservado como `simultaneous-controls-yaw-wrap-oracle-red.json` y `.log`, fue un error del oráculo: el endpoint de un giro de +230,6° se normalizaba a −129,4°. La corrección integra los cambios reales de yaw por tick; no cambia el juego.

El fixture es un plano físico transitable de 500 × 500 m a cota 200 m. No hubo contacto predictivo, bloqueo de giro ni bloqueo de orilla en sus ventanas. Esto separa la lectura de controles del atasco comunicado junto a la muralla: ese atasco necesita su regresión específica de geometría/contactos. Esta prueba headless no certifica imagen renderizada en GPU, FPS ni daño a enemigos; `test_siege` y los recorridos nativos cubren esos aspectos por separado.
