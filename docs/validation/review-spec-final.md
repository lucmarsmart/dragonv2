# Revisión focalizada de cierre — FINPASS

Estado revisado: `161070425ce3dbd3905487d48901826fde76c59d` + working tree, incluyendo las correcciones de gait, barrido de fuego, identificación del collider y reinicio de partículas. Fuente de verdad: `docs/plans/natural-dragon.md`. No leí `review-rules.md` ni edité código.

**Bloqueantes abiertos en este alcance: 0.** Los dos bloqueantes de `review-spec.md` están corregidos. Esta revisión focalizada no sustituye la validación visual final de E07 que ejecuta el coordinador.

1. **E03 — marcha contra obstáculo: corregido.** `dragon_controller.gd:303–315` mide desplazamiento después de `move_and_slide()`. La fase avanza por distancia horizontal efectiva y giro; una pared frontal que impide avanzar pone `current_speed` en cero. `dragon_ground_pose.gd:27–29` usa `ground_motion_speed` para decidir marcha y sentido. Las sondas de pies sólo consultan terreno, máscara 1, y dejan de escoger troncos como suelo. La prueba negativa de pared mantiene posición, velocidad y fase estables durante 30 ticks después del contacto; pasó tanto en mi ejecución focalizada como en la aceptación final. Avance, reversa, sprint, giro y despegue siguen pasando.

2. **E04 — tronco lejano fuera de los rayos: corregido.** El radio ahora incluye apertura de llama de 7°, tarjeta y apertura de brasas de 13°; el solapamiento inicial se consulta antes del cast. Una sonda independiente con Godot real, sin terreno ni otras colisiones, detectó el cilindro de radio 0,32 m a 20 m y desplazamiento lateral 2,70 m: impacto a **19,730 m**. Al retirar el cilindro, el aire vacío devolvió `impact_active=false`, alcance 26 m. La suite final traslada los casos de troncos a aire despejado y compara `hit_collider_id` con el objeto concreto, evitando un falso positivo por suelo.

3. **Efectos colaterales comprobados.** El barrido es conservativo: sobre un suelo plano y con soplo horizontal, una boca a 3 m limita el alcance a 6,5 m; a 4 m, a 13 m; a 5 m, a 19,5 m. Esto permite contactos anticipados y alcance escalonado. No demuestra un incumplimiento del contrato, que no fija precisión volumétrica ni alcance mínimo. En el estado terrestre real de la aceptación medí boca a 6,32 m sobre la colisión local y alcance completo de 26 m, sin impacto. No apareció una regresión bloqueante de uso terrestre. Mantener documentado este compromiso.

El reinicio de llamas, humo y brasas al perder el impacto o cambiar bruscamente su plano elimina las partículas que podrían reaparecer detrás del plano anterior. La prueba de retirada de obstáculo y traslado a aire claro verifica que aumenta `effect_resets`; pasó. Esto verifica la política de limpieza, no la apariencia de cada partícula.

Evidencia: `docs/validation/acceptance.log` y `acceptance.json` finales registran **53/53**, sin fallos; el coordinador ejecutó la suite final. Mis dos ejecuciones independientes fueron `./tools/godot.sh --headless --path . --script /tmp/dragon-focus-review.gd` y `./tools/godot.sh --headless --path . --script /tmp/dragon-isolated-breath-review.gd`, ambas exit 0, Godot **4.7.2 stable oficial**. Sus salidas se conservan en `review-spec-focus.log` y `review-spec-isolated-breath.log`.

Límite: el error de IK mide convergencia del hueso a su objetivo, no contacto exacto de cada garra. La recomendación visual previa sobre pendientes permanece como límite observacional, sin un defecto nuevo demostrado en esta ronda.

Huella SHA-256 de fuentes revisadas:

```text
9ec0bd7f46d1fa46a4e43278396976dbfde0259b061c584e0f23f564bddb06c9  scripts/dragon_controller.gd
642caef2d66b52ff3844c2c8b6b325d8da3e3aac5319520e8cc010f840d4bd5b  scripts/dragon_ground_pose.gd
2c0d95d388f65a4f56099e5df8c98e1fb762bb05731ff7f2a853368bd66df122  scripts/dragon_breath.gd
d0f7eb73334dacdaf741f8c06293756f49d33c4c77dafdbbd352977e3d26a589  scripts/test_dragon_acceptance.gd
```

**Idea 10x, ~2x esfuerzo:** añadir una sola secuencia renderizada lateral que combine choque frontal, giro en pendiente, tronco lejano, apagado y giro; guardar posición efectiva de pies e ID del impacto junto a los frames.

FINPASS
