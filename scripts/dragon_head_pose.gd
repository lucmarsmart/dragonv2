extends RefCounted
# One driver owns the neck. Collision limits the rendered pose, never the actor position.
const Probe = preload("res://scripts/dragon_pose_probe.gd")
var probe = Probe.new()
var shape := ConvexPolygonShape3D.new()
var near_box := BoxShape3D.new()
var last_safe_pose: Dictionary = {}
var nearby_hits: Array[Dictionary] = []
var convex_bounds: Dictionary = {}

func _drive(dragon: Node3D, sk: Skeleton3D, wanted: Vector3) -> void:
	var head: int = dragon.bone_head_idx
	var muzzle := sk.find_bone("Point021_018")
	# The source's basal Neck joint also parents both fore-leg clavicles.
	# Aim through the two upper cervicals and skull so looking sideways does
	# not pull the load-bearing shoulders and planted forefeet with the head.
	for pair in [[dragon.bone_neck_indices[1], 0.22], [dragon.bone_neck_indices[2], 0.38], [head, 0.40]]:
		var current := (sk.to_global(sk.get_bone_global_pose(muzzle).origin) - sk.to_global(sk.get_bone_global_pose(head).origin)).normalized()
		var correction := Quaternion.IDENTITY.slerp(Quaternion(current, wanted), float(pair[1]))
		var b: int = pair[0]
		var parent := sk.get_bone_parent(b)
		var parent_world := (sk.global_basis * sk.get_bone_global_pose(parent).basis).orthonormalized().get_rotation_quaternion()
		sk.set_bone_pose_rotation(b, parent_world.inverse() * correction * parent_world * sk.get_bone_pose_rotation(b))
	dragon.head_rendered_direction = (sk.to_global(sk.get_bone_global_pose(muzzle).origin) - sk.to_global(sk.get_bone_global_pose(head).origin)).normalized()

func _neck_contact(dragon: Node3D, sk: Skeleton3D) -> bool:
	if probe.samples.is_empty():
		probe.profile_label = "head_skin"
		# Reuse the immutable affine support already calibrated by the final pose sampler.
		probe.samples = dragon.wing_contact.probe.samples.filter(func(sample): return sample.neck)
	var points := probe.coordinates(sk,dragon)
	# A vertex inside a convex solid is positive contact evidence. Point queries
	# use the actual physics shape; casts remain necessary for edge/face crossings
	# with no interior vertex. This avoids expensive EPA on a rejected aim pose.
	var positive_started := Time.get_ticks_usec() if Probe.profiling else 0
	for hit in nearby_hits:
		if not is_instance_valid(hit.collider): continue
		for child in hit.collider.get_children():
			if not child is CollisionShape3D or not child.shape is ConvexPolygonShape3D: continue
			var identity: RID = child.shape.get_rid()
			if not convex_bounds.has(identity):
				var vertices: PackedVector3Array = child.shape.points
				var bounds := AABB(vertices[0],Vector3.ZERO)
				for vertex in vertices: bounds = bounds.expand(vertex)
				convex_bounds[identity] = bounds
			var placement: Transform3D = child.global_transform.affine_inverse()*dragon.global_transform
			var bounds: AABB = convex_bounds[identity]
			var query := PhysicsPointQueryParameters3D.new()
			query.exclude = [dragon.get_rid()]
			query.collision_mask = 3
			for point in points:
				if not bounds.has_point(placement*point): continue
				query.position = dragon.to_global(point)
				if not dragon.get_world_3d().direct_space_state.intersect_point(query,1).is_empty():
					Probe.record("head_positive_query",positive_started)
					return true
	Probe.record("head_positive_query",positive_started)
	var hull_started := Time.get_ticks_usec() if Probe.profiling else 0
	shape.points = points
	Probe.record("head_hull",hull_started)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = dragon.global_transform
	query.exclude = [dragon.get_rid()]
	query.margin = 0.08
	query.collision_mask = 3
	var query_started := Time.get_ticks_usec() if Probe.profiling else 0
	var blocked := not dragon.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
	Probe.record("head_query",query_started)
	return blocked

func _obstacle_near(dragon: Node3D) -> bool:
	if dragon.wing_contact.hulls.size() < 4 or dragon.wing_contact.hulls[3].points.size() < 4: return false
	var query := PhysicsShapeQueryParameters3D.new()
	var points: PackedVector3Array = dragon.wing_contact.hulls[3].points
	var bounds := AABB(points[0],Vector3.ZERO)
	for point in points: bounds = bounds.expand(point)
	bounds = bounds.grow(2.0)
	near_box.size = bounds.size
	query.shape = near_box
	query.transform = dragon.global_transform*Transform3D(Basis.IDENTITY,bounds.get_center())
	query.exclude = [dragon.get_rid()]
	# More than maximum neck travel of a4-degree aim tick on this audited rig.
	query.margin = 0.0
	query.collision_mask = 3
	var started := Time.get_ticks_usec() if Probe.profiling else 0
	nearby_hits.assign(dragon.get_world_3d().direct_space_state.intersect_shape(query,16))
	var nearby := not nearby_hits.is_empty()
	Probe.record("head_broad_query",started)
	return nearby

func _limited_direction(previous: Vector3, wanted: Vector3, step: float) -> Vector3:
	var angle := previous.angle_to(wanted)
	if angle <= step or angle < 0.001: return wanted
	var axis := previous.cross(wanted)
	if axis.length_squared() < 0.000001:
		axis = previous.cross(Vector3.UP)
		if axis.length_squared() < 0.000001: axis = previous.cross(Vector3.RIGHT)
	return (Basis(axis.normalized(),step) * previous).normalized()

func apply(dragon: Node3D, sk: Skeleton3D) -> void:
	var head: int = dragon.bone_head_idx
	var muzzle := sk.find_bone("Point021_018")
	if head < 0 or muzzle < 0: return
	var bones: Array = dragon.bone_neck_indices.duplicate()
	bones.append(head)
	var nearby := _obstacle_near(dragon)
	var previous: Vector3 = dragon.head_rendered_direction
	var wanted := _limited_direction(previous,dragon.head_aim_direction,minf(deg_to_rad(4.0),deg_to_rad(240.0)*dragon.get_process_delta_time()))
	_drive(dragon,sk,wanted)
	dragon.head_pose_blocked = false
	if nearby and _neck_contact(dragon,sk):
		dragon.head_pose_blocked = true
		if not last_safe_pose.is_empty():
			var root: int = bones[0]
			var parent := sk.get_bone_parent(root)
			var root_pose: Transform3D = sk.global_transform.affine_inverse()*dragon.global_transform*last_safe_pose.root_relative
			var local: Transform3D = sk.get_bone_global_pose(parent).affine_inverse()*root_pose
			sk.set_bone_pose_rotation(root,local.basis.orthonormalized().get_rotation_quaternion())
			for bone in last_safe_pose.children:
				sk.set_bone_pose_rotation(int(bone),last_safe_pose.children[bone].rotation)
			dragon.head_rendered_direction = (sk.to_global(sk.get_bone_global_pose(muzzle).origin)-sk.to_global(sk.get_bone_global_pose(head).origin)).normalized()
	else:
		var children := {}
		for bone in bones:
			if bone!=bones[0]: children[bone] = {"rotation":sk.get_bone_pose_rotation(bone),"position":sk.get_bone_pose_position(bone)}
		last_safe_pose = {"root_relative":dragon.global_transform.affine_inverse()*sk.global_transform*sk.get_bone_global_pose(bones[0]),"children":children}
