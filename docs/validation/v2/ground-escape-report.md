# Retirada y giro junto a la fortaleza real

Estado del corredor: prueba headless real aprobada (`rc0`, 15 comprobaciones), con fuentes invariantes. La certificación global de geometría y la ejecución nativa las realiza la integración; esta pasada no acredita FPS, calidad visual ni IA activa.

## Causa y corrección

La reproducción legal inicia en `(215, altura real + 4, 205)`, se asienta grounded y mantiene libres los 18 hulls. Luego observa exclusivamente teclas reales W/S/A/D con `Input.parse_input_event`, sin `manual_input_override` ni teletransporte. El guard anterior dejó que una articulación posterior al barrido introdujera ala/pata en la esquina suroeste concava: W avanzó 3.375 m y S/A/D quedaron en cero con `nonconvex_overlap_requires_clearance`. `ground-escape-flat-approach-red.log` conserva esa reproducción. Diagnósticos que iniciaban dentro de la esquina o en una ladera excesiva no cuentan como aproximación legal.

La compactación por sí sola tampoco bastó: `ground-escape-bisect-1855-red-*` conserva W7.653 m, S0 y bloqueo posterior tras A66.27°. Su apoyo/piel sí pasaban; el ala intersectaba la esquina 4.309 mm. Se conservó la negativa a barrer desde overlap concavo y se corrigió la articulación.

- La pertenencia alar sigue las ramas importadas96/120. Los originales de una cara que conecta ambas ramas se duplican en ambos hulls. No cambia al cruzar X=0.
- El guard conserva únicamente quaternions de cada rama alar, cuando su hull final está libre. Restaura esa rama bajo el root real actual y revalida. Si cambió el parent, compensa la orientación del root alar respecto del actor; si hace falta, pliega gradualmente hasta4° alejando el contacto con un eje `lever×normal`. Los frames publicados tienen límite mundial4°.
- El guard no escribe posiciones, spine, patas, cabeza ni visual_root. Conserva los targets/IK de apoyo y el apuntado libre de ese tick. No existe fallback global.
- El barrido se detiene conservadoramente1mm antes del impacto para tolerar redondeo float32. Conserva hulls, capas, márgenes, superficies, Y fija, recast y rechazo concavo original.

## Evidencia final del corredor

`ground-escape-final-stable-1855.log`, `ground-escape-final-stable-1855-trace.json` y `ground-escape-final-stable-1855-metrics.csv` preservan el resultado. Los nombres canónicos `ground-escape-trace.json`, `ground-escape-skin.json`, `ground-escape-metrics.csv` se regeneran al ejecutar el driver.

| Observación real | Resultado |
|---|---:|
| W hacia la esquina / S de retirada | 7.895 / 10.936 m |
| A inicial contra obstáculo | 1.721° limitado físicamente |
| D después de retirar / A de retorno | 159.085 / 77.528° |
| W / S después de ambos giros | 6.566 / 6.147 m |
| Frames finales grounded | 1.176 / 1.176 |
| Originales evaluados contra terreno | 30.109.128 = 25.603 × 1.176 |
| Peor piel frente al terreno | −8.260 mm, dentro del contrato existente5cm |
| Peor deslizamiento de garra en apoyo | 4.179 mm, dentro del contrato existente15mm |
| Overlaps de obstáculos mask2, todas18 piezas cada frame | 0 |
| Paso angular máximo alas / cabeza | 0.999 / 4.000° |
| S + T + ratón + F coexistentes | 180 frames |
| Objetivos independientes de cabeza | +15.000 / −15.000° |
| Error final del fuego, posición / dirección | 0 m / 0° |
| Recuperaciones alares / pliegues / sin despejar | 244 / 4 / 0 |

A inicial queda limitada por la geometría; A de retorno demuestra giro libre después de retirarse. No se promete girar a través del muro. La punta de cola `Object_8:4783` llegó8.26mm bajo la superficie real, confirmado también por rayo físico: esta prueba acredita el contrato5cm, no penetración universal cero.

