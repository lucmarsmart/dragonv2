extends SceneTree
func _init():
	root.size = Vector2i(1280,720)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var d = scene.get_node("Dragon")
	for f in range(80): await process_frame
	var plane := StaticBody3D.new()
	plane.position=Vector3(180,250,120)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(200,1,200)
	col.shape=shape
	plane.add_child(col)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size=shape.size
	mesh.mesh=box
	var material := StandardMaterial3D.new()
	material.albedo_color=Color(0.24,0.28,0.16)
	mesh.material_override=material
	plane.add_child(mesh)
	scene.add_child(plane)
	d.global_position=Vector3(180,257,120)
	d.velocity=Vector3(0,-2,0)
	d.has_taken_off=true
	d.current_speed=0
	d.locomotion_state=d.LocomotionState.LANDING
	d.rotation=Vector3.ZERO
	d.target_pitch=0
	d.target_yaw=0
	d.target_roll=0
	d.manual_input_override=true
	var cam=scene.get_node("FlightCamera")
	cam.set_process(false)
	cam.set_physics_process(false)
	var hud=scene.get_node("HUD")
	hud.visible=false
	for f in range(180): await physics_frame
	cam.global_position=d.global_position+Vector3(17,3,-6)
	cam.look_at(d.global_position+Vector3(0,-1,0))
	for f in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/dragon-ground-idle.png")
	print("GROUND IDLE ",d.global_position," state ",d.locomotion_state," errors ",d.ground_pose.debug_errors)
	d.manual_move_input=1.0
	for f in range(100): await physics_frame
	cam.global_position=d.global_position+Vector3(17,3,-6)
	cam.look_at(d.global_position+Vector3(0,-1,0))
	for f in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/dragon-ground-walk.png")
	print("GROUND WALK ",d.global_position," state ",d.locomotion_state," errors ",d.ground_pose.debug_errors)
	scene.queue_free()
	await process_frame
	quit()
