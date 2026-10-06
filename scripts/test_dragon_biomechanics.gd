extends SceneTree
const Biomechanics = preload("res://scripts/dragon_biomechanics.gd")
var failures: Array[String] = []
const LENGTHS := Vector3(2.396954,1.305055,.81368)

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)

# Negative control: the original preferred-direction cone projection, without
# a published hock seed. Its radial changes sign across this alignment.
func original_hock(hip: Vector3, foot: Vector3) -> Vector3:
	var distal:=Vector3(0,.9,.35).normalized()
	var axis: Vector3=(hip-foot).normalized()
	var distance: float=hip.distance_to(foot)
	var reach: float=absf(LENGTHS.x-LENGTHS.y)
	var cosine: float=clampf((distance*distance+LENGTHS.z*LENGTHS.z-reach*reach)/(2*distance*LENGTHS.z),-1,1)
	var radial: Vector3=(distal-axis*distal.dot(axis)).normalized()
	return foot+(axis*cosine+radial*sqrt(maxf(0,1-cosine*cosine)))*LENGTHS.z

func _initialize() -> void:
	var hip:=Vector3(0,2.5,0)
	var first_foot:=Vector3(0,1.4,-.4277777778-.0002)
	var next_foot:=Vector3(0,1.4,-.4277777778+.0002)
	var old_hock: Vector3=original_hock(hip,first_foot)
	var original_jump: float=old_hock.distance_to(original_hock(hip,next_foot))
	check(original_jump>1.0,"Original preferred radial has >1m hock jump for a 0.4mm foot move")
	var lengths:=PackedFloat32Array([LENGTHS.x,LENGTHS.y,LENGTHS.z])
	var seed:=PackedVector3Array([hip,Vector3(0,.8,-1.2),old_hock,first_foot])
	var previous: PackedVector3Array=Biomechanics.rear_joints(seed,lengths,first_foot,Basis.IDENTITY)
	check(previous.size()==4,"Actual helper initializes reachable cone fixture")
	if previous.size()!=4:
		quit(1)
		return
	var initial_pose: PackedVector3Array=previous.duplicate()
	var current: PackedVector3Array=Biomechanics.rear_joints(previous,lengths,next_foot,Basis.IDENTITY)
	check(current.size()==4,"Actual helper resolves published-seed crossing")
	if current.size()!=4:
		quit(1)
		return
	var crossing_hock_step: float=current[2].distance_to(previous[2])
	var crossing_angle:=0.0
	for link in 3:
		crossing_angle=maxf(crossing_angle,rad_to_deg((current[link+1]-current[link]).angle_to(previous[link+1]-previous[link])))
	check(crossing_hock_step<=.01,"Published hock moves<=1cm across original radial singularity")
	check(crossing_angle<=5.0,"All three actual helper link axes change<=5deg at crossing")
	var maximum_length_error:=0.0
	var maximum_endpoint_error:=0.0
	var maximum_hock_step:=crossing_hock_step
	var maximum_axis_step:=crossing_angle
	var maximum_same_bend:=0.0
	var minimum_upright_hock:=INF
	var cone_exit_observed:=false
	previous=current
	# Continue through the alignment and out of the inner reach cone. Every
	# query seeds from the actual preceding helper result, never a fake pose.
	for step in 5000:
		var foot:=Vector3(0,1.4,next_foot.z-float(step+1)*.0004)
		current=Biomechanics.rear_joints(previous,lengths,foot,Basis.IDENTITY)
		if current.size()!=4:
			check(false,"Finite reachable sweep resolves every target")
			break
		for link in 3:
			maximum_length_error=maxf(maximum_length_error,absf(current[link].distance_to(current[link+1])-lengths[link]))
			maximum_axis_step=maxf(maximum_axis_step,rad_to_deg((current[link+1]-current[link]).angle_to(previous[link+1]-previous[link])))
		maximum_endpoint_error=maxf(maximum_endpoint_error,current[3].distance_to(foot))
		maximum_hock_step=maxf(maximum_hock_step,current[2].distance_to(previous[2]))
		var knee_bend: Vector3=(current[1]-current[0]).cross(current[2]-current[1])
		var hock_bend: Vector3=(current[2]-current[1]).cross(current[3]-current[2])
		maximum_same_bend=maxf(maximum_same_bend,knee_bend.dot(hock_bend))
		minimum_upright_hock=minf(minimum_upright_hock,(current[2]-foot).dot(Vector3.UP))
		var preferred_hock: Vector3=foot+Vector3(0,.9,.35).normalized()*LENGTHS.z
		if preferred_hock.distance_to(hip)>absf(LENGTHS.x-LENGTHS.y): cone_exit_observed=true
		previous=current
	check(cone_exit_observed,"Sweep crosses alignment and exits original preferred inner cone")
	check(maximum_length_error<=.00001,"Actual helper preserves original three lengths within1e-5")
	check(maximum_endpoint_error<=.00001,"Actual helper preserves every foot target within1e-5")
	check(maximum_hock_step<=.01,"Actual helper hock stays continuous<=1cm throughout finite sweep")
	check(maximum_axis_step<=5.0,"Actual helper axes stay continuous<=5deg throughout finite sweep")
	check(maximum_same_bend<=.00001,"Actual helper retains opposing knee/hock bends within float tolerance")
	check(minimum_upright_hock>=-.000001,"Actual helper keeps hock above foot throughout finite sweep")
	# A rising swing target can be above its previous published hock. The
	# nearest feasible point must also satisfy the actor-UP hemisphere.
	var risen_foot:=Vector3(0,2,-1)
	var below_seed:=PackedVector3Array([hip,Vector3(0,.8,-1.2),Vector3(-.1,1.9,-1.1),risen_foot])
	var upright_result: PackedVector3Array=Biomechanics.rear_joints(below_seed,lengths,risen_foot,Basis.IDENTITY)
	check(upright_result.size()==4,"Actual helper resolves a risen target above its prior hock")
	if upright_result.size()==4:
		check((upright_result[2]-risen_foot).dot(Vector3.UP)>=-.000001,"Risen swing target keeps hock in upright hemisphere")
		for link in 3:
			check(absf(upright_result[link].distance_to(upright_result[link+1])-lengths[link])<=.00001,"Risen target preserves original link %d length" % link)
		check(upright_result[3].distance_to(risen_foot)<=.00001,"Risen target preserves exact foot endpoint")
	# Reachable hip/hock spheres alone accepted this target with matching
	# knee/hock bend normals (dot +0.8744 in the previous construction).
	var opposed_target:=Vector3(-.0611011802,1.9068030386,-.6795235439)
	var opposed_result: PackedVector3Array=Biomechanics.rear_joints(initial_pose,lengths,opposed_target,Basis.IDENTITY)
	check(opposed_result.size()==4,"Opposing-bend reach bound resolves previously incompatible knee arc")
	if opposed_result.size()==4:
		var opposed_knee: Vector3=(opposed_result[1]-opposed_result[0]).cross(opposed_result[2]-opposed_result[1])
		var opposed_hock: Vector3=(opposed_result[2]-opposed_result[1]).cross(opposed_result[3]-opposed_result[2])
		check(opposed_knee.dot(opposed_hock)<=.00001,"Previously incompatible arc now has opposing bend normals")
		for link in 3:
			check(absf(opposed_result[link].distance_to(opposed_result[link+1])-lengths[link])<=.00001,"Opposing-bend bound preserves original link %d" % link)
		check(opposed_result[3].distance_to(opposed_target)<=.00001,"Opposing-bend bound preserves exact target")
	previous=initial_pose
	var opposed_axis_step:=0.0
	var opposed_hock_step:=0.0
	var opposed_same_bend:=0.0
	var opposed_length_error:=0.0
	var reported_jump:=false
	for step in 2000:
		var foot: Vector3=first_foot.lerp(opposed_target,float(step+1)/2000.0)
		current=Biomechanics.rear_joints(previous,lengths,foot,Basis.IDENTITY)
		if current.size()!=4:
			check(false,"Opposing-bend finite sweep resolves every target")
			break
		for link in 3:
			opposed_axis_step=maxf(opposed_axis_step,rad_to_deg((current[link+1]-current[link]).angle_to(previous[link+1]-previous[link])))
			opposed_length_error=maxf(opposed_length_error,absf(current[link].distance_to(current[link+1])-lengths[link]))
		var knee_normal: Vector3=(current[1]-current[0]).cross(current[2]-current[1])
		var hock_normal: Vector3=(current[2]-current[1]).cross(current[3]-current[2])
		opposed_same_bend=maxf(opposed_same_bend,knee_normal.dot(hock_normal))
		opposed_hock_step=maxf(opposed_hock_step,current[2].distance_to(previous[2]))
		if not reported_jump and current[2].distance_to(previous[2])>.01:
			print("BIOMECHANICS_OPPOSED_FIRST_JUMP sample=",step," previous=",previous," target=",foot," output=",current)
			reported_jump=true
		previous=current
	check(opposed_axis_step<=5.0,"Opposing-bend sweep retains axis continuity <=5deg")
	check(opposed_hock_step<=.01,"Opposing-bend sweep retains hock continuity <=1cm")
	check(opposed_same_bend<=.00001,"Opposing-bend sweep retains opposing normals")
	check(opposed_length_error<=.00001,"Opposing-bend sweep retains original lengths")
	print("BIOMECHANICS_OPPOSED_SWEEP hock_step_m=",opposed_hock_step," axis_step_deg=",opposed_axis_step," same_bend=",opposed_same_bend," length_error_m=",opposed_length_error," samples=2000")
	print("BIOMECHANICS_SWEEP original_hock_jump_m=",original_jump," hock_step_m=",maximum_hock_step," axis_step_deg=",maximum_axis_step," length_error_m=",maximum_length_error," endpoint_error_m=",maximum_endpoint_error," same_bend=",maximum_same_bend," minimum_hock_above_foot_m=",minimum_upright_hock," samples=5000")
	quit(0 if failures.is_empty() else 1)
