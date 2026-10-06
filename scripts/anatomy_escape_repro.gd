extends SceneTree
const Probe = preload("res://scripts/dragon_pose_probe.gd")
class AuthoredPose extends SkeletonModifier3D:
	var bones: Array = []
	var positions: Dictionary = {}
	func _process_modification() -> void:
		var sk := get_skeleton()
		for bone in bones: positions[bone] = sk.get_bone_pose_position(bone)
var dragon: Node3D
var full = Probe.new()
var label := ""
var skin_snapshots: Dictionary = {}
var acceptance := OS.get_cmdline_user_args().has("--acceptance")
var track_skin := false
var checked_frames := 0
var checked_vertices := 0
var maximum_penetration := 0.0
var maximum_head_step := 0.0
var maximum_link_change := 0.0
var previous_head := Vector3.ZERO
var authored: AuthoredPose
var failures: Array[String] = []
var egg: MeshInstance3D
func check(condition: bool, description: String) -> void:
	print("PASS " if condition else "FAIL ",description)
	if not condition: failures.append(description)
func egg_depth(world: Vector3) -> float:
	# Independent full visual surface: aligned64-sided,48-ring planar frusta.
	# Horizontal depth overestimates shortest surface distance, so5cm here is
	# conservative. It also detects closed-solid interiors omitted by trimesh queries.
	var point := egg.to_local(world)
	if point.y<=0 or point.y>=3.7: return 0.0
	var at := point.y/3.7*48.0
	var lower := mini(floori(at),47)
	var v0 := float(lower)/48.0
	var v1 := float(lower+1)/48.0
	var radius := lerpf(sin(v0*PI)*1.35*(1.1-v0*.4),sin(v1*PI)*1.35*(1.1-v1*.4),at-lower)
	var radial := Vector2(point.x,point.z).length()
	if radial>radius: return 0.0
	var sector := fposmod(atan2(point.z,point.x),TAU/64.0)
	var surface := radius*cos(PI/64.0)/cos(sector-PI/64.0)
	return maxf(0.0,surface-radial)
func _initialize() -> void: call_deferred("run")
func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
func capture_pose() -> void:
	if label.is_empty() and not track_skin: return
	var points := full.points(dragon.skeleton)
	if track_skin:
		checked_frames += 1
		checked_vertices += points.size()
		for point in points: maximum_penetration = maxf(maximum_penetration,egg_depth(point.position))
		if previous_head!=Vector3.ZERO: maximum_head_step = maxf(maximum_head_step,rad_to_deg(previous_head.angle_to(dragon.head_rendered_direction)))
		previous_head = dragon.head_rendered_direction
		for bone in dragon.bone_neck_indices+[dragon.bone_head_idx]:
			var position: Vector3 = dragon.skeleton.get_bone_pose_position(bone)
			maximum_link_change = maxf(maximum_link_change,position.distance_to(authored.positions[bone]))
	if label.is_empty(): return
	if label=="baseline":
		var egg_faces: PackedVector3Array = egg.global_transform*egg.mesh.get_faces()
		var geometry: Array = []
		for p in egg_faces: geometry.append([p.x,p.y,p.z])
		var vertices: Array = []
		for p in points: vertices.append([p.position.x,p.position.y,p.position.z])
		var collision: CollisionShape3D = egg.get_node("LastCaptiveDragonEgg_col").get_child(0)
		var collider_points: Array = []
		if collision.shape is ConvexPolygonShape3D:
			for p in collision.global_transform*collision.shape.points: collider_points.append([p.x,p.y,p.z])
		var output := FileAccess.open("res://docs/validation/v2/anatomy-escape-egg-geometry.json",FileAccess.WRITE)
		output.store_string(JSON.stringify({"egg_faces_world":geometry,"skin_vertices_world":vertices,"egg_transform":str(egg.global_transform),"collider_points_world":collider_points}))

	var terrain_min := INF
	var terrain_under := 0
	var terrain_checked := 0
	var point_query := PhysicsPointQueryParameters3D.new()
	point_query.collision_mask = 2
	point_query.exclude = [dragon.get_rid()]
	var prop_vertices := {}
	var hull_report: Array = []
	var space := dragon.get_world_3d().direct_space_state
	for point in points:
		# Concave point queries cannot certify closed-solid interior; use the
		# independent full-mesh egg hull verifier instead of expensive EPA per vertex.

		if not point.sample.wing and int(point.sample.claw)<0:
			var query := PhysicsRayQueryParameters3D.create(point.position+Vector3.UP*30,point.position+Vector3.DOWN*40,1)
			query.exclude = [dragon.get_rid()]
			var ground := space.intersect_ray(query)
			if not ground.is_empty():
				terrain_checked += 1
				var clearance: float = point.position.y-ground.position.y
				terrain_min = minf(terrain_min,clearance)
				if clearance<-.05: terrain_under += 1
	for index in dragon.wing_contact.hulls.size():
		for mask in [1,2]:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = dragon.wing_contact.hulls[index]
			query.transform = dragon.global_transform
			query.collision_mask = mask
			query.exclude = [dragon.get_rid()]
			query.margin = 0
			var started := Time.get_ticks_usec()
			var hits := space.intersect_shape(query,8)
			var details: Array = []
			for hit in hits: details.append(str(hit.collider.get_path()))
			hull_report.append({"hull":index,"mask":mask,"hits":details,"time_us":Time.get_ticks_usec()-started})
	print("ESCAPE_SKIN ",label," ",JSON.stringify({"vertices":points.size(),"body_terrain_checked":terrain_checked,"body_terrain_min":terrain_min,"body_terrain_under5cm":terrain_under,"prop_vertex_hits":prop_vertices,"hulls":hull_report,"position":str(dragon.global_position),"rotation":str(dragon.rotation),"head":str(dragon.head_rendered_direction),"details":dragon.wing_contact.contact_details,"body_pose_blocked":dragon.wing_contact.body_pose_blocked}))
	label = ""
