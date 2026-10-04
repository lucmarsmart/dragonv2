@tool
extends SceneTree

# Paso A: Investigar si existe animación de caminata o en tierra en algún clip
func _init():
	var raw = load("res://assets/models/dragon.glb").instantiate()
	root.add_child(raw)
	var ap: AnimationPlayer = null
	var sk: Skeleton3D = null
	var q = [raw]
	while q.size() > 0:
		var c = q.pop_front()
		if c is AnimationPlayer: ap = c
		if c is Skeleton3D: sk = c
		for ch in c.get_children(): q.append(ch)
		
	var l_foot = sk.find_bone("Bip001-L-Foot_0118")
	var r_foot = sk.find_bone("Bip001-R-Foot_0133")
	var l_thigh = sk.find_bone("Bip001-L-Thigh_0115")
	var r_thigh = sk.find_bone("Bip001-R-Thigh_0130")
	var l_calf = sk.find_bone("Bip001-L-Calf_0116")
	var r_calf = sk.find_bone("Bip001-R-Calf_0131")
	var pelvis = sk.find_bone("Bip001_03")
	var spine = sk.find_bone("Bip001-Spine2_07")
	var head = sk.find_bone("Bip001-Head_011")
	var tail = sk.find_bone("Bone008_0154")
	
	for anim_name in ap.get_animation_list():
		var a = ap.get_animation(anim_name)
		ap.play(anim_name)
		ap.pause()
		print("\n==========================================")
		print("Analizando anim: ", anim_name, " (longitud: ", a.length, "s)")
		print("==========================================")
		
		var step = 0.5
		var t = 0.0
		var walk_candidates = []
		
		while t <= a.length:
			ap.seek(t, true)
			await process_frame
			await process_frame
			
			var p_pel = sk.get_bone_global_pose(pelvis).origin
			var p_lf = sk.get_bone_global_pose(l_foot).origin
			var p_rf = sk.get_bone_global_pose(r_foot).origin
			var p_lt = sk.get_bone_global_pose(l_thigh).origin
			var p_rt = sk.get_bone_global_pose(r_thigh).origin
			var p_head = sk.get_bone_global_pose(head).origin
			
			# Altura de patas relativa a pelvis
			var leg_drop_l = p_pel.y - p_lf.y
			var leg_drop_r = p_pel.y - p_rf.y
			# Desfase entre muslos en Z (avance alterno de marcha)
			var thigh_z_diff = abs(p_lt.z - p_rt.z)
			var foot_z_diff = abs(p_lf.z - p_rf.z)
			
			# ¿Pies están por debajo de pelvis?
			# En vuelo, las patas cuelgan o se pliegan hacia atrás (+Z).
			# En tierra, los pies tocan el suelo (Y bajo) y se mueven hacia adelante y atrás.
			if foot_z_diff > 150.0 and thigh_z_diff > 80.0:
				walk_candidates.append({
					"t": t,
					"foot_diff": foot_z_diff,
					"thigh_diff": thigh_z_diff,
					"leg_drop": min(leg_drop_l, leg_drop_r)
				})
				
			t += step
			
		print("Candidatos de alternancia de patas en ", anim_name, ": ", walk_candidates.size())
		if walk_candidates.size() > 0:
			for i in range(min(5, walk_candidates.size())):
				var c = walk_candidates[i]
				print("  t=%.2f: foot_diff=%.1f thigh_diff=%.1f leg_drop=%.1f" % [c["t"], c["foot_diff"], c["thigh_diff"], c["leg_drop"]])
				
	quit(0)
