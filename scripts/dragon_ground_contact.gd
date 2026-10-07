extends RefCounted
# Translation guard. Pass the FINAL displacement intended for this physics tick.
# Successful results preserve its y. Apply the complete returned motion once;
# valid=false means whole-motion stop and pose recovery, never discard that flag.
const EPS := 0.000001
const DEPTH_EPS := 0.0001
const MAX_OVERLAPS := 4
const MAX_CONTACTS := 4
const MAX_CAST_PASSES := 3
const SWEEP_SEPARATION := 0.001 # Stop 1mm before contact to survive float32 actor coordinates.

static func constrain(space: PhysicsDirectSpaceState3D, hull: Shape3D,
		transform: Transform3D, rid: RID, actual_motion: Vector3) -> Dictionary:
	return constrain_all(space, [hull], transform, rid, actual_motion)

static func constrain_all(space: PhysicsDirectSpaceState3D, hulls: Array,
		transform: Transform3D, rid: RID, actual_motion: Vector3) -> Dictionary:
	var planes: Array = []
	var queries: Array = []
	var retreats: Array = []
	for hull_index in hulls.size():
		var hull: Shape3D = hulls[hull_index]
		if hull == null: continue
		if hull is ConvexPolygonShape3D and hull.points.size() < 4: continue
		for mask in [2]: # Only scenery obstacles (layer 2) restrict horizontal walking motion
			var query := _query(hull, transform, [rid], mask)
			queries.append(query)
			var hits := space.intersect_shape(query, MAX_OVERLAPS + 1)
			if hits.is_empty(): continue
			if hits.size() > MAX_OVERLAPS:
				return _blocked(planes, "overlap_budget_exceeded")
			for hit in hits:
				var collider_rid: RID = hit.rid
				# Restrict the recovery case to one convex shape per physical body.
				# Compound/concave overlaps need a pose fix, not a permissive cast.
				if not hit.collider is PhysicsBody3D:
					return _blocked(planes, "unsupported_overlap")
				if PhysicsServer3D.body_get_shape_count(collider_rid) != 1:
					return _blocked(planes, "compound_overlap_requires_clearance")
				var shape_rid := PhysicsServer3D.body_get_shape(collider_rid, int(hit.shape))
				var kind := PhysicsServer3D.shape_get_type(shape_rid)
				if kind < PhysicsServer3D.SHAPE_SPHERE or kind > PhysicsServer3D.SHAPE_CONVEX_POLYGON:
					return _blocked(planes, "nonconvex_overlap_requires_clearance")
				var excluded: Array[RID] = [rid]
				for other in hits:
					if other.rid != collider_rid: excluded.append(other.rid)
				var isolated := _query(hull, transform, excluded, mask)
				var pairs := space.collide_shape(isolated, MAX_CONTACTS)
				if pairs.is_empty() or pairs.size() % 2 != 0:
					return _blocked(planes, "ambiguous_existing_overlap")
				var depth := 0.0
				for index in range(0, pairs.size(), 2):
					# Zero query margin avoids treating separated witness points as
					# penetration. First point belongs to query; second to collider.
					var separation: Vector3 = pairs[index + 1] - pairs[index]
					var distance := separation.length()
					if distance <= EPS:
						return _blocked(planes, "degenerate_contact")
					depth = maxf(depth, distance)
					planes.append({"normal":separation / distance, "minimum":0.0,
						"hull":hull_index, "mask":mask, "rid":collider_rid,
						"query_point":pairs[index], "collider_point":pairs[index + 1]})
				retreats.append({"query":isolated, "depth":depth})
	var solved := solve(actual_motion, planes)
	if not solved.valid: return solved
	var candidate: Vector3 = solved.motion
	for attempt in MAX_CAST_PASSES:
		var fraction := 1.0
		for query in queries:
			query.motion = candidate
			var cast: PackedFloat32Array = space.cast_motion(query)
			if cast.size() != 2: return _blocked(planes, "invalid_cast")
			fraction = minf(fraction, clampf(cast[0], 0.0, 1.0))
		if fraction >= 1.0:
			# Verify that real contacts did not deepen at the accepted endpoint.
			# This supplements the convex contact-plane constraints; it is not a
			# substitute for a sweep of a concave/compound overlapping collider.
			for retreat in retreats:
				var check: PhysicsShapeQueryParameters3D = retreat.query
				check.transform.origin = transform.origin + candidate
				check.motion = Vector3.ZERO
				var pairs := space.collide_shape(check, MAX_CONTACTS)
				for index in range(0, pairs.size() - 1, 2):
					if pairs[index].distance_to(pairs[index + 1]) > float(retreat.depth) + DEPTH_EPS:
						return _blocked(planes, "retreat_deepens_contact")
			return {"motion":candidate, "planes":planes, "valid":true,
				"blocked":not candidate.is_equal_approx(actual_motion),
				"reason":"swept" if retreats.is_empty() else "convex_retreat_checked",
				"requires_pose_clearance":false}
		# Scaling x/z alone does NOT inherit a 3D cast's safe fraction. Re-solve
		# every plane and re-cast every hull on the resulting actual displacement.
		var separated_fraction := maxf(0.0,fraction-SWEEP_SEPARATION/maxf(candidate.length(),EPS))
		var shortened := Vector3(candidate.x * separated_fraction, actual_motion.y, candidate.z * separated_fraction)
		solved = solve(shortened, planes)
		if not solved.valid: return solved
		candidate = solved.motion
	return _blocked(planes, "cast_budget_exhausted")