func run() -> void:
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for frame in 100: await process_frame
	key(KEY_ENTER,true)
	await process_frame
	key(KEY_ENTER,false)
	dragon = scene.get_node("Dragon")
	egg = scene.get_node("SiegeEnvironment/LastCaptiveDragonEgg")
	dragon.global_position = Vector3(300.029602,27.500141,89.30162)
	dragon.rotation = Vector3(0,-.02241,0)
	dragon.target_yaw = -.02241
	dragon.target_pitch = 0
	dragon.target_roll = 0
	dragon.locomotion_state = dragon.LocomotionState.GROUNDED
	dragon.has_taken_off = true
	dragon.velocity = Vector3.ZERO
	dragon.current_speed = 0
	dragon.ground_blend = 1
	dragon.wing_fold_blend = 1
	dragon.ground_pose.reset()
	dragon.set_head_aim(-.017437491,PI/6)
	full.configure(dragon,dragon.skeleton,1)
	authored = AuthoredPose.new()
	authored.bones = dragon.bone_neck_indices+[dragon.bone_head_idx]
	dragon.skeleton.add_child(authored)
	dragon.skeleton.move_child(authored,0)
	var modifier: SkeletonModifier3D
	for child in dragon.skeleton.get_children():
		if child is SkeletonModifier3D: modifier = child
	modifier.modification_processed.connect(capture_pose)
	print("ISOLATED ESCAPE REGRESSION; exact native blocked position, yaw inferred from recorded snout; not mission acceptance")
	track_skin = acceptance
	for frame in 90:
		await physics_frame
		if frame%10==0:
			print("ESCAPE_WARM ",frame," ",JSON.stringify({"headblocked":dragon.head_pose_blocked,"costs":Probe.costs}))
			Probe.costs = {}
	label = "baseline"
	for frame in 2: await process_frame
	if acceptance:
		check(dragon.head_pose_blocked,"Blocked egg aim reports pose limit")
		check(egg_depth(egg.global_position+Vector3.UP*1.8)>.5,"Independent closed-surface probe rejects interior point")
	Probe.costs = {}
	key(KEY_S,true)
	key(KEY_SHIFT,true)
	var start := dragon.global_position
	for frame in (1 if "--geometry-only" in OS.get_cmdline_user_args() else 180):
		await physics_frame
		await process_frame
		if frame%30==0:
			print("ESCAPE_RUNTIME ",frame," ",JSON.stringify({"position":str(dragon.global_position),"speed":dragon.current_speed,"velocity":str(dragon.velocity),"contacts":dragon.wing_contact.contact_details,"body_pose_blocked":dragon.wing_contact.body_pose_blocked,"costs":Probe.costs}))
			Probe.costs = {}
	label = "retreat"
	for frame in 2: await process_frame
	key(KEY_S,false)
	key(KEY_SHIFT,false)
	print("ESCAPE_RESULT distance=",dragon.global_position.distance_to(start))
	if acceptance:
		check(dragon.global_position.distance_to(start)>3,"Native S+Shift retreats beyond3m from exact blocked egg position")
		check(checked_frames>=270 and checked_vertices==checked_frames*25603,"Every final rendered frame checks all25603 visible skin vertices")
		check(maximum_penetration<=.05,"Full skin stays within5cm penetration of actual closed visual egg")
		check(maximum_link_change<.00001,"Pose recovery preserves authored neck link translations")
		check(maximum_head_step<5,"Rendered head continuity remains below5degrees per frame")
		print("ESCAPE_ACCEPTANCE ",JSON.stringify({"frames":checked_frames,"vertices":checked_vertices,"max_visual_penetration_m":maximum_penetration,"max_head_step_degrees":maximum_head_step,"max_neck_translation_change":maximum_link_change,"retreat_m":dragon.global_position.distance_to(start),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
