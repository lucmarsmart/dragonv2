extends RefCounted
# Kinematic proxies on the ORIGINAL rig, not simulated biological muscles.
# Full rest/name/axis provenance: dragon_anatomy_reference.json.
const ACTUATORS := {
	"rear_left": [5, 6, 7, 8],
	"rear_right": [20, 21, 22, 23],
	"fore_left": [38, 39, 40, 41],
	"fore_right": [79, 80, 81, 82],
	"pectoral_wing_left": [96, 97],
	"pectoral_wing_right": [120, 121],
	"wing_left_digit_bases": [98, 104, 111, 117],
	"wing_right_digit_bases": [122, 128, 135, 141],
	"neck": [37, 53, 54, 55],
	"tail": [148, 149, 150, 151, 152, 153, 154, 155],
}

# A digitigrade rear has two opposite bends: hip/knee/hock/foot. Choosing
# the hock first prevents a common convex FABRIK arc from putting it below
# its planted foot. Every point lies on the ORIGINAL segment-length spheres.
# Empty means the target is outside the three-link reach or upright hock
# hemisphere; caller retains
# its existing fallback and collision handling.
static func rear_joints(joints: PackedVector3Array, lengths: PackedFloat32Array, target: Vector3, actor_to_skeleton: Basis, preferred_distal:Vector3=Vector3.ZERO) -> PackedVector3Array:
	if joints.size()!=4 or lengths.size()!=3: return PackedVector3Array()
	var hip: Vector3=joints[0]
	var thigh: float=lengths[0]
	var shin: float=lengths[1]
	var metatarsus: float=lengths[2]
	var foot_to_hip: Vector3=hip-target
	var distance: float=foot_to_hip.length()
	if minf(thigh,minf(shin,metatarsus))<.000001 or distance<.000001: return PackedVector3Array()
	var minimum: float=maxf(0.0,maxf(thigh,maxf(shin,metatarsus))*2.0-thigh-shin-metatarsus)
	if distance>thigh+shin+metatarsus or distance<minimum: return PackedVector3Array()
	# Continue the published hock on the foot-length sphere, both inside and
	# outside the reach cone. Returning to a fixed preferred direction on
	# leaving the cone would reintroduce the discontinuity at its boundary.
	var distal: Vector3=(actor_to_skeleton*Vector3(0,.9,.35)).normalized()
	var previous_distal: Vector3=joints[2]-target
	if previous_distal.length_squared()>.00000001:
		distal=previous_distal.normalized()
	if not preferred_distal.is_zero_approx(): distal=preferred_distal.normalized()
	var lower: float=absf(thigh-shin)
	var upper: float=thigh+shin
	# A reachable knee circle is not necessarily compatible with the source
	# opposing bends. For the original rear rig shin > metatarsus, existence
	# of that compatible arc also bounds the hip/hock radius. Derive this
	# bound before choosing H, rather than clamping an impossible knee arc.
	if shin>metatarsus+.000001:
		var difference: float=thigh*thigh-shin*shin
		var foot_radius: float=distance*distance-metatarsus*metatarsus
		var opposed_upper_squared: float
		if foot_radius>=difference:
			opposed_upper_squared=(shin*foot_radius-metatarsus*difference)/(shin-metatarsus)
		else:
			opposed_upper_squared=(shin*foot_radius+metatarsus*difference)/(shin+metatarsus)
		upper=minf(upper,sqrt(maxf(lower*lower,opposed_upper_squared)))
	var axis: Vector3=foot_to_hip/distance
	var cosine_min: float=clampf((distance*distance+metatarsus*metatarsus-upper*upper)/(2.0*distance*metatarsus),-1.0,1.0)
	var cosine_max: float=clampf((distance*distance+metatarsus*metatarsus-lower*lower)/(2.0*distance*metatarsus),-1.0,1.0)
	var up: Vector3=(actor_to_skeleton*Vector3.UP).normalized()
	distal=_closest_upright_distal(distal,axis,up,cosine_min,cosine_max,actor_to_skeleton*Vector3.FORWARD)
	if distal==Vector3.ZERO: return PackedVector3Array()
	var hock: Vector3=target+distal*metatarsus
	var hock_distance: float=hock.distance_to(hip)
	if hock_distance<.000001: return PackedVector3Array()
	var knee_axis: Vector3=(hock-hip)/hock_distance
	var along: float=(thigh*thigh-shin*shin+hock_distance*hock_distance)/(2.0*hock_distance)
	var center: Vector3=hip+knee_axis*along
	var radius: float=sqrt(maxf(0.0,thigh*thigh-along*along))
	var knee_pole: Vector3=joints[1]-center
	# Continue the incoming knee plane when it is well defined.
	knee_pole-=knee_axis*knee_pole.dot(knee_axis)
	if knee_pole.length_squared()<.00000001:
		knee_pole=actor_to_skeleton*Vector3.FORWARD
		knee_pole-=knee_axis*knee_pole.dot(knee_axis)
	if knee_pole.length_squared()<.00000001:
		knee_pole=knee_axis.cross(Vector3.RIGHT if absf(knee_axis.x)<.9 else Vector3.UP)
	var knee: Vector3=center+knee_pole.normalized()*radius
	var knee_bend: Vector3=(knee-hip).cross(hock-knee)
	var hock_bend: Vector3=(hock-knee).cross(target-hock)
	# Source rests have opposing knee/hock bend normals. A hard knee mirror
	# chooses a point 180 degrees away on the knee circle. Instead project
	# the previous pole to the nearest compatible arc on that same circle.
	if knee_bend.dot(hock_bend)>0.0:
		var distal_link: Vector3=target-hock
		var axial: float=distal_link.dot(knee_axis)
		var perpendicular: Vector3=distal_link-knee_axis*axial
		var remaining: float=hock_distance-along
		if absf(remaining)>.000001 and perpendicular.length_squared()>.00000001:
			var compatible_axis: Vector3=perpendicular.normalized()*signf(remaining)
			var cosine_limit: float=clampf(-radius*axial/(absf(remaining)*perpendicular.length()),-1.0,1.0)
			var tangent: Vector3=knee_pole-knee_pole.dot(compatible_axis)*compatible_axis
			if tangent.length_squared()<.00000001: tangent=knee_axis.cross(compatible_axis)
			var compatible_pole: Vector3=compatible_axis*cosine_limit+tangent.normalized()*sqrt(maxf(0.0,1.0-cosine_limit*cosine_limit))
			knee=center+compatible_pole*radius
	return PackedVector3Array([hip,knee,hock,target])

