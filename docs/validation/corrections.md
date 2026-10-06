# Correcciones y reglas conservadas

- Aterrizaje sobre pared: se exige normal transitable y proximidad al terreno. Regla: el contacto genérico no equivale a suelo. Caso negativo en aceptación.
- Pose restaurada después de SkeletonModifier: contactos y hocico se miden durante su callback. Regla: las coordenadas de huesos deben corresponder al instante renderizado; no mezclar pose authored y pose final.
- Destellos de terreno y alas: mipmaps, normales RG reconstruidas, UV correcto y especular orgánico. Regla: inspeccionar importación, texturas y parámetros del GLB antes de corregir iluminación a ciegas.
- Millones de polígonos de bosque: MultiMesh sectorizado con tres LOD. Regla: medir render completo después de calentamiento; no extrapolar una cámara fija.
- Tronco fino entre rayos: se añade sweep de volumen además de rayos y regresión explícita. Regla: un efecto volumétrico necesita comprobar obstáculos que no están en su eje central.
- ESPACIO con botón enfocado: preserva el control de vuelo; ENTER activa GUI. Regla: probar mandos después de clic y foco, no solo desde escena nueva.
- Teardown de diagnóstico: liberar escena/audio y esperar frames antes de quit. Regla: distinguir fugas del harness de fallos del juego, y reparar ambas antes de declarar logs limpios.

Estas reglas quedan acotadas a este proyecto y comprobadas por sus suites; no se agregan políticas globales ni excepciones de autorización.

- Marcha contra obstáculo: la fase y el solver usan desplazamiento después de move_and_slide, separado de la velocidad solicitada. Regla: intención de avanzar no equivale a distancia recorrida; regresión contra pared, reversa y sprint mantienen el comportamiento.
- Apertura del fuego: radio incluye apertura angular y tamaño de tarjeta, comprobando también overlaps iniciales que cast_motion omite. Regla: derivar cobertura del efecto visible, no de una constante arbitraria; regresión con tronco lejano lateral.

- Regresión de obstáculos identifica collider_id exacto en aire libre: un impacto de suelo ajeno no puede hacer pasar la prueba del tronco. Regla: comprobar el objeto esperado, no solo que exista cualquier impacto.
- Partículas residuales tras girar: reiniciar emisores al abandonar/cambiar bruscamente un plano, con regresión del contador de reinicios. Regla: coordenadas mundo y recorte actual requieren manejar partículas del plano anterior.
