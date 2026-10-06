# Licencias y atribución de assets — Dragon v2

Registro verificado el **5 de octubre de 2026**. Cada licencia corresponde a los archivos indicados y a su fuente artística; la licencia del código de un repositorio no se usa para inferir la de un modelo.

## Caballero: Knight / armadura de piacenti — CC BY 3.0

**Autor:** piacenti. **Distribución de la malla:** Sascha Willems, Vulkan-Assets.

- Original: [Knight, OpenGameArt](https://opengameart.org/content/knight-2).
- Malla GitHub utilizada: [models/armor/armor.gltf, commit a27c0e584434d59b7c7a714e9180eefca6f0ec4b](https://github.com/SaschaWillems/Vulkan-Assets/blob/a27c0e584434d59b7c7a714e9180eefca6f0ec4b/models/armor/armor.gltf).
- [Licencia específica del modelo en ese commit](https://github.com/SaschaWillems/Vulkan-Assets/blob/a27c0e584434d59b7c7a714e9180eefca6f0ec4b/models/armor/license.txt), conservada en `assets/characters/source/piacenti_github_license.txt`.
- Texturas originales empacadas: [armored knight.zip, descarga del autor](https://opengameart.org/sites/default/files/armored%20knight.zip), conservada como `assets/characters/source/piacenti_armored_knight.zip`.
- Licencia: [Creative Commons Attribution 3.0 Unported](https://creativecommons.org/licenses/by/3.0/), [texto legal completo](https://creativecommons.org/licenses/by/3.0/legalcode).

**Archivo derivado:** `assets/characters/knight.glb`. **Modificaciones:** conversión de materiales originales a PBR con mapas 2K del autor, escala 1.9m, orientación −Z, esqueleto de 17 huesos, pesos, clips de reposo/marcha/ataque/daño/muerte y corrección del contacto de la malla al caer. El modelo original era estático; las animaciones se crearon para Dragon v2.

**Atribución:** “Knight — piacenti, CC BY 3.0; malla distribuida por Sascha Willems. Adaptación para Dragon v2: materiales PBR, escala, rig y animaciones.” Conservar título, autor, enlaces a original/licencia y declaración de modificaciones cuando se distribuya el derivado. No se atribuye respaldo del autor al proyecto.

## Ballista: Kenney Castle Kit — CC0 1.0

**Autor:** Kenney. **Distribución GitHub:** Hidencod/tge-assets.

- Original y licencia primaria: [Kenney Castle Kit](https://kenney.nl/assets/castle-kit).
- Malla GitHub utilizada: [packs/castle-kit/siege-ballista.glb, commit 1f7dee9076ee848773f08fd632ab4e4e73357777](https://github.com/Hidencod/tge-assets/blob/1f7dee9076ee848773f08fd632ab4e4e73357777/packs/castle-kit/siege-ballista.glb).
- [Licencia del pack redistribuido](https://github.com/Hidencod/tge-assets/blob/1f7dee9076ee848773f08fd632ab4e4e73357777/LICENSE), contrastada con la página primaria de Kenney; copia en `assets/siege/weapons/source/kenney_github_LICENSE.txt`.
- Licencia: [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/), [texto legal completo](https://creativecommons.org/publicdomain/zero/1.0/legalcode).

**Archivo derivado:** `assets/siege/weapons/ballista.glb`. **Modificaciones:** se conserva bastidor/culata del modelo descargado; se eliminan ruedas y banderines, se reemplaza la paleta por PBR y se añaden pedestal, rodamiento, pivotes de puntería, arco laminado, haces de torsión, cuerda, virote, tambor, manivelas, herrajes y remaches. Geometría agrupada por material y pivote para reducir superficies.

**Crédito voluntario:** “Ballista base — Kenney, Castle Kit, CC0; distribución GitHub Hidencod/tge-assets. Mecanismo y materiales adaptados para Dragon v2.”

### Madera de la ballista: ambientCG Wood060 — CC0 1.0

**Autor:** Lennart Demes / ambientCG. [Wood060](https://ambientcg.com/view?id=Wood060), [licencia primaria ambientCG](https://docs.ambientcg.com/license/), [CC0 1.0, texto legal](https://creativecommons.org/publicdomain/zero/1.0/legalcode).

**Archivos:** `assets/siege/weapons/textures/Wood060_2K-JPG_{Color,NormalGL,Roughness}.jpg`, también embebidos en `ballista.glb`. Fuente: [Wood060_2K-JPG.zip](https://ambientcg.com/get?file=Wood060_2K-JPG.zip), conservada en `source/wood060_2k.zip`. **Modificaciones:** asignación UV, tono de albedo más oscuro y amplitud normal reducida en material; imágenes originales conservadas. **Crédito voluntario:** “Wood060 — Lennart Demes / ambientCG, CC0.”

## Virote: Ballista Bolt — CC BY 3.0

**Autor:** Kutejnikov, también denominado drumdorf por el propio autor. Original: [Ballista Bolt, OpenGameArt](https://opengameart.org/content/ballista-bolt). Fuente: [ballista_bolt.7z](https://opengameart.org/sites/default/files/ballista_bolt.7z), conservada en `assets/siege/weapons/source/kutejnikov_ballista_bolt.7z`. Licencia: [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/), [texto legal completo](https://creativecommons.org/licenses/by/3.0/legalcode).

**Archivo derivado:** `assets/siege/weapons/bolt.glb`. **Modificaciones:** OBJ→GLB, reconstrucción PBR desde mapas originales 2048×256, longitud 1.8m, orientación −Z y origen central.

**Atribución:** “Ballista Bolt — Kutejnikov (drumdorf), CC BY 3.0; conversión, materiales y escala para Dragon v2.” Conservar original/licencia enlazados y esta declaración de modificaciones al distribuirlo.

## Entorno: Poly Haven — CC0 1.0

[Licencia primaria Poly Haven](https://polyhaven.com/license) y [CC0 1.0, texto legal completo](https://creativecommons.org/publicdomain/zero/1.0/legalcode). La licencia de assets cubre modelos y texturas descargables; no se incorporan renders promocionales del sitio.

| Recurso y fuente primaria | Autoría verificada | Archivos locales | Modificaciones para Dragon v2 |
|---|---|---|---|
| [Modular Fort 01](https://polyhaven.com/a/modular_fort_01) | Rico Cilliers | `assets/siege/environment/fort/` | kit instanciado en fortaleza, escala/posiciones/colisiones; mapas originales 4K |
| [Large Castle Door](https://polyhaven.com/a/large_castle_door) | Tina | `assets/siege/environment/gate/` | instancia en acceso, escala/posición/colisión; mapas originales 2K |
| [Coast Rocks 05](https://polyhaven.com/a/coast_rocks_05) | Rob Tuytel | `assets/environment/rock/` | reducción local de geometría a LOD0/1; UV y PBR 2K conservados |
| [Pine Sapling Small](https://polyhaven.com/a/pine_sapling_small) | Rob Tuytel: fotografía; Rico Cilliers: modelado | `assets/environment/pine/` | variante A seleccionada, tres LOD y atlas derivados durante investigación; no se usa en el runtime final |
| [Mature Fir Tree 01](https://polyhaven.com/a/fir_tree_01) | Rob Tuytel: fotografía; Rico Cilliers: modelado | `assets/environment/fir/` | variante A, PBR 2K, reducción de madera; LOD lejanos volumétricos con subconjuntos de ramitas originales, sin atlas cruzados en runtime |
| [Namaqualand Cliff 01](https://polyhaven.com/a/namaqualand_cliff_01) | Jenelle van Heerden: fotografía; Rico Cilliers: modelado | `assets/environment/github_cliff.glb` | escaneo rocoso descargado de GitHub, instancia a escala4 y collider real; bytes GLB conservados |
| [Grass Medium 01](https://polyhaven.com/a/grass_medium_01) | Rob Tuytel: fotografía; Rico Cilliers: modelado | `assets/environment/grass/` | instancias de hierba sobre terreno; mapas originales 2K |
| [Aerial Grass Rock](https://polyhaven.com/a/aerial_grass_rock) | Rob Tuytel | `assets/environment/aerial_grass_{diff,normal,rough}.jpg` | material de terreno/campos a escala del escenario |
| [Rocky Terrain 02](https://polyhaven.com/a/rocky_terrain_02) | Amal Kumar | `assets/environment/rocky_terrain_02_{diffuse,nor_gl,rough}.jpg` | material de roca/suelo; mapas 2K |
| [Forest Ground 04](https://polyhaven.com/a/forest_ground_04) | Rob Tuytel: fotografía/proceso; Rico Cilliers: ajuste menor | `assets/environment/forest_ground_04_{diffuse,nor_gl,rough}.jpg` | material de suelo forestal; mapas 2K |

Autorías contrastadas con la API pública `https://api.polyhaven.com/info/<recurso>` el 5 de octubre de 2026. Crédito voluntario: “Modelos y texturas de entorno — Poly Haven y los autores indicados, CC0; escala, LOD e integración adaptados para Dragon v2.”

URLs exactas de descargas y MD5 oficiales por archivo: `docs/validation/v2/environment-assets.json`. Ratios de reducción y derivados: `docs/validation/v2/environment-lods.json`. Los SHA-256 de archivos distribuidos aparecen al final de este documento.


### Fuente GitHub del acantilado

[Namaqualand Cliff 01, Papyszoo/CC0-Public-Domain-Models, commit 77343cac874f06b73d16ad0063339df7c9ca254c](https://github.com/Papyszoo/CC0-Public-Domain-Models/blob/77343cac874f06b73d16ad0063339df7c9ca254c/packs/polyhaven-nature-rocks/models/namaqualand_cliff_01/namaqualand_cliff_01.glb). [Licencia del repositorio fijado](https://github.com/Papyszoo/CC0-Public-Domain-Models/blob/77343cac874f06b73d16ad0063339df7c9ca254c/LICENSE), contrastada con el CC0 de la página primaria Poly Haven y sus autores. El archivo descargado conserva sus bytes; escala/rotación/colisión se aplican en runtime.

## Farol: Khronos glTF Sample Assets / Lantern — CC0 1.0

**Autoría original:** © 2017 Microsoft; sbtron, versión inicial. El [registro legal específico del modelo](https://github.com/KhronosGroup/glTF-Sample-Assets/blob/0b4f3a5862f3037c7092206e75c6f2a31a504ca5/Models/Lantern/README.md) también identifica © 2018 Frank Galligan, compresión Draco, bajo CC0. El archivo usado es la variante `glTF-Binary`, sin atribuir la compresión Draco a ese GLB.

Fuente utilizada y comprobada byte a byte: [Models/Lantern/glTF-Binary/Lantern.glb, commit 0b4f3a5862f3037c7092206e75c6f2a31a504ca5](https://github.com/KhronosGroup/glTF-Sample-Assets/blob/0b4f3a5862f3037c7092206e75c6f2a31a504ca5/Models/Lantern/glTF-Binary/Lantern.glb). Licencia: [CC0 1.0 Universal, texto legal](https://creativecommons.org/publicdomain/zero/1.0/legalcode).

**Archivo local:** `assets/siege/environment/lantern.glb`, SHA-256 `a79458c4b02d695187a952f23a63b8bf278e7bc3d316a3c2a314f2d6974181f1`, idéntico a la fuente fijada. **Modificaciones:** GLB conservado sin cambios; escala/posición/colisiones de instancia en el escenario. Los `lantern_0.png`…`lantern_3.png` son texturas extraídas por la importación local del mismo modelo. **Crédito voluntario:** “Lantern — Microsoft / sbtron, CC0; distribución Khronos glTF Sample Assets.”

## Huellas de fuentes y archivos distribuidos

SHA-256 calculado sobre los archivos locales, sin archivos generados por el importador `.import`/`.godot`. Commit identifica la versión de la fuente GitHub; SHA-256 identifica los bytes de cada fuente/derivado. Los ZIP/7z conservados permiten recuperar los originales.

| Archivo | SHA-256 |
|---|---|
| `assets/characters/knight.glb` | `ff7418d0dcad2598b79874dcec44e0b49c5060101b2cc7c0bfaef9aed1567796` |
| `assets/characters/source/piacenti_armored_knight.zip` | `edea99305ea1dfffbe56434498693e325d909cf638845f1a473c6d0993aca100` |
| `assets/characters/source/piacenti_github_armor.gltf` | `61096834b3b822a630a261230aada947fb68a33f09061463670f6e9d7c27654a` |
| `assets/characters/source/piacenti_github_license.txt` | `3a9e2ad7ce210179d4c04034d9882feef31642c9051d0132adb766a3d1d48aed` |
| `assets/siege/weapons/ballista.glb` | `f284cbd3e22f0012ae8afd7cfd2c9c2e82c0097f152a3dbea373caaa1f797f22` |
| `assets/siege/weapons/ballista_Wood060_2K-JPG_Color.jpg` | `0473543a25a05f4f10a0fd85c373abe1ce5ce34eb72a12266cb21395b435b478` |
| `assets/siege/weapons/ballista_Wood060_2K-JPG_NormalGL.jpg` | `e7bf6ad2192404b98a3d8878b5a0e43731b4ea3b6761dbe153531a79e168cb0f` |
| `assets/siege/weapons/bolt.glb` | `1b11ae36228533e415436b82d22ece363371f0109fbf5a8d0f003b66de197ca0` |
| `assets/siege/weapons/source/kenney_ballista_github.glb` | `3905ff533ad6d836cab57986871ff58938f5ec572cf8e5154b5651d4368de10f` |
| `assets/siege/weapons/source/kenney_github_LICENSE.txt` | `6913dd72bdc20532b7f02d86469058f45d886c9dabf60831275ed16927aa523b` |
| `assets/siege/weapons/source/kenney_tower-defense-kit.zip` | `d4c887680b709218315e4e1c17ae18c160635dcdfc4199763eeba97c02c77f00` |
| `assets/siege/weapons/source/kutejnikov_ballista_bolt.7z` | `a9dd81b97ffdd5ef0a75bcf8f98326a9caa1bb50d938285431035956bde29bdb` |
| `assets/siege/weapons/source/wood060_2k.zip` | `54527fac1222a0d59c2a039f5ab83c84eec284936557fb2f87ee30c566594900` |
| `assets/siege/weapons/textures/Wood060_2K-JPG_Color.jpg` | `0473543a25a05f4f10a0fd85c373abe1ce5ce34eb72a12266cb21395b435b478` |
| `assets/siege/weapons/textures/Wood060_2K-JPG_NormalGL.jpg` | `e7bf6ad2192404b98a3d8878b5a0e43731b4ea3b6761dbe153531a79e168cb0f` |
| `assets/siege/weapons/textures/Wood060_2K-JPG_Roughness.jpg` | `57971f79d5c7d6c0cdb3fb296b13d84a553d75cc259d3642788836c9a5e0ef59` |
| `assets/environment/aerial_grass_diff.jpg` | `1a2ddfa4652adbe00447b940c40019d46f4b88245bc1b341cdf622c2110b7bc5` |
| `assets/environment/aerial_grass_normal.jpg` | `c6aa14b042ce243f93a6ca807f46a085711c23ad316b104578e92df7770ee285` |
| `assets/environment/aerial_grass_rough.jpg` | `fc0fff40e3378f2f54d225db6e3e566a8563bb2c143eef0f09b543c9d4698776` |
| `assets/environment/forest_ground_04_diffuse.jpg` | `24b8aaf4c8547305d80b0e029ec365219ab1b90748d4ca5651bdc9e75bfde5e6` |
| `assets/environment/forest_ground_04_nor_gl.jpg` | `b37ac799ed410976541e0011c246fca254e74eaa3f096ae7a7d74178db5a6d9b` |
| `assets/environment/forest_ground_04_rough.jpg` | `24194662948424c323c75e0918461ad9d38bc0a275022000144f248b3efb4119` |
| `assets/environment/grass/grass_medium_01.bin` | `f4587cabdb96a2e96d8be644923dc954a248edfaaa717a0ff224cacb898bee1f` |
| `assets/environment/grass/grass_medium_01.gltf` | `aed63929a83fb694e6884e3a5c0fdb962ab8cf9153830247c8201a482ff02664` |
| `assets/environment/grass/textures/grass_medium_01_arm_2k.jpg` | `7b593b1c470c1817b937bb3ca00da7e4b27ca00120e98b06b43bb3a7d5810aa1` |
| `assets/environment/grass/textures/grass_medium_01_diff_2k.jpg` | `f768aa68daf14f37a92dd96621628a5252b169f4d94b4d1cc830d62cd3ac9e68` |
| `assets/environment/grass/textures/grass_medium_01_nor_gl_2k.jpg` | `245349ce6d1910b3b7474da6013452a5be993f9058be78e17171a0866a6889e9` |
| `assets/environment/pine/pine_impostor.png` | `a947cd179a683b31192102ba0be6523d2c01b2e76018f960246b0e14d9c38412` |
| `assets/environment/pine/pine_lod0.glb` | `4f5197abe716a4cd58171c0a4b2059b84e8f542c1eb4eb9731b715fea9ac4667` |
| `assets/environment/pine/pine_lod0_pine_sapling_small_bark_arm_2k.jpg` | `7afccadf4d239dfbcb99338067bf1b4d0c3316b42021ac2d7cdf17f8dddb7346` |
| `assets/environment/pine/pine_lod0_pine_sapling_small_bark_diff_2k.jpg` | `359bb1be7aab30f5b79d391af9ef088503d6d135d529c9fc06bce60adf28ef60` |
| `assets/environment/pine/pine_lod0_pine_sapling_small_bark_nor_gl_2k.jpg` | `5b0cc5c45f8f42c2bb7f20518f6a06485d4eaa5444380907916e278517cc5b1e` |
| `assets/environment/pine/pine_lod0_pine_sapling_small_twig_arm_2k.jpg` | `f7907164f65ac089d997a6759db63c3504d25a97ad6c26c9ef5a7f58b985d11d` |
| `assets/environment/pine/pine_lod0_pine_sapling_small_twig_diff_2k.png` | `5179b1b58e0d11f3eb0489a4c04d353dd53ac0e33c18d6611d394539a1fbcad0` |
| `assets/environment/pine/pine_lod0_pine_sapling_small_twig_nor_gl_2k.jpg` | `b28ea2a70a480b1931f328315fbe65a57e3db723c506839f670ced2626482a26` |
| `assets/environment/pine/pine_lod1.glb` | `b5d8e0641199fa0ba3f1f5337c55344dbe2a66bf6ad9530a0c9b2002ec55710e` |
| `assets/environment/pine/pine_lod1_pine_sapling_small_bark_arm_2k.jpg` | `7afccadf4d239dfbcb99338067bf1b4d0c3316b42021ac2d7cdf17f8dddb7346` |
| `assets/environment/pine/pine_lod1_pine_sapling_small_bark_diff_2k.jpg` | `359bb1be7aab30f5b79d391af9ef088503d6d135d529c9fc06bce60adf28ef60` |
| `assets/environment/pine/pine_lod1_pine_sapling_small_bark_nor_gl_2k.jpg` | `5b0cc5c45f8f42c2bb7f20518f6a06485d4eaa5444380907916e278517cc5b1e` |
| `assets/environment/pine/pine_lod1_pine_sapling_small_twig_arm_2k.jpg` | `f7907164f65ac089d997a6759db63c3504d25a97ad6c26c9ef5a7f58b985d11d` |
| `assets/environment/pine/pine_lod1_pine_sapling_small_twig_diff_2k.png` | `5179b1b58e0d11f3eb0489a4c04d353dd53ac0e33c18d6611d394539a1fbcad0` |
| `assets/environment/pine/pine_lod1_pine_sapling_small_twig_nor_gl_2k.jpg` | `b28ea2a70a480b1931f328315fbe65a57e3db723c506839f670ced2626482a26` |
| `assets/environment/pine/pine_lod2.glb` | `6febfbcdfe9bfde9d165537e551d04634cd7f58988316c5d0db4f3278938c1c6` |
| `assets/environment/pine/pine_lod2_pine_sapling_small_bark_arm_2k.jpg` | `7afccadf4d239dfbcb99338067bf1b4d0c3316b42021ac2d7cdf17f8dddb7346` |
| `assets/environment/pine/pine_lod2_pine_sapling_small_bark_diff_2k.jpg` | `359bb1be7aab30f5b79d391af9ef088503d6d135d529c9fc06bce60adf28ef60` |
| `assets/environment/pine/pine_lod2_pine_sapling_small_bark_nor_gl_2k.jpg` | `5b0cc5c45f8f42c2bb7f20518f6a06485d4eaa5444380907916e278517cc5b1e` |
| `assets/environment/pine/pine_lod2_pine_sapling_small_twig_arm_2k.jpg` | `f7907164f65ac089d997a6759db63c3504d25a97ad6c26c9ef5a7f58b985d11d` |
| `assets/environment/pine/pine_lod2_pine_sapling_small_twig_diff_2k.png` | `5179b1b58e0d11f3eb0489a4c04d353dd53ac0e33c18d6611d394539a1fbcad0` |
| `assets/environment/pine/pine_lod2_pine_sapling_small_twig_nor_gl_2k.jpg` | `b28ea2a70a480b1931f328315fbe65a57e3db723c506839f670ced2626482a26` |
| `assets/environment/rock/rock_lod0.glb` | `de9da0dd828934fcb59dae36b527f3f15cc526756e43b69bdaabfcf5f730a31f` |
| `assets/environment/rock/rock_lod0_coast_rocks_05_arm_2k.jpg` | `e610fb57fa8539249432ba0435e6d8bd8df22833b423b8f33737d8143ef17d25` |
| `assets/environment/rock/rock_lod0_coast_rocks_05_diff_2k.jpg` | `3e95fdf0955df96007bddec6053ddb8809575426337ca3a10901649037f9e7c7` |
| `assets/environment/rock/rock_lod0_coast_rocks_05_nor_gl_2k.jpg` | `2392a5d3ace4365cb6b7d5fd533c5c214a5e5c0a6e4dbfc84565737888f2c5f0` |
| `assets/environment/rock/rock_lod1.glb` | `5923be84c38d09dbfb498f8b652b2ef43f9d2c71a2c2b9adbb91216f92318c33` |
| `assets/environment/rock/rock_lod1_coast_rocks_05_arm_2k.jpg` | `e610fb57fa8539249432ba0435e6d8bd8df22833b423b8f33737d8143ef17d25` |
| `assets/environment/rock/rock_lod1_coast_rocks_05_diff_2k.jpg` | `3e95fdf0955df96007bddec6053ddb8809575426337ca3a10901649037f9e7c7` |
| `assets/environment/rock/rock_lod1_coast_rocks_05_nor_gl_2k.jpg` | `2392a5d3ace4365cb6b7d5fd533c5c214a5e5c0a6e4dbfc84565737888f2c5f0` |
| `assets/environment/rocky_terrain_02_diffuse.jpg` | `9b042fe0618ffbc3650592456d7d8d265ba9a1cb5ce802f5f1d86b7ee79508a1` |
| `assets/environment/rocky_terrain_02_nor_gl.jpg` | `556ed903180a9431b253fc1c334c769dc4615c5c0f4ef1cedf20533ae8409ce8` |
| `assets/environment/rocky_terrain_02_rough.jpg` | `89f3c7b9e467160a821cbac32a1fdfd75f13cb87c9deeb22099d16677a711126` |
| `assets/siege/environment/fort/modular_fort_01.bin` | `de86e71af4cd5b37006914a8e7ae7de59b245b73364317f1886285a6aa797f57` |
| `assets/siege/environment/fort/modular_fort_01.gltf` | `bc8b7a4c959a23c1cb7c336e7db2891b268cf61cda2a71627437f97c91ac797d` |
| `assets/siege/environment/fort/textures/modular_fort_01_plaster_arm_4k.jpg` | `b276fe3c7e102761e7b9dad216b0f08e2830f0dc1b4648b07fcca94091887695` |
| `assets/siege/environment/fort/textures/modular_fort_01_plaster_diff_4k.jpg` | `44cb2d32d190ad95873754f0c0bf7dcf16db4744ed18c1c7d171e32e58559bba` |
| `assets/siege/environment/fort/textures/modular_fort_01_plaster_nor_gl_4k.jpg` | `a76aea190d45cef82fb94496cf4e9d34586eef3406e8e83f02ca0e6000ce50ea` |
| `assets/siege/environment/fort/textures/modular_fort_01_trim_arm_4k.jpg` | `fc42582c889964c5bbfd2eaa435ad5c711be28cfefcf3937dd73e3184ed9a208` |
| `assets/siege/environment/fort/textures/modular_fort_01_trim_diff_4k.jpg` | `42de78116beba077dbc5cc5d2788ba67d14c988121e4970f972488eb6df62209` |
| `assets/siege/environment/fort/textures/modular_fort_01_trim_nor_gl_4k.jpg` | `b2c1571a277b782759efd59d26b6613240809e089690cb43c6150906c747984a` |
| `assets/siege/environment/fort/textures/modular_fort_01_wall_arm_4k.jpg` | `be11ef4e9ff7635998e2db6880c555cf1c5f69793ea4fd3a1fee59fe8761b806` |
| `assets/siege/environment/fort/textures/modular_fort_01_wall_diff_4k.jpg` | `097a96f3991ea22c4610e8f65783dd3fe8eb80785527027213c0c98437b9ec64` |
| `assets/siege/environment/fort/textures/modular_fort_01_wall_nor_gl_4k.jpg` | `18599d17d9755af8a40c6a37c58c70be067b842145f94a1a5d03801ac72e23b2` |
| `assets/siege/environment/gate/large_castle_door.bin` | `7db2eb9d2b81207a30c849ba5de0f2c25085add88e437bc69764ce792758ff76` |
| `assets/siege/environment/gate/large_castle_door.gltf` | `c9622dd67a5f58c821eee2817c719c04c0eb595d01b121da503a3afdf9b5b4d9` |
| `assets/siege/environment/gate/textures/large_castle_door_arm_2k.jpg` | `038a66752c095bf4bf5f4b24849cf4bd1ae58ac4718edda37b7ee1fbfd1a33bc` |
| `assets/siege/environment/gate/textures/large_castle_door_diff_2k.jpg` | `ca2d7cc8071fd7c57ddbd4b71892bbfa775e0d6cc9b65e70f7eda0398f707302` |
| `assets/siege/environment/gate/textures/large_castle_door_nor_gl_2k.jpg` | `333e55f9fccdf8778c8aa94d1d8d296ce8bce50c8055e6f385545dac1e622fbd` |
| `assets/siege/environment/lantern.glb` | `a79458c4b02d695187a952f23a63b8bf278e7bc3d316a3c2a314f2d6974181f1` |
| `assets/siege/environment/lantern_0.png` | `a2d6aa660f0b9ce46b3863e955248454e73be96063218b799af9f750e0f7be71` |
| `assets/siege/environment/lantern_1.png` | `01b8105756fd86f13e66602f85ee03e7e5daf22a8531f32bef8bbe678cf38cf6` |
| `assets/siege/environment/lantern_2.png` | `3318a4d3bef8be53c192d87b7401145493774126c54a22e50e1269f9476065fa` |
| `assets/siege/environment/lantern_3.png` | `eafa6390501d537f5bbcf92c64ad1c39d2493aef4508e9cc9d537771efe8bad7` |

### Huellas actuales del abeto A y acantilado GitHub

Los cuatro GLB de abeto son derivados locales del recurso CC0 indicado arriba. Los LOD1/2/3 retienen fragmentos de ramitas originales en sus posiciones tridimensionales y simplifican el tronco; se amplían fragmentos para mantener cobertura bajo resolución. El antiguo atlas se conserva como experimento y no se instancia. El corte alfa en runtime conserva la fotografía y permite profundidad/sombras de follaje sin tratar agujas como vidrio transparente.

| Archivo | SHA-256 |
|---|---|
| `assets/environment/fir/fir_impostor.png` | `17e116378ff22500a098b0d177eb4abe6437763237b06ddfa37dffc86be259d9` |
| `assets/environment/fir/fir_lod0.glb` | `b8e0d94acacde88f03fa4c742d00aa9a2503f83cbe4be6fddede8bff7722730f` |
| `assets/environment/fir/fir_lod0_fir_tree_01_bark_diff_2k.png` | `733bfdd255dd468886a68487d5ddc990384ce92f10646af92076e86d789f79b9` |
| `assets/environment/fir/fir_lod0_fir_tree_01_bark_nor_gl_2k.png` | `32940b0be3a6f9ce10ec9579d2057fac2e7b639f279a37f623467ec12a58e836` |
| `assets/environment/fir/fir_lod0_fir_tree_01_bark_rough_2k.png` | `ff09ac91017dc978e1814b643c51c1c81f2ddc83e9a6d9932187217cc216e332` |
| `assets/environment/fir/fir_lod0_fir_tree_01_trunk_a_diff_2k.png` | `5913b7176d9bebb50e5c85bf3aaf8d49d6aee5ff2d6620037b3a18298c397e7f` |
| `assets/environment/fir/fir_lod0_fir_tree_01_trunk_a_nor_gl_2k.png` | `108acc38dc02a664f7d4d97f1e0792782ce9b4c998348b9fc6301ca003af4809` |
| `assets/environment/fir/fir_lod0_fir_tree_01_trunk_a_rough_2k.png` | `cbad32512b9479a55e4712e70a8ea7d3807f73675b19d8640f8adb48d9eca63a` |
| `assets/environment/fir/fir_lod0_fir_tree_01_twig_diff-fir_tree_01_twig_alpha.png` | `856f133abb2c2f908ab86cfbdfcb2f6ce0adfaf1441c4c9465d01da859fceb7d` |
| `assets/environment/fir/fir_lod0_fir_tree_01_twig_nor_gl_2k.png` | `03f6a70cebfe684ba61d84a6abbfab078a6a252ec52f6bbe8fcdb87de62add0a` |
| `assets/environment/fir/fir_lod0_fir_tree_01_twig_rough_2k.png` | `7a98df0033a12d90483c8183da4e0796f66da93e1dcd2c455939246b8a629cee` |
| `assets/environment/fir/fir_lod1.glb` | `2bda8e768077a4f1266d78d5e73e3e80bf8f905ca2da61ccec56317336046f1d` |
| `assets/environment/fir/fir_lod1_fir_tree_01_bark_diff_2k.png` | `733bfdd255dd468886a68487d5ddc990384ce92f10646af92076e86d789f79b9` |
| `assets/environment/fir/fir_lod1_fir_tree_01_bark_nor_gl_2k.png` | `32940b0be3a6f9ce10ec9579d2057fac2e7b639f279a37f623467ec12a58e836` |
| `assets/environment/fir/fir_lod1_fir_tree_01_bark_rough_2k.png` | `ff09ac91017dc978e1814b643c51c1c81f2ddc83e9a6d9932187217cc216e332` |
| `assets/environment/fir/fir_lod1_fir_tree_01_trunk_a_diff_2k.png` | `5913b7176d9bebb50e5c85bf3aaf8d49d6aee5ff2d6620037b3a18298c397e7f` |
| `assets/environment/fir/fir_lod1_fir_tree_01_trunk_a_nor_gl_2k.png` | `108acc38dc02a664f7d4d97f1e0792782ce9b4c998348b9fc6301ca003af4809` |
| `assets/environment/fir/fir_lod1_fir_tree_01_trunk_a_rough_2k.png` | `cbad32512b9479a55e4712e70a8ea7d3807f73675b19d8640f8adb48d9eca63a` |
| `assets/environment/fir/fir_lod1_fir_tree_01_twig_diff-fir_tree_01_twig_alpha.png` | `856f133abb2c2f908ab86cfbdfcb2f6ce0adfaf1441c4c9465d01da859fceb7d` |
| `assets/environment/fir/fir_lod1_fir_tree_01_twig_nor_gl_2k.png` | `03f6a70cebfe684ba61d84a6abbfab078a6a252ec52f6bbe8fcdb87de62add0a` |
| `assets/environment/fir/fir_lod1_fir_tree_01_twig_rough_2k.png` | `7a98df0033a12d90483c8183da4e0796f66da93e1dcd2c455939246b8a629cee` |
| `assets/environment/fir/fir_lod2.glb` | `f18b21eef4fb08f03a7ecad92cedebab68112a8b417f6fc6774ffa9aca819108` |
| `assets/environment/fir/fir_lod2_fir_tree_01_bark_diff_2k.png` | `733bfdd255dd468886a68487d5ddc990384ce92f10646af92076e86d789f79b9` |
| `assets/environment/fir/fir_lod2_fir_tree_01_bark_nor_gl_2k.png` | `32940b0be3a6f9ce10ec9579d2057fac2e7b639f279a37f623467ec12a58e836` |
| `assets/environment/fir/fir_lod2_fir_tree_01_bark_rough_2k.png` | `ff09ac91017dc978e1814b643c51c1c81f2ddc83e9a6d9932187217cc216e332` |
| `assets/environment/fir/fir_lod2_fir_tree_01_trunk_a_diff_2k.png` | `5913b7176d9bebb50e5c85bf3aaf8d49d6aee5ff2d6620037b3a18298c397e7f` |
| `assets/environment/fir/fir_lod2_fir_tree_01_trunk_a_nor_gl_2k.png` | `108acc38dc02a664f7d4d97f1e0792782ce9b4c998348b9fc6301ca003af4809` |
| `assets/environment/fir/fir_lod2_fir_tree_01_trunk_a_rough_2k.png` | `cbad32512b9479a55e4712e70a8ea7d3807f73675b19d8640f8adb48d9eca63a` |
| `assets/environment/fir/fir_lod2_fir_tree_01_twig_diff-fir_tree_01_twig_alpha.png` | `856f133abb2c2f908ab86cfbdfcb2f6ce0adfaf1441c4c9465d01da859fceb7d` |
| `assets/environment/fir/fir_lod2_fir_tree_01_twig_nor_gl_2k.png` | `03f6a70cebfe684ba61d84a6abbfab078a6a252ec52f6bbe8fcdb87de62add0a` |
| `assets/environment/fir/fir_lod2_fir_tree_01_twig_rough_2k.png` | `7a98df0033a12d90483c8183da4e0796f66da93e1dcd2c455939246b8a629cee` |
| `assets/environment/fir/fir_lod3.glb` | `8c5d7e2c1c8b33ad12571ef53e59ca0c8c8faf75d3c19d0b61f3f17ecd77ed7f` |
| `assets/environment/fir/fir_lod3_fir_tree_01_bark_diff_2k.png` | `733bfdd255dd468886a68487d5ddc990384ce92f10646af92076e86d789f79b9` |
| `assets/environment/fir/fir_lod3_fir_tree_01_bark_nor_gl_2k.png` | `32940b0be3a6f9ce10ec9579d2057fac2e7b639f279a37f623467ec12a58e836` |
| `assets/environment/fir/fir_lod3_fir_tree_01_bark_rough_2k.png` | `ff09ac91017dc978e1814b643c51c1c81f2ddc83e9a6d9932187217cc216e332` |
| `assets/environment/fir/fir_lod3_fir_tree_01_trunk_a_diff_2k.png` | `5913b7176d9bebb50e5c85bf3aaf8d49d6aee5ff2d6620037b3a18298c397e7f` |
| `assets/environment/fir/fir_lod3_fir_tree_01_trunk_a_nor_gl_2k.png` | `108acc38dc02a664f7d4d97f1e0792782ce9b4c998348b9fc6301ca003af4809` |
| `assets/environment/fir/fir_lod3_fir_tree_01_trunk_a_rough_2k.png` | `cbad32512b9479a55e4712e70a8ea7d3807f73675b19d8640f8adb48d9eca63a` |
| `assets/environment/fir/fir_lod3_fir_tree_01_twig_diff-fir_tree_01_twig_alpha.png` | `856f133abb2c2f908ab86cfbdfcb2f6ce0adfaf1441c4c9465d01da859fceb7d` |
| `assets/environment/fir/fir_lod3_fir_tree_01_twig_nor_gl_2k.png` | `03f6a70cebfe684ba61d84a6abbfab078a6a252ec52f6bbe8fcdb87de62add0a` |
| `assets/environment/fir/fir_lod3_fir_tree_01_twig_rough_2k.png` | `7a98df0033a12d90483c8183da4e0796f66da93e1dcd2c455939246b8a629cee` |
| `assets/environment/github_cliff.glb` | `3072df79b11ab11469ec79a6837ad9af2675e9c79775dcd906f8ec61cb323516` |

## Roca desnuda del terreno: Poly Haven Rock Face — CC0 1.0

Fotografía: **Greg Zaal**. Procesado: **Dario Barresi**. Fuente primaria: [Rock Face](https://polyhaven.com/a/rock_face); [licencia de Poly Haven](https://polyhaven.com/license), [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). La fuente describe roca erosionada con grietas y superficie rugosa; sus materiales PBR siguen el [estándar seamless de Poly Haven](https://docs.polyhaven.com/en/technical-standards/textures).

Tres mapas originales JPG 2048×2048, sin editar imágenes: albedo, normal OpenGL y rugosidad. Se proyectan sobre el terreno en dos escalas y se mezclan por pendiente, altura y suelo. Sustituyen `rocky_terrain_02` como roca expuesta: ese mapa anterior contiene pasto y guijarros. El acantilado fotogramétrico de GitHub conserva su propia malla y atlas; ese atlas no se repite sobre el terreno.

| Archivo | SHA256 |
|---|---|
| `assets/environment/rock_face_diff_2k.jpg` | `b989c832327538a9e546cca359417acb9a657d041f300407e8398daaf743f5bc` |
| `assets/environment/rock_face_nor_gl_2k.jpg` | `352b87db2502d54487b0ed8abdfb621fae2abf7d360a281b419f567346178cf0` |
| `assets/environment/rock_face_rough_2k.jpg` | `91517cdc191bf60fdb135929e12041e2ad50dd7343b33f25dae75d87ba61b226` |
