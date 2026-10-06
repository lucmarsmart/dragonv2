# D05: adquisición y ataques con IA activa

Ejecutado en Godot **4.7.2.stable.official.ed1daf0bf**, headless: **11/11 controles**, código **0**, sin `SCRIPT ERROR`, `SHADER ERROR` ni `ERROR`.

```sh
./tools/godot.sh --headless --path . --script scripts/combat/test_active_ai_los.gd
```

El fixture carga `scenes/main.tscn` y comienza la misión mediante un evento real **Enter**. Selecciona un caballero normal y una ballista existentes, con sus modelos importados y el script de IA de producción. Sólo el actor seleccionado conserva `_physics_process` activo; se desactivan los demás y se retiran sus proyectiles anteriores para atribuir inequívocamente el daño. No se llama a funciones de disparo o daño, ni se crean virotes desde el fixture.

El dragón conserva su collider real y se fija como objetivo `GROUNDED`, con velocidad cero y física del controlador/fuego detenida. Se retira la gracia inicial. Esto aísla la oclusión del movimiento, apuntado del jugador y transición de locomoción; **no sustituye la partida completa ni valida FPS o gráficos**.

La pared es un `StaticBody3D` de capa **2**, caja de **80 × 20 × 1 m**. Su anchura impide que el patrullaje normal salga lateralmente de la oclusión durante la ventana observada. Los negativos observan 360 frames con IA activa y cooldown inicialmente cero. Para cada positivo se elimina **únicamente la pared**; no se recoloca ni reinicia el enemigo, su pose, cooldown o estado.

| Actor | Montaje reproducible | Negativo | Control positivo después de retirar la pared |
|---|---|---|---|
| Caballero | Enemigo `(300,24.05,130)`, dragón `(300,28.1,135)`, pared `(300,32,132.5)` | **360/360** frames activo; LOS 0; `patrol` 360; persecución, windup, golpes y daño **0** | **540/540** frames activo y LOS visible; `chase` 321, `windup` 219; **3** golpes de IA, **3** eventos de daño, **21 HP** perdidos |
| Ballista | Enemigo `(300,24.05,130)`, dragón `(300,28.1,155)`, pared `(300,32,142.5)` | **360/360** frames activo; LOS 0; `idle` 360; windup, avisos, virotes y daño **0** | **660/660** frames activo, LOS visible y pivote apuntando; `windup` 150, `reload` 510; **3** virotes de IA, **2** avisos observados, **2** eventos de daño, **36 HP** perdidos |

Los tres frames de asentamiento después de retirar la pared ocurren antes de la observación positiva: el primer aviso de la ballista puede comenzar ahí; la tabla cuenta sólo los avisos dentro de la ventana medida. Ningún disparo puede completarse en ese intervalo de 0.05 s, dado el windup de producción de 0.85 s.

Las aserciones principales observan estado real de la IA, contador real de ataques/virotes, hijos vivos de `Projectiles`, eventos de daño y salud. La consulta adicional a `_line_of_sight` sirve como diagnóstico de visibilidad, no como sustituto de esos efectos. La prueba registra que la IA seleccionada continúa activa en **cada** frame de ambos negativos y positivos.

Evidencias: `active-ai-los-headless.log`, `active-ai-los.json` y `active-ai-los-run.json`. El recibo conserva comando, versión, código, errores y SHA posteriores de fixture, runtime y modelos; **no afirma un enlace antes/después** que no se registró en esta ejecución de desarrollo. El launcher final puede reproducir el fixture y enlazar sus SHA antes/después junto al resto de la aceptación.

No se modificó el runtime ni ningún umbral de gameplay.
