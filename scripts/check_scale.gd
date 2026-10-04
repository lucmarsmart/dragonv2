@tool
extends SceneTree

func _init():
	var raw_scene = load("res://assets/models/dragon.glb").instantiate()
	root.add_child(raw_scene)
	raw_scene.position = Vector3(0, 0, 0)
	raw_scene.rotation_degrees = Vector3(0, 180, 0)
	
	var ap: AnimationPlayer = null
	var skel: Skeleton3D = null
	var q = [raw_scene]
	while q.size() > 0:
		var c = q.pop_front()
		if c is AnimationPlayer: ap = c
		if c is Skeleton3D: skel = c
		for ch in c.get_children(): q.append(ch)
		
	ap.play("Qishilong_fly2")
	ap.seek(34.0, true)
	for f in range(2): await process_frame
	
	var b_pelvis = skel.find_bone("Bip001_03")
	var pelvis_world = skel.global_transform * skel.get_bone_global_pose(b_pelvis).origin
	print("pelvis_world at 34.0: ", pelvis_world)
	print("skel.scale: ", skel.scale, " raw_scene.scale: ", raw_scene.scale)
	quit(0)
