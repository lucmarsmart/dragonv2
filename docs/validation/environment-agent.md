# Entorno E-05 — evidencia

Implementación: `scripts/terrain.gd`, cuatro shaders en `shaders/`, texturas originales `pine_needles.png` y `meadow_blades.png` con generador reproducible `scripts/generate_environment_foliage.py`. Seis texturas PBR Poly Haven descargadas y verificadas por el coordinador, licencia CC0. Importaciones de texturas fijadas con mipmaps; normales OpenGL importadas como normal maps. No se usan assets de juegos.

El terreno original conserva colisión trimesh exacta. Se añadieron bancos serpenteantes, costa visible y cordillera original con colisiones; se quitó el piso de seguridad invisible. Río/lagunas ocupan depresiones reales, mar exterior a -18 m. API `is_water_at`, `ground_height` y `find_landing_site` para evitar aterrizar en agua. Muestreo de altura auxiliar bilineal; contacto final debe usar raycast de física real.

Bosque: 6500 coníferas, ramas con corteza y tarjetas de agujas, tres LOD repartidos en 16 sectores. Agujas se mecen suavemente. 500 rocas y 3200 matas de hierba. En este slice los props eran decorativos. La integración final añade SceneryCollisions: pool cercano acotado de192troncos y64rocas con colisión física; terreno/bancos/costa/cordillera conservan colisiones. La aceptación final comprueba cuerpos y rayos contra estas capas.

## Validación ejecutada

Godot oficial 4.7.2, Metal Mobile, Apple M5, 1280×720.

- `--headless --path . --editor --import --quit`: importación completada, sin errores de scripts/shaders tras reparaciones.
- `--headless --path . --script res://scripts/test_env_agent.gd`: exit 0, cero fallos. Comprueba clasificación agua/tierra, destino de aterrizaje seco, eliminación de piso invisible y raycast colisionable normal ascendente en terreno, bancos, costa y cordillera.
- `--path . --script res://scripts/capture_env_agent.gd`: cinco vistas con render GPU real en `artifacts/environment/`: aerial, valley, dragon_landscape, ground_detail, texture_detail. Inspeccionadas visualmente: material PBR cercano, agujas y ramas, banco sinuoso, nubes, silueta montañosa. Sin errores shader. Una ejecución de teardown de escena completa produjo advertencia ObjectDB (2 instancias), no reproducida en test aislado de entorno.
- `--path . --script res://scripts/benchmark_env_agent.gd`: 90 frames de calentamiento y 180 medidos. Última medición 1.508103 s = **119.36 FPS**, 78 draw calls y 2,657,234 primitivas (incluye sombras). Escena completa, dragón detenido durante sonda y cámara de valle fija. No representa todos los escenarios/hardware.

Correcciones visuales verificadas: winding invertido de bancos/costa corregido con prueba negativa raycast; grano/parpadeo de PBR eliminado activando mipmaps; bosque anterior con conos opacos sustituido por agujas alpha; LOD redujo el primer prototipo de 116M primitivas/16.7 FPS a ~2.66M/~119 FPS.
