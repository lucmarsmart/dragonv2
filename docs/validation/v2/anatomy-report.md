# Anatomía y contacto — campaña del 5 de octubre de 2026

Los resultados de **1088 extremos originales de alas** descritos en las secciones siguientes son la **base anterior al nuevo feedback de descenso/compactación**, no certifican la geometría nueva. La nueva campaña reproduce ese feedback y vuelve a medir piel, transición y envolventes; su estado se registra al final. La aceptación integrada de FPS y misión queda a cargo del pipeline nativo del padre. El [manifest anterior](anatomy-manifest.json) conserva la campaña base y debe distinguirse del nuevo recibo.

## Comportamiento implementado

La marcha usa una zancada longitudinal de3.5m, cuatro fases de apoyo, transferencia de peso y FABRIK con longitudes authored. El contacto se ancla a un vértice de garra visible. La orientación del pie sigue el rumbo durante swing y se conserva durante apoyo. La corrección de altura examina **todos los vértices originales de cada pie**, también después de ajustar el anclaje horizontal: reducir un hull convexo no conserva el mínimo contra un terreno por triángulos.

Durante aproximación, los pies extienden su postura entre12y5m de proximidad al suelo. El primer frame terrestre aplica IK aunque el blend visual aún sea0; conserva los contactos calculados durante aterrizaje. Las alas se compactan antes de tocar. La recuperación corporal restaura rotaciones seguras de cola/columna antes de resolver cabeza, alas y apoyos; una recuperación no avanza el reloj de marcha dos veces. El guard de miembro conserva target, fase, pole y orientación del pie; ante una rama articular colisionante recupera las rotaciones seguras del miembro, sin cambiar traslaciones ni longitudes. Un alza de torso acotada a30cm mantiene los objetivos de apoyo en mundo y se reinicia al despegar/reintentar.

La cabeza distribuye mirada por cuello/cráneo. T activa ratón o flechas con límites±45°/±30°. `set_head_aim(yaw,pitch)` recibe radianes; `head_aim_direction` representa el objetivo y `head_rendered_direction` el hocico final. El fuego lee la boca y dirección renderizadas después de los modificadores. La cabeza conserva orientaciones seguras, sin estirar enlaces, y limita su recuperación a4° porframe60Hz.

Dieciocho piezas convexas siguen la piel: dos alas, cuello, torso y catorce segmentos de patas. Todas las piezas corporales mantienen terreno+props, capas1+2. La partición elimina el falso puente convexo entre apoyos; las esquinas de caras de frontera se duplican completas, incluidas fronteras con garras/cuello/alas. El solver terrestre resuelve todos los hulls juntos, conserva el Y solicitado y vuelve a barrer el vector final. El movimiento ejecutado por slide/snap puede diferir del consultado: las pruebas comprueban la piel realmente publicada, sin asumir igualdad universal. Se reconstruyen hulls cuando cambia la pose, aunque ocurra dentro del mismo tick físico.

## Piel, construcción y holdout

