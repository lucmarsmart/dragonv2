extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	var d = scene.get_node("Dragon")
	var vm = scene.get_node("Dragon/VisualModel")
	var cam = scene.get_node("FlightCamera")
	var sk: Skeleton3D = d.find_child("*Skeleton3D*", true, false)
	
	print("--- POSITIONS IN RUNNING SCENE ---")
	print("Dragon pos: ", d.global_position)
	print("VisualModel pos: ", vm.global_position, " rot: ", vm.rotation_degrees)
	print("Camera pos: ", cam.global_position)
	
	var spine0 = sk.find_bone("Bip001-Spine_05")
	var spine2 = sk.find_bone("Bip001-Spine2_07")
	var head = sk.find_bone("Bip001-Head_011")
	var pelvis = sk.find_bone("Bip001_03")
	
	print("Spine0 global pos: ", sk.get_bone_global_pose(spine0).origin)
	print("Spine2 global pos: ", sk.get_bone_global_pose(spine2).origin)
	print("Head global pos:   ", sk.get_bone_global_pose(head).origin)
	print("Pelvis global pos: ", sk.get_bone_global_pose(pelvis).origin)
	
	# Relative to Dragon root:
	var s0_world = sk.global_transform * sk.get_bone_global_pose(spine0).origin
	var s2_world = sk.global_transform * sk.get_bone_global_pose(spine2).origin
	var h_world = sk.global_transform * sk.get_bone_global_pose(head).origin
	print("World Spine0 pos: ", s0_world)
	print("World Spine2 pos: ", s2_world)
	print("World Head pos:   ", h_world)
	
	print("Offset from Dragon center to Spine0: ", s0_world - d.global_position)
	print("Offset from Dragon center to Head:   ", h_world - d.global_position)
	
	quit(0)
