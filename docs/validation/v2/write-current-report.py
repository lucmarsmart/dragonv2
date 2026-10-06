"""Present current measured results, keeping prior campaigns explicitly historical."""
import json
import re
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
V = ROOT / 'docs/validation/v2'
def read(name): return json.loads((V / name).read_text())
for name in ['launcher-final-run.json', 'native-gates-run.json', 'playthrough-native-final-run.json',
             'playthrough-metal-final-run.json', 'user-feedback-native-run.json', 'anatomy-enclosure-final-run.json']:
    assert read(name)['passed'], name
manifest = read('anatomy-manifest.json')
metrics = manifest['metrics']
bench = read('combat-performance.json')
mission = read('playthrough-native-report.json')
movie = read('playthrough-metal-report.json')
perf = mission['performance']['post_warmup_all_intervals']
escape = read('ground-escape-trace.json')
descent = read('anatomy-descent-compact-candidate.json')
mouth = read('anatomy-mouth-report.json')
terrain_reports = {name: read(name) for name in ['terrain-player-escape-500-450.json', 'terrain-player-escape-850-130.json', 'terrain-player-escape--450-220.json']}
air = read('air-contact-escape.json')
player = read('player-aim-feedback.json')
camera = read('camera-surfaces.json')
feedback_receipt = read('user-feedback-native-run.json')
current_sources = read('launcher-final-run.json')['source_files_sha256_after']
assert not mouth['failures'] and mouth['sources_unchanged']
assert len(mouth['captures']) >= 40
assert all(not value['failures'] and value['source_before'] == value['source_after'] for value in terrain_reports.values())
assert air['pass'] and not air['failures'] and player['pass'] and not player['failures']
expected_feedback = {'descent': 3, 'ground-escape': 3, 'mouth': 40, 'terrain-player-escape-500-450': 3, 'terrain-player-escape-850-130': 3, 'terrain-player-escape--450-220': 3, 'air-contact-escape': 0, 'player-aim-feedback': 2}
assert {run['name'] for run in feedback_receipt['runs']} == set(expected_feedback)
for run in feedback_receipt['runs']:
    assert run['passed'] and run['report_passed'] and run['source_files_unchanged']
    assert len(run['captures_sha256']) >= expected_feedback[run['name']]
    assert run['report_sha256'] == hashlib.sha256((V / run['report']).read_bytes()).hexdigest()
    assert all(hashlib.sha256((V / name).read_bytes()).hexdigest() == digest for name, digest in run['captures_sha256'].items())
    # Launcher fingerprints additionally include the two .command files and
    # tools/godot.sh; native receipts bind runtime/imports, not those wrappers.
    assert all(run['source_files_sha256_before'].get(path) == digest for path, digest in current_sources.items()
               if path in {'project.godot', 'scenes/main.tscn'} or path.startswith(('scripts/', 'shaders/', 'assets/')))
assert all(hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest for path, digest in current_sources.items())
mouth_run = next(run for run in feedback_receipt['runs'] if run['name'] == 'mouth')
assert all(Path(row['path']).name in mouth_run['captures_sha256'] for row in mouth['captures'])
player_run = next(run for run in feedback_receipt['runs'] if run['name'] == 'player-aim-feedback')
assert len(player['snapshots']) >= 2 and all(Path(path).name in player_run['captures_sha256'] for path in player['snapshots'])
for name, value in {'anatomy-mouth-report.json': mouth, 'air-contact-escape.json': air, 'player-aim-feedback.json': player, **terrain_reports}.items():
    declared = value.get('source_sha256_before', value.get('source_before', value.get('sources_sha256', {})))
    assert declared, name
    assert all(hashlib.sha256((ROOT / path.removeprefix('res://')).read_bytes()).hexdigest() == digest for path, digest in declared.items()), name
