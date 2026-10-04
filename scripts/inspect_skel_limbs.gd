@tool
extends SceneTree

func _init():
	var raw = load("res://assets/models/dragon.glb").instantiate()
	root.add_child(raw)
	var sk: Skeleton3D = null
	var q = [raw]
	while q.size() > 0:
		var c = q.pop_front()
		if c is Skeleton3D: sk = c
		for ch in c.get_children(): q.append(ch)
		
	print("--- SKELETON BONES (Total: %d) ---" % sk.get_bone_count())
	for i in range(sk.get_bone_count()):
		var bname = sk.get_bone_name(i)
		var p_idx = sk.get_bone_parent(i)
		var pname = sk.get_bone_name(p_idx) if p_idx != -1 else "ROOT"
		if "Thigh" in bname or "Foot" in bname or "Calf" in bname or "Arm" in bname or "Hand" in bname or "Wing" in bname or "Pelvis" in bname or "Spine" in bname:
			print("Bone [%d] '%s' (parent: %s)" % [i, bname, pname])
	quit(0)
