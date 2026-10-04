@tool
extends SceneTree

func _init():
	var root_node = Node3D.new()
	root.add_child(root_node)
	
	var dragon_body = Node3D.new()
	root_node.add_child(dragon_body)
	
	var visual_root = Node3D.new()
	dragon_body.add_child(visual_root)
	
	var raw_scene = load("res://assets/models/dragon.glb").instantiate()
	visual_root.add_child(raw_scene)
	
	var ap: AnimationPlayer = null
	var skel: Skeleton3D = null
	var q = [raw_scene]
	while q.size() > 0:
		var c = q.pop_front()
		if c is AnimationPlayer: ap = c
		if c is Skeleton3D: skel = c
		for ch in c.get_children(): q.append(ch)
		
	ap.play("Qishilong_fly2")
	var b_pelvis = skel.find_bone("Bip001_03")
	var b_head = skel.find_bone("Bip001-Head_011")
	var b_tail = skel.find_bone("Bone008_0154")
	var b_rw = skel.find_bone("Bone017_068")
	var b_lw = skel.find_bone("Bone017(mirrored)_092")
	
	for yaw in [-24.0, -25.0, -26.0, -27.0, -28.0, -29.0, -30.0]:
		visual_root.rotation_degrees = Vector3(0, yaw, 0)
		visual_root.position = Vector3.ZERO
		ap.seek(34.0, true)
		for f in range(2): await process_frame
		
		var pelvis_world = skel.global_transform * skel.get_bone_global_pose(b_pelvis).origin
		visual_root.global_position += (dragon_body.global_position - pelvis_world)
		for f in range(2): await process_frame
		
		var h = skel.global_transform * skel.get_bone_global_pose(b_head).origin - dragon_body.global_position
		var t = skel.global_transform * skel.get_bone_global_pose(b_tail).origin - dragon_body.global_position
		var rw = skel.global_transform * skel.get_bone_global_pose(b_rw).origin - dragon_body.global_position
		var lw = skel.global_transform * skel.get_bone_global_pose(b_lw).origin - dragon_body.global_position
		
		# Wing symmetry: rw.x should be positive, lw.x should be negative, |rw.x| == |lw.x|
		var wing_asym = abs(rw.x + lw.x)
		print("Yaw %5.1f: Head X=%+5.2f, Tail X=%+5.2f, RW.X=%+5.2f, LW.X=%+5.2f, Wing Asym=%5.2f" % [yaw, h.x, t.x, rw.x, lw.x, wing_asym])
		
	quit(0)
