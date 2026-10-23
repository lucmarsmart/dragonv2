@tool
extends SceneTree

func _init():
	root.size = Vector2i(1280, 720)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	for f in range(20): await process_frame
	for c in scene.get_children():
		if c is CanvasLayer: c.visible = false
		
	var dragon: DragonController = scene.get_node("Dragon")
	var sk: Skeleton3D = dragon.skeleton
	
	# Apply symmetric base pose
	var raw_glb = load("res://assets/models/dragon.glb").instantiate()
	root.add_child(raw_glb)
	var raw_ap: AnimationPlayer = raw_glb.find_child("*AnimationPlayer*", true, false)
	raw_ap.play("Qishilong_fly2")
	raw_ap.seek(40.25, true)
	var raw_sk: Skeleton3D = raw_glb.find_child("*Skeleton3D*", true, false)
	for b in range(raw_sk.get_bone_count()):
		sk.set_bone_pose_rotation(b, raw_sk.get_bone_pose_rotation(b))
	sk.force_update_all_bone_transforms()
	
	dragon.global_position = Vector3(300, 24, 120)
	
	# World axes
	var up = dragon.global_basis.y.normalized()
	var right = dragon.global_basis.x.normalized()
	var fwd = -dragon.global_basis.z.normalized()
	
	# Test rotations on Left Wing (96 shoulder, 97 elbow, 104/98/111 fingers)
	# Left Wing:
	# 1. Swing shoulder backward around UP: angle positive
	dragon._rotate_bone_world(sk, 96, up, deg_to_rad(45.0))
	dragon._rotate_bone_world(sk, 96, fwd, deg_to_rad(-25.0)) # tuck down
	sk.force_update_all_bone_transforms()
	
	# 2. Flex elbow backward/inward:
	dragon._rotate_bone_world(sk, 97, up, deg_to_rad(-35.0))
	dragon._rotate_bone_world(sk, 97, right, deg_to_rad(20.0))
	sk.force_update_all_bone_transforms()
	
	# Right Wing: EXACT MIRROR!
	# (up is negated, right is same, fwd is negated for roll)
	dragon._rotate_bone_world(sk, 120, up, deg_to_rad(-45.0))
	dragon._rotate_bone_world(sk, 120, fwd, deg_to_rad(25.0))
	sk.force_update_all_bone_transforms()
	
	dragon._rotate_bone_world(sk, 121, up, deg_to_rad(35.0))
	dragon._rotate_bone_world(sk, 121, right, deg_to_rad(20.0))
	sk.force_update_all_bone_transforms()
	
	var cam: Camera3D = scene.get_node("FlightCamera")
	cam.set_process(false)
	cam.set_physics_process(false)
	cam.global_position = dragon.global_position + Vector3(0, 10, 18)
	cam.look_at(dragon.global_position + Vector3(0, 1, 0))
	
	for f in range(5): await process_frame
	await RenderingServer.frame_post_draw
	
	var img = root.get_texture().get_image()
	img.save_png("res://test_world_rot_fold.png")
	print("Saved test_world_rot_fold.png")
	quit(0)
