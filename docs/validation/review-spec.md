La suite actual pasó **50/50 checks, exit 0**. Revisé el diff indicado, JSON/log y capturas. No edité archivos. Los bloqueantes siguientes están demostrados por código y geometría; su reproducción visual específica sigue pendiente.

1. **BLOQUEANTE — E04: el barrido sigue siendo menor que el volumen de fuego.**  
   [dragon_breath.gd:209](/Users/fede/Proyectos/Dragonv2/scripts/dragon_breath.gd:209) limita el radio a `0.35 + distancia × 0.07`: máximo **2,17 m**. La llama se emite a **7°**, además del tamaño de sus tarjetas.

   **Reproducir:** orientar el soplo horizontalmente hacia un tronco de radio 0,32 m situado a 20 m del hocico y desplazado lateralmente 2,70 m. Los rayos lo omiten y su borde queda a 2,38 m del eje, fuera del barrido. Sin embargo, una trayectoria de llama a 6,84° pasa a 0,298 m de su centro y lo atraviesa. Al faltar impacto, [flame.gdshader:24](/Users/fede/Proyectos/Dragonv2/shaders/flame.gdshader:24) no aplica el plano de recorte. La nueva prueba cubre un tronco a 10 m, no este extremo del alcance.

2. **BLOQUEANTE — E03: las patas marchan aunque la colisión impida avanzar.**  
   [dragon_controller.gd:514](/Users/fede/Proyectos/Dragonv2/scripts/dragon_controller.gd:514) calcula la fase con `current_speed` antes de `move_and_slide()`. En tierra, el retorno de [dragon_controller.gd:597](/Users/fede/Proyectos/Dragonv2/scripts/dragon_controller.gd:597) evita corregir esa velocidad tras chocar.

   **Reproducir:** aterrizar y mantener W perpendicularmente contra un tronco o roca colisionable. Aunque el desplazamiento se detenga, `current_speed` permanece en 7,5 m/s y el ciclo avanza unos **13,46 rad/s**. Las patas siguen dando pasos sin distancia recorrida, incumpliendo E03. La aceptación busca expresamente un corredor libre de obstáculos.

3. **RECOMENDACION — E04: comprobar partículas residuales al abandonar un impacto.**  
   [dragon_breath.gd:81](/Users/fede/Proyectos/Dragonv2/scripts/dragon_breath.gd:81) mantiene partículas en coordenadas mundo, sin colisión individual. El recorte utiliza únicamente el impacto actual.

   **Reproducir:** exhalar contra un obstáculo durante ≥0,3 s, soltar F y girar; observar lateralmente durante 0,85 s. Las partículas ocultas detrás podrían reaparecer al desaparecer el plano. Es un mecanismo identificado estáticamente, todavía sin confirmación visual.

4. **RECOMENDACION — E03/E07: el error de IK no demuestra contacto de las garras en pendientes.**  
   [dragon_ground_pose.gd:37](/Users/fede/Proyectos/Dragonv2/scripts/dragon_ground_pose.gd:37) añade una separación fija al objetivo; [dragon_ground_pose.gd:95](/Users/fede/Proyectos/Dragonv2/scripts/dragon_ground_pose.gd:95) mide el hueso final contra ese objetivo. Los milímetros registrados demuestran convergencia del solver, pero no ausencia de penetración de dedos ni apoyo de la superficie del pie.

   **Reproducir:** caminar y pivotar sobre pendientes transitables, midiendo puntas de garras contra la colisión durante apoyo, dentro del modificador de esqueleto.

**NOTA:** retiré los hallazgos iniciales sobre ESPACIO con foco GUI y el cierre de la suite: fueron corregidos durante esta revisión. La última ejecución terminó correctamente; los avisos de escritura corresponden al sandbox de solo lectura. No encontré otra falla demostrada en ascenso/picada, agua/borde o layout de las resoluciones capturadas.

**Idea 10x, ~2x esfuerzo:** agregar una secuencia adversarial única: marcha contra roca → giro en pendiente → fuego rasante contra tronco lejano → apagar/girar, con aserciones y cámara lateral.

BLOQUEANTES: 2  
FIN DEL INFORME