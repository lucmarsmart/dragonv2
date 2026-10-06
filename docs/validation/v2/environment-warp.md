# Relieve irregular y superficie funcional preservada

El candidato del 2026-10-05 reemplaza fuera de las zonas funcionales las siluetas regulares del heightmap por desplazamiento de coordenadas y relieve determinista de varias escalas. `scripts/terrain.gd` conserva el grid 320, los mismos índices/triángulos y el mismo cálculo barycéntrico de `ground_height`. Render y collider se generan de esa única superficie. No se modificó `siege_environment.gd` en este ajuste.

La semilla 913527 genera ruido Simplex smooth/ridged de cuatro octavas, frecuencia 0.0045, con domain warp de tres octavas, amplitud 75 m y frecuencia 0.0028. La deformación del heightmap base añade desplazamiento de coordenadas hasta 145 m de amplitud nominal, hombros amplios y gullies de menor escala. Es relieve procedural inspirado en erosión, **no** simulación hidráulica ni fotogrametría integral. API primaria: [Godot FastNoiseLite](https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html).

La máscara continua vale cero en patio y transición (`court_distance≤1.55`), banda del río hasta `width+64 m` y acceso ampliado (X252–348/Z150–430). Las expresiones de flatten y corredor anteriores permanecen intactas. No hay máscara especial alrededor del fixture QA450,220. El cambio exterior máximo medido es116.116871 m.

La superficie nueva recalcula dónde pueden crecer los árboles y ajusta sus bases a las alturas reales: 2728 instancias, frente a 2771 anteriores. No añade árboles ni malla; se limita expresamente la población a 2771. Permanecen los escaneos, el acantilado de GitHub y los LOD volumétricos 43,349/1,017/513/218 triángulos. Distancias 3D 32/75/230 m, culling individual y sombras sólo en los dos LOD próximos. Los lejanos conservan geometría simplificada; no son equivalentes al scan completo.

Rock Face CC0 seamless 2K continúa como roca PBR. Las dos muestras existentes de albedo usan escalas y orientaciones distintas, con mezcla continua y variación amplia. El detalle normal desaparece gradualmente entre 55–210 m de cámara para evitar que la repetición se convierta en un patrón de iluminación. No se incorporan samplers, mapas ni muestras adicionales: aproximadamente 33 lecturas de textura y cuatro ruidos por fragmento como antes.

## Evidencia

Capturas comparables actuales: `environment-mountain.png`, `environment-fortress-air.png` y `environment-pine.png`. Antes de este cambio: sufijo `-before-warp.png`; antes de la exposición de roca: `-before-rock-exposure.png`. Los mismos encuadres X/Z y objetivos usan el harness existente; su cámara se eleva automáticamente si la nueva superficie quedaría por encima. Root revisó las tres vistas y aceptó el candidato visual como paisaje de juego PBR, sujeto a física/C3. Se mantiene visible el carácter procedural y cierta repetición del material; no se certifica realismo por conteos.

Se ejecutó primero la captura Metal Forward+ 1280×720 y después:

```sh
tools/godot.sh --headless --path . --script scripts/verify_siege_environment.gd
tools/godot.sh --headless --path . --script docs/validation/v2/environment-warp-check.gd
```

Ambos salen 0, sin errores de script y sin fallos. `environment-physics.json`: 180 rayos aleatorios, altura/collider, 8 knights, 3 plataformas, puerta/muro/montaña, acceso al nido y liberación/reset; error máximo 0.000200975 m. `environment-warp-physics.json` compara la fórmula previa del terreno SHA a17cc68d… con el nuevo grid usando el mismo almacenamiento float32: diferencia protegida **exactamente 0.0 m**. Comprueba 2115 muestras de patio/transición, 9721 de río y 675 de acceso; conjuntos pueden solaparse. El harness conserva la fórmula baseline para reproducir la comparación.

| Superficie real | Altura m | Pendiente | Normal | Uso siguiente |
|---|---:|---:|---|---|
|450,220|66.637695|19.2427°|−.313059,.944131,.103008|fixture previo actualizado; sin protección especial|
|600,−450|132.909729|13.6328°|.108192,.971826,−.209401|nueva ladera transitable; +8.130272 m frente a baseline|
|650,−300|118.445313|46.6020°|−.257665,.687062,.679378|cara para colisión durante vuelo|
|300,275|24|0°|0,1,0|escape protegido|
|300,82|24|0°|0,1,0|rescate protegido|

Se cedió CPU/GPU a anatomía después de estas verificaciones. Piel/hulls sobre las superficies nuevas y gates nativos/C3 quedan a sus responsables. No se ejecutaron benchmarks del entorno en esta ronda. El harness de captura conserva el warning anterior de siete Texture RIDs al apagar; no hay evidencia aquí de crecimiento de memoria durante gameplay.

Runtime congelado: terrain SHA256 `a193093006a3c045918b135b874448d497605a537d1e9de2c9987389266a9a84`; shader `1879eb4be9971a4b19fe3a37a3b2bd8492ea131ce1d7e484f3b772ab1cd7779d`. Fuentes/PNG en `environment-warp-integrity.json`; logs `environment-warp-capture.log`, `environment-warp-protected-verify.log` y `environment-warp-environment-verify.log`.

Idea 10×/~2×: mantener la comparación de superficies protegidas junto a las cámaras suelo/aire en cada modificación del relieve. Permite mejorar el paisaje conservando evidencia concreta de los accesos funcionales.