# Closest feasible horizontal displacement, preserving desired.y. Constraints
# are normal.dot(motion) >= minimum; retain ALL hulls' planes in one invocation.
static func solve(desired: Vector3, planes: Array) -> Dictionary:
	var wanted := Vector2(desired.x, desired.z)
	var limits: Array = []
	for plane in planes:
		var normal: Vector3 = plane.normal
		var axis := Vector2(normal.x, normal.z)
		var bound: float = float(plane.get("minimum", 0.0)) - normal.y * desired.y
		if axis.length_squared() <= EPS * EPS:
			if bound > EPS: return _blocked(planes, "fixed_y_infeasible", true)
			continue
		limits.append({"axis":axis, "bound":bound})
	var candidates: Array[Vector2] = [wanted]
	for index in limits.size():
		var a: Vector2 = limits[index].axis
		var b: float = limits[index].bound
		candidates.append(wanted + a * ((b - a.dot(wanted)) / a.length_squared()))
		for other_index in range(index):
			var c: Vector2 = limits[other_index].axis
			var d: float = limits[other_index].bound
			var determinant := a.cross(c)
			if absf(determinant) <= EPS * a.length() * c.length(): continue
			candidates.append(Vector2(b * c.y - a.y * d, a.x * d - b * c.x) / determinant)
	var best := Vector2.ZERO
	var best_distance := INF
	for candidate in candidates:
		var feasible := true
		for limit in limits:
			var axis: Vector2 = limit.axis
			if axis.dot(candidate) < float(limit.bound) - EPS:
				feasible = false
				break
		if feasible and candidate.distance_squared_to(wanted) < best_distance:
			best = candidate
			best_distance = candidate.distance_squared_to(wanted)
	if is_inf(best_distance): return _blocked(planes, "contact_planes_infeasible", true)
	return {"motion":Vector3(best.x, desired.y, best.y), "planes":planes,
		"valid":true, "blocked":false, "reason":"planes_solved", "requires_pose_clearance":false}

static func _query(shape: Shape3D, transform: Transform3D, excluded: Array,
		mask: int) -> PhysicsShapeQueryParameters3D:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = transform
	var excluded_rids: Array[RID] = []
	excluded_rids.assign(excluded)
	query.exclude = excluded_rids
	query.collision_mask = mask
	query.margin = 0.0 # Real surfaces avoid artificial support overlaps and reversed gap witnesses.
	return query

static func _blocked(planes: Array, reason: String, pose_clearance := false) -> Dictionary:
	return {"motion":Vector3.ZERO, "planes":planes, "valid":false, "blocked":true,
		"reason":reason, "requires_pose_clearance":pose_clearance}
