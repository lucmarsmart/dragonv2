# Assets del asedio: procedencia y contrato de integración

Verificados el 5 de octubre de 2026. Los archivos usados son locales: el juego no consulta proveedores ni envía información a APIs. Investigación y descargas contienen sólo términos genéricos y recursos públicos, sin datos personales.

## Caballero

`assets/characters/knight.glb` usa la **malla efectiva descargada desde GitHub**: [SaschaWillems/Vulkan-Assets, models/armor/armor.gltf](https://github.com/SaschaWillems/Vulkan-Assets/tree/a27c0e584434d59b7c7a714e9180eefca6f0ec4b/models/armor). Su licencia específica adjunta identifica a **piacenti**, [Knight, OpenGameArt](https://opengameart.org/content/knight-2), bajo [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/). No se dedujo la licencia del modelo desde la del código del repositorio.

Los mapas PBR originales del autor —color, normal, metalness y roughness, todos 2048×2048— se recuperaron del `.blend` empacado en `piacenti_armored_knight.zip`, descargado de esa misma página primaria. La malla GitHub conserva UV originales y reconoce anatomía, placas de armadura, grabados, guanteletes, espada y escudo. Se reconstruyeron materiales Principled→glTF PBR, se normalizó escala y se creó rig/animaciones localmente. **El original era estático**; las animaciones no son captura de movimiento ni clips del autor original.

Contrato: +Y arriba, **−Z adelante**, pies Y=0, altura 1.9m. AABB de reposo medida en Godot: posición (−0.733318, 0, −0.301453), tamaño (1.637386, 1.9, 1.162813)m; incluye espada y escudo. Tiene 17 huesos, 15,843 vértices exportados y 19,217 triángulos, dos superficies/mallas que comparten material. Godot genera `Skeleton3D` y `AnimationPlayer`.

| Clip | Duración | Uso |
|---|---:|---|
| `idle` | 2.0s | respiración, cabeza contenida; repetir |
| `walk_loop` | 1.133333s | marcha en sitio; repetir, traslación por AI |
| `sword_attack` | 1.133333s | anticipación 0–0.41s, golpe aprox. 0.41–0.82s, recuperación |
| `hit_chest` | 0.466667s | reacción al daño |
| `death` | 1.8s | caída, detener al final |

En `death` se corrigió la altura sobre **los vértices deformados**, después de encontrar penetración de 20.8cm. La sonda independiente Godot, 21 poses por clip y todos los vértices skinned, da mínimo Y≈−0.000202m al caer y Y≈0 en idle/walk/attack. Esto verifica el asset sobre plano; contacto con pendientes y navegación corresponden a la integración de actores. Las animaciones son una primera pasada de rig y deben revisarse en movimiento dentro de la misión, sin presentar el test de geometría como una aprobación visual universal.

Crédito requerido y modificaciones: **“Knight — piacenti, CC BY 3.0; malla distribuida por Sascha Willems. Adaptación: materiales PBR, escala, rig y animaciones para Dragon v2.”** Enlazar la fuente primaria y licencia en créditos accesibles del juego.

## Ballista

`assets/siege/weapons/ballista.glb` incorpora la malla real `siege-ballista.glb` de [Hidencod/tge-assets, Castle Kit](https://github.com/Hidencod/tge-assets/blob/1f7dee9076ee848773f08fd632ab4e4e73357777/packs/castle-kit/siege-ballista.glb). El repositorio identifica a Kenney y licencia CC0; esto se corroboró contra [Castle Kit, página primaria de Kenney](https://kenney.nl/assets/castle-kit). Se conserva el bastidor y culata del recurso descargado; se eliminan ruedas/banderines, se cambia el shader de paleta y se amplía con pedestal, rodamiento, arco laminado curvo, cuerdas tensadas, haces de torsión, carril de virote, tambor enrollador, manivelas, abrazaderas y remaches modelados localmente.

La madera utiliza albedo/normal OpenGL/roughness **2K reales de escaneo fotométrico** [ambientCG Wood060](https://ambientcg.com/view?id=Wood060), por Lennart Demes, [CC0](https://docs.ambientcg.com/license/). El hierro y latón responden mediante metallic/roughness físicos. Se han agrupado 158 piezas en **6 superficies/mallas por material y pivote**, 47k triángulos aproximadamente, para reducir draw calls. El modelo no consiste sólo en primitivas: conserva malla descargada y tiene mecanismo reconocible con detalles de construcción.

Contrato: base Y=0, −Z adelante. `Ballista/AimYaw/AimPitch/Muzzle`: girar `AimYaw.rotation.y`; elevar `AimPitch.rotation.x`. `AimPitch.position=(0,2.1,0)` y `Muzzle.position=(0,0,−3.3)` respecto a AimPitch. Los hijos mantienen su origen mientras se animan los pivotes; no se necesita rig ni animation player. AABB medida: posición (−2.381138,0,−3.12222), tamaño (4.762277,2.57,4.872221)m. El volumen ancho incluye extremos del arco. Colisión/navegación y límites de disparo son responsabilidad del actor, usando la misma superficie del terreno y fortaleza.

Créditos recomendados: **“Ballista base — Kenney, Castle Kit, CC0, distribución GitHub Hidencod/tge-assets. Madera — Lennart Demes / ambientCG Wood060, CC0. Adaptación del mecanismo y materiales para Dragon v2.”**

## Virote opcional

`assets/siege/weapons/bolt.glb` proviene de [Ballista Bolt, Kutejnikov/drumdorf, OpenGameArt](https://opengameart.org/content/ballista-bolt), CC BY 3.0 explícito del autor. OBJ convertido a GLB localmente, longitud 1.8m, eje −Z y origen central. Incluye mapas 2048×256 albedo/normal/metallic/roughness. Crédito: **“Ballista Bolt — Kutejnikov (drumdorf), CC BY 3.0; conversión y escala para Dragon v2.”**

## Evidencia y reproducción

`tests/artifacts/siege-assets/` contiene close-ups de idle, marcha, ataque, muerte y ballista, renderizados en **Godot 4.7.2 / Metal 4 / Apple M5**, no thumbnails de páginas ni renders offline. En el inspector directo GLTF se generan mipmaps para revisar textura sin alias; la importación normal del proyecto debe conservar filtrado lineal y mipmaps. Estas capturas no sustituyen el requisito de vista conjunta con dragón ni el benchmark de combate; el responsable de integración debe generar esas evidencias después de incorporar actores.

`assets/characters/probe_asset.gd` recorre todos los vértices con pesos de skin, matrices bind y poses de huesos. Ejecución:

```sh
tools/godot.sh --headless --path . --script assets/characters/probe_asset.gd -- "$PWD/assets/characters/knight.glb"
```

Conversores: `assets/characters/build_knight.py`, `assets/siege/weapons/build_ballista.py`, `build_bolt.py`. Blender oficial 4.5.9 arm64 descargado desde download.blender.org, instalación aislada `/tmp/dragon-blender/Blender.app/Contents/MacOS/Blender`. Para regenerar caballero, extraer `armor.blend` desde el ZIP original y ejecutar Blender `-b armor.blend -P assets/characters/build_knight.py`; para ballista, `-b -P assets/siege/weapons/build_ballista.py`. Fuentes con `.gdignore` para no intentar importar los originales Blender/ZIP durante el arranque.

El manifiesto `assets/siege/weapons/asset-manifest.json` registra SHA-256 de fuentes y salidas; no se compara calidad contando triángulos. Se descartaron el caballero mid-poly de crownjoshua (apariencia estilizada), AutoSprite Sentinel (su GLB real no correspondía a la descripción del sitio y carecía de PBR metálico), Quaternius/KayKit (estilo cartoon) y candidatos de Sketchfab/CGTrader/Fab cuya descarga requería login. No se extrajeron modelos de juegos, se eludieron cuentas ni se compraron activos.

Idea 10× con ~2× esfuerzo: conservar este rig y aplicar un segundo atlas/heráldica a los caballeros de élite, diferenciando telegráficos y amenaza sin añadir geometría o memoria de animación por entidad.
