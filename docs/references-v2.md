# Investigación aplicada al asedio

Consulta de fuentes primarias durante octubre2026; principios adaptados a Godot, sin copiar recursos de videojuegos ni afirmar que un animal ficticio tenga fisiología demostrable.

- [Century: Age of Ashes — entrevista al desarrollador](https://www.unrealengine.com/developer-interviews/dragon-battle-game-century-age-of-ashes-flies-high): vínculo entre controles, movimiento y cámara. Aplicado a transiciones, planeo, objetivos y respuesta del cuerpo.
- [Day of Dragons — sitio oficial de Beawesome Games](https://dayofdragons.com/): el estudio describe vuelo basado en física y diferencias entre especies. Se usa como referencia del peso, inercia y continuidad entre vuelo y desplazamiento terrestre; su sitio no publica el algoritmo, por lo que no se le atribuye la implementación de este proyecto. La búsqueda del nombre literal «The Two Dragon» no identificó una fuente primaria inequívoca; no se presupone que sea este título.
- [Century — práctica y bots](https://century-age-of-ashes.com/second-closed-beta-announcement/): referencia para combate y entrenamiento accesible; el asedio aquí es original.
- [Divinity: Dragon Commander — sitio del desarrollador](https://www.divinitydragoncommander.com/faq.php): referencia de dragón sobre campo militar y objetivos ligados a narrativa. Aplicado al valle ocupado, artillería y rescate; no se reutiliza su historia.
- [Wolfire — Procedural Animation Redux](https://www.wolfire.com/blog/2008/11/procedural-animation-redux/): física/animación procedural. Aquí los apoyos son vértices skinned contra colisión real, con pruebas de deslizamiento y zancada.
- [Ubisoft, GDC 2016 — Fitting the World: A Biomechanical Approach to Foot IK](https://gdcvault.com/play/1023009/Fitting-the-World-A-Biomechanical): la descripción pública explica el paso de corrección reactiva a predicción para conservar movimiento de la animación en Assassin's Creed. Referencia de anticipación y continuidad; no se afirma haber reproducido un algoritmo privado ni visto contenido no accesible.
- [Khronos — Foot Placement on Uneven Terrain](https://github.khronos.org/Vulkan-Site/tutorial/latest/Advanced_glTF/Procedural_Animation_IK/04_foot_placement.html): distingue posición del apoyo, orientación según normal, altura corporal y suavizado temporal; separar apoyo y swing evita que la IK impida levantar la pata. Se usa para contrastar el orden de solución y los apoyos de este rig cuadrúpedo, que requieren validación propia.
- [NASA — ecuación de sustentación](https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/lift-equation/): sustenta relación cualitativa entre velocidad/sustentación y aceleración de picada. Constantes del dragón son decisiones jugables.
- [NVIDIA GPU Gems3 — terrenos procedurales](https://developer.nvidia.com/gpugems/gpugems3/part-i-geometry/chapter-1-generating-complex-procedural-terrains-using-gpu): referencia histórica de detalle a varias escalas; la implementación usa triangulación CPU consistente con collider y mapas PBR.
- [Godot Environment](https://docs.godotengine.org/en/stable/classes/class_environment.html): iluminación, ambient occlusion e indirecta de pantalla en ForwardPlus; evaluación en Metal real.

Fuentes de modelos, commits, derechos, cambios y hashes: [licencias completas](../assets/LICENSES.md), [contratos de enemigos](assets-siege.md) y [entorno](validation/v2/environment-research.md). Se usaron efectivamente modelos de GitHub para caballero, ballista, acantilado y faroles; fotogrametría autorizada de PolyHaven para entorno.

Las imágenes y materiales visibles se juzgan en capturas del juego. Una fuente técnica o un test de polígonos no demuestra por sí solo naturalidad, perfección o calidad cinematográfica.
# Continuidad de las patas durante el descenso — ampliación 5oct2026

Se revisaron fuentes primarias para distinguir contacto del pie, dirección de flexión y continuidad de la pose:

- [Khronos: FABRIK y restricciones articulares](https://github.khronos.org/Vulkan-Site/tutorial/latest/Advanced_glTF/Procedural_Animation_IK/03_fabrik.html): las posiciones resueltas se convierten a rotaciones respecto al padre; las restricciones necesitan marcos de referencia coherentes. Aplicación local: conservar longitudes/binds, rama de flexión y orientación publicada del rig al entrar en apoyo.
- [Epic: Two Bone IK](https://dev.epicgames.com/documentation/unreal-engine/animation-blueprint-two-bone-ik-in-unreal-engine): distingue la posición del extremo del objetivo de la articulación intermedia. Aplicación local: no aceptar un pie en suelo como prueba suficiente de una rodilla/corvejón natural.

Estas referencias orientan la solución; su suficiencia para este dragón se comprueba en la piel y la ejecución real del proyecto.
# Colisiones y giro: fuentes del motor

La documentación de [PhysicsDirectSpaceState3D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html) advierte que `cast_motion` ignora las formas inicialmente solapadas; por eso la recuperación comprueba el contacto inicial y el extremo además del barrido. [PhysicsShapeQueryParameters3D](https://docs.godotengine.org/en/stable/classes/class_physicsshapequeryparameters3d.html) define el margen de consulta. El [código de GodotPhysics3D](https://github.com/godotengine/godot/blob/master/modules/godot_physics_3d/godot_space_3d.cpp) pasa ese margen al solver en `intersect_shape`. Reservar espacio durante el giro es una decisión de esta implementación: su suficiencia requiere las pruebas con la pose final y margen cero, no se deduce de la documentación.

### Vista de ataque sobre la cabeza

Referencia primaria revisada: https://docs.godotengine.org/en/stable/tutorials/3d/spring_arm.html . Documenta barridos de volumen para proteger la cámara contra obstáculos y la exclusión del collider del jugador. La implementación existente conserva su barrido esférico y los rayos de comprobación, y cambia el anclaje desde el hombro a la boca/cabeza (+2,2m), de modo que las alas quedan detrás del campo de ataque. El giro del cuerpo recibe sólo el exceso sobre el rango cervical, con velocidad terrestre acotada; una pulsaciónT alterna el modo y W/S+ratón+clic permiten mover, apuntar y exhalar juntos. Las capturas y las comprobaciones de IA/HP son evidencia de casos concretos, no una afirmación de ausencia universal de obstrucciones.
