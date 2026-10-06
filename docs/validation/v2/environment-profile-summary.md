# Diagnóstico de rendimiento del entorno

Metal Forward+, Apple M5,1280×720. Cada fase mide10s tras180frames de carga y5s de misión. La entradaF conserva0.8s/4s del benchmark del orquestador. Los overrides se limitan al harness diagnóstico; no modifican producción.

| Fase | Fuego | FPS | p95ms | Interpretación |
|---|---:|---:|---:|---|
| Original | No |26.20|54.81| reproduce caída sin partículas |
| Original | Sí |26.54|58.95| fuego no explica el cuello principal |
| Bosque oculto | No |65.31|16.34| aísla coste de follaje |
| LOD0/1 ocultos | No |38.14|36.77| detallados y lejanos aportan coste |
| LOD reducido/culling | Sí |55.18|19.45| aún insuficiente |
| Alpha scissor | Sí |58.60|17.98| prueba con actividad headless concurrente |
| Final limpio | Sí |64.63|16.59| supera umbral corto; requiere60s integrado |

La variantefreeze_lod dio51.63FPS durante prueba headless de CPU; no sustenta desactivar actualizaciones. La física permaneció activa en todos los perfiles; no se redujeron partículas, IA ni criterio60FPS. Follaje final:43,349/1,017/513/218triángulos por LOD, distancias3D32/75/230m, corte alfa0.25, esferas/frustum y margen de giro. SourceSHA en environment-integrity.json.

RenderingServer entregó CPU de render0.24–0.30ms y GPU0; ese0 se considera no disponible. TIME_PROCESS mide duración de frame y puede incluir espera; no se interpreta como CPU pura. Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME cuenta vértices o índices e incluye depth/sombras ([documentación primaria](https://docs.godotengine.org/en/stable/classes/class_performance.html));10.0M del perfil final no equivalen a10M triángulos únicos. CompilacionesDRAW=0: no se observó compilación de pipeline durante dibujo; contador MESH/SURFACE corresponde a carga/caché.

```sh
tools/godot.sh --path . --script scripts/profile_siege_environment.gd
tools/godot.sh --path . --script scripts/profile_siege_environment.gd -- --fire
tools/godot.sh --path . --script scripts/profile_siege_environment.gd -- --variant=no_forest
tools/godot.sh --path . --script scripts/profile_siege_environment.gd -- --variant=no_near
tools/godot.sh --path . --script scripts/profile_siege_environment.gd -- --fire --variant=optimized-clean
```

Las variantesno_forest/no_near aíslan componentes; no deben usarse como prueba de aceptación del producto. El benchmark final60s continúa a cargo del orquestador sobre runtime congelado. Los renders confirman copas presentes con ramas volumétricas, pero la simplificación y el relieve procedural se declaran; FPS no certifica naturalidad fotográfica.
