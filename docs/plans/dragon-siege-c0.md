# C0 — Dragon siege

Ronda 1 · 2026-10-04 · Revisor: subagente independiente, contexto delegado; modelo/esfuerzo heredados, sin evidencia de que sean distintos del orquestador. Revisión documental y lectura mínima de controller, ground pose, terreno y shader; no ejecución ni edición de runtime.

Artefacto: `docs/plans/dragon-siege.md`, SHA-256 `ae216d11d9a3785b76de34cc54ba42e53848a279c3b2bb7ecd1808c6e183059e`.

El contrato responde a los defectos reportados y exige evidencia visual real. D01 evita el falso positivo de medir sólo huesos. No detecto contradicción fundamental entre vuelo, combate y escenario. Quedan dos vacíos que permiten aprobar un resultado visiblemente inferior a lo pedido.

1. **BLOQUEANTE — D02/D07: marcha y postura sin condición de aceptación suficiente.** La precisión posterior del usuario identifica pasos demasiado cortos y cabeza siempre dirigida al piso; considera natural el resto del cuerpo. La versión revisada aún permite ambos defectos: oscilar 2–10° alrededor de una inclinación incorrecta cumple D02. Fijar eje hocico→mirada en coordenadas del mundo, rango neutral respecto del horizonte y objetivo frontal durante reposo/marcha; medir zancada en función de la anatomía y velocidad, distinguiendo avance de giro sobre el sitio. “Revisar visualmente garras” tampoco define aprobación: el runtime coloca el hueso terminal a 0,66/0,88 unidades del suelo y error IK pequeño no demuestra contacto de malla. Fijar marcha/giro en plano y pendiente con vértices de punta/suela identificados, tolerancia en apoyo y deslizamiento máximo; vídeo lateral cercano debe mostrar zancada suficiente, mirada frontal y ausencia de patinaje. Conservar como referencia visual el cuerpo que el usuario ya considera natural. Huella: `d02 marcha y postura sin condicion suficiente`; estado: **nuevo**.

2. **BLOQUEANTE — D03/D04: fidelidad comparable al dragón queda sin gate observable.** Material PBR, licencia y ausencia de cubos también los cumple un caballero de muy bajo detalle; falta trasladar el pedido de modelos comparables al dragón a una condición de aceptación. Fijar comparación visual en el mismo render/luz, con dragón, caballero, torreta y fortaleza a distancia normal de juego y de contacto; revisar textura, silueta, articulaciones y coherencia de escala. Registrar assets candidatos y elección antes de integrar; un recurso que sólo cumple licencia no aprueba calidad. No hace falta inventar un umbral de polígonos. Huella: `d03 fidelidad comparable al dragon`; estado: **nuevo**.

**RECOMENDACIONES (no bloquean):** D01 debe medir contra la superficie física/renderizada del punto de cada vértice y documentar transformaciones/bind poses; `terrain.gd` usa interpolación de alturas y geometría triangulada que no conviene asumir idénticas. D04 debería fijar duración y estadístico del benchmark (por ejemplo, 60 s de combate y p95 de frame time), número de enemigos y resolución de render efectiva. D06 debería concretar el disparador de liberar la reliquia y el volumen de escape, para que D07 pruebe victoria prematura, derrota durante objetivos y reinicio de todas las fases. Registrar también el protocolo/runner previsto para entrada real y el vínculo a la evidencia, además de nombrar Godot headless/Metal.

Desacuerdos: ninguno registrado. Decisión: corregir estos dos criterios y revisar sólo sus cambios antes de editar runtime. La separación de modelos requerida por la skill debe verificarse en el registro del orquestador; no se presume satisfecha con este informe.

Idea 10x, a ~2x esfuerzo: convertir la ruta de aterrizaje, marcha y asedio en una repetición determinista con vídeo y mediciones sincronizadas; cada futura regresión podrá compararse con la misma secuencia.

Resultado ronda 1: **2 bloqueantes**.

## Ronda 2 — 2026-10-04

Mismo revisor y alcance documental, sin cambios de runtime. Artefacto revisado: SHA-256 `8216d26e95b2d15cab6b693a6447fd6b3de57be1b812783c9c174caf2516520b`.

- `d02 marcha y postura sin condicion suficiente`: **corregido**. Se fijaron zancada, orientación neutral del hocico después de modificadores, precisión/tiempo de seguimiento, límites anatómicos, apoyo, penetración y deslizamiento, con vídeo de transiciones. La cabeza mirando al suelo y los pasos demasiado cortos ya pueden causar rechazo explícito.
- `d03 fidelidad comparable al dragon`: **corregido**. Se exige evidencia cercana/conjunta con el dragón y se describen detalle, articulación, materiales y estilos rechazados. El tamaño de textura complementa esa inspección; no la sustituye.
- **D08–D10, requisitos nuevos:** sin bloqueantes. Planeo distingue neutralidad de giro y añade umbrales/vídeo; entorno requiere comparación visual por zonas; colisión cubre volumen visible final, velocidad, frontal/lateral y respuesta sin atravesar. Están asignados a slices y sujetos al cierre D07.

**Recomendaciones, sin nueva ronda:** medir además deslizamiento acumulado por apoyo, porque 1,5 cm/frame permite patinaje sostenido; para D08 elegir y registrar antes del test el umbral alternativo si el rig es asimétrico; fijar tolerancia de separación del suelo para la clasificación de pata apoyada. Son endurecimientos de medición: el vídeo y los requisitos explícitos existentes ya impiden aprobar estos defectos visibles.

Desacuerdos: ninguno. Conteo: **2 → 0**. Decisión documental: **aprobado para iniciar implementación**. Se mantiene la salvedad de procedencia/modelo declarada en ronda 1; este informe no certifica por sí solo el requisito de otro modelo.

BLOQUEANTES: 0
FIN DEL INFORME