oral_landmarks = mouth['asset_landmarks']
oral_error = max(row['maximum_oral_error_m'] for row in mouth['cases'])
mouth_captures = len(next(run for run in feedback_receipt['runs'] if run['name'] == 'mouth')['captures_sha256'])
retreat = player['measured_retreat']
assert player['checks'] >= 16 and player['attack_mode_pulses'] == 2
assert player['legacy_head_and_simultaneous_tests_modified'] is False
assert retreat['forbidden_key_frames'] == 0 and retreat['enemy_hp_after'] <= 0
assert retreat['mouse_overflow_body_yaw_deg'] > 10 and retreat['mouse_overflow_max_requested_head_yaw_deg'] <= 45 + 0.001 * 180 / 3.141592653589793
reference = json.loads((ROOT / 'scripts/dragon_anatomy_reference.json').read_text())
assert reference['joint_count'] == len(reference['joints']) == 156
assert reference['contains_muscle_simulation'] is False
assert hashlib.sha256((ROOT / reference['source']).read_bytes()).hexdigest() == reference['source_sha256']
for path in ['docs/anatomy-reference.md', 'scripts/dragon_anatomy_reference.json', 'scripts/dragon_biomechanics.gd']:
    assert manifest['source_and_artifact_sha256'][path] == hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), path
normalization_notices = []
log_names = [read('launcher-final-run.json')['log']] + [run['log'] for run in feedback_receipt['runs']]
for name in dict.fromkeys(log_names):
    for line in (V / name).read_text(errors='replace').splitlines():
        if 'vector3' in line.lower() and 'normaliz' in line.lower():
            normalization_notices.append({'log': name, 'message': line.strip()})
normalization_note = (f"Los logs actuales registran {len(normalization_notices)}avisos del motor sobre normalización de Vector3; revisar _rotation_contact y sus consultas físicas. Se conservan en {', '.join(sorted({row['log'] for row in normalization_notices}))}. Las comprobaciones finales de puntos, props y apoyo aprobadas no demuestran que estos avisos sean irrelevantes o que el motor no tenga casos problemáticos." if normalization_notices else 'La campaña de diagnóstico conservó avisos del motor sobre normalización de Vector3 en _rotation_contact. No se encontraron líneas con Vector3/normaliz en los logs actuales del launcher y feedback; esto no acredita ausencia universal de avisos del motor.')
terrain_rows = '\n'.join(f"| Ladera {value['fixture_xz']} | W/S {value['stages']['forward']['horizontal_distance_m']:.3f}/{value['stages']['reverse']['horizontal_distance_m']:.3f}m; A {abs(value['stages']['left']['yaw_delta_deg']):.3f}°; W/S tras giro {value['stages']['forward_after_turn']['horizontal_distance_m']:.3f}/{value['stages']['reverse_after_turn']['horizontal_distance_m']:.3f}m; piel mínima {value['minimum_skin_terrain_clearance_m']*1000:.3f}mm; apoyo {value['maximum_stance_slide_m']*1000:.3f}mm; overlaps de props {value['maximum_prop_overlap_count']} |" for value in terrain_reports.values())
ui = read('ui-measurements.json')
clicks = [e for e in ui['measurements'] if e['state'] == 'start_click']
corridor_limit = ('El mínimo de piel en el corredor es negativo y se declara arriba: está dentro del contrato existente de5cm, no se llama penetración cero.' if escape['minimum_skin_terrain_clearance_m'] < 0 else 'La piel observada en el corredor mantiene separación positiva respecto al terreno. El contrato conserva el límite existente de5cm; estas muestras finitas no garantizan toda pose futura.')
groups = '\n'.join(f"| {name} | {p['frames']} | {p['fps_actual_wall']:.3f} | {p['frame_p95_ms']:.3f} |"
                   for name, p in mission['performance']['by_phase_and_locomotion'].items())
