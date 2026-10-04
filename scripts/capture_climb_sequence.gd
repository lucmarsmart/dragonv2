extends SceneTree

# Captura secuencia de CLIMB en juego (vista lateral) para comparar con el video de referencia.
func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for f in range(15): await process_frame
	var dragon = scene.get_node("Dragon")
	var cam = scene.get_node("FlightCamera")
	dragon.has_taken_off = true
	dragon.trigger_normal()
	cam.set_view(cam.ViewPreset.RIGHT)
	cam.target_distance = 40.0
	for f in range(60):
		dragon._physics_process(1.0 / 60.0)
		dragon._process(1.0 / 60.0)
		cam._physics_process(1.0 / 60.0)
		await process_frame
	dragon.trigger_climb()
	var out = "c:/Proyectos/Dragon v2/climb_game/"
	DirAccess.make_dir_recursive_absolute(out)
	var n = 0
	for f in range(240):
		dragon._physics_process(1.0 / 60.0)
		dragon._process(1.0 / 60.0)
		cam._physics_process(1.0 / 60.0)
		await process_frame
		if f >= 60 and f % 9 == 0 and n < 12:
			root.get_viewport().get_texture().get_image().save_png(out + "g_%02d.png" % n)
			print("f=%d pitch=%.1f anim_pos=%.2f speed=%.2f" % [f, rad_to_deg(dragon.rotation.x), dragon.anim_player.current_animation_position, dragon.anim_player.speed_scale])
			n += 1
	quit(0)