Los vértices y garras se observan en `modification_processed` del último `SkeletonModifier`, una vez por frame físico y continuamente entre acciones. El terreno consultado comparte la triangulación barycentric exacta del collider; el peor vértice se contrasta además con un rayo físico. AI enemiga desactivada y grace1000 aíslan esta regresión de movimiento; la IA requiere su propia validación.

El nuevo oráculo experimental que exigía cero overlap de cualquier hull resultó más estricto que el contrato de piel5cm: un hull conservador de cuerpo toca terreno durante retirada, con piel final medida dentro del contrato y movimiento posterior válido. Se preserva `ground-escape-wing-fold-zero-overlap-red-*`. El oráculo final exige cero overlaps contra obstáculos mask2 y evalúa TODOS los originales frente al terreno cada frame, sin modificar los casts físicos de terreno, las tolerancias5cm/15mm ni el requerimiento de retirada posterior al giro.

## Candidatos rechazados y errores de diagnóstico

El fallback global experimental restauraba rotaciones locales antiguas bajo un root nuevo y borraba el IK actual: penetración real de cola6.365cm y slide59.3cm. Se eliminó completamente del runtime. Se conservan `ground-escape-rejected-guard-source.gd.txt`, `ground-escape-full-guard-real-red-*` y `ground-escape-final-modifier-1108.log`.

El primer oráculo fuera de `SkeletonModifier` veía animación base restaurada; su aparente penetración1.283m no era piel final. Se conserva `ground-escape-stale-skeleton-red-*` como error de medición. El primer guard sólo alar usó por error `rest_basis.inverse()` al convertir la orientación; esa fórmula no corresponde a pose local respecto del parent en este rig. Se conserva `ground-escape-wing-rest-basis-red-*`. La compensación correcta sin pliegue aún dejaba2.98mm y bloqueo: `ground-escape-wing-body-relative-red-*`.

El helper de paridad `ground-escape-skin-verifier.py` es sólo diagnóstico: la malla de esquina real tiene332 aristas abiertas/no manifold, por lo que no permite una afirmación de volumen cerrado. No se presenta como prueba independiente de penetración cero.

## Ejecución y límites

Headless:

```sh
./tools/godot.sh --headless --path . --fixed-fps 60 --script scripts/combat/test_ground_escape.gd
```

Capturas nativas (integración conserva la lease GPU):

```sh
./tools/godot.sh --path . --fixed-fps 60 --script scripts/combat/test_ground_escape.gd -- --capture-ground-escape
```

Esta es una secuencia finita de regresión en la esquina real, con fixture explícito. No acredita geometría global de todas las animaciones, FPS, GPU, IA ni una partida completa. La selección1855 usada aquí queda sujeta a construcción densa/holdout independiente de anatomía y al rerun de integración. Tras freeze, integración debe ejecutar las regresiones previas de body-contact, foot-yaw, locomotion-contract y real-terrain/body-terrain, además de este corredor y captura nativa.

## Fuentes enlazadas

Se verificaron17 hashes antes/después iguales (runtime, driver, escena, modelo/importación). JSON conserva la lista completa. Principales SHA256:

- `res://scripts/combat/test_ground_escape.gd`: `95785291f0f59a1420291cdb0ee8a7535bd6e0b8774d9418c2f1a99aaf8f1556`
- `res://scripts/dragon_wing_contact.gd`: `b658afdfd6dd9875f13ecf07951abcab0dfda05d4f6f685e2a0f538eb4709c74`
- `res://scripts/dragon_ground_contact.gd`: `d32898ac30ea9d3abb9c1fb40dac3bcbd2c30c7ad51386144c3eb215f68254e0`
- `res://scripts/dragon_ground_pose.gd`: `258ea0da74f81a86a7456ce624ad003cee6d6f4d779e213c4aee85928fc5d1e2`
- `res://scripts/dragon_controller.gd`: `72ba92ce1745d2b838f2ece3064a658e454362d5c6c3911f96aa0ccde9ef33c9`
- `res://scripts/dragon_pose_probe.gd`: `234e2cf33afee4956f30f55acdbe5ddd54d554fb6c7ced804528da68362efeaf`
- `res://scripts/dragon_wing_extrema.json`: `eb13212defa06dff530e0a8a82f96c063359ef45eb7d007b50ef1a5db8509bd6`
