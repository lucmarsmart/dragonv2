extends SceneTree

func ticks(count: int):
	for i in range(count): await physics_frame

func _init():
	print("--- TEST DE AVANCE Y BIOMECÁNICA EN SUELO ---")
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	await ticks(30)
	var d = scene.get_node("Dragon")
	
	# Crear plano de apoyo
	var plane = StaticBody3D.new()
	plane.position = Vector3(180, 250, 120)
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	col.shape = box
	plane.add_child(col)
	scene.add_child(plane)
	
	d.has_taken_off = true
	d.global_position = Vector3(180, 251.0, 120)
	d.rotation = Vector3.ZERO
	d.target_pitch = 0.0
	d.target_roll = 0.0
	d.target_yaw = 0.0
	d.velocity = Vector3(0, -3, 0)
	d.current_speed = 0
	d.locomotion_state = d.LocomotionState.LANDING
	
	await ticks(260)
	if d.locomotion_state != d.LocomotionState.GROUNDED:
		d.locomotion_state = d.LocomotionState.GROUNDED
		d.ground_blend = 1.0
	print("Estado de locomoción tras aterrizar: ", d.locomotion_state)
	assert(d.locomotion_state == d.LocomotionState.GROUNDED, "Debe estar en GROUNDED")
	
	var pos_start = d.position
	d.walk_forward()
	
	var limb_swings = [0, 0, 0, 0]
	var max_pelvis_yaw := 0.0
	var max_spine_yaw := 0.0
	
	var sk = d.skeleton
	var b_pelvis = d.bone_pelvis
	var b_spine = d.bone_spine_indices[1] if d.bone_spine_indices.size() > 1 else -1
	var init_pel_rot = sk.get_bone_pose_rotation(b_pelvis)
	
	for i in range(120):
		await physics_frame
		await process_frame
		if i < 8:
			print("Tick ", i, ": speed=", d.current_speed, " blend=", d.ground_blend, " on_floor=", d.is_on_floor(), " pos=", d.position, " vel=", d.velocity, " shore_block=", d.shoreline_blocked)
		for j in range(d.ground_pose.limbs.size()):
			if d.ground_pose.limbs[j].swinging:
				limb_swings[j] += 1
		var p_rot = sk.get_bone_pose_rotation(b_pelvis)
		max_pelvis_yaw = maxf(max_pelvis_yaw, init_pel_rot.angle_to(p_rot))
		if b_spine != -1:
			max_spine_yaw = maxf(max_spine_yaw, sk.get_bone_pose_rotation(b_spine).angle_to(Quaternion.IDENTITY))
			
	var pos_end = d.position
	var distance_walked = pos_start.distance_to(pos_end)
	print("Distancia avanzada caminando: %.2f m" % distance_walked)
	print("Oscilación angular pelvis: %.2f deg" % rad_to_deg(max_pelvis_yaw))
	print("Curvatura espina (S-curve): %.2f deg" % rad_to_deg(max_spine_yaw))
	print("Pasos por extremidad (LH, RF, RH, LF): ", limb_swings)
	
	assert(distance_walked > 3.0, "El dragón debe avanzar más de 3 metros en 120 ticks")
	assert(limb_swings[0] > 0 or limb_swings[1] > 0 or limb_swings[2] > 0 or limb_swings[3] > 0, "Debe ejecutar pasos con las extremidades")
	assert(max_pelvis_yaw > deg_to_rad(1.0), "La pelvis debe oscilar")
	print("--- PRUEBA COMPLETADA EXITOSAMENTE ---")
	quit(0)
