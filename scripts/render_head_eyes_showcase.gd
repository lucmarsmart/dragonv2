extends SceneTree

func _init():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	
	# Hide HUD and Siege UI
	var siege_ui = scene.get_node_or_null("SiegeUI")
	if siege_ui: siege_ui.visible = false
	var hud = scene.get_node_or_null("HUD")
	if hud: hud.visible = false
	
	var dragon = scene.get_node("Dragon")
	var cam: Camera3D = scene.get_node("FlightCamera")
	cam.set_script(null)
	
	for f in range(25): await process_frame
	
	# Find MeshInstance3D of Object_8 (Body & Head)
	var mi: MeshInstance3D = null
	for child in dragon.visual_root.find_children("*", "MeshInstance3D", true, false):
		if child.name == "Object_8" or (child.mesh and child.mesh.get_surface_count() > 0):
			mi = child
			break
			
	var skel: Skeleton3D = dragon.skeleton
	var b_head = dragon.bone_head_idx
	var head_pos = skel.global_transform * skel.get_bone_global_pose(b_head).origin
	
	# Find the vertices closest to the eye UVs
	var target_uv_left = Vector2(655.0 / 1024.0, 893.0 / 1024.0)
	var best_dist = 999.0
	var eye_left_world = head_pos
	
	if mi and mi.mesh:
		var arr = mi.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		
		for i in range(uvs.size()):
			var uv = uvs[i]
			var d = uv.distance_to(target_uv_left)
			if d < best_dist:
				best_dist = d
				# approximate position via mesh global transform
				eye_left_world = mi.global_transform * verts[i]
				
	print("Head Bone Pos: ", head_pos, " Eye Approx World: ", eye_left_world, " best UV dist: ", best_dist)
	
	# Let's take 3 focused head shots:
	# 1. Left side 3/4 front view showing snout, single golden eye, horn crest
	var target_focus = head_pos + (eye_left_world - head_pos) * 0.5
	cam.fov = 28.0
	cam.global_position = head_pos - dragon.global_basis.x * 2.2 + dragon.global_basis.y * 0.4 - dragon.global_basis.z * 1.8
	cam.look_at(head_pos - dragon.global_basis.z * 0.6, Vector3.UP)
	
	for f in range(5): await process_frame
	var img_head_l = root.get_viewport().get_texture().get_image()
	if img_head_l:
		img_head_l.save_png("c:/Proyectos/Dragon v2/showcase_head_eye_left.png")
		print("Saved showcase_head_eye_left.png")
		
	# 2. Right side 3/4 front view showing the single right golden eye
	cam.global_position = head_pos + dragon.global_basis.x * 2.2 + dragon.global_basis.y * 0.4 - dragon.global_basis.z * 1.8
	cam.look_at(head_pos - dragon.global_basis.z * 0.6, Vector3.UP)
	for f in range(5): await process_frame
	var img_head_r = root.get_viewport().get_texture().get_image()
	if img_head_r:
		img_head_r.save_png("c:/Proyectos/Dragon v2/showcase_head_eye_right.png")
		print("Saved showcase_head_eye_right.png")
		
	# 3. Direct side profile of the face / snout
	cam.global_position = head_pos - dragon.global_basis.x * 2.6 + dragon.global_basis.y * 0.1 - dragon.global_basis.z * 0.5
	cam.look_at(head_pos - dragon.global_basis.z * 0.5, Vector3.UP)
	for f in range(5): await process_frame
	var img_profile = root.get_viewport().get_texture().get_image()
	if img_profile:
		img_profile.save_png("c:/Proyectos/Dragon v2/showcase_head_side_profile.png")
		print("Saved showcase_head_side_profile.png")
		
	quit(0)
