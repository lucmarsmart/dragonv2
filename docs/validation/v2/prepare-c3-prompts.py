"""Materialize both isolated audit prompts against the same resolved Git snapshot."""
import json
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "docs/validation/v2"
scope = json.loads((OUT / "review-snapshot.json").read_text())
manifest = json.loads((OUT / "anatomy-manifest.json").read_text())
metrics = manifest["metrics"]
feedback = json.loads((OUT / "user-feedback-native-run.json").read_text())
mouth = json.loads((OUT / "anatomy-mouth-report.json").read_text())
player = json.loads((OUT / "player-aim-feedback.json").read_text())
assert feedback["passed"] and not mouth["failures"] and player["pass"] and not player["failures"]
mouth_run = next(run for run in feedback["runs"] if run["name"] == "mouth")
player_run = next(run for run in feedback["runs"] if run["name"] == "player-aim-feedback")
assert len(mouth_run["captures_sha256"]) >= 40 and len(player_run["captures_sha256"]) >= 2
assert {run['name'] for run in feedback['runs']} == {'descent','ground-escape','mouth','terrain-player-escape-500-450','terrain-player-escape-850-130','terrain-player-escape--450-220','air-contact-escape','player-aim-feedback'}
for run in feedback['runs']:
    assert run['passed'] and run['report_passed'] and run['source_files_unchanged']
    assert run['report_sha256'] == hashlib.sha256((OUT / run['report']).read_bytes()).hexdigest()
    assert all(run['source_files_sha256_before'].get(path) == digest for path, digest in manifest['source_sha256'].items()
               if path in {'project.godot', 'scenes/main.tscn'} or path.startswith(('scripts/', 'shaders/', 'assets/')))
    assert all(hashlib.sha256((OUT / name).read_bytes()).hexdigest() == digest for name, digest in run['captures_sha256'].items())
assert all(hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest for path, digest in manifest['source_sha256'].items())
mouth_side = sorted(name for name in mouth_run["captures_sha256"] if "neutral_fire_on-side-" in name)
assert any(name.endswith("-clean.png") for name in mouth_side) and any(name.endswith("-landmarks.png") for name in mouth_side)
reference_images = ["anatomy-reference-" + part + ".png" for part in ["skeleton", "muscles", "skin"]]
assert all((OUT / name).is_file() for name in reference_images)
mandatory_images = mouth_side + sorted(player_run["captures_sha256"]) + reference_images
mandatory_image_list = "\n".join("- " + str(OUT / name) for name in mandatory_images)
oral = mouth["asset_landmarks"]
retreat = player["measured_retreat"]
assert player["checks"] >= 16 and player["attack_mode_pulses"] == 2
assert player["legacy_head_and_simultaneous_tests_modified"] is False
assert retreat["forbidden_key_frames"] == 0 and retreat["enemy_hp_after"] <= 0
assert retreat["mouse_overflow_body_yaw_deg"] > 10 and retreat["mouse_overflow_max_requested_head_yaw_deg"] <= 45 + 0.001 * 180 / 3.141592653589793
reference = json.loads((ROOT / "scripts/dragon_anatomy_reference.json").read_text())
assert reference["joint_count"] == len(reference["joints"]) == 156 and reference["contains_muscle_simulation"] is False
assert hashlib.sha256((ROOT / reference["source"]).read_bytes()).hexdigest() == reference["source_sha256"]
for path in ["docs/anatomy-reference.md", "scripts/dragon_anatomy_reference.json", "scripts/dragon_biomechanics.gd"]:
    assert manifest["source_and_artifact_sha256"][path] == hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), path
