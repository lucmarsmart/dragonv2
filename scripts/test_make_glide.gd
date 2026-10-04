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
		
	var anim_fly2 = ap.get_animation("Qishilong_fly2")
	var glide_anim = Animation.new()
	glide_anim.length = 2.0
	glide_anim.loop_mode = Animation.LOOP_LINEAR
	
	var rest_pelvis_pos = Vector3(32.7745, 356.433, 549.343)
	var t_glide = 45.30
	
	for t in range(anim_fly2.get_track_count()):
		var track_type = anim_fly2.track_get_type(t)
		var track_path = str(anim_fly2.track_get_path(t))
		var is_pelvis = "Bip001_03" in track_path
		
		var new_t = glide_anim.add_track(track_type)
		glide_anim.track_set_path(new_t, NodePath(track_path))
		glide_anim.track_set_interpolation_type(new_t, Animation.INTERPOLATION_CUBIC)
		
		if is_pelvis and track_type == Animation.TYPE_POSITION_3D:
			glide_anim.track_insert_key(new_t, 0.0, rest_pelvis_pos)
			glide_anim.track_insert_key(new_t, 2.0, rest_pelvis_pos)
		elif track_type == Animation.TYPE_ROTATION_3D:
			var rot = anim_fly2.rotation_track_interpolate(t, t_glide)
			glide_anim.track_insert_key(new_t, 0.0, rot)
			glide_anim.track_insert_key(new_t, 2.0, rot)
		elif track_type == Animation.TYPE_POSITION_3D:
			var pos = anim_fly2.position_track_interpolate(t, t_glide)
			glide_anim.track_insert_key(new_t, 0.0, pos)
			glide_anim.track_insert_key(new_t, 2.0, pos)
		elif track_type == Animation.TYPE_SCALE_3D:
			var scl = anim_fly2.scale_track_interpolate(t, t_glide)
			glide_anim.track_insert_key(new_t, 0.0, scl)
			glide_anim.track_insert_key(new_t, 2.0, scl)
			
	var lib = ap.get_animation_library("")
	lib.add_animation("Qishilong_glide", glide_anim)
	print("Glide anim created with %d tracks!" % glide_anim.get_track_count())
	quit(0)