La sonda independiente reconstruye los25.603 vértices visibles usando Skin/bind/índices/pesos originales y la pose final en `modification_processed`. No sustituye piel por huesos. Los dos tramos strict frontal360/lateral180 y los casos estacionario/cuerpo/huevo comprueban todos esos vértices. En terreno, cada frame observado examina20.191 vértices de cuerpo/cuello/**todas las2430 garras**, además de5412 vértices de alas. Rayos físicos identifican superficie real; `checked=0` en aire alto es N/A, nunca terreno verde.

La selección de alas conserva la base histórica987 y añade extremos convexos originales de21 poses finales. Ese candidato1056 falló un primer conjunto adicional de12 poses: hasta28.298cm fuera en transición aérea. Se preservó el rojo, se incorporaron sus extremos a **construcción**, y se generaron12 poses nuevas con otras fases/aim/giro. Estas últimas nunca se usaron para seleccionar IDs y son el **holdout independiente**. [Separación y SHA](anatomy-enclosure-method.json).

[Verificador de alas](anatomy-hull-verifier.py): todos5412 puntos contra todos los planos. La selección final pasa213 poses enumeradas (168 históricas+21 finales+12 promovidas a construcción+12 holdout), máximo exterior0.531mm. Los **hulls realmente emitidos por el runtime final** pasan33 poses frescas:21 regresiones+12 holdout, máximo exterior0.521mm. [Selección](anatomy-hull-enclosure.json), [runtime](anatomy-runtime-hull-enclosure.json), [holdout](anatomy-enclosure-holdout2-green.json). El margen físico terrestre sigue0; el resultado no usa margen para ocultar vértices exteriores.

[Verificador corporal independiente](anatomy-body-partition-verifier.py):19.993 triángulos completos que tocan cuerpo/garra,14 poses finales, sin esquina omitida. Comprueba que las tres esquinas de cada cara pertenecen a una misma pieza. Máximo exterior0.111mm, tolerancia numérica1mm; una traslación negativa deliberada de20m se rechaza. Las otras20.440 caras de fuente corresponden a cuello/alas independientes. [Reporte corporal](anatomy-body-partition-enclosure.json).

Los soportes afines conservan índices, bind y pesos completos; la prueba en espacio bind da1.78e−15m. El skinning empaquetado renueva matrices en cada llamada y se compara con la fórmula independiente:11.730 soportes por snapshot, máximo medido en esta campaña<0.13mm. Esto describe error float observado, no igualdad bit a bit ni garantía sobre poses futuras.

## Regresiones de la base previa al feedback

Todos los comandos finalizan con rc0, sin FAIL/ERROR:

| Caso | Resultado |
|---|---|
| [Strict](anatomy-strict-final-green.log) |42/42; sondas negativas de piel, marcha/planeo/aim/15° y frontal/lateral completos |
| [Cabeza/giro estacionarios](anatomy-stationary-final-green.log) |11/11;25.603 vértices porframe; F real coincide con hocico0° y boca0m; recuperación≤4.001° |
| [Huevo y retirada](anatomy-egg-final-green.log) |7/7;274frames,7.015.222 comprobaciones de vértices; penetración0m, retirada23.589m, giro≤3.99975°, traslaciones de cuello intactas |
| [Muro corporal](anatomy-body-contact-final-green.log) |8/8; piel sin intrusos, avance al retirar, deslizamiento de apoyo1.869mm |
| [Giro de pies](anatomy-foot-yaw-final-green.log) |3/3; cuerpo gira93.583°, error final de pies0°, deslizamiento1.848mm |
| [Legado](anatomy-legacy-final-green.log) |54/54; umbrales de caminar/sprint conservados |
| [Terreno real](anatomy-real-terrain-final-green.log) |79/79;6 ventanas continuas/508frames,10.257.028 rayos corporales observados, más5412 alas porframe |

La postura neutral en llano mide pitch1.611–5.485°, variación idle4.823°. Los pasos completos convergen a3.5m; arranque contiene pasos incompletos. Deslizamiento máximo en strict4.301mm<15mm. Planeo20s: roll0°, delta vertical entre extremos de **toda** la membrana≤0.21442m, envergadura35.82477m.

En terreno, ambas aproximaciones alcanzan apoyo real. Primera ladera touchdown mínimo+1.912cm, marcha+1.929cm; retirada real de≈21m pasa con mínimo+0.557mm. El antebrazo junto a árbol2613 queda a profundidad máxima0.395mm. Segunda ladera nueva fuera de zonas protegidas: touchdown+1.996cm, marcha+1.247cm y avance≈8.1m. En las508frames no hay vértices bajo el límite−5cm ni rayos corporales ausentes; máximo salto de cabeza1.515°, deslizamiento4.419mm. F real está activo19/20 y89/90 frames de touchdown/marcha en ambas laderas; dirección0° y boca0m respecto a landmarks finales.

El escarpe se aproxima mediante vuelo continuo **dentro** del grid físico:662.5/−387.5 hacia600/−450. Se observan todos20.191 vértices corporales durante198frames, mínimo+1.901m y sin rayos ausentes, además de las5412 alas. El antiguo caso fuera de mapa1350/−1600 no se usa como prueba de montaña. La aproximación rápida al cliff usa su AABB real, avanza y encuentra primero árbol2354; se reporta ese contacto y no se afirma un golpe directo a la roca.

## Regresión del huevo sólido

El trimesh original permitía7.117cm de piel dentro del huevo y bloqueaba la retirada. Un convexo denso de todos los vértices conserva superficie a3.25mm, pero consultas de≈500ms lo hicieron inaceptable. El collider final contiene272 puntos derivados del perfil visual16×16; el mesh visual64×48 sigue igual. [Verificación](anatomy-egg-hull-enclosure.json) sobre los6144 triángulos originales: todos dentro del collider, expansión máxima certificada3.145cm<5cm. No se quitó colisión ni capas. Rechazo temprano de un punto original dentro del sólido evita repetir EPA; los cruces sin vértices interiores conservan la consulta convexa. Perfil aislado del guard≈0.53ms; la prueba decisiva de FPS sigue siendo la misión nativa final.

## Rendimiento de LANDING — diagnóstico nativo posterior

La misión nativa sin captura había ganado, pero su grupo aéreo conservaba p95 de28.121ms>25ms. Ese rojo está preservado por el padre como `playthrough-landing-no-capture-red-native-*`. El perfil localizado usa la escena real1280×720,360ticks de warmup, Enter/T/L nativos y30ticks finales en tierra; no teletransporta ni modifica estado/pose, ni escribe PNG durante la medición. [Driver](../../../scripts/anatomy_profile_landing.gd), [datos/método antes/después](anatomy-landing-profile-summary.json).

El pico principal era EPA/get_rest_info por cada pieza que encontraba terreno durante LANDING. El análisis de consumidores confirmó que la normal sólo dirige el pitch bajo la rama **FLYING**. LANDING usa cast/intersect para recortar movimiento y plegar; la normal era diagnóstico. Se omite únicamente esa consulta durante LANDING y se publica `normal_available=false`/normal0. Se conservan todos los casteos, solapes,18piezas, vértices, capas1+2 y margen1.2m aéreo; FLYING mantiene EPA/normal para steering. No se cambiaron poses, alas1088, algoritmo de pies ni paisaje. Se precalientan sólo vértices/binds/pesos e índices de pies antes de habilitar el briefing; reset conserva esos metadatos porSkeletoninstance_id y las matrices de pose se renuevan en cada skinning. Contactos/orientación siguen inicializados por apply en su primera pose real.

| Perfil nativo instrumentado | Antes | Después |
|---|---:|---:|
| LANDING completo |76.59FPS / p95 25.759ms|86.90FPS / p95 15.327ms|
| Preparación a menos12m |49.80FPS / p95 34.333ms|72.25FPS / p95 15.631ms|
| Constrain durante preparación, media/p95 |6.312 /20.394ms|0.878 /2.470ms|

El algoritmo de pies y reconstrucción de hulls permanecen iguales. Preparar los metadatos antes del briefing elimina el pico inicial: ground_total máximo en LANDING pasa77.759→4.918ms. La comprobación posterior a la medición ejecuta3reset+prepare sin frames/poses; mantiene contador1 y las mismas4instanciasProbe. El perfil intermedio EPA-solo que aún tenía≈75ms se conserva en anatomy-landing-profile-epa-only.*. Ambos perfiles antes/final finalizaron rc0; el renderer avisa7 TextureRID al cerrar. Este resultado instrumentado no sustituye la **misión nativa completa sin captura**, que el padre debe repetir antes de MovieMaker. No se añadieron caches de pose ni consultas porframe: sólo se reutilizan metadatos inmutables del mismoSkeleton.

## Captura final y límites

[Metal: aproximación, apoyo y marcha con F](anatomy-real-final.mp4), [touchdown](anatomy-real-final-touchdown.png), [marcha](anatomy-real-final-walk.png), [registro rc0](anatomy-real-motion-final-metal.log). Grabación original1280×720/60Hz,719frames/11.983s; MP4 recorta2.5s iniciales de montaje. Usa el runtime1088 anterior a omitir EPA diagnóstico en LANDING y conserva verdes los chequeos continuos de la primera ladera. Esa optimización conserva casteos, clipping y poses; la misión/vídeo nativa posterior del padre verifica la integración final. Al cerrar MovieMaker aparecen avisos de7 TextureRID y2 ObjectDB sin liberar; rc0 y ningún error de script. Se registran como avisos de cierre, no como medición de FPS. Los árboles ocultan parte de la vista lateral; las métricas de contacto se obtienen de toda la piel. Es una captura de fixture colocado al inicio, no una misión completada ni benchmark de FPS.

[Planeo previo](anatomy-glide.mp4) conserva utilidad como referencia visual aérea; la suite final vuelve a medir su piel completa. Los vídeos antiguos de marcha/landing no se presentan como la transición final de terreno.

La cobertura de hulls y terreno es finita y enumerada. No integra toda deformación dentro del intervalo entre dos renders, ni certifica cualquier geometría estrecha o posición futura. Los guardas conservadores pueden detener una pose antes del contacto visible; no se exige overlap artificial0 si movimiento/retirada y piel reales pasan. Un montaje teletransportado dentro de un escarpe no demuestra una ruta transitable; la aproximación real continua sí se conserva. FPS nativos de suelo/capitán/rescate/escape, misión con entradas reales y C3 pertenecen a la aceptación integrada posterior a este freeze.

## Historial rojo preservado — 5 de octubre de2026

Los registros son candidatos anteriores, no resultados del estado final:

- [Piel original](anatomy-red.log): alas−7.0109m y garras−1.3078m; IK solo no lo detectaba.
- [Enclosure987](anatomy-runtime-hull-enclosure-ground-red.json): hasta94.7cm fuera tras cambios de postura. [Holdout1056](anatomy-enclosure-holdout1-red.json):28.298cm fuera; promovido a construcción antes del holdout2 independiente.
- [Muro/cola](anatomy-body-contact-red.log) y [solver intermedio](anatomy-body-contact-solver-candidate.log): nueva deformación después del barrido penetraba hasta0.4997m.
- [Touchdown con todas las garras](anatomy-touchdown-final-pose-diagnostic-red.log): primera pose terrestre omitía IK y enterraba dedos hasta1.478m.
- [Pie fijo en mundo](anatomy-foot-yaw-red.log): error93.583° al girar el cuerpo. [Todos los pies contra terreno](anatomy-real-warp-all-claw-terrain-candidate2.log): Toe0/Toe3 cruzaban una cresta que la reducción afín no representaba.
- [Miembro/árbol](anatomy-real-warp-member-final-diagnostic-red.log): antebrazo Bone40 hasta45cm dentro pese al target del pie; recuperar rama angular resuelve el caso.
- [Huevo real](anatomy-escape-egg-geometry-red.json):7.117cm dentro y retirada imposible. [Misión nativa anterior](playthrough-attempt11-escape-red-native-report.json) conserva el fallo integrado de escape y su rendimiento.

El manifest registra la fecha de modificación y SHA de cada evidencia preservada; no se reutilizan sellos de anteriores runs como aceptación actual.

Aceptación integrada de la **base anterior al nuevo feedback**: launcher y gates nativos verdes; benchmark89,773FPS/p9513,698ms y misión71,873/p9515,617, todos los grupos≥60FPS/p95≤25ms, victoria por inputs. Película de esa base gana sin overrides. Vista frontal llana de esa base: anatomy-flat-front.mp4; vista frontal de ladera: anatomy-real-front.mp4 con oclusiones declaradas. Esas métricas y vídeos no certifican la nueva preparación de patas, compactación ni partición alar estable.

## Feedback nuevo: descenso y compactación terrestre

La reproducción independiente encontró las garras traseras por encima del torso en LANDING: centro izquierdo hasta+3,826m; la membrana terrestre medía10,393m de ancho. Se preservan [log rojo](anatomy-descent-compact-red.log) y [métricas originales](anatomy-descent-compact-red.json). La sonda mide garras2430 y membrana5412 originales, con torso definido por el centro de piel de sus vértices de columna dominantes. No compara únicamente los orígenes de huesos.

El FK trasero prepara rodilla/corvejón bajo el torso en ejes medidos en mundo/cuerpo, manteniendo traslaciones, binds y longitudes originales. Un presupuesto angular sobre la orientación publicada evita que el cambio de un padre sume otro giro al hijo. La entrada de apoyo terrestre conserva rama, pole y orientación publicados; todos los solves y calibraciones de un frame comparten presupuesto3° para dejar espacio a la rotación simultánea del torso. El IK mantiene sus objetivos y verifica las garras originales. La corrección alar reduce la componente lateral de las mismas articulaciones durante el plegado progresivo: en llano la membrana completa mide6,289m, aproximadamente39,5% menos que la base.

Ampliar la prueba desde80m hasta GROUND+30 expuso una discontinuidad adicional de158,5° en el corvejón al entrar en tierra; [se conserva el rojo](anatomy-descent-compact-full-transition.log). Conservar rama únicamente redujo el salto a21,5°, y presupuestar cada solve por separado aún excedía5°; el [holdout angular rojo](anatomy-descent-compact-holdout-angular-red.json) registra5,324° en mundo. La solución final comparte el presupuesto entre todos los passes, conservando contacto de piel y anclaje.

La compactación cambió los extremos de la membrana. Los verificadores conservan los rojos de [1088](anatomy-descent-compact-enclosure-1088-red.json), [1108](anatomy-descent-compact-1108-transition-enclosure-red.json), [1184](anatomy-descent-compact-1184-holdout-runtime-enclosure.json) y [1855 con corte X](anatomy-descent-compact-1855-dense-runtime-red.json). Las listas son índices originales; ningún margen se aumentó para esconder puntos exteriores. La construcción densa anterior usa140 poses con la partición histórica por signoX y explica la unión1855; **no se agrega al conteo de validaciones con la partición nueva**.

El corte por signoX era discontinuo: un vértice cerca del eje cambiaba de mitad y podía volverse extremo entre muestras. La partición actual usa las raíces96/120 de la jerarquía del rig, con `wing_side_mask` estable. Las caras de frontera se duplican desde sus máscaras originales, sin propagar la duplicación por el mesh. Los exportes declaran `rig-root96-120-boundary-v1`; el verificador rechaza agregar particiones distintas y exige5412 IDs únicos por pose. Las entradas duplicadas se cuentan aparte. En este asset no aparecen caras entre ambas raíces, por lo que cada pose contiene5412 entradas y5412 IDs únicos. El [piloto estable de82 poses](anatomy-descent-compact-stable-dense-pilot-enclosure.json) pasa con1855 IDs y exterior máximo2,519mm; es diagnóstico anterior al guard alar final, **no el freeze integrado**.

El driver [anatomy_descent_compact_repro.gd](../../../scripts/anatomy_descent_compact_repro.gd) mide poses publicadas en `modification_processed`, sin recolocar durante el descenso. Su modo `--capture` ofrece frontal y lateral dirigidos al centro de piel del torso; no mide FPS. La aceptación actual requiere las nuevas regresiones de transición/enclosure/holdout, el corredor real con piel completa y las capturas/pipeline nativo posteriores del padre. No se atribuyen los33 snapshots ni213 poses históricas a este rig cambiado.


## Campaña anterior a la reapertura del launcher: preparación, reloj local y partición estable

Esta campaña sustituye las cifras de1088/33/213 anteriores como evidencia del rig actual. El FK progresivo y el plegado mantienen posiciones/binds originales: las garras quedan por debajo del centro de piel del torso durante todo el descenso, hasta GROUND+30; el mayor valor relativo observado es−0,79161m. El ancho terrestre de los5412 vértices originales es6,288626m. No se recorta ni oculta la membrana.

Extender la observación a120frames de idle y al primerW/S reveló un salto de objetivo de2,70m. El swing usaba la fase global aunque acabara de crear start/finish; la corrección de posición reutilizaba un timestamp anterior. Ahora el reloj empieza en0, avanza una vez por tick físico y se comparte entre target/altura/calibraciones; completar el paso publica finish y vuelve a stance antes de decidir otro swing. Las pruebas usan `--fixed-fps 60`; los candidatos sin reloj fijo quedan como diagnóstico. La [discontinuidad original](anatomy-descent-compact-primary-target-diagnostic.log) y los candidatos de rama rechazados se conservan. No se elevó el torso ni se cambiaron longitudes para ocultar ese defecto.

El solver conserva la geometría FABRIK original. Durante el handoff, todos sus passes comparten el presupuesto angular y el pole trasero publicado; el antebrazo delantero mantiene su comportamiento. El roll de los enlaces traseros se transporta desde la orientación publicada hacia el nuevo eje, en lugar de recuperar el twist del siguiente frame del clip. Esto elimina el giro de91° cuando el eje sólo había cambiado22°. Las pruebas distinguen preparación/handoff (máximo5° por tick) de locomoción normal; registran ambos y no inventan5° para toda la caminata.

| Prueba actual | Construcción/validación | Holdout3 independiente |
|---|---:|---:|
| [Driver/log](anatomy-descent-compact-stable-final.log) / [holdout](anatomy-descent-compact-holdout3-final.log) |rc0|rc0|
| Giro máximo de transición, actor/mundo |4,000369° /4,383918°|4,000369° /4,555609°|
| Giro máximo durante marcha, quaternion/eje |22,038275° /22,038278°|21,897868° /21,897834°|
| Garra original sobre superficie, mínimo |+19,806mm|+19,455mm|
| Deslizamiento máximo de apoyo original |1,541mm|1,299mm|
| Cambio máximo de target, límite0,85m |0,802015m|0,788012m|
| Cambio máximo de longitud en mundo, límite0,1mm |0,085831mm|0,07224mm|
| Traslación local de huesos respecto al clip |0m|0m|

La secuencia holdout3 mantieneW al llegar a12m de proximidad y continúa durante GROUND+30; no libera la continuidad simplemente por pulsar una tecla. Ambos recorridos observan idle120, primerW,480ticks de caminata estable yS. Cada una de las cuatro patas completa al menos cuatro ciclos observados de stance a stance y una zancada≥2m, a velocidad realmente ejecutada7,5m/s. Las zancadas estables son3,5m; el primer ciclo trasero derecho observado mide2,745m. No se aceptan cuatro pasos de una sola pata como cobertura de las cuatro.

La lista actual contiene1864 IDs originales. La unión [local estable](anatomy-descent-compact-stable-extrema-union.json) conserva1855 y añade nueve índices de152 poses de construcción estable; sus archivos originales se preservan. Ningún holdout3 se incorporó a la selección. Validación recién emitida:149poses densas+11fixtures=160, contra todos5412 puntos de cada pose, [exterior máximo40,261mm](anatomy-descent-compact-stable-construction-runtime-enclosure.json). El holdout3 usa temporización distinta:151densas+11fixtures=162, [exterior máximo35,356mm](anatomy-descent-compact-stable-holdout3-runtime-enclosure.json). Ambos pasan el límite5cm sin aumentar margen físico. La cifra anterior de0,521mm corresponde a otra campaña y no se reutiliza.

Archivos actuales para la comprobación integrada:

- `anatomy-descent-compact-stable-dense-validation-poses.json.gz` y `anatomy-descent-compact-stable-fixture-validation-poses.json` (160).
- `anatomy-descent-compact-stable-holdout3-dense-poses.json.gz` y `anatomy-descent-compact-stable-holdout3-poses.json` (162; namespaces distintos).

El guard alar sigue limitado a las ramas96/120; no restaura globalmente pies, cabeza ni cuerpo. El candidato de fallback global rechazado y su deslizamiento de59cm quedan archivados por ground_escape. La tangencia residual de hull1 contra la esquina suroeste se registra como rojo en `ground-escape-1864-witness-diagnostic-red-*`: seis cuadros y normales erráticas obtenidas de pares separados apenas15–34micras. El testigo de1mm sólo obtiene una normal; la aceptación de pose sigue consultando los18hulls con margen0, capas1+2, y el presupuesto alar4° permanece intacto. El cierre del corredor, la revalidación de BODY/parent poses y las capturas nativas posteriores todavía corresponden a la integración del padre; aquí no se afirma FPS ni aceptación nativa de este nuevo rig.


### Corredor de la campaña anterior cerrado

La [pasada final](ground-escape-1864-final-green.log) termina rc0,15/15, con fuentes idénticas antes/después. Cada uno de los18 volúmenes finales conserva0solapes contra props durante1176frames; no se relajó ese oráculo. Las30.109.128 comprobaciones originales dejan mínimo+19,077mm respecto al terreno y deslizamiento máximo5,268mm. W/S avanzan28,931/10,681m; después de girar,6,567/6,089m. Alas≤4,000565° y cabeza≤4,000111° porframe;T con±15° yF funciona180frames con error de boca0m y dirección0°.

El contacto degenerado de15–34micras no describía una normal fiable. Únicamente cuando los pares tienen profundidad≤0,1mm, el guard obtiene un testigo con margen1mm; sus separaciones observadas0,98–1,08mm recuperan la normal de la pared. El plegado de0,25° consigue separación usando la consulta original margen0/capas1+2. No se aumentó el presupuesto4°, no se hicieron giros arbitrarios±axis y no se añadióEPA/get_rest_info. El logging detallado sólo se activa con `--wing-tangency-diagnostic`.

Fuentes congeladas en esa campaña anterior; [handoff histórico conSHA, comandos,rc y límites](anatomy-descent-compact-final-handoff.json). Las nubes160/162 preceden únicamente a este fallback local, inactivo en sus fixtures libres; skinning, generación de hulls y selección permanecen idénticos. El launcher del padre regenerará sus datasets operacionales con el SHA global final. Capturas frontal/lateral, FPS nativos y C3 siguen pendientes de ese pipeline; los vídeos antiguos no se presentan como esta pose actual.


## Reapertura por coordinación de apoyos (5 de octubre, campaña final)

El launcher integrado detectó un fallo real: dos correctives podían levantar simultáneamente las patas23/41 y dejar menos de tres apoyos. La base se conserva en `anatomy-flat-support-launcher-red.log`; la reproducción mínima `--flat-support-only` usa el mismo descenso, espera, marcha y oráculo del parent. No cambia ni el mínimo de tres contactos ni sus tolerancias.

La planificación primaria avanza y completa los cuatro relojes antes de elegir un único pie en vuelo. La cola normal FIFO registra el ciclo al empezar, sin marcar como servido un ciclo nuevo al terminar. Los solves de recuperación leen ese plan y no crean otros pasos ni avanzan relojes. El tiempo de cada paso normal se escala por su recorrido real respecto a3,5m; el mínimo nominal de velocidad del reloj sólo se aplica al arranque. Se conserva el corrective de0,18s. La preparación LANDING sigue concurrente porque todavía no soporta el peso terrestre.

El holdout conW mantenida expuso un segundo defecto durante el handoff. Antes de asentarse el estabilizador, el torso ya aceleraba: la pata41 llegó a pedir3,797m con3,588m de enlaces y la corrección del apoyo divergió hasta56,1cm. Se conservan `anatomy-flat-support-fifo-reach-red.*` y su traza. Cambiar prioridades no resolvió el problema y ese candidato también se conserva como rojo; la fuente final vuelve al FIFO simple. La intervención mínima fija target_walk=0 sólo mientras GROUNDED y ground_blend<0,99, usando la fricción terrestre existente. No resetea velocity ni input; la marcha consumeW/S al asentarse. Nuevos pasos esperan ese mismo blend y los que ya venían de LANDING terminan normalmente. Las anclas, objetivos, longitudes, binds y umbrales permanecen intactos.

Resultados recién emitidos sobre esa fuente:

| Métrica | Default /149+11 poses | Holdout3 /151+11 poses |
|---|---:|---:|
| rc del driver |0|0|
| Transición actor/mundo |4,000369° /4,383918°|4,000369° /4,555609°|
| Giro de locomoción regular |21,905156°|22,273537°|
| Piel original de garra, mínimo |+19,806mm|+19,455mm|
| Deslizamiento de apoyo original |1,541mm|1,248mm|
| Cambio máximo de target |0,775906m|0,777803m|
| Cambio de longitud publicado |0,089169mm|0,072241mm|
| Traslación de huesos |0m|0m|
| Enclosure5412/pose,1864 IDs |40,261mm|36,234mm|

Los logs finales son `anatomy-flat-support-final-default-construction.log`, `anatomy-flat-support-settle-acceleration-holdout.log`, `anatomy-flat-support-final-construction-proof.log` y `anatomy-flat-support-final-holdout-enclosure.log`. Ambas secuencias observan al menos16 ciclos completos por cada pata, aproximadamente3,5m de zancada a velocidad realmente ejecutada7,5m/s. El contacto usa las2430 garras originales y conserva15mm de deslizamiento,5cm de penetración,0,85m de salto de target y0,1mm de error numérico de longitud. La prueba angular de5° se aplica a preparación/handoff; los máximos de marcha se publican aparte.

Las mismas cuatro rutas de nubes160/162 listadas arriba se han regenerado después de la corrección. El holdout3 nunca se usa para selección de IDs; ya observado durante el diagnóstico, sigue siendo independiente de la selección, no un ensayo ciego. Las pruebas son finitas: no garantizan cualquier pose ni reemplazan la integración nativa. La captura first_walk representa90ticks deW, antes del tramo largo de480ticks. Capturas, FPS y aceptación del launcher completo serán responsabilidad de la nueva campaña del padre.

La nueva pasada de corredor (`ground-escape-flat-coordination-final.log`) termina rc1 exclusivamente por apoyo:69,496mm frente al límite15mm. Piel original−12,084mm dentro de5cm y0 solapes conprops, pero eso no cierra la regresión. La traza diagnóstica confirma que el fallback corporal original restaura la rama delantera82 en coordenadas locales cuando el actor ya se ha movido; el contacto original17199 pierde su ancla y avanza con el actor. Los dedos89/90 no cambian su rotación local. Este caso sigue abierto; ninguna de las pruebas verdes anteriores se declara cierre integrado.