base, head = scope["base"], scope["head"]
spec = (ROOT / "docs/plans/dragon-siege.md").read_text()
gate = Path("/Users/fede/.codex/skills/feature-dev/references/gate-de-slice.md").read_text()
# This is the literal required role/output template, not the surrounding how-to shell snippet.
role = gate.split("# ===== PREFIJO ESTABLE (cacheable entre slices) =====", 1)[1].split("# ===== VARIABLE POR SLICE =====", 1)[0]
prompt = "# ===== PREFIJO ESTABLE =====\n" + role + f"""
## Slice bajo revisión
SL-DRAGON-SIEGE-INTEGRATION: locomoción/contacto natural, asedio completo y modelos3D reales.
Directorio: {ROOT}
Diff exacto: git -C {ROOT} diff {base}..{head}
BASE_SHA: {base}
HEAD_SHA: {head}
Snapshot local inmutable; no se movió HEAD ni el índice del usuario. Ver review-snapshot.json.
Archivos: controlador/modificadores/sondas, terrain/entorno/shaders, scripts/combat, main/project,
assets de characters/siege/environment, launchers, investigación, pruebas y evidencia nativa.
Todos D01,D02,D03,D04,D05,D06,D07,D08,D09,D10 son RECLAMADOS; ninguno cubierto por otro slice,
ninguno asignado a otro slice. Texto literal de cada ID en spec completa abajo.
Comando validado: ./VALIDAR_DRAGON.command; locomotion-contract (cada pata y bank/skin), camera_surfaces144, active_ai_los11; ui clic+Enter y test_siege nativos; benchmark_siege60s;
play_siege_validation nativo sinMovieMaker y sinreadback/PNG (subclass sólo capture), luego película. Detalles y rc en report.md/manifest.

## EVIDENCIA DE INTERFAZ
Origen: este snapshot y manifests de fuentes al principio/fin de cada ejecución,
Godot4.7.2 Metal4 Forward+ AppleM5,5octubre2026, constructor ejecuta controles reales.
| Tarea | Captura | Estado |
|---|---|---|
| Menú/créditos/ayuda | ui-briefing-960.png,ui-credits-960.png,ui-help-960.png |1280/960,focus/Tab/Enter/clic→primer frame presentado |
| Marcha y aterrizaje | anatomy-real-final-touchdown.png,anatomy-real-final-walk.png,anatomy-real-final.mp4; anatomy-flat-front-touchdown.png,anatomy-flat-front.mp4; anatomy-real-front.mp4 (relieve con oclusión de árboles); anatomy-gait-0168.png y vídeo llano | Rig final en relieve nuevo y fixture llano; sonda final y contactos |
| Planeo | anatomy-glide-0000.png,0420.png,0840.png y anatomy-flight-final.mp4 | Tres vistas,5412puntos |
| Alabeo y recuperación | anatomy-bank-left_turn.png,left_release.png,right_turn.png,right_release.png; anatomy-bank-native-run.json | Native1280, subclass sólo cámara/capturas; contrato padre intacto |
| Fallos reportados por el jugador | anatomy-descent-compact-*.png,ground-escape-*.png; user-feedback-native-run.json | Descenso con patas bajo torso y movimiento/retirada/giro con apuntado y fuego en esquina real |
| Boca oral frente a punta nasal | anatomy-mouth-*-side-clean.png,anatomy-mouth-*-side-landmarks.png y vistas frontales; anatomy-mouth-report.json | {mouth['checks']}comprobaciones; {len(mouth_run['captures_sha256'])}PNG nativos actuales; midpoint de piel superior/inferior+8cm; IDs GLB{oral['upper_original_glb_index']}/{oral['lower_original_glb_index']} resueltos por POSITION/hueso, no índice importado |
| Tres aterrizajes y salidas en terreno real | terrain-player-escape-500-450-*.png,terrain-player-escape-850-130-*.png,terrain-player-escape--450-220-*.png y sus JSON | Fixture aéreo inicial declarado; FLY→L→W/S/A reales en(500,450),(850,130),(-450,220); AI/colliders sin desactivar durante la observación |
| Salida de contacto en vuelo | air-contact-escape.json | Fixture físico vertical declarado; controles reales y18hulls finales; prueba funcional finita, no PNG/FPS ni cobertura universal de paisaje |
| Cámara sobre cabeza y enemigo durante retirada | Todas las PNG del receipt player-aim-feedback: vuelo en ataque, reverse-aim-fire, after-retreat y mouse-overflow-above-head; player-aim-feedback.json | {player["checks"]}comprobaciones; MAIN/cámara/Skin/enemigo/AI reales; S+ratón+clic izquierdo con T una pulsación liberada para entrar/salir, HP{retreat['enemy_hp_before']:.1f}→{retreat['enemy_hp_after']:.1f}; retícula LOS fresca sin fuego; excedente del ratón tras±45° cervical gira el cuerpo; cero A/D/F/T sostenida en la observación |
| Modelos de combate | combat-knight-and-dragon.png,combat-aimed-fire.png; tests/artifacts/siege-assets/*.png | Armadura y mecanismo detallados |
| Paisaje | environment-fortress-air.png,environment-river-close.png,environment-mountain.png,environment-pine.png | Conjunto/ribera/montaña/vegetación |
| Misión completa | playthrough-metal.mp4 y playthrough-metal-*-victory.png |Victoria por inputs,enemigos activos,sin overrides |

Inspecciona realmente las imágenes adjuntas para criterios visualesD01/D02/D03/D06/D08/D09/D10;
si view_image está disponible puedes abrir además las rutas. No uses base64 impreso como visión;
no aceptar por conteos/SHA o por juicio del constructor. Todas rutas arriba relativas a docs/validation/v2
excepto tests/artifacts. Lee report.md, anatomy-report.md, visual-gate.md, ux-gate.md y JSON de métricas,
y luego refuta con código/test concretos.
Las siguientes imágenes son OBLIGATORIAS y están seleccionadas del receipt nativo actual:
{mandatory_image_list}
Ábrelas con view_image o la herramienta visual disponible. Inspecciona realmente la salida oral
en el lateral limpio y con landmarks: distingue mandíbula superior/inferior de nariz, posición del
emisor, abertura y dirección con fuego. Compara con las vistas frontales actuales. Inspecciona
todas las PNG de la cámara sobre la parte delantera de la cabeza: Skin original, alas fuera
de la línea visual del enemigo, soldado legible, retícula y destino del fuego durante S.
Comprueba además vuelo en modo ataque y giro corporal por el excedente del mouse. Cita el archivo y lo observado en tu informe. Si no puedes abrir píxeles,
declara esa parte visual sin verificar; el SHA,{mouth["checks"]}checks/{len(mouth_run["captures_sha256"])}PNG orales o HP{retreat["enemy_hp_before"]:.1f}→{retreat["enemy_hp_after"]:.1f} no la sustituyen.
Inspecciona además al menos una captura actual de cada una de las tres laderas. Comprueba en
JSON el resto del recorrido y las posiciones iniciales declaradas; no confundir estos fixtures
con una partida sin placement inicial. El fixture aéreo es explícitamente sintético y físico.
Adaptador playthrough-movie-evidence.gd sólo fija clasificación MovieMaker antes de capturar; no cambia Input/gameplay. Salidas frescas y hashes internos verificados. Los FPS válidos vienen de la campaña native --no-capture.
Alas: {metrics["final_geometry_candidates"]} índices originales, verificación de selección en {metrics["selection_verified_poses"]} poses.
Consulta enclosure_method y las nuevas poses/holdout de descenso y plegado: no aceptar poses usadas
para seleccionar la unión como si fueran prueba independiente. Los rojos y límites están preservados.
BODY: anatomy-body-partition-enclosure.json comprueba 19.993 caras completas en {metrics["body_triangle_proof_poses"]} poses,
incluyendo corners de frontera. Terreno: {metrics["continuous_frames"]} cuadros, 20.191 puntos corporales + 5.412 alares
por cuadro, aproximaciones dentro del mapa y consultas de suelo físicas presentes.
La compresión del cuello se verifica con anatomy-affine-enclosure.json y anatomy-affine-verifier.py:
misma identidad de bits de pesos/binds, originales convexos porgrupo, fallback degenerate/all. No imprimas JSON enormes de nube de puntos: usa análisis
selectivo y verificador/reportes de enclosure. No ejecutar GPU/benchmark simultáneos ni cambiar archivos.
Nuevas comprobaciones dedicadas: anatomy-locomotion-contract.json (4 patas, velocidad por tiempo físico
real, negativos pooled y banco/recenter del cuerpo y eje skin); camera-surfaces.json (caja física
y fortaleza importada, negativos, segundo rayo post-lerp, esfera/segmentos/sweeps); active-ai-los.json
(caballero/ballista activos detrás de pared, misma IA tras retirar únicamente la pared);
ui-measurements.json distingue start_click nativo presentado de start_keyboard. Launcher final
vincula fuentes antes/después y ejecuta las pruebas nuevas. No asumir cobertura por su nombre:
refuta sus aserciones y el método. La geometría/postura cambió tras los fallos reportados por el jugador:
exige grabación y capturas actuales vinculadas a los SHA de producción, no reutilizar el viejo rig
como prueba de la corrección. integration-round2.json comprueba la identidad del movie actual.
test_simultaneous_controls usa controles reales; test_ground_escape recorre la esquina real con
W/S/A/D, T/ratón/F; anatomy_descent_compact_repro mide piel de patas y continuidad. Verifica sus
rojos conservados, pruebas negativas y nueva evidencia de enclosure de las poses modificadas.
Para boca, contrasta anatomy-mouth-report.json y el rojo anatomy-mouth-raw-index-red.json:
POSITION+hueso deben conservar la identidad GLB aunque el importador reordene vértices.
La nariz orienta la cabeza; el origen se calcula desde piel oral después de abrir la mandíbula.
Para las tres laderas lee terrain-player-escape-500-450.json, terrain-player-escape-850-130.json
y terrain-player-escape--450-220.json: exige L real, W/S y A tras contacto, piel≤5cm, apoyo≤15mm,
18hulls/props activos y fuentes antes/después iguales. air-contact-escape.json debe atribuir
la salida a inputs y re-barrido físico, sin teleport del driver posterior al fixture ni override.
Ese contador no niega las correcciones físicas acotadas de posición del guard del runtime.
Para player-aim-feedback.json refuta la preparación con W/S y mouse sin clamp del driver:
exige cono/LOS y visibilidad estables12ticks; la alineación corporal estrecha no sustituye la
cabeza independiente. Refuta después S continua+ratón+clic izquierdo contra AI activa: T
se pulsa una vez para entrar y se suelta; otra pulsación liberada sale. La ventana medida
prohíbe A/D/F/T sostenida, mantiene distancia>2m y exige enemigo muerto/HP0. Revisa el giro
corporal>10° al continuar mouse más allá de±45°, sin superar el límite de cabeza.
Las suites legadas de cabeza independiente y controles simultáneos no se cambiaron. El daño real no se valida con una llamada directa ni con
test_simultaneous_controls, que no tiene enemigo real. La proyección/LOS físico de cámara no
demuestra por sí solo que el mesh renderizado deje ver al soldado: las PNG obligatorias mandan.
Verifica preview de retícula sin fuego y clip visual del cono frente al daño26m/7°/48DPS/LOS.
Lee docs/anatomy-reference.md, scripts/dragon_anatomy_reference.json y dragon_biomechanics.gd:
{reference["joint_count"]}joints originales, padres/hijos/TRS/ejes y clips del GLB vinculados por SHA.
El mapa no aporta límites biológicos ni músculos simulados. Refuta rear_joints: corvejón primero,
rodilla desde el círculo de intersección, target y longitudes originales; fallback cuando no hay
solución. Revisa el seed de rodilla desde support_rotations publicado y eje original del hijo,
no la siguiente clave aérea importada. HeadPose apunta mediante53/54 (0,42/0,58) y cabeza55;
37 no participa en el aim porque mueve las clavículas38/79. Comprueba marcha/apoyos y boca
mientras apunta usando las poses publicadas finales, no sólo las ecuaciones offline.
Revisa _refit_compact_wings: dígitos smoothstep(0,.65), codo(.08,.82), hombro(.18,.95);
apertura en orden inverso, guards y presupuestos conservados. Exige secuencia visual actual
para atribuir naturalidad al cierre; no aceptar la etiqueta de músculos ni un conteo de joints.
Los números candidatos en anatomy-reference.md son históricos y no sustituyen los JSON
finales del mismo SHA. No hay fuerzas musculares, torque ni volumen de tejidos simulado.
En el postjaw revisa sample_jaw_final: soporte mandibular de originales debe actualizar la
envolvente publicada después del modifier de mandíbula; no aceptar hull anterior a apertura.
Revisa guard_tail_terrain del parche final de aterrizaje: la regresión histórica de cola−0,685m
y segundo apoyo16,98mm queda como rojo, no como resultado actual. El guard anterior a BODY
reutiliza slots originales de soporte afín Tail en BODY2, sin cambiar membership ni crear otro
SkinSampler; consulta altura exacta del Terrain. Anticipa con reserva0,12m, rotando la primera
TailRoot con anchor del quaternion mundial publicado y≤4°/tick; aplica LANDING<12m/GROUNDED,
mantiene links originales y publica la cola después de los guards de BODY/alas. Comprueba
la condición de capacidad: landscape debe ser válido y tener ground_height; fixtures llanos
con cuerpos físicos omiten sólo esa consulta analítica y conservan el guard ordinario BODY.
Verifica que la reserva no cambia los límites5cm de piel/15mm de apoyo ni elimina puntos del oráculo.
Refuta la cola final con PNG actuales de descenso/ladera y JSON de aterrizaje/segundo apoyo,
ventanas continuas y partición/enclosure del mismo SHA. Una prueba candidata de6ventanas/508frames
o un primer intento con reserva distinta no acreditan la campaña final ni aprobación independiente.
Usa los valores actuales de JSON y launcher final; no traslades la medición de apoyo de un
candidato anterior al resultado final. La doble C3 sigue pendiente hasta los informes aislados.
Revisa los guards actuales: _rotation_contact reserva3mm; _body_contact reserva3mm sólo contra
props máscara2, junto a la consulta sin margen, y mantiene margen0 para terreno máscara1. El rojo terrain-tail-margin-red.log demuestra hit0/reserva3mm vacío/shape nueva hit0 en idéntica postura; la aceptación requiere ambas consultas libres. GroundContact y el oráculo final de
las18piezas consultan con margen0. Refuta los resultados de(-450,220) contra árboles/rocas reales;
la reserva preventiva no permite aceptar overlaps finales ni omitir una pieza.
Revisa las optimizaciones exactas posteriores al rojo de rendimiento: transform e inversa del terreno
precalculados por apply, mínimo de piel de la extremidad reutilizado sólo mientras no cambia FK,
topología de descendientes original almacenada en configure, consultas BODY por hull/capa/margen
reutilizadas sólo durante guard_body_pose síncrono. sample_final, sample_jaw_final y transform actor
invalidan queries; cada solve posterior invalida mínimo. No acepta menor geometría, menos vértices,
ningún umbral más laxo o caché entre distintas posturas/colliders. Refuta esas invalidaciones y fuente
final contra las regresiones y performance nativa actual; el rojo anterior no acredita FPS final.
Revisa el rechazo final de un paso físico: distancia≤walk_speed/physics_ticks_per_second+0,05m
(0,175m a7,5m/s/60Hz), ángulo≤5°, recuperación del FULL actor transform INCLUIDA posición,
velocidad/speed0, visual y todas las FK de la última pose publicada segura. Se restaura una copia
profunda del estado de marcha; sus relojes vuelven al frame actual para impedir que el paso lógico
termine antes de aceptar la pose física. Cache posterior al guard de alas, apoyos preservados y
dirección real de cabeza recalculada. No confundir este rollback pequeño de colisión con teleport
del driver, ni ignorar la escritura de posición: refuta su límite y oráculo de obstáculos original.
No atribuyas una ampliación de ancestros del torso que fue retirada. Exige JSON actuales y fuente
final coincidente; un SHA correcto no certifica apoyos, cuello o ausencia de overlaps.
Los avisos del motor sobre normalización de Vector3 en _rotation_contact deben figurar como límite
con su log actual, aunque no haya errores de script/shader y los oráculos finales pasen. No ocultarlos
ni deducir de esos positivos que todo aviso es inocuo; distingue motor, código y observación final.
No revisar PDF del usuario ni archivos ajenos fuera del rango.
Los assets del Git snapshot son binarios exactos; origen/checksums/licencias en assets/LICENSES.md.
No hay servicio externo en runtime que un doble sustituya: fuentes públicas usadas realmente en assets.
Límites de observación están declarados; no convertirlos en perfección universal ni ampliar contrato.

D07: esta revisiónCLI y un agente fresco de reglas se ejecutan aislados sobre este mismo rango.
No leas ningún c3-*rules*gate, c3-*rules*run ni report-final-audit, actual o anterior; ninguno recibe el informe del otro. Root registra/combina
ambos después. No exigir recursivamente que tu informe exista dentro del snapshot que revisas.
No hay cambios de runtime después del freeze; metadatos del cierre se agregan al finalizar auditoría.

## Spec completa, literal
{spec}
"""
(OUT / "c3-spec-prompt.md").write_text(prompt)
rules = f"""## Rol
Eres revisor de reglas escritas del proyecto, fresco y separado del constructor y gate de spec.
Lee /Users/fede/.codex/skills/feature-dev/references/revisor-de-reglas.md y usa exactamente su
formato/clases/evidencia. No revisar contra spec ni emitir preferencias sin regla escrita.
Modelo seleccionado: gpt-6-astra; esfuerzo high; registra los valores reales.

## Alcance
Directorio: {ROOT}
Rango: {base}..{head}
Diff exacto: git -C {ROOT} diff {base}..{head}
Snapshot inmutable local, branch/index usuario intactos. Código real del rango es fuente de verdad.
Reglas escritas aportadas por humano en docs/validation/v2/project-rules-input.md; reunir AGENTS.md,
CLAUDE.md, arquitectura/ADR, DESIGN/tokens si existen en directorios tocados.
Busca implementation-rules.md selectivamente porGodot/GDScript/componente, nunca entero.
Origen/selectividad documentados en docs/validation/v2/review-sources.md.
Sólo lectura, no modificaciones, no mensajes a otros chats ni lectura de PDF/archivos personales ajenos.
No leer ningún c3-*spec*gate, c3-*spec*run ni informe del otro revisor, actual o anterior. No confiar en resúmenes.
No correr GPU o repetir benchmark; pruebas y fuentes están vinculadas por manifest.
Las pruebas nuevas incluyen boca oral contra nasal (anatomy-mouth-report.json), tres fixtures
FLY→L→W/S/A reales terrain-player-escape, contacto aéreo en fixture físico vertical declarado y
player-aim-feedback con MAIN/cámara/Skin/enemigo/AI reales, S+ratón+clic izquierdo y T
una pulsación liberada para entrar y otra para salir; sin A/D/F/T sostenida al medir.
Exige HP0, retirada>2m y giro corporal por overflow>10° con cabeza dentro de±45°;
las suites legadas independientes de cabeza y controles simultáneos permanecen intactas. Los placements iniciales
de los fixtures no equivalen a teleports durante la observación; verifica el código y la regla
aplicable antes de atribuirlos. El daño se acredita por HP y producción, no por llamadas directas.
El runtime puede corregir físicamente la posición hasta walk_speed/physics_ticks_per_second+0,05m
y≤5° al rechazar un paso inseguro, restaurando actor/FK/visual/marcha publicados. El contador de
teleports del driver no afirma que no existan esas escrituras. Examina límites, relojes de marcha,
guard final y avisos de normalización Vector3 frente a las reglas aplicables y oráculos actuales.
La nueva anticipación de cola usa slots originales BODY2, altura Terrain y rotación TailRoot
≤4°/tick con reserva0,12m durante LANDING<12m/GROUNDED. Distingue esa reserva de los límites
del oráculo y verifica la publicación final después de BODY/alas. La API analítica requiere
landscape válido+ground_height; fixtures físicos llanos retienen el guard BODY ordinario.
Los rojos de cola/segundo apoyo
se conservan; la pasada candidata no es auditoría independiente ni sustituye JSON/PNG finales.
La referencia actual docs/anatomy-reference.md y scripts/dragon_anatomy_reference.json
registra156joints originales; dragon_biomechanics.gd usa proxies cinemáticos, no músculo físico.
Examina la rama posterior con seed de rodilla publicado (support_rotations/eje original),
HeadPose sobre cervicales53/54 y cabeza55 sin girar37, y plegado por fases dígitos/codo/hombro.
Las pruebas matemáticas offline y los verdes candidatos escritos en la referencia no acreditan
la campaña actual ni naturalidad visual: exige JSON/capturas actuales de las mismas fuentes.
Si una regla evaluada exige evidencia visual, debes abrir estas PNG actuales y citar lo visto:
{mandatory_image_list}
Comprueba lateral oral limpio+landmarks y cámara sobre cabeza en vuelo, retirada y giro:
abre todas las PNG actuales del receipt player; Skin y alas no deben ocultar al enemigo.
Conteos, SHA y resúmenes no acreditan posición semántica de boca ni legibilidad del soldado.
Si no dispones de herramienta visual, declara esa evidencia sin verificar. No inventes una
regla de aspecto: toda observación bloqueante debe citar una regla escrita aplicable.
D07 dobleC3 se combina después por root: no exigir tu informe dentro del snapshot de entrada.

Tu salida final es el informe completo, primera línea vocabulario cerrado VEREDICTOS: ..., última
FIN DEL INFORME. Cita archivo:línea y texto literal de cada REGLA; riesgo explica fallo observable
y reproducido/teórico. Si no hay bloqueo escrito, no inventarlo.
"""
(OUT / "c3-rules-prompt.md").write_text(rules)
print(scope["range"])
