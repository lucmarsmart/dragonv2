extends SceneTree

func _init():
	var d = load("res://assets/models/dragon.glb").instantiate()
	var ap: AnimationPlayer = d.find_child("*AnimationPlayer*", true, false)
	var sk: Skeleton3D = d.find_child("*Skeleton3D*", true, false)
	var a = ap.get_animation("Qishilong_up")
	
	print("--- ALL BONES WITH 'Wing' OR 'Bone01' OR 'Bone02' ---")
	for i in range(sk.get_bone_count()):
		var b_name = sk.get_bone_name(i)
		if "wing" in b_name.to_lower() or "bone01" in b_name.to_lower() or "bone02" in b_name.to_lower():
			print("Bone %d: %s (Parent: %s)" % [i, b_name, sk.get_bone_name(sk.get_bone_parent(i)) if sk.get_bone_parent(i) != -1 else "NONE"])
	quit(0)