report = f'''# Validación integrada de Dragon v2

Las correcciones del descenso, locomoción en tres laderas, salida de contacto en vuelo, boca y apuntado pasan los reportes y receipts nativos actuales. Las fuentes se mantienen iguales durante las pasadas aceptadas. D01–D10 están reclamados con evidencia; la doble revisión C3 ronda2 aún está pendiente y no se presenta como aprobada.

## Cambios y causas

Las patas traseras del clip de frenado subían sobre el torso. Ahora se preparan bajo el cuerpo con rotaciones progresivas del rig original. La transición al apoyo conserva la rama de rodilla/corvejón y comparte un presupuesto angular entre todas las calibraciones; no estira ni traslada los huesos. El paso comienza en su fase local cero y termina antes de reiniciar; el reloj de recolocación parte del cuadro actual. Esto elimina el salto de objetivo de2,7m. Al resolver la pata se transporta el giro publicado sobre su eje, evitando el retorcimiento de91,6° del siguiente frame importado. La planificación de pasos se ejecuta una sola vez por cuadro, antes de resolver el IK. Durante la marcha terrestre una sola pata se levanta y las demás conservan el apoyo; durante la aproximación de aterrizaje las patas se preparan juntas. La aceleración de caminata espera a que termine el blend de apoyo existente (14ticks a60Hz); conserva la entrada pendiente y usa la fricción terrestre, sin reiniciar la velocidad ni añadir un temporizador. El giro, apuntado y fuego siguen disponibles. Los pasos pendientes se atienden por orden de espera; el arranque no pierde un turno por la fase de una corrección anterior. El tiempo de cada paso tiene en cuenta su recorrido real; el arranque conserva una velocidad mínima de recuperación de la pata y la marcha estable mantiene su ciclo por distancia, con ritmo mínimo nominal para terminar cada paso levantado normal cuando el cuerpo debe esperar.

La animación terrestre podía introducir un ala en la esquina después del barrido y bloquear W/S/A/D. Las alas se pliegan hasta 6,289 m de ancho; cada membrana conserva su identidad por las raíces96/120 del esqueleto, incluso al cruzar el centro. El guard recupera sólo la rama alar colisionante y la recoge contra la superficie. Conserva el IK y el apuntado de ese frame. En contacto casi tangente, una consulta testigo de1mm obtiene una normal estable para orientar el plegado; la aceptación sigue usando la consulta original sin margen. Los 18 hulls y las consultas de terreno/obstáculos siguen activos; no se atraviesan muros para permitir salir.

En ladera, el barrido del pie podía bloquear un movimiento que el IK todavía podía apoyar. El contacto físico usa hasta0,036m de soporte adicional, limitado por el alcance del IK; conserva los18hulls y los límites existentes de piel/apoyo. La marcha prioriza la pata cuyo alcance limita el desplazamiento y conserva al menos tres apoyos. La normal del raycast del terreno mantiene la alineación aunque floor snap falte un frame. El aterrizaje mantiene una transición amplia y suave hasta el contacto. En vuelo, la salida tangente vuelve a barrer las18piezas y conserva el guard final de las alas. Los tres fixtures terrestres y el fixture aéreo son casos finitos, con colliders activos.

El nuevo parche de aterrizaje dejó visible otra regresión: en la campaña diagnóstica la cola llegó a0,685m bajo el terreno y el segundo apoyo alcanzó16,98mm de deslizamiento. Esos resultados se conservan como rojos históricos. guard_tail_terrain anticipa el contacto antes de los guards de cuerpo: reutiliza los slots originales de soporte afín de cola dentro de BODY2 y los compara con la altura exacta del Terrain. La consulta analítica sólo se ejecuta si landscape es válido y expone ground_height; los fixtures llanos con cuerpos físicos conservan el guard ordinario de BODY sin invocar esa API. Eleva por rotación la primera raíz de cola cuando la separación baja de0,12m, con objetivo limitado a4° por tick respecto al quaternion mundial publicado. Se aplica durante LANDING por debajo de12m de proximidad y en GROUNDED; mantiene longitudes e identidades originales. La pose de cola se publica después de los guards de cuerpo/alas. Reutiliza los puntos del sample final de BODY, sin otro muestreador de piel. La reserva de anticipación no eleva el límite admitido por el oráculo: los resultados actuales de aterrizaje, segundo apoyo y ventanas continuas son los medidos en los JSON finales de esta fuente, mostrados abajo. Una pasada candidata de seis ventanas no equivale a la auditoría independiente C3.

La punta nasal se confundía con la salida oral y los índices del GLB original se confundían con el orden importado. El emisor ahora usa el punto medio de piel entre mandíbula superior e inferior más8cm en la dirección real; resuelve POSITION y hueso para los IDs originales {oral_landmarks['upper_original_glb_index']}/{oral_landmarks['lower_original_glb_index']}. El hueso nasal sólo determina la dirección. La cámara aterrizando/en tierra pasa suavemente sobre la parte delantera de la cabeza; en vuelo usa esa misma vista cuando el ataque está activo. Su objetivo inicial es boca−dirección×0,7m+UP×2,2m y conserva el volumen físico Sphere0,2m, los dos raycasts de máscara3 y el barrido entre cuadros. La ausencia de oclusión por alas o piel exige inspección de las PNG actuales, además del LOS físico. La retícula consulta LOS aun sin fuego. El shader recorta la llama al cono usado por el daño, evitando que tarjetas anchas aparenten alcanzar un soldado lateral. Alcance26m, semicono7°,48DPS y oclusión se conservan.

El refresco postjaw recalcula528puntos originales deformados por la mandíbula en la categoría3 después de su modificador; reemplaza esos slots de la envolvente publicada y conserva las demás identidades. _rotation_contact reserva3mm para el giro; _body_contact exige consultas sin margen y con3mm contra props de capa2, y margen0 contra terreno de capa1. El rojo terrain-tail-margin-red.log reproduce la misma forma contra tree1652: margen0 detecta,3mm omite y una forma nueva con0 también detecta. La consulta dual evita certificar esa postura como libre sin atribuir una causa interna al motor. La traslación GroundContact y las consultas finales independientes de las18piezas mantienen margen0. La reserva deja espacio para el estabilizador visual y el ajuste IK posteriores en contactos tangentes, y exige más separación para aceptar la pose.

Si el ajuste final hace inseguro un paso físico, el guard puede rechazarlo cuando la distancia a la pose segura anterior es≤walk_speed/physics_ticks_per_second+0,05m y el cambio angular es≤5°. A7,5m/s y60Hz, el límite es0,175m. Recupera el transform completo del actor, incluida su posición, pone velocidad y speed a0 y restaura el transform visual, todas las rotaciones FK y una copia profunda del estado de marcha publicado. Actualiza los relojes al frame físico actual para que un paso lógico no termine mientras su pose sigue rechazada; recalcula la dirección real de cabeza. La cache se toma después del guard final de alas. Es una corrección física pequeña y acotada de colisión, no una recolocación larga ni un cruce de obstáculos. Los resultados de boca abierta, las tres laderas y el contacto físico citados aquí corresponden a JSON aprobados y receipts actuales vinculados a la misma fuente final; el generador rechaza fallos, capturas antiguas o fuentes distintas antes de escribir el informe. La prueba de(-450,220) exige overlaps finales sin margen: una reserva preventiva o un SHA correcto no sustituyen ese resultado. La evidencia acredita los casos medidos y sus límites, sin extenderlos a cualquier pose futura.

El límite de alcance co-limita XYZ sobre superficie transitable: bloquear XZ sin limitar la componente vertical generaba ascenso residual en pendiente. Los objetivos de apoyo se reconstruyen desde el FK alcanzado y el residual XYZ del ancla original, incluso dentro del deadband, evitando conservar una altura inalcanzable que luego desplazaba la garra. Mantiene los umbrales existentes. La optimización posterior precalcula topología y transformación del terreno y reutiliza mediciones o consultas sólo con idéntica postura dentro de la resolución síncrona; nuevas resoluciones FK, publicación de pose/mandíbula y cambios del transform actor invalidan sus respectivos resultados. El rojo de rendimiento y el receipt nativo verde se conservan; no se reduce detalle ni geometría para mejorar FPS.

Una pulsación de T entra o sale del ataque y la tecla se suelta. W/S mueve el cuerpo, el ratón apunta y el clic izquierdo dispara desde la boca final; al continuar el mouse más allá del límite cervical±45°, el excedente gira el cuerpo. La cabeza conserva su independencia dentro del límite. El driver establece cono real, LOS y visibilidad de cámara durante12ticks con W/S+ratón; después observa S continua+ratón+clic izquierdo, sin A/D/F/T sostenida. Exige muerte del caballero real, distancia de retirada mayor que2m y giro corporal por excedente del mouse mayor que10°; no sustituye la cámara ni fuerza daño. Las pruebas anteriores de cabeza independiente y controles simultáneos permanecen intactas. La ayuda y el briefing explican esa combinación. El entorno incorpora materiales PBR, relieve de varias escalas, agua y vegetación con sombras. Knight, ballista, acantilado y farol se descargaron de repositorios GitHub reales: pins, licencias, SHA y modificaciones en assets/LICENSES.md.

La referencia [docs/anatomy-reference.md](../../anatomy-reference.md) y scripts/dragon_anatomy_reference.json documentan los{reference['joint_count']}joints originales, jerarquía, TRS, ejes y clips leídos del GLB. dragon_biomechanics.gd resuelve primero el corvejón y luego la rodilla de las cadenas posteriores, manteniendo target y longitudes; cuando no hay solución conserva el fallback. La rama de rodilla se reconstruye desde support_rotations publicado y el eje original del hijo, evitando usar como seed la siguiente clave aérea importada. HeadPose distribuye el apuntado entre cervicales superiores53/54 (pesos0,42/0,58) y cabeza55; no gira el basal37, del que dependen ambas clavículas38/79. El cierre alar se distribuye entre dígitos smoothstep(0,0.65), codo(0.08,0.82) y hombro(0.18,0.95); la apertura invierte el orden. Los guards, presupuestos angulares y contactos finales siguen gobernando la aceptación. Son proxies cinemáticos y artísticos: no hay simulación de fuerzas musculares, torque, ligamentos ni deformación volumétrica. El mapa de156joints y las comprobaciones matemáticas offline no prueban piel libre de contacto o naturalidad visual. Los resultados aceptados aquí se obtienen de los JSON y receipts actuales; los candidatos históricos de la referencia no se trasladan como cifras de la campaña final.

## Comprobaciones actuales

Godot4.7.2.stable.official.ed1daf0bf, Metal4/Forward+, AppleM5; 1280×720 y UI960×540. ./VALIDAR_DRAGON.command termina rc0 sin errores de scripts/shaders, con las suites anteriores y las regresiones nuevas. La sonda usa los 25.603 vértices originales, bind/pesos y pose publicada tras el último modificador. Los fixtures colocan sólo el inicio; la misión completa conserva AI, daño y combustible normales.

| Caso | Resultado actual |
|---|---|
| Descenso continuo de80m a apoyo+30frames | Patas debajo del torso; salto de articulación en cuerpo {descent['maximum_joint_step_deg']:.3f}° y mundo {descent['maximum_world_joint_step_deg']:.3f}°; traslaciones {descent['maximum_translation_change']:.6f}m; garras mínimo {descent['minimum_ground_claw_clearance_m']*100:.3f}cm; apoyo {descent['maximum_stance_slip_m']*1000:.3f}mm |
| Pasos posteriores al aterrizaje | Objetivo máximo {descent['maximum_walk_target_step_m']:.3f}m por tick; giro articular/eje {descent['ordinary_first_walk_joint_step_deg']:.3f}/{descent['ordinary_first_walk_axis_step_deg']:.3f}° durante marcha7,5m/s, medido separado de la transición≤5°; cuatro patas y ciclos completos individuales |
| Esquina real y recuperación | S {escape['stages']['reverse']['horizontal_distance_m']:.3f}m; D {abs(escape['stages']['right']['yaw_delta_deg']):.3f}°; A de retorno {escape['stages']['left_return']['yaw_delta_deg']:.3f}°; W/S después de girar {escape['stages']['forward_after_turn']['horizontal_distance_m']:.3f}/{escape['stages']['reverse_after_turn']['horizontal_distance_m']:.3f}m |
| Piel y apuntado en esquina | {escape['observed_final_frames']}frames finales; {escape['original_vertices_checked']:,}vértices comprobados; piel mínima {escape['minimum_skin_terrain_clearance_m']*1000:.3f}mm respecto al terreno; apoyo {escape['maximum_stance_slide_m']*1000:.3f}mm; cero overlaps de obstáculos en las18piezas |
| Retroceder+apuntar+fuego | {escape['retreat_fire_frames']}/180frames; objetivos de cabeza±15°; salida del fuego {escape['maximum_fire_mouth_error_m']:.6f}m/{escape['maximum_fire_head_error_deg']:.6f}° de error |
| Boca real | {mouth['checks']}comprobaciones; error máximo respecto al midpoint de piel {oral_error*1000:.3f}mm; {mouth_captures}capturas nativas frontales/laterales, con y sin landmarks |
{terrain_rows}
| Contacto y salida en vuelo | {air['checks']}comprobaciones; ascenso real {air['climb_height_m']:.3f}m; máximo {air['maximum_actual_overlaps']}overlaps de las18piezas contra el fixture físico |
| Retirada con enemigo real | {player['checks']}comprobaciones; S+ratón+clic izquierdo {retreat['concurrent_frames']}frames; T dos pulsaciones liberadas, una para entrar y otra para salir; A/D/F/T sostenida {retreat['forbidden_key_frames']}frames; retroceso {retreat['reverse_distance_m']:.3f}m; HP enemigo {retreat['enemy_hp_before']:.1f}→{retreat['enemy_hp_after']:.1f}; objetivo proyectado y LOS cámara claros {retreat['visible_frames']}frames; giro corporal por mouse {retreat['mouse_overflow_body_yaw_deg']:.3f}° y head solicitado máximo {retreat['mouse_overflow_max_requested_head_yaw_deg']:.3f}° |
| Zancada/alabeo | Contrato24 comprobaciones; cuatro patas por separado,16ciclos/pata, negativos de promedio agregado y recuperación; capturas nativas de ambos giros y vuelta a nivel |
| Cámara/IA | Cámara{camera['checks']} comprobaciones con superficies físicas/fortaleza real y negativo; IA11 con caballero/ballista activos ocluidos y misma IA tras retirar sólo la pared |
| Envolventes actuales | {metrics['final_geometry_candidates']}IDs originales; {metrics['runtime_hull_poses']}poses de partición estable, 5412vértices/pose; runtime exterior máximo {metrics['runtime_hull_maximum_outside_m']*1000:.3f}mm; holdout independiente declarado en método |
| Cuerpo/terreno | {metrics['body_touching_complete_triangles']}caras completas/{metrics['body_triangle_proof_poses']}poses; {metrics['continuous_frames']}frames continuos en terreno real; mínimo {metrics['continuous_minimum_body_clearance_m']*1000:.3f}mm; no puntos omitidos |
| UI/combate | Clic→primerframe presentado {clicks[0]['latency_ms']:.3f}/{clicks[1]['latency_ms']:.3f}ms a1280/960; controles≥48px, foco/Tab; combate nativo19casos |

## Rendimiento y partida completa

Benchmark real de combate60s: **{bench['fps_average']:.3f}FPS/p95 {bench['frame_p95_ms']:.3f}ms**. Misión completa sin capturas ni MovieMaker: **{perf['fps_actual_wall']:.3f}FPS/p95 {perf['frame_p95_ms']:.3f}ms**. Todos los grupos medidos≥60FPS/p95≤25ms. No hay otro Godot ni trabajo pesado concurrente durante estas mediciones.

Victoria nativa a {mission['time']:.3f}s, salud {mission['health']:.0f}/240; {mission['shots_fired']}disparosAI, {mission['damage_events']}eventos de daño y {mission['fire_hits']}contactos de fuego. Recorrido {mission['path_distance_m']:.3f}m. Entradas Enter/T/L/WASD/Shift/F/E/ratón; cero teleports del driver tras el inicio, overrides o llamadas manuales de daño. El contador de teleports del driver no niega las correcciones físicas acotadas de posición del guard de colisión. Las fases avanzan [1,2,3,4,5].

| Fase/locomoción | Cuadros | FPS de pared | p95ms |
|---|---:|---:|---:|
{groups}

[Partida grabada actual](playthrough-metal.mp4) gana a {movie['time']:.3f}s; [aterrizaje frontal](anatomy-flat-front.mp4), [lateral en ladera](anatomy-real-final.mp4) y [vuelo/planeo actual](anatomy-flight-final.mp4) muestran el mismo runtime. MovieMaker es evidencia visual y nunca acredita FPS. Las fuentes antes/después, comandos y fechas están en los receipts nativos y final-manifest.json.

## Límites y antecedentes

La cobertura es finita: no certifica toda geometría, cualquier pose futura, biomecánica de un animal inexistente ni calidad AAA. La construcción posterior y la secuencia de plegado son cinemáticas: no se atribuyen a músculo físico simulado. Las PNG sobre cabeza en vuelo, retirada y giro deben mostrar el Skin real sin que las alas oculten al enemigo. A inicial junto al muro queda limitado; A de retorno en espacio libre sí gira. {corridor_limit} Apoyo conserva el límite15mm. Viewport y LOS físico de cámara no prueban por sí solos ausencia de oclusión por la piel renderizada: las capturas nativas requieren revisión visual. Los landmarks de boca también requieren lectura frontal/lateral. Las capturas a60Hz y las sondas instrumentadas no acreditan FPS; el fixture aéreo no requiere PNG y su alcance es funcional. Las laderas son procedurales y el LOD/material repetido sigue visible; agua usa reflexión por probe. Los avisos de cierre de TextureRID/ObjectDB se conservan en logs, sin inferir fugas universales ni costeGPUcero.

{normalization_note}

Los rojos de patas, IK, cola al aterrizar, segundo apoyo, partición porX, fallback global, controlador/oráculo, retícula obsoleta, índices orales incorrectos, laderas y contacto aéreo están preservados junto al rendimiento anterior. Las poses históricas X/213 y los vídeos previos son baseline; no se agregan a la certificación de la partición estable. Las nuevas muestras de holdout no se usaron para seleccionar IDs. Detalles: anatomy-report.md, ground-escape-report.md, anatomy-mouth-report.json, terrain-player-escape-*.json, air-contact-escape.json, player-aim-feedback.json, user-feedback-native-run.json, anatomy-enclosure-method.json, anatomy-enclosure-final-run.json, ux-gate.md y visual-gate.md.

El PDF y trabajo ajeno permanecen intactos. Sin publicación, push ni merge.
'''
(V / 'report.md').write_text(report)
(V / 'ground-escape-report.md').write_text(f"""# Corrección del atasco terrestre

La esquina de la torre suroeste y la ladera se reproduce en el escenario real desde x215/z205. La sonda coloca únicamente el inicio y después utiliza W/S/A/D, T, ratón y F; observa la pose publicada tras el último modificador, una vez por cuadro físico. El driver no cambia colliders ni recoloca al actor durante el recorrido. El runtime sí puede rechazar un paso de colisión y volver al transform seguro anterior dentro del límite físico walk_speed/physics_ticks_per_second+0,05m y≤5°, restaurando articulación y marcha publicadas.

El barrido del cuerpo podía terminar libre y la animación introducir después un ala en la pared. La recuperación actual conserva patas, cuello y apuntado: restaura y recoge sólo la rama alar afectada, con un límite angular de4° por cuadro. Las consultas siguen usando las18piezas originales, capas1/2 y la aceptación sin margen. Cuando la separación es≤0,1mm, una consulta testigo de1mm orienta el plegado con una normal estable; no se usa para declarar una pose libre.

La corrección posterior de las patas y la coordinación de sus primeros pasos también están incluidas en esta pasada; los resultados anteriores se conservan como históricos.

| Medida | Resultado actual |
|---|---:|
| Cuadros de pose final | {escape['observed_final_frames']} |
| Vértices originales comprobados | {escape['original_vertices_checked']:,} |
| Retroceso inicial | {escape['stages']['reverse']['horizontal_distance_m']:.3f}m |
| Giro D | {abs(escape['stages']['right']['yaw_delta_deg']):.3f}° |
| Giro A de retorno | {escape['stages']['left_return']['yaw_delta_deg']:.3f}° |
| Avance/retroceso tras girar | {escape['stages']['forward_after_turn']['horizontal_distance_m']:.3f}/{escape['stages']['reverse_after_turn']['horizontal_distance_m']:.3f}m |
| Mínima separación de piel/terreno | {escape['minimum_skin_terrain_clearance_m']*1000:.3f}mm |
| Deslizamiento máximo de apoyo | {escape['maximum_stance_slide_m']*1000:.3f}mm |
| Retroceder+apuntar+fuego | {escape['retreat_fire_frames']}/180cuadros |
| Error de hocico/dirección del fuego | {escape['maximum_fire_mouth_error_m']:.6f}m/{escape['maximum_fire_head_error_deg']:.6f}° |

El oráculo conserva15mm para apoyo y5cm para la piel respecto al terreno; comprueba cero overlaps de obstáculos en las18piezas. {corridor_limit} El giro A inicial está limitado por el muro, mientras que A de retorno funciona en espacio libre. Esta prueba no permite girar dentro de una pared ni garantiza cualquier geometría futura.

{normalization_note}

Fuentes, comando, fecha, SHA y capturas actuales: launcher-final-run.json, ground-escape-trace.json, ground-escape-skin.json y user-feedback-native-run.json. Rojos conservados: fallback global que movía patas, bloqueo original W/S/A/D y contacto casi tangente con normal inestable. La revisión C3 aún está pendiente.
""")