# Closest published direction on the unit sphere subject to the hip reach
# band and H above F. The nearest feasible point is either the original
# direction, a nearest point on a boundary circle, or an intersection of
# the reach circle with the upright hemisphere boundary.
static func _closest_upright_distal(preferred: Vector3, axis: Vector3, up: Vector3, cosine_min: float, cosine_max: float, fallback: Vector3) -> Vector3:
	var candidates:=PackedVector3Array([preferred])
	var radial: Vector3=preferred-axis*preferred.dot(axis)
	if radial.length_squared()<.00000001:
		radial=fallback-axis*fallback.dot(axis)
	if radial.length_squared()<.00000001:
		radial=axis.cross(Vector3.RIGHT if absf(axis.x)<.9 else Vector3.UP)
	var horizontal: Vector3=preferred-up*preferred.dot(up)
	if horizontal.length_squared()>.00000001: candidates.append(horizontal.normalized())
	var horizontal_axis: Vector3=axis-up*axis.dot(up)
	for cosine in [cosine_min,cosine_max]:
		candidates.append(axis*cosine+radial.normalized()*sqrt(maxf(0.0,1.0-cosine*cosine)))
		if horizontal_axis.length_squared()>.00000001:
			var horizontal_cosine: float=cosine/horizontal_axis.length()
			if absf(horizontal_cosine)<=1.0:
				var horizontal_direction: Vector3=horizontal_axis.normalized()
				var tangent: Vector3=up.cross(horizontal_direction).normalized()
				var intersection_center: Vector3=horizontal_direction*horizontal_cosine
				var intersection_radius: float=sqrt(maxf(0.0,1.0-horizontal_cosine*horizontal_cosine))
				candidates.append(intersection_center+tangent*intersection_radius)
				candidates.append(intersection_center-tangent*intersection_radius)
	var closest:=Vector3.ZERO
	var best_score: float=-INF
	for candidate in candidates:
		candidate=candidate.normalized()
		var reach_cosine: float=candidate.dot(axis)
		# Vector3 boundary construction/dot products use float32 even though
		# scalar formulas use doubles. Rejecting their rounding residual can
		# discard the nearest reach circle and jump to the other boundary.
		if candidate.dot(up)<-.000001 or reach_cosine<cosine_min-.000001 or reach_cosine>cosine_max+.000001: continue
		var score: float=candidate.dot(preferred)
		if score>best_score:
			best_score=score
			closest=candidate
	return closest
