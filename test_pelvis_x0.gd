extends SceneTree

var frames = 0
var main_scene = null

func _init():
	main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)

func _process(_delta: float) -> bool:
	frames += 1
	var dragon = main_scene.get_node("Dragon")
	var sk: Skeleton3D = dragon.find_child("*Skeleton3D*", true, false)
	var anim_player: AnimationPlayer = dragon.find_child("*AnimationPlayer*", true, false)
	
	var b_s2 = sk.find_bone("Bip001-Spine2_07")
	var b_head = sk.find_bone("Bip001-Head_011")
	
	if frames == 1:
		# Fix the pelvis track in Qishilong_fly2
		var lib = anim_player.get_animation_library("")
		var anim = lib.get_animation("Qishilong_fly2")
		for t in range(anim.get_track_count()):
			if "Bip001_03" in str(anim.track_get_path(t)) and anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
				var v0 = anim.track_get_key_value(t, 0)
				print("Original track key 0: ", v0)
				# replace with X = 0
				var fixed_v = Vector3(0.0, v0.y, v0.z)
				anim.track_set_key_value(t, 0, fixed_v)
				anim.track_set_key_value(t, 1, fixed_v)
		anim_player.play("Qishilong_fly2")
		
	var s2_d = dragon.to_local(sk.to_global(sk.get_bone_global_pose(b_s2).origin))
	var head_d = dragon.to_local(sk.to_global(sk.get_bone_global_pose(b_head).origin))
	
	print("Frame %d | Spine2_d: %s | Head_d: %s" % [frames, s2_d, head_d])
	
	if frames == 5:
		quit(0)
		return true
	return false
