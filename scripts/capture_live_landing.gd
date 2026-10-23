@tool
extends SceneTree

func _init():
	root.size = Vector2i(1280, 720)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(25): await process_frame
	for c in scene.get_children():
		if c is CanvasLayer: c.visible = false
		
	var dragon: DragonController = scene.get_node("Dragon")
	var cam: Camera3D = scene.get_node("FlightCamera")
	cam.set_process(false)
	cam.set_physics_process(false)
	
	print("\n--- INICIANDO CAPTURA DE SECUENCIA DE ATERRIZAJE ---")
	
	# Fase 1: En aproximación de aterrizaje a 25m de altura
	dragon.global_position = Vector3(300, 24 + 25, 120)
	dragon.velocity = Vector3(0, -4.0, 10.0)
	dragon.has_taken_off = true
	dragon.trigger_landing()
	
	for step in range(15):
		dragon._physics_process(0.033)
		dragon._process(0.033)
		await process_frame
		
	print("Fase 1 (Aproximación 20m): wing_fold_blend = %.3f (debe ser 0.0)" % dragon.wing_fold_blend)
	cam.global_position = dragon.global_position + Vector3(0, 5, 20)
	cam.look_at(dragon.global_position + Vector3(0, 0, 0))
	for f in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var img1 = root.get_texture().get_image()
	if img1:
		img1.save_png("res://landing_seq_1_approach_flare.png")
		print("Guardada landing_seq_1_approach_flare.png")
		
	# Fase 2: Simular hasta tocar el suelo
	for step in range(120):
		dragon._physics_process(0.033)
		dragon._process(0.033)
		await process_frame
		if dragon.locomotion_state == dragon.LocomotionState.GROUNDED:
			print("Contacto en paso %d: Posición Y = %.2f" % [step, dragon.global_position.y])
			break
			
	# Dejar que las alas se plieguen completamente y las patas se asienten
	for step in range(40):
		dragon._physics_process(0.033)
		dragon._process(0.033)
		await process_frame
		
	print("Fase 2 (En suelo): wing_fold_blend = %.3f (debe ser > 0.9)" % dragon.wing_fold_blend)
	cam.global_position = dragon.global_position + Vector3(0, 8, 18)
	cam.look_at(dragon.global_position + Vector3(0, 1.5, 0))
	for f in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var img2 = root.get_texture().get_image()
	if img2:
		img2.save_png("res://landing_seq_2_ground_folded.png")
		print("Guardada landing_seq_2_ground_folded.png")
		
	# Fase 3: Vista lateral de perfil
	cam.global_position = dragon.global_position + Vector3(18, 5, 0)
	cam.look_at(dragon.global_position + Vector3(0, 1.5, 0))
	for f in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var img3 = root.get_texture().get_image()
	if img3:
		img3.save_png("res://landing_seq_3_flank_profile.png")
		print("Guardada landing_seq_3_flank_profile.png")
		
	print("\n>>> SECUENCIA DE ATERRIZAJE CAPTURADA CON ÉXITO <<<")
	quit(0)