readme = ROOT / 'README.md'
text = readme.read_text()
text = re.sub(r'Ejecución final en Mac M5:.*', f'Ejecución final en Mac M5: benchmark de combate {bench["fps_average"]:.2f} FPS/p95 {bench["frame_p95_ms"]:.2f} ms; misión completa {perf["fps_actual_wall"]:.2f} FPS/p95 {perf["frame_p95_ms"]:.2f} ms, todas las fases≥60 FPS. [Partida grabada](docs/validation/v2/playthrough-metal.mp4), [aterrizaje lateral](docs/validation/v2/anatomy-real-final.mp4), [aterrizaje frontal](docs/validation/v2/anatomy-flat-front.mp4) e [informe y límites](docs/validation/v2/report.md). MovieMaker es evidencia visual y no mide FPS.', text)
readme.write_text(text)
ledger = ROOT / 'docs/plans/dragon-siege-ledger.md'
ledger.write_text(f"""# Ledger de criterios — Dragon v2

Contrato literal: dragon-siege.md. Todos D01–D10 se reclaman en esta integración; la doble C3 ronda2 determinará cobertura. Cada revisión debe usar el mismo rango inmutable y permanecer aislada.

| ID | Comprobación actual | Estado |
|---|---|---|
| D01 | Descenso continuo, apoyo original y nueva regresión de patas; capturas frontales/laterales actuales | Evidencia actual; pendiente C3 |
| D02 | Zancada de cada pata, neutral/aim y fuego;44 controles simultáneos; esquina W/S/A/D y apoyo | Evidencia actual; pendiente C3 |
| D03 | GitHub assets exactos/pins/licencias; caballero/ballista/acantilado/farol y créditos | Evidencia; pendiente C3 |
| D04 | Paisaje/fortaleza; benchmark {bench['fps_average']:.3f}FPS/p95{bench['frame_p95_ms']:.3f}ms; misión {perf['fps_actual_wall']:.3f}FPS/p95{perf['frame_p95_ms']:.3f}ms | Todas fases≥60FPS; pendiente C3 |
| D05 | Combate19 nativo, IA activa ocluida11, proyectiles/retry y misión real | Evidencia actual; pendiente C3 |
| D06 | UI1280/960; foco/Tab y clic presentado {clicks[0]['latency_ms']:.3f}/{clicks[1]['latency_ms']:.3f}ms | Evidencia actual; pendiente C3 |
| D07 | Launcher completo rc0; victoria por inputs sin overrides; fuentes antes/después iguales | Pendiente doble C3 |
| D08 | Planeo20s completo y bank/recenter cuerpo+membrana; capturas actuales | Evidencia actual; pendiente C3 |
| D09 | Entorno PBR/agua/vegetación/sombras; límites de relieve procedural y LOD declarados | Evidencia visual; pendiente C3 |
| D10 | {metrics['final_geometry_candidates']}IDs/{metrics['runtime_hull_poses']}poses estables; BODY{metrics['body_triangle_proof_poses']}poses; {metrics['continuous_frames']}frames terreno; esquina y cámara144 | Evidencia actual; pendiente C3 |

Resultados antiguos X/1088/213/33 y campañas de rendimiento anteriores son históricos. No se mezclan con la partición estable ni se acreditan como capturas del rig actual. Los cinco huecos de evidencia de C3r1 se corrigieron; el feedback posterior exigió nuevas correcciones de patas y contacto y una campaña completa nueva.

No hay publicación, compra, push/merge ni solicitud de permiso pendientes. El PDF y archivos ajenos permanecen intactos. Reporte actual: docs/validation/v2/report.md; fuentes y receipts: anatomy-manifest.json/final-manifest.json.
""")
print('Current report, README and ledger refreshed; independent review remains pending.')
