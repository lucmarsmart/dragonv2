# Entorno del asedio: fuentes y decisiones

Revisión D03/D04/D09, 2026-10-04. Todo se procesa localmente; no se envían datos personales a APIs. Descargas de modelos públicos autorizados; no compra, extracción de juegos ni publicación.

## Modelos originales y derechos

- [Poly Haven Modular Fort 01](https://polyhaven.com/a/modular_fort_01), Rico Cilliers, CC0: módulos de mampostería envejecida, torres cilíndricas, almenas, escaleras y portón. Geometría original de 28K triángulos en el conjunto y PBR 4K. Se instancia el kit con escala métrica y colisión triangular real; no se sustituye por un castillo de cubos.
- [Coast Rocks 05](https://polyhaven.com/a/coast_rocks_05), Rob Tuytel, CC0: escaneo fotogramétrico de roca erosionada. LOD0/1 locales reducidos con Blender oficial, preservando UV y PBR 2K; formaciones en ribera, base de montaña y piedras del santuario.
- [Mature Fir Tree 01](https://polyhaven.com/a/fir_tree_01), Rob Tuytel (fotografía), Rico Cilliers (modelo), CC0: variante A de abeto maduro, 18.75m antes de variación de tamaño. Se preservan las caras de ramitas con su alfa fotográfico y se simplifica sólo la madera escaneada. GLB con PBR 2K. Los LOD lejanos también son tridimensionales: tronco original simplificado y fragmentos de ramitas originales distribuidos por la copa, ampliados para conservar cobertura subpíxel. El atlas experimental no se instancia; mapas con mipmaps. Los árboles jóvenes investigados antes quedan fuera del runtime.
- [Namaqualand Cliff 01](https://polyhaven.com/a/namaqualand_cliff_01), Jenelle van Heerden (fotografía), Rico Cilliers (modelo), CC0: escaneo de pared rocosa erosionada, descargado del [repositorio GitHub fijado](https://github.com/Papyszoo/CC0-Public-Domain-Models/tree/77343cac874f06b73d16ad0063339df7c9ca254c/packs/polyhaven-nature-rocks/models/namaqualand_cliff_01), con licencia contrastada contra el autor original. Forma de 94,369 triángulos instalada en la ladera al este de la fortaleza, colisión de su superficie real en capa2.
- [Grass Medium 01](https://polyhaven.com/a/grass_medium_01), Rob Tuytel/Rico Cilliers, CC0: mata de hierba tridimensional y mapas PBR 2K; reemplaza el atlas de pasto generado anterior.
- [Large Castle Door](https://polyhaven.com/a/large_castle_door), Tina, CC0: madera, herrajes, remaches y tiradores modelados, PBR 2K.
- [GitHub Khronos Lantern](https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/Lantern), Microsoft / sbtron, CC0-1.0: modelo de farol de madera con PBR, instalado en accesos y santuario. [Licencia original](https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/Lantern/README.md). Uso real de un modelo encontrado en GitHub, no solamente enlace a un catálogo.
- [Licencia primaria Poly Haven](https://polyhaven.com/license): CC0 permite modificar y distribuir los propios modelos/texturas. Los renders promocionales de su sitio tienen derechos separados; se citan como referencia visual, no se incluyen en el producto.

Sponza se investigó en GitHub Khronos y se descartó: su [licencia original](https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/Sponza/LICENSE.md) identifica Cryengine Limited License Agreement. No se confunde la licencia del repositorio con los derechos de cada modelo.

El manifiesto `environment-assets.json` conserva URL de cada descarga, autor/origen, resolución, tamaño y MD5 original verificado. `environment-lods.json` registra la reducción de geometría. Los GLB derivados tendrán SHA256 en manifiesto final.

## Principios aplicados

El valle deja de superponer un río sobre un plano rectangular. El lecho y las riberas son parte de una sola superficie triangulada, con una cinta de agua que sigue su cauce sinuoso y ancho variable. Se incorporan flujo, absorción por profundidad, refracción del fondo y espuma cerca de las orillas. La reflexión especular usa el cielo y un ReflectionProbe del valle. El renderer de integración es Forward+, con SSAO y SSIL moderados; no se confunde esa reflexión con un SSR completo. [Documentación primaria de entorno Godot](https://docs.godotengine.org/en/stable/classes/class_environment.html).

El relieve añade detalle a varias escalas y un macizo de crestas erosionadas en el horizonte; los afloramientos cercanos son escaneos reales. La coloración del suelo usa fotografías PBR con variación de escala y vegetación contenida; se elimina la saturación verde uniforme. Sol y disco solar comparten la misma dirección, con cielo como luz ambiente/reflejo y niebla de distancia.

El patio de 144×124m y la brecha sur de 24m quedan despejados; el acceso tiene pendiente suave y las plataformas de artillería son alcanzables (4.5m por encima del suelo). La altura analítica devuelve la interpolación baricéntrica de los triángulos de colisión, no una altura bilineal diferente. `ground_surface` ofrece un rayo al suelo físico; fortaleza/rocas son obstáculos en capa2 y los pedestales transitables usan capas1+2.

## Límites de aceptación

Conteo de árboles, resolución o polígonos no prueba naturalidad. Revisar capturas reales tierra/ribera/montaña/fortaleza, consistencia de escalas junto al dragón, sombras y vistas de vuelo. La medida de GPU/combate completo pertenece a integración D07. No se declara fotorrealismo porque el shader compile o las colisiones pasen.

El santuario contiene un huevo de dragón modelado para este proyecto, de 3.7m de alto, con normal fotográfica y dos cadenas de hierro tridimensionales. `liberate_nest()` retira las cadenas y despierta la cáscara; `reset_nest()` restaura ambas señales para reintentar. Es un huevo cautivo, no una cría animada descargada.

## Evidencia de esta entrega

`environment-physics.json`: 180 muestras de altura física frente a la interpolación triangular (error máximo 0.000201m), ocho spawns de soldados, tres plataformas, puerta libre, muro obstructivo, montaña colisionable y liberación/reinicio de cadenas. Sin fallos. La apertura final del nido retira tres piedras del frente sur para evitar bloquear el hocico detectado por el playthrough.

Capturas reales de Godot 4.7.2, Metal Forward+, 1280×720: `environment-fortress.png`, `environment-fortress-air.png`, `environment-river.png`, `environment-mountain.png`, `environment-pine.png`, `environment-nest-captive.png`, `environment-nest-free.png`. Las capturas se actualizaron después de abrir el nido por el sur y de sustituir el LOD lejano; se añade `environment-river-close.png` para observar fondo/reflejo/flujo. Se sustituyeron los atlas cruzados lejanos por LOD volumétrico, después de que la revisión independiente los rechazara por parecer recortes. Los LOD conservan volumen y ramas, con menor detalle; no se declara calidad fotográfica para todo el escenario. Queda la aceptación visual y medición de combate integrado a cargo del orquestador, sobre runtime congelado.

Coordenadas para anatomía sobre terreno real: (450,66.45,220), pendiente local 15.19°, gradiente de subida X+ / Z−; alternativa (380,61.19,290), 14.97°. Tomar Y exacta con `landscape.ground_surface` antes de colocar el dragón. Acantilado `GithubNamaqualandCliffScan`: X462/Z145, cara hacia oeste, ~33m ancho y 20m alto, capa2; montaña exterior física en X1450/Z−1600, capa1. `environment-integrity.json` fija SHA256 de runtime y derivados relevantes.

## Revisión D09 posterior

La revisión independiente rechazó los recortes lejanos, el amarillo uniforme y el río sólido turquesa. Cambios finales: LOD1/2/3 volumétricos de 1,017/513/218 triángulos reales, medidos por índices GLB/3; distancias3D a copa 32/75/230m; selección determinista de fragmentos de ramitas del abeto A, tronco original simplificado y cobertura aumentada. El suelo mezcla roca sobre pendientes y tonos de humedad en manchas amplias; el agua conserva ondulación normal de escala mayor en vistas lejanas y reduce la reflexión azul uniforme. Se verificó su carga/render en Metal Forward+; la medida de FPS de combate debe repetirse sobre esta versión. Superficies físicas, colliders, accesos y coordenadas se conservan.

Comandos reproducibles desde la raíz del proyecto:

```sh
tools/godot.sh --headless --editor --import --path .
tools/godot.sh --headless --path . --script scripts/verify_siege_environment.gd
tools/godot.sh --path . --script scripts/capture_siege_environment.gd
```

La captura final escribió ocho vistas sin errores de script o carga. Al cerrar, Godot reporta siete Texture RIDs retenidos del ReflectionProbe: limitación observada del cierre de este harness, no evidencia de pérdida acumulativa durante una partida. El bosque lejano se simplifica y las montañas son un relieve procedural basado en la malla original; no se presenta toda la escena como fotogrametría. Las formaciones cercanas sí usan escaneos reales con fuente y derechos verificados.

## Rendimiento: corrección final

El diagnóstico original reprodujo 26.2FPS sin fuego y 26.5 con fuego: las partículas no eran la causa principal. Ocultar sólo el bosque produjo65.3FPS; ocultar sólo sus LOD detallados produjo38.1. El cuello estaba en el coste de geometría/material de follaje, amplificado por depth/sombras, y en la distanciaXZ que trataba copas bajo la cámara de vuelo como próximas. Se sustituye el LOD intermedio de43,349 tri por1,017, se reduce el lejano a218 manteniendo volumen original, se calcula distancia3D a la copa y se seleccionan esferas de árbol contra el frustum antes de enviar cada MultiMesh. Margen de frustum y actualización5Hz evitan cortes al girar. Modelos/colliders y acceso físico quedan intactos.

El original exportaba hojas como alphaMode BLEND. El runtime usa alpha scissor0.25 conservando el alfa fotográfico para permitir profundidad y sombras de copa; normal y roughness detallados se reservan al LOD próximo. La iluminación SSAO/SSIL, suelo y río no se redujeron para ganar FPS.

Último diagnóstico limpio10s conF:64.63FPS/p9516.59ms, sólo un proceso Godot; no es el certificado de60s. Dos perfiles intermedios coincidieron con pruebas headless de CPU y se conservan como diagnóstico, no aceptación. El timestamp GPU devuelve0 en este Metal y se trata como no disponible. El monitor RENDER_TOTAL_PRIMITIVES_IN_FRAME cuenta vértices/índices e incluye pases; no es un conteo de triángulos únicos. Datos, límites y comandos en `environment-profile-summary.md`.
