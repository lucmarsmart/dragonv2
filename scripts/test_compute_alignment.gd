@tool
extends SceneTree

func _init():
	var raw_scene = load("res://assets/models/dragon.glb").instantiate()
	root.add_child(raw_scene)
	
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
	
	var pelvis_p = skel.get_bone_global_pose(skel.find_bone("Bip001_03")).origin
	var spine2_p = skel.get_bone_global_pose(skel.find_bone("Bip001-Spine2_07")).origin
	var r_wing_p = skel.get_bone_global_pose(skel.find_bone("Bone017_068")).origin
	var l_wing_p = skel.get_bone_global_pose(skel.find_bone("Bone017(mirrored)_092")).origin
	
	# Model's local forward (from pelvis along spine to chest):
	var local_fwd = (spine2_p - pelvis_p).normalized()
	# Model's local right (from left wing to right wing):
	var local_right = (r_wing_p - l_wing_p).normalized()
	# Model's local up (dorsal crest, orthogonal to fwd and right):
	var local_up = local_right.cross(local_fwd).normalized()
	# Re-orthogonalize right:
	local_right = local_fwd.cross(local_up).normalized()
	
	print("MODEL LOCAL AXES IN RAW GLB (AT 34s):")
	print("Local Forward: ", local_fwd)
	print("Local Right:   ", local_right)
	print("Local Up (Back): ", local_up)
	
	# We want:
	# target_forward = Vector3(0, 0, -1)   (-Z)
	# target_up      = Vector3(0, 1, 0)    (+Y, back to sky!)
	# target_right   = Vector3(1, 0, 0)    (+X)
	
	# Current basis of the dragon:
	var dragon_basis = Basis(local_right, local_up, -local_fwd)
	
	# The rotation R needed satisfies: R * dragon_basis = Basis.IDENTITY
	# So R = dragon_basis.inverse()
	var needed_basis = dragon_basis.inverse()
	var needed_euler = needed_basis.get_euler()
	var needed_deg = Vector3(rad_to_deg(needed_euler.x), rad_to_deg(needed_euler.y), rad_to_deg(needed_euler.z))
	
	print("\nEXACT NEEDED ROTATION TO ALIGN BACK TO SKY (+Y) AND HEAD TO -Z:")
	print("Euler degrees (Pitch, Yaw, Roll): ", needed_deg)
	print("Needed Basis:\n", needed_basis)
	
	quit(0)
