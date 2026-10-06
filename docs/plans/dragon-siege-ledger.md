# Ledger de criterios — Dragon v2

Contrato literal:`dragon-siege.md`; C0:`dragon-siege-c0.md`. Todo el alcance D01–D10 está asignado a integración final; ninguno se difiere a otro slice. `Con evidencia` no equivale a `cubierto`: la cobertura final corresponde al gate adversarial C3. Revisor de spec por Codex CLI y revisor de reglas separado revisan el mismo snapshot inmutable.

| ID | Implementación | Comprobación/evidencia | Estado previo a C3 |
|---|---|---|---|
| D01 | dragon_ground_pose, dragon_skeleton_modifier, dragon_pose_probe, dragon_wing_contact | test_dragon_anatomy; rojo piel, negativo, pendiente y terreno real; anatomy-report y vídeo de aterrizaje | Con evidencia; pendiente C3 |
| D02 | dragon_ground_pose, dragon_head_pose, dragon_controller, HUD, breath_modifier | Strict skin de garras, zancada,4aimtargets, idle/neutral; vídeo marcha; UI T/flechas y fuego/LOS | Con evidencia; pendiente C3 |
| D03 | assets/characters, assets/siege, assets/environment; siege_enemy, siege_environment | Fuente/autor/licencia/checksums; visual-gate, capturas cercanas y créditos | Con evidencia; pendiente C3 |
| D04 | terrain, scenery_collisions, siege_environment, main, project.godot | verify_siege_environment; benchmark_siege activo60s/1280, objetivo60FPS/p95≤25ms | Benchmark final89.773 FPS/p95 13.698 ms; misión final71.873/15.617. Todas las fases y escape pasan; pendiente C3 |
| D05 | siege_enemy, siege_projectile, siege_combat, dragon_breath | test_siege19casos, Input real fullmission; LOS, muerte por proyectil, retry | Con evidencia; pendiente C3 |
| D06 | siege_ui, HUD, siege_combat | UI1280/960; teclado/foco/latencia, narrativa real, derrota/retry, secuenciaVictoria | Con evidencia nativa final; pendiente C3 |
| D07 | integración real de escena/actores/controlador | VALIDAR_DRAGON.command, MovieMaker sin overrides, manifestSHA, C3dobleaislado | Launcher y misión nativa completos, victoria real sin overrides; grabación final aprobada; C3 en curso |
| D08 | dragon_skeleton_modifier, dragon_controller | Planeo20s, cuerpo0°, membranas5412 máximodiferencia0.2145m, vídeo3vistas | Con evidencia; pendiente C3 |
| D09 | terrain y shaders paisaje, escaneos/firLOD, iluminación main | Capturas tierra/aire comparadas; rechazo de laderas verdes y atlas repetido | Nuevo relieve y roca repetible inspeccionados; superficies protegidas y rayos verdes. Pendiente C3 |
| D10 | hulls alas/cuerpo/cuello; barridos físicos y cámara/fire/projectiles | Piel completa contra pared/terreno y giro parado; huevo 7/7, 7.015.222 puntos sin penetración; soportes afines | 508 cuadros/13.006.324 vértices; 79/79, vuelo dentro del mapa, todos los puntos de muros/huevo; 1.088 extremos/33 poses runtime/12 holdout; BODY19.993 caras/14 poses. Misión final verde; pendiente C3 |

No quedan publicaciones, compras, merge/push ni solicitudes de permiso pendientes. El resultado se entrega en el workspace compartido con launcher, assets y pruebas; se conserva trabajo ajeno y el PDF del usuario.

Actualización ronda2: cinco huecos de evidencia de C3r1 corregidos, sin cambios de producción. D02 per-paw24; D08 body/skin bank/recenter y4capturas nativas; D04/D10 camera144; D05 activeAI11; D06 clic nativo22,002/21,074ms. Launcher/receipts actuales y pruebas negativas pasan; detalle integration-round2.json. Benchmark85,656FPS/p9514,210ms; misión67,338FPS/p9517,013ms y todos los grupos≥60. Estado de todos D01–D10: reclamados con evidencia, pendientes de doble C3 nuevo. La película conservada coincide con todas las fuentes de producción actuales; no se atribuye una nueva grabación.

Reapertura por feedback real del jugador: D01/D02/D10 en reparación; movimiento/apuntado/fuego44/44 en espacio libre no sustituyen el caso de esquina. Rig y guardas terrestres cambiando; se requieren pruebas y grabaciones actuales y dobleC3r2 en nuevo snapshot. Los resultados anteriores son baseline.

Reapertura por referencias de esqueleto/músculos/piel y dificultad humana: D01/D02/D06/D08/D10 en reparación. Se requiere mapa del rig, cadena digitígrada de flexiones opuestas, desacoplar hombros del apuntado cervical y comprobar plegado; modo ataque sobre cabeza con una pulsaciónT, W/S+ratón+clic contra IA/HP reales. Cámara antigua sobre hombro/F y benchmark/misión anteriores son históricos desde estos cambios. No se han ejecutado revisores C3r2; campaña actual pendiente.
