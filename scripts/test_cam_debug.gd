@tool
extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(5): await process_frame
	
	var dragon = scene.get_node("Dragon")
	var cam = scene.get_node("FlightCamera")
	var skel: Skeleton3D = null
	var q = [dragon]
	while q.size() > 0:
		var c = q.pop_front()
		if c is Skeleton3D: skel = c
		for ch in c.get_children(): q.append(ch)
		
	var b_pelvis = skel.find_bone("Bip001_03")
	var b_head = skel.find_bone("Bip001-Head_011")
	
	print("--- FRAME 0 ---")
	print("Dragon pos: ", dragon.global_position)
	print("Dragon rot: ", dragon.rotation_degrees)
	print("Cam pos:    ", cam.global_position)
	print("Cam rot:    ", cam.rotation_degrees)
	
	for f in range(70):
		dragon._physics_process(1.0 / 60.0)
		dragon._process(1.0 / 60.0)
		cam._physics_process(1.0 / 60.0)
		await process_frame
		
	var p_world = skel.global_transform * skel.get_bone_global_pose(b_pelvis).origin
	var h_world = skel.global_transform * skel.get_bone_global_pose(b_head).origin
	
	print("--- FRAME 70 ---")
	print("Dragon pos:   ", dragon.global_position)
	print("Dragon rot:   ", dragon.rotation_degrees)
	print("Pelvis world: ", p_world)
	print("Head world:   ", h_world)
	print("Cam pos:      ", cam.global_position)
	print("Cam rot:      ", cam.rotation_degrees)
	print("Cam-to-Dragon: ", dragon.global_position - cam.global_position)
	print("Cam-to-Pelvis: ", p_world - cam.global_position)
	print("Cam-to-Head:   ", h_world - cam.global_position)
	
	quit(0)
