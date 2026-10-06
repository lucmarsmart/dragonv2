# D02/D08: cierre de cobertura C3, 2026-10-05

Cambio exclusivo en `scripts/test_dragon_anatomy.gd`: nuevo modo `--locomotion-contract`. El runtime y los 1.088 extremos de ala conservan sus SHA del receipt anterior. Las pruebas previas, sus umbrales y su geometría permanecen; este modo agrega 24 aserciones. No hay nuevo driver `.gd` que añadir al audit. Root ya incorporó el flag al launcher.

Comando: `./tools/godot.sh --headless --path . --script scripts/test_dragon_anatomy.gd -- --locomotion-contract`.
Resultado de la ejecución autónoma: **rc0, 24 PASS, 0 FAIL, sin errores de script**. `--check-only` rc0 y log limpio. Fuente del test congelada: `af087672eacee898a91ed87502b3aca1fe38a76f8278154ee618578c73c0a4bc`.

## D02: cuatro patas, no un conjunto mezclado

Tras estabilizar la postura y excluir aceleración, se elige un vértice original de piel de cada pata. Se observa la transición swing→stance; la primera llegada sólo siembra el ancla y se descarta como paso inicial incompleto. Cada evento posterior contiene sus dos posiciones mundiales, ticks físicos, zancada longitudinal, recorrido real del actor y velocidades mínima/máxima de los intervalos observados. El mismo vértice se conserva durante toda la ventana.

Cada pata debe aportar al menos cuatro ciclos completos; **todos** sus ciclos completos deben alcanzar 2 m, con velocidad real 7,5±0,05 m/s. El medidor divide el desplazamiento observado por los ticks físicos realmente transcurridos; no utiliza `current_speed`, la velocidad pedida ni presupone un tick por callback. La ventana resultó de8s/60m a7,5m/s.

| Pata/bone | Ciclos completos | Zancada mínima | Velocidad real | Vértice original |
|---|---:|---:|---:|---|
| Bip001-L-Foot_0118 (8) | 16 | 3.375004 m | 7,500000 m/s | Object_8:15578 |
| Bip001-R-Foot_0133 (23) | 16 | 3.374992 m | 7,500000 m/s | Object_8:16941 |
| Bip001-L-Hand_040 (41) | 16 | 3.375004 m | 7,500000 m/s | Object_8:10963 |
| Bip001-R-Hand_055 (82) | 16 | 3.375000 m | 7,500000 m/s | Object_8:11427 |

Se descarta una llegada inicial incompleta por pata: 64 ciclos completos medidos, 16 por pata. El final parcial no genera un evento ni puede aprobar por sí mismo.

El rojo lógico `anatomy-stride-pooled-logic-red.json` conserva cuatro pasos de3,5m de una sola pata y cuatro de1m para cada una de las otras: la aserción antigua acepta; la nueva rechaza las tres patas cortas. Es una demostración del hueco de aserción, no un bug de locomoción observado.

## D08: bank publicado y soltar desde un viraje real

Una única colocación aérea inicial permite estabilizar planeo. Desde ella se ejecutan izquierda durante120ticks→soltar180ticks→derecha120ticks→soltar180ticks. Entre fases sólo cambia el mando; no se reinicia `rotation`, `target_roll` ni la pose para declarar recuperación.

El callback final de SkeletonModifier registra cada frame publicado, incluso si comparte tick físico con otro render: 1.291 poses, todas FLYING. Lee `dragon.rotation.z` efectivo y el eje lateral entre dos vértices originales del torso con influencias de skin idénticas, recalculados mediante skinning independiente. Retira yaw y el sesgo inicial de ese eje; no lee `target_roll` como oracle. El eje mide 2.316264m y usa `Object_8:6193` / `Object_8:6273`.

| Medida | Izquierda | Derecha |
|---|---:|---:|
| Roll del cuerpo al acabar giro | +26,926° | −26,868° |
| Roll del eje de piel al acabar giro | +26,644° | −26,586° |
| Máximo cambio cuerpo/frame publicado | 0,550641° | 0,551241° |
| Máximo cambio piel/frame publicado | 0,548297° | 0,549169° |
| Cuerpo/piel al1s de soltar | +5,744°/+5,743° | −5,739°/−5,739° |
| Primera recuperación de ambos a±2° | 1,45s | 1,45s |
| Cuerpo/piel al final (~3s) | +0,043375°/+0,043792° | −0,043302°/−0,043002° |

Los límites operativos son bank congruente de al menos5°, cambio≤5° por frame publicado, soltar desde bank≥5° y recuperación de cuerpo/eje de piel a±2° dentro de3s. **A1s aún hay~5,74°**: el informe no afirma recenter de bank en1s. Se conservan negativos que rechazan mando sin bank publicado, bank permanente tras soltar y un salto instantáneo de50°.

## Evidencia y límites

`anatomy-locomotion-contract-standalone-green.json` y `anatomy-locomotion-contract-green.log` son la ejecución autónoma preservada; `anatomy-locomotion-contract.json` es la salida operativa que el launcher puede reescribir. El receipt específico vincula SHA de fuentes y artefactos. Las poses/valores exactos están en JSON, no sólo en esta tabla.

Los rojos de desarrollo quedan explícitos: `time-oracle-red` usaba desplazamiento×60 y produjo22,5m/s en un intervalo de3ticks; `axis-fixture-red` asumía vértices pure-pelvis que este mesh no contiene; `parse-red` fue una llamada incorrecta a un método de instancia. Son errores de implementación del test, corregidos antes del freeze; no se les atribuye un defecto del juego.

Esta nueva evidencia es headless con física60Hz en suelo plano y aire libre. No mide FPS/GPU ni añade una captura visual nativa. No prueba todas las fases posibles de gait/bank; las suites previas siguen cubriendo colisiones, apoyos, terrenos y geometría. Root ejecuta después el launcher y gates nativos integrados sobre la fuente congelada.
