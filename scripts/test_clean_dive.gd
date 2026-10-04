@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(15): await process_frame
	
	var dragon = scene.get_node("Dragon")
	var cam = scene.get_node("FlightCamera")
	var skel: Skeleton3D = dragon.skeleton
	var ap: AnimationPlayer = dragon.anim_player
	
	dragon.has_taken_off = true
	# Play Qishilong_glide as base for dive
	ap.play("Qishilong_glide")
	dragon.current_mode = dragon.FlightMode.DIVE
	dragon.dive_fold_blend = 1.0
	dragon.target_pitch = -deg_to_rad(50.0)
	dragon.current_speed = 36.0
	
	for f in range(30):
		dragon._physics_process(1.0 / 60.0)
		dragon._process(1.0 / 60.0)
		cam._physics_process(1.0 / 60.0)
		await process_frame
		
	var img = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png("c:/Proyectos/Dragon v2/test_dive_glide_base.png")
		print("Saved test_dive_glide_base.png")
		
	quit(0)
