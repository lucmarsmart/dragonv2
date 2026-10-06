extends SceneTree
const Probe = preload("res://scripts/dragon_pose_probe.gd")
var dragon: DragonController
var probe = Probe.new()
var reports: Array = []
var frame := 0

func runtime_benchmark() -> void:
	dragon.global_position = Vector3(0,340,100)
	dragon.has_taken_off = true
	dragon.manual_input_override = true
	dragon.glide_mode_active = true
	dragon.locomotion_state = dragon.LocomotionState.FLYING
	camera.global_position = Vector3(0,350,170)
	camera.look_at(dragon.global_position)
	await ticks(300)
	var fps: Array[float] = []
	var physics_ms: Array[float] = []
	for i in 600:
		await ticks(1)
		camera.global_position = dragon.global_position + Vector3(0,10,70)
		camera.look_at(dragon.global_position)
		fps.append(Engine.get_frames_per_second())
		physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000)
	var sum_fps := 0.0
	var sum_physics := 0.0
	for value in fps: sum_fps += value
	for value in physics_ms: sum_physics += value
	physics_ms.sort()
	print("ANATOMY RUNTIME avgFPS=",sum_fps/fps.size()," avgPhysicsMs=",sum_physics/physics_ms.size()," p95PhysicsMs=",physics_ms[int(physics_ms.size()*0.95)])

var modifier: SkeletonModifier3D
var result := {}
var last_frame := -1
var failures: Array[String] = []
var capture := false
var camera: Camera3D
var glide_metrics: Array[Dictionary] = []
var negative_probe := false
var negative_seen := false
var previous_head := Vector3.FORWARD
var maximum_head_step := 0.0
var claw_tracking: Dictionary = {}
var maximum_stance_slide := 0.0
var visible_steps: Array[float] = []
var flight_wall: StaticBody3D
var all_contact_probe = Probe.new()
var full_contact_tracking := false
var final_contact_points: Array = []
var final_head_position := Vector3.ZERO
var maximum_box_penetration := 0.0
var maximum_ground_guard_error := 0.0
var maximum_ground_snap_y := 0.0
var maximum_ground_executed_y := 0.0
var negative_neck_probe := false
var negative_neck_seen := false
var wall_penetrations := 0
var track_wall := false
var max_tick_displacement := 0.0
var wall_half_extents := Vector3(45,40,1.5)
var previous_body := Vector3.ZERO
var full_snapshot_label := ""
var full_probe = Probe.new()
var body_terrain_probe = Probe.new()
var body_partition_snapshots: Dictionary = {}
var body_partition_probe = Probe.new()
var body_terrain_track_remaining := 0
var body_terrain_track_label := ""
var body_terrain_track_metrics: Dictionary = {}

# Contract-specific oracles observe original skinned vertices after all modifiers.
# Their initial placement is a fixture; no pose/roll reset occurs during a sequence.
var contract_feet: Dictionary = {}
var contract_stride_active := false
var contract_last_root := Vector3.ZERO
var contract_last_tick := -1
var contract_last_process := -1
var contract_bank_phase := ""
var contract_bank_frames: Array = []
var contract_axis_samples: Array = []
var contract_axis_baseline := 0.0

func complete_foot_events_pass(events: Array) -> bool:
	if events.size() < 4: return false
	for event in events:
		if event.stride_m < 2.0 or absf(event.real_speed_mps-7.5) > .05: return false
		if event.minimum_tick_speed_mps < 7.45 or event.maximum_tick_speed_mps > 7.55: return false
	return true

func record_locomotion_contract() -> void:
	var tick := Engine.get_physics_frames()
	if contract_stride_active and tick>contract_last_tick:
		var elapsed_s := float(tick-contract_last_tick)/Engine.physics_ticks_per_second
		contract_last_tick = tick
		var travel := Vector2(dragon.global_position.x-contract_last_root.x,dragon.global_position.z-contract_last_root.z).length()
		var speed := travel/elapsed_s
		contract_last_root = dragon.global_position
		for limb in dragon.ground_pose.limbs:
			var foot: Dictionary = contract_feet[limb.end]
			var p: Vector3 = probe.point(dragon.skeleton,foot.sample)
			if foot.seeded:
				foot.body_distance_m += travel
				foot.minimum_speed = minf(foot.minimum_speed,speed)
				foot.maximum_speed = maxf(foot.maximum_speed,speed)
			if foot.swing and not limb.swinging:
				if foot.seeded:
					var duration := float(tick-foot.landing_tick)/Engine.physics_ticks_per_second
					foot.events.append({"start_tick":foot.landing_tick,"end_tick":tick,"stride_m":absf((p-foot.landing).dot(Vector3.FORWARD)),"body_distance_m":foot.body_distance_m,"duration_s":duration,"real_speed_mps":foot.body_distance_m/duration,"minimum_tick_speed_mps":foot.minimum_speed,"maximum_tick_speed_mps":foot.maximum_speed,"start_vertex_world":str(foot.landing),"end_vertex_world":str(p)})
				else:
					foot.discarded_initial_incomplete += 1
				foot.seeded = true
				foot.landing = p
				foot.landing_tick = tick
				foot.body_distance_m = 0.0
				foot.minimum_speed = INF
				foot.maximum_speed = 0.0
			foot.swing = limb.swinging
	if not contract_bank_phase.is_empty() and contract_last_process!=Engine.get_process_frames():
		contract_last_process=Engine.get_process_frames()
		var axis: Vector3 = probe.point(dragon.skeleton,contract_axis_samples[1])-probe.point(dragon.skeleton,contract_axis_samples[0])
		var heading_axis := Basis(Vector3.UP,-dragon.rotation.y)*axis
		var skin_roll := wrapf(atan2(heading_axis.y,heading_axis.x)-contract_axis_baseline,-PI,PI)
		contract_bank_frames.append({"tick":tick,"process_frame":Engine.get_process_frames(),"phase":contract_bank_phase,"command":dragon.manual_turn_input,"body_roll_deg":rad_to_deg(dragon.rotation.z),"skin_axis_roll_deg":rad_to_deg(skin_roll),"body_yaw_deg":rad_to_deg(dragon.rotation.y),"state":dragon.locomotion_state})

func bank_sequence_pass(frames: Array, sign_value: float) -> Dictionary:
	var turn: Array = frames.filter(func(entry): return entry.command == sign_value)
	var released: Array = frames.filter(func(entry): return entry.command == 0)
	var max_body_step := 0.0
	var max_skin_step := 0.0
	for i in range(1,frames.size()):
		max_body_step = maxf(max_body_step,absf(wrapf(frames[i].body_roll_deg-frames[i-1].body_roll_deg,-180,180)))
		max_skin_step = maxf(max_skin_step,absf(wrapf(frames[i].skin_axis_roll_deg-frames[i-1].skin_axis_roll_deg,-180,180)))
	var complete := turn.size() >= 120 and released.size() >= 180
	if not complete: return {"complete":false,"congruent":false,"gradual":false,"recenter":false}
	var turn_end: Dictionary = turn.back()
	var release_end: Dictionary = released.back()
	var release_tick: int = turn_end.get("tick",0)
	var recenter_s := INF
	var at_1s: Dictionary = released[59]
	for entry in released:
		var elapsed_s := float(entry.get("tick",0)-release_tick)/Engine.physics_ticks_per_second
		if elapsed_s<=1.0: at_1s=entry
		if recenter_s==INF and absf(entry.body_roll_deg)<=2 and absf(entry.skin_axis_roll_deg)<=2: recenter_s=elapsed_s
	return {"complete":true,"turn_frames":turn.size(),"release_frames":released.size(),"turn_end_body_deg":turn_end.body_roll_deg,"turn_end_skin_deg":turn_end.skin_axis_roll_deg,"release_first_body_deg":released[0].body_roll_deg,"release_1s_body_deg":at_1s.body_roll_deg,"release_1s_skin_deg":at_1s.skin_axis_roll_deg,"recenter_time_s":recenter_s,"release_end_body_deg":release_end.body_roll_deg,"release_end_skin_deg":release_end.skin_axis_roll_deg,"maximum_body_step_deg":max_body_step,"maximum_skin_step_deg":max_skin_step,"congruent":sign_value*turn_end.body_roll_deg>=5 and sign_value*turn_end.skin_axis_roll_deg>=5,"gradual":max_body_step<=5 and max_skin_step<=5,"recenter":absf(released[0].body_roll_deg)>=5 and recenter_s<=3.0 and absf(release_end.body_roll_deg)<=2 and absf(release_end.skin_axis_roll_deg)<=2}

func validate_locomotion_contract() -> void:
	var synthetic := {}
	var old_pooled: Array = []
	for foot in [8,82,23,41]:
		var events: Array = []
		for i in 4:
			var length := 3.5 if foot == 8 else 1.0
			old_pooled.append(length)
			events.append({"stride_m":length,"real_speed_mps":7.5,"minimum_tick_speed_mps":7.5,"maximum_tick_speed_mps":7.5})
		synthetic[str(foot)] = {"events":events,"new_per_foot_pass":complete_foot_events_pass(events)}
	var old_accepts := old_pooled.filter(func(length):return length>2.0).size()>=4
	var logical_red := {"kind":"logical false positive, not runtime defect","old_pooled_accepts":old_accepts,"synthetic_feet":synthetic}
	FileAccess.open("res://docs/validation/v2/anatomy-stride-pooled-logic-red.json",FileAccess.WRITE).store_string(JSON.stringify(logical_red,"  "))
	print("POOLED_ASSERTION_LOGICAL_RED ",JSON.stringify(logical_red))
	check(old_accepts and not synthetic["82"].new_per_foot_pass and not synthetic["23"].new_per_foot_pass and not synthetic["41"].new_per_foot_pass,"Per-foot oracle rejects the old assertion's one-foot false positive")
	dragon.global_position = Vector3(0,203.5,100)
	dragon.rotation = Vector3.ZERO
	dragon.target_yaw = 0
	dragon.target_pitch = 0
	dragon.target_roll = 0
	dragon.velocity = Vector3.ZERO
	dragon.current_speed = 0
	dragon.locomotion_state = dragon.LocomotionState.GROUNDED
	dragon.ground_pose.reset()
	await ticks(180)
	dragon.walk_forward()
	await ticks(90) # Exclude acceleration from the 7.5m/s measurement window.
	var points: Array = probe.points(dragon.skeleton)
	for limb in dragon.ground_pose.limbs:
		var chosen: Dictionary = {}
		for point in points:
			if point.sample.claw != limb.end: continue
			if chosen.is_empty() or point.position.y<chosen.position.y: chosen=point
		check(not chosen.is_empty(),"Original rendered claw vertex exists for "+dragon.skeleton.get_bone_name(limb.end))
		if chosen.is_empty(): continue
		contract_feet[limb.end]={"sample":chosen.sample,"events":[],"swing":limb.swinging,"seeded":false,"discarded_initial_incomplete":0,"landing":chosen.position,"landing_tick":0,"body_distance_m":0.0,"minimum_speed":INF,"maximum_speed":0.0}
	contract_last_root = dragon.global_position
	contract_last_tick = Engine.get_physics_frames()
	var walk_start_tick := contract_last_tick
	var walk_start := dragon.global_position
	contract_stride_active = true
	await ticks(480)
	contract_stride_active = false
	dragon.manual_move_input = 0
	var feet_report := {}
	for end in [8,82,23,41]:
		var foot: Dictionary = contract_feet.get(end,{})
		if foot.is_empty(): continue
		var foot_report := {"bone":dragon.skeleton.get_bone_name(end),"mesh":foot.sample.mesh,"vertex":foot.sample.index,"discarded_initial_incomplete":foot.discarded_initial_incomplete,"events":foot.events,"pass":complete_foot_events_pass(foot.events)}
		feet_report[str(end)] = foot_report
		print("PER_FOOT_STRIDE ",JSON.stringify(foot_report))
		check(foot_report.pass,"Every complete stride >=2m at actual7.5m/s, >=4cycles: "+foot_report.bone)
	check(feet_report.size()==4,"All four feet independently measured")
	var walk_distance := walk_start.distance_to(dragon.global_position)
	var walk_duration := float(Engine.get_physics_frames()-walk_start_tick)/Engine.physics_ticks_per_second
	print("REAL_WALK distance_m=",walk_distance," duration_s=",walk_duration," speed_mps=",walk_distance/walk_duration)
	check(walk_duration>=8.0 and absf(walk_distance/walk_duration-7.5)<=.05,"Actual body displacement is7.5m/s over the entire >=8s physical window")
	await ticks(90)
	# One initial airborne fixture placement; from here through both release phases,
	# only manual turn input changes. Neither actual nor requested roll is reset.
	dragon.global_position = Vector3(0,340,100)
	dragon.rotation = Vector3.ZERO
	dragon.target_yaw = 0
	dragon.target_pitch = 0
	dragon.target_roll = 0
	dragon.locomotion_state = dragon.LocomotionState.FLYING
	dragon.ground_blend = 0
	dragon.velocity = Vector3(0,0,-26)
	dragon.current_speed = 26
	dragon.glide_mode_active = true
	dragon.manual_turn_input = 0
	await ticks(180)
	var axis_probe = Probe.new()
	axis_probe.configure(dragon,dragon.skeleton,1)
	var groups := {}
	for sample in axis_probe.samples:
		if sample.wing or sample.neck or sample.claw>=0: continue
		var trunk := false
		for influence in sample.influence:
			if influence.bone in dragon.bone_spine_indices and influence.weight>=.5: trunk=true
		if not trunk: continue
		var key := str(sample.influence)
		if not groups.has(key): groups[key]=[]
		groups[key].append(sample)
	var left: Dictionary = {}
	var right: Dictionary = {}
	var minimum_x := 0.0
	var maximum_x := 0.0
	for group in groups.values():
		var low := INF
		var high := -INF
		var low_sample := {}
		var high_sample := {}
		for sample in group:
			var local: Vector3 = dragon.to_local(probe.point(dragon.skeleton,sample))
			if local.x<low: low=local.x; low_sample=sample
			if local.x>high: high=local.x; high_sample=sample
		if high-low>maximum_x-minimum_x:
			minimum_x=low
			maximum_x=high
			left=low_sample
			right=high_sample
	check(not left.is_empty() and left.influence==right.influence,"Visible torso supplies two original vertices with identical skin influences for bank")
	if left.is_empty(): return
	contract_axis_samples = [left,right]
	var axis: Vector3 = probe.point(dragon.skeleton,right)-probe.point(dragon.skeleton,left)
	var heading_axis := Basis(Vector3.UP,-dragon.rotation.y)*axis
	contract_axis_baseline = atan2(heading_axis.y,heading_axis.x)
	check(maximum_x-minimum_x>1,"Actual skinned torso axis spans more than1m laterally")
	var banks := {}
	for side in ["left","right"]:
		var sign_value := 1.0 if side=="left" else -1.0
		var first := contract_bank_frames.size()
		contract_bank_phase = side+"_turn"
		dragon.manual_turn_input = sign_value
		await ticks(120)
		contract_bank_phase = side+"_release"
		dragon.manual_turn_input = 0
		await ticks(180)
		var metrics := bank_sequence_pass(contract_bank_frames.slice(first),sign_value)
		banks[side] = metrics
		print("BANK_SEQUENCE ",side," ",JSON.stringify(metrics))
		check(metrics.complete,"Actual "+side+" turn→release has >=120/180 published samples")
		check(metrics.congruent,"Published body and visible torso bank agree with "+side+" command")
		check(metrics.gradual,"Published body and visible torso bank change<=5deg per published frame: "+side)
		check(metrics.recenter,"Release begins banked and recovers body/visible torso<=2deg within3s: "+side)
	contract_bank_phase = ""
	# Negative sequences distinguish actual banking from a target-only assertion,
	# an instantaneous jump and a permanently banked release.
	var missing_actual: Array = []
	for i in 300: missing_actual.append({"command":1.0 if i<120 else 0.0,"body_roll_deg":0.0,"skin_axis_roll_deg":0.0})
	check(not bank_sequence_pass(missing_actual,1).congruent,"Bank oracle rejects a turn with no published bank")
	var stuck: Array = []
	for i in 300: stuck.append({"command":1.0 if i<120 else 0.0,"body_roll_deg":25.0,"skin_axis_roll_deg":25.0})
	check(not bank_sequence_pass(stuck,1).recenter,"Bank oracle rejects release that remains banked")
	stuck[1].body_roll_deg = -25.0
	check(not bank_sequence_pass(stuck,1).gradual,"Bank oracle rejects an instantaneous50deg body jump")
	var report := {"scope":"Headless60Hz finite sequences; not GPU performance or rendered capture","physics_ticks_per_second":Engine.physics_ticks_per_second,"stride":{"required_per_foot_m":2.0,"minimum_cycles_per_foot":4,"required_actual_speed_mps":7.5,"speed_tolerance_mps":.05,"window_s":walk_duration,"real_speed_mps":walk_distance/walk_duration,"body_distance_m":walk_distance,"feet":feet_report},"bank":{"step_limit_deg":5.0,"release_limit_deg":2.0,"release_window_s":3,"axis_originals":[{"mesh":left.mesh,"index":left.index},{"mesh":right.mesh,"index":right.index}],"axis_skin_influences":str(left.influence),"axis_width_m":maximum_x-minimum_x,"axis_baseline_deg":rad_to_deg(contract_axis_baseline),"sequences":banks,"frames":contract_bank_frames},"failures":failures}
	FileAccess.open("res://docs/validation/v2/anatomy-locomotion-contract.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("LOCOMOTION_CONTRACT failures=",failures.size())

func start_body_terrain_tracking(label: String, frames: int) -> void:
	body_terrain_track_label = label
	body_terrain_track_remaining = frames
	body_terrain_track_metrics = {"frames":0,"vertices_per_frame":20191,"minimum_m":INF,"penetrating":0,"missing_checks":0,"head_step_deg":0.0,"fire_direction_deg":0.0,"mouth_error_m":0.0,"invalid_body_pose":0,"wing_penetrating":0,"wing_minimum_m":INF,"fire_frames":0}
	previous_head = dragon.head_rendered_direction
	claw_tracking.clear()
	maximum_stance_slide = 0.0
	if "touchdown" in label or "walk" in label:
		var fire := InputEventKey.new()
		fire.keycode = KEY_F
		fire.pressed = true
		Input.parse_input_event(fire)

func finish_body_terrain_tracking() -> void:
	body_terrain_track_metrics.stance_slide_m = maximum_stance_slide
	print("CONTINUOUS_BODY_TERRAIN ",body_terrain_track_label," ",JSON.stringify(body_terrain_track_metrics))
	check(body_terrain_track_remaining==0 and body_terrain_track_metrics.penetrating==0 and body_terrain_track_metrics.missing_checks==0,"Every final rendered body/neck vertex clears physical terrain over continuous "+body_terrain_track_label)
	check(body_terrain_track_metrics.head_step_deg<=5.0 and body_terrain_track_metrics.fire_direction_deg<.1 and body_terrain_track_metrics.mouth_error_m<.01,"Recovered head stays continuous and final fire landmarks agree: "+body_terrain_track_label)
	check(body_terrain_track_metrics.wing_penetrating==0,"All5412 final wing vertices clear physical solids: "+body_terrain_track_label)
	if dragon.locomotion_state == dragon.LocomotionState.GROUNDED: check(maximum_stance_slide<=.015,"Actual claw stance remains locked within1.5cm: "+body_terrain_track_label)
	if "touchdown" in body_terrain_track_label or "walk" in body_terrain_track_label:
		check(body_terrain_track_metrics.fire_frames>0,"F is actually firing during recovered "+body_terrain_track_label)
		var fire := InputEventKey.new()
		fire.keycode = KEY_F
		fire.pressed = false
		Input.parse_input_event(fire)

var full_snapshots: Dictionary = {}
var vertex_markers: Array[MeshInstance3D] = []

func snapshot(label: String) -> void:
	full_snapshot_label = label
	await ticks(6)

func visible_body_surface() -> Dictionary:
	if body_terrain_probe.samples.is_empty():
		body_terrain_probe.configure(dragon,dragon.skeleton,1)
		body_terrain_probe.samples = body_terrain_probe.samples.filter(func(sample): return not sample.wing)
	var minimum := INF
	var penetrating := 0
	var checked := 0
	var worst: Dictionary = {}
	var prop_under := 0
	var maximum_prop_depth := 0.0
	var prop_worst := ""
	for point in body_terrain_probe.points(dragon.skeleton):
		var prop_query := PhysicsPointQueryParameters3D.new()
		prop_query.position = point.position
		prop_query.collision_mask = 2
		prop_query.exclude = [dragon.get_rid()]
		for contact in dragon.get_world_3d().direct_space_state.intersect_point(prop_query,8):
			var body: CollisionObject3D = contact.collider
			var owner := body.shape_owner_get_owner(body.shape_find_owner(contact.shape)) as CollisionShape3D
			if not owner or not owner.shape is CylinderShape3D:
				prop_under += 1
				continue
			var local := owner.to_local(point.position)
			var depth := minf(owner.shape.radius-Vector2(local.x,local.z).length(),owner.shape.height*.5-absf(local.y))
			if depth>maximum_prop_depth:
				maximum_prop_depth = depth
				var bones := []
				for influence in point.sample.influence: bones.append([dragon.skeleton.get_bone_name(influence.bone),influence.weight])
				prop_worst = str(body.get_path())+" "+str(point.position)+" "+str(point.sample.mesh)+":"+str(point.sample.index)+" "+JSON.stringify(bones)
			if depth>.05: prop_under += 1
		var q := PhysicsRayQueryParameters3D.create(point.position+Vector3.UP*30,point.position+Vector3.DOWN*40,1)
		q.exclude = [dragon.get_rid()]
		var hit := dragon.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty(): continue
		checked += 1
		var clearance: float = point.position.y-hit.position.y
		if clearance < minimum:
			minimum = clearance
			worst = {"position":str(point.position),"mesh":point.sample.mesh,"index":point.sample.index,"influences":[],"surface":str(hit.position),"normal":str(hit.normal),"root":str(dragon.global_position)}
			for influence in point.sample.influence: worst.influences.append([dragon.skeleton.get_bone_name(influence.bone),influence.weight,str(dragon.skeleton.to_global(dragon.skeleton.get_bone_global_pose(influence.bone).origin))])
		if clearance < -.05: penetrating += 1
	worst["joints"] = {}
	for limb in dragon.ground_pose.limbs:
		var chain: Array = limb.chain.duplicate()
		chain.append(limb.end)
		for bone in chain: worst.joints[str(bone)] = str(dragon.skeleton.to_global(dragon.skeleton.get_bone_global_pose(bone).origin))
	return {"vertices":body_terrain_probe.samples.size(),"checked":checked,"minimum_m":minimum,"penetrating":penetrating,"worst":worst,"prop_penetrating":prop_under,"maximum_prop_depth":maximum_prop_depth,"prop_worst":prop_worst}

func take_full_snapshot() -> void:
	if "--verify-flat" in OS.get_cmdline_user_args():
		var packed: PackedVector3Array = dragon.wing_contact.probe.coordinates(dragon.skeleton,dragon)
		var independent: Array = dragon.wing_contact.probe.points(dragon.skeleton)
		var error := 0.0
		for index in packed.size(): error = maxf(error,packed[index].distance_to(dragon.to_local(independent[index].position)))
		print("FLAT_SKIN_VERIFY ",full_snapshot_label," support_vertices=",packed.size()," maximum_error_m=",error)
		check(error<.001,"Packed skin agrees with independent Skin formula within1mm: "+full_snapshot_label)
	if full_probe.samples.is_empty():
		full_probe.configure(dragon,dragon.skeleton,1)
		full_probe.samples = full_probe.samples.filter(func(sample): return sample.wing)
	var cloud: Array = [[],[]]
	var vertex_ids: Array = [[],[]]
	for point in full_probe.points(dragon.skeleton,true):
		var local: Vector3 = dragon.to_local(point.position)
		for side in 2:
			if int(point.sample.wing_side_mask)&(1<<side):
				cloud[side].append([local.x,local.y,local.z])
				vertex_ids[side].append("%s:%d:%d" % [point.sample.mesh,point.sample.surface,point.sample.index])
	var hull_points: Array = []
	for side in 2:
		var data: Array = []
		for p in dragon.wing_contact.hulls[side].points: data.append([p.x,p.y,p.z])
		hull_points.append(data)
	if capture and full_snapshot_label == "neutral_glide":
		var calibrated: Array[Dictionary] = []
		var left: Dictionary = {}
		var right: Dictionary = {}
		var lower: Dictionary = {}
		for point in full_probe.points(dragon.skeleton,true):
			if left.is_empty() or dragon.to_local(point.position).x < dragon.to_local(left.position).x: left = point
			if right.is_empty() or dragon.to_local(point.position).x > dragon.to_local(right.position).x: right = point
			if lower.is_empty() or point.position.y < lower.position.y: lower = point
		calibrated = [left,right,lower]
		for i in 3:
			var marker := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.25
			sphere.height = 0.5
			var material := StandardMaterial3D.new()
			material.albedo_color = [Color.ORANGE,Color.CYAN,Color.MAGENTA][i]
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			sphere.material = material
			marker.mesh = sphere
			dragon.add_child(marker)
			marker.global_position = calibrated[i].position
			vertex_markers.append(marker)
			print("VERTEX_CALIBRATION ",i," mesh=",calibrated[i].sample.mesh," surface=",calibrated[i].sample.surface," index=",calibrated[i].sample.index," world=",calibrated[i].position)
	if "--body-terrain" in OS.get_cmdline_user_args():
		var body_surface := visible_body_surface()
		print("FULL_BODY_TERRAIN ",full_snapshot_label," ",JSON.stringify(body_surface))
		if dragon.locomotion_state == dragon.LocomotionState.GROUNDED:
			check(body_surface.vertices==20191 and body_surface.checked==20191 and body_surface.penetrating==0 and body_surface.prop_penetrating==0,"All20191 visible body/neck/claw vertices checked and clear terrain/props: "+full_snapshot_label)
		elif body_surface.checked>0:
			check(body_surface.penetrating==0,"Observed airborne body vertices clear terrain: "+full_snapshot_label)
		else: print("BODY_TERRAIN N/A no physical surface in ray reach: ",full_snapshot_label)
	if "--verify-body-partition" in OS.get_cmdline_user_args():
		if body_partition_probe.samples.is_empty(): body_partition_probe.configure(dragon,dragon.skeleton,1)
		var source_points := {}
		for point in body_partition_probe.points(dragon.skeleton):
			var p: Vector3 = dragon.to_local(point.position)
			source_points["%s:%d:%d" % [point.sample.mesh,point.sample.surface,point.sample.index]] = [p.x,p.y,p.z]
		var body_shapes := {}
		for index in dragon.wing_contact.body_indices:
			var coordinates := []
			for p in dragon.wing_contact.hulls[index].points: coordinates.append([p.x,p.y,p.z])
			body_shapes[str(index)] = coordinates
		body_partition_snapshots[full_snapshot_label] = {"vertices":source_points,"hulls":body_shapes}
	var surface: Dictionary = full_probe.ground_report(dragon,dragon.skeleton)
	full_snapshots[full_snapshot_label] = {"wing_partition":"rig-root96-120-boundary-v1","vertices":cloud,"vertex_ids":vertex_ids,"hulls":hull_points,"surface":surface,"margin":0.0 if dragon.locomotion_state == dragon.LocomotionState.GROUNDED else 1.2}
	print("FULL_SKIN ",full_snapshot_label," vertices=",full_probe.samples.size()," surface=",surface)
	check(float(surface.minimum_wing_clearance) >= -0.05,"All membrane vertices clear collider: " + full_snapshot_label)
	full_snapshot_label = ""

func track_claws() -> void:
	if dragon.locomotion_state != dragon.LocomotionState.GROUNDED or dragon.ground_blend < 0.99: return
	var points: Array = probe.points(dragon.skeleton)
	for limb in dragon.ground_pose.limbs:
		var end: int = limb.end
		if not claw_tracking.has(end):
			var chosen: Dictionary = {}
			for point in points:
				if int(point.sample.claw) != end: continue
				if chosen.is_empty() or point.position.y < chosen.position.y: chosen = point
			if chosen.is_empty(): continue
			claw_tracking[end] = {"mesh": chosen.sample.mesh,"index": chosen.sample.index,"previous":chosen.position,"swing":limb.swinging,"landing":chosen.position}
		var tracked: Dictionary = claw_tracking[end]
		for point in points:
			if point.sample.mesh != tracked.mesh or int(point.sample.index) != int(tracked.index): continue
			var p: Vector3 = point.position
			if not limb.swinging and not tracked.swing:
				var slide := Vector2(p.x-tracked.previous.x,p.z-tracked.previous.z).length()
				if slide>maximum_stance_slide and slide>.012 and OS.get_cmdline_user_args().has("--leg-diagnostic"):
					print("STANCE_FRAME_WORST tick=",Engine.get_physics_frames()," end=",end," slide_m=",slide," transition=",limb.get("support_transition",false)," limited=",limb.get("support_limited",false)," speed=",dragon.ground_motion_speed," body_recovering=",dragon.wing_contact.body_pose_recovering," primary_step=",limb.get("primary_step_world",0)," previous=",tracked.previous," current=",p)
				maximum_stance_slide = maxf(maximum_stance_slide,slide)
			if not limb.swinging and tracked.swing:
				visible_steps.append(absf((p-tracked.landing).dot(-dragon.global_basis.z)))
				tracked.landing = p
			tracked.previous = p
			tracked.swing = limb.swinging
			break

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func _initialize() -> void: call_deferred("run")
func ticks(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func record() -> void:
	if "--capture-real-motion" in OS.get_cmdline_user_args():
		var heading := Basis(Vector3.UP,dragon.rotation.y)
		camera.global_position = dragon.global_position+heading*Vector3(-38,12,7)
		camera.look_at(dragon.global_position+Vector3.DOWN)
	record_locomotion_contract()
	if last_frame == Engine.get_physics_frames(): return
	last_frame = Engine.get_physics_frames()
	frame += 1
	if frame > 5:
		var step := rad_to_deg(previous_head.angle_to(dragon.head_rendered_direction))
		if step > maximum_head_step:
			maximum_head_step = step
			if step > 5: print("HEADSTEP ", frame, " ",step," ",previous_head," ",dragon.head_rendered_direction)
	if body_terrain_track_remaining>0:
		var continuous := visible_body_surface()
		if OS.get_cmdline_user_args().has("--claw-diagnostic") and continuous.minimum_m<-.05:
			print("CLAW_RENDER frame=",Engine.get_physics_frames()," blend=",dragon.ground_blend," min=",continuous.minimum_m," errs=",dragon.ground_pose.debug_errors," bone=",continuous.worst.influences)
		body_terrain_track_remaining -= 1
		body_terrain_track_metrics.frames += 1
		if continuous.minimum_m<body_terrain_track_metrics.minimum_m:
			body_terrain_track_metrics.worst = continuous.worst
			body_terrain_track_metrics.worst_frame = frame
		body_terrain_track_metrics.minimum_m = minf(body_terrain_track_metrics.minimum_m,continuous.minimum_m)
		body_terrain_track_metrics.penetrating += continuous.penetrating
		body_terrain_track_metrics.penetrating += continuous.prop_penetrating
		if continuous.maximum_prop_depth>body_terrain_track_metrics.get("maximum_prop_depth",0.0):
			body_terrain_track_metrics.maximum_prop_depth = continuous.maximum_prop_depth
			body_terrain_track_metrics.prop_worst = continuous.prop_worst
		if dragon.locomotion_state == dragon.LocomotionState.GROUNDED and continuous.checked !=20191: body_terrain_track_metrics.missing_checks += 1
		body_terrain_track_metrics.observed_surface_vertices = int(body_terrain_track_metrics.get("observed_surface_vertices",0))+continuous.checked
		body_terrain_track_metrics.head_step_deg = maxf(body_terrain_track_metrics.head_step_deg,rad_to_deg(previous_head.angle_to(dragon.head_rendered_direction)))
		var breath = dragon.get_node("DragonBreath")
		if breath.is_firing: body_terrain_track_metrics.fire_frames += 1
		body_terrain_track_metrics.fire_direction_deg = maxf(body_terrain_track_metrics.fire_direction_deg,rad_to_deg(breath.breath_direction.angle_to(dragon.head_rendered_direction)))
		body_terrain_track_metrics.mouth_error_m = maxf(body_terrain_track_metrics.mouth_error_m,breath.mouth_position.distance_to(breath.rendered_oral_center+breath.breath_direction*.08))
		if not dragon.wing_contact.body_pose_valid: body_terrain_track_metrics.invalid_body_pose += 1
		var wings: Dictionary = full_probe.ground_report(dragon,dragon.skeleton)
		body_terrain_track_metrics.wing_penetrating += wings.penetrating_samples
		body_terrain_track_metrics.wing_minimum_m = minf(body_terrain_track_metrics.wing_minimum_m,wings.minimum_wing_clearance)
	previous_head = dragon.head_rendered_direction
	track_claws()
	if negative_neck_probe:
		var head_bone: int = dragon.bone_head_idx
		var original_head := dragon.skeleton.get_bone_pose_position(head_bone)
		var parent := dragon.skeleton.get_bone_parent(head_bone)
		var parent_basis := dragon.skeleton.global_basis * dragon.skeleton.get_bone_global_pose(parent).basis
		dragon.skeleton.set_bone_pose_position(head_bone,original_head + parent_basis.inverse() * Vector3.RIGHT * 0.75)
		var negative_count := 0
		for point in all_contact_probe.points(dragon.skeleton):
			var relative: Vector3 = flight_wall.to_local(point.position)
			if absf(relative.x) < wall_half_extents.x-0.05 and absf(relative.y) < wall_half_extents.y-0.05 and absf(relative.z) < wall_half_extents.z-0.05: negative_count += 1
		dragon.skeleton.set_bone_pose_position(head_bone,original_head)
		negative_neck_seen = negative_count > 0
		negative_neck_probe = false
		print("NEGATIVE NECK full_vertices=",all_contact_probe.samples.size()," penetrating=",negative_count)
	if dragon.locomotion_state == dragon.LocomotionState.GROUNDED:
		maximum_ground_guard_error = maxf(maximum_ground_guard_error,Vector2(dragon.ground_guard_snap_delta.x,dragon.ground_guard_snap_delta.z).length())
		maximum_ground_snap_y = maxf(maximum_ground_snap_y,absf(dragon.ground_guard_snap_delta.y))
		maximum_ground_executed_y = maxf(maximum_ground_executed_y,absf(dragon.ground_executed_motion.y))
	if full_contact_tracking:
		final_contact_points = all_contact_probe.points(dragon.skeleton)
		final_head_position = dragon.skeleton.to_global(dragon.skeleton.get_bone_global_pose(dragon.bone_head_idx).origin)
	if track_wall:
		max_tick_displacement = maxf(max_tick_displacement,dragon.global_position.distance_to(previous_body))
		previous_body = dragon.global_position
		for point in (final_contact_points if full_contact_tracking else probe.points(dragon.skeleton)):
			var relative: Vector3 = flight_wall.to_local(point.position)
			if absf(relative.x) < wall_half_extents.x-0.05 and absf(relative.y) < wall_half_extents.y-0.05 and absf(relative.z) < wall_half_extents.z-0.05:
				wall_penetrations += 1
				maximum_box_penetration = maxf(maximum_box_penetration,minf(wall_half_extents.x-absf(relative.x),minf(wall_half_extents.y-absf(relative.y),wall_half_extents.z-absf(relative.z))))
	if frame % 6 != 0: return
	if not full_snapshot_label.is_empty(): take_full_snapshot()
	if negative_probe:
		var root_bone := 2
		var original := dragon.skeleton.get_bone_pose_position(root_bone)
		var parent_basis:Basis=dragon.skeleton.global_basis*dragon.skeleton.get_bone_global_pose(dragon.skeleton.get_bone_parent(root_bone)).basis
		dragon.skeleton.set_bone_pose_position(root_bone, original + parent_basis.inverse() * Vector3.DOWN * 25)
		var negative: Dictionary = probe.ground_report(dragon, dragon.skeleton)
		negative_seen = int(negative.penetrating_samples) >= 3 and float(negative.minimum_wing_clearance) < -0.5
		dragon.skeleton.set_bone_pose_position(root_bone, original)
		negative_probe = false
		print("NEGATIVE SKIN CALIBRATION ", JSON.stringify(negative))
	if dragon.glide_blend > 0.98 and dragon.locomotion_state == dragon.LocomotionState.FLYING:
		var left := Vector3.ZERO
		var right := Vector3.ZERO
		for point in full_probe.points(dragon.skeleton, true):
			var local: Vector3 = dragon.to_local(point.position)
			if local.x < left.x: left = local
			if local.x > right.x: right = local
		glide_metrics.append({"span": right.x-left.x, "tip_height_delta": absf(right.y-left.y), "roll": absf(rad_to_deg(dragon.rotation.z))})
	var r: Dictionary = probe.ground_report(dragon, dragon.skeleton)
	var head := dragon.skeleton.find_bone("Bip001-Head_011")
	var snout := dragon.skeleton.find_bone("Point021_018")
	# Report the imported bone names to calibrate muzzle landmarks once.
	if snout >= 0:
		var direction := (dragon.skeleton.get_bone_global_pose(snout).origin - dragon.skeleton.get_bone_global_pose(head).origin).normalized()
		r.muzzle_pitch = rad_to_deg(asin((dragon.skeleton.global_basis * direction).normalized().y))
	r.roll = rad_to_deg(dragon.rotation.z)
	r.ik_errors = dragon.ground_pose.debug_errors.duplicate()
	r.frame = frame
	r.state = dragon.locomotion_state
	if "--flat-support-only" in OS.get_cmdline_user_args():
		r.feet=[]
		for limb in dragon.ground_pose.limbs:
			r.feet.append({"end":limb.end,"planted":str(limb.planted),"clearance":limb.clearance,"home_xz_m":Vector2(limb.planted.x-(dragon.global_position+Basis(Vector3.UP,dragon.rotation.y)*limb.home).x,limb.planted.z-(dragon.global_position+Basis(Vector3.UP,dragon.rotation.y)*limb.home).z).length(),"swing":limb.swinging,"reposition":limb.repositioning,"t":limb.get("swing_elapsed",0),"step_t":limb.step_t,"cycle":limb.get("last_swing_cycle",0),"distance_home":(limb.planted as Vector3).distance_to(dragon.global_position+Basis(Vector3.UP,dragon.rotation.y)*limb.home)})
	reports.append(r)
	print("ANATOMY ", JSON.stringify(r))


func validate_body_contact(scene: Node3D) -> void:
	dragon.global_position = Vector3(0,203.5,100)
	dragon.rotation = Vector3.ZERO
	dragon.target_yaw = 0
	dragon.target_pitch = 0
	dragon.target_roll = 0
	dragon.velocity = Vector3.ZERO
	dragon.current_speed = 0
	dragon.locomotion_state = dragon.LocomotionState.GROUNDED
	dragon.ground_pose.reset()
	await ticks(180)
	all_contact_probe.configure(dragon,dragon.skeleton,1)
	full_contact_tracking = true
	await ticks(2)
	maximum_ground_guard_error = 0
	maximum_ground_snap_y = 0
	maximum_ground_executed_y = 0
	var furthest: Dictionary = {}
	for point in final_contact_points:
		if furthest.is_empty() or point.position.z > furthest.position.z: furthest = point
	flight_wall = StaticBody3D.new()
	flight_wall.collision_layer = 2
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80,50,1)
	collider.shape = box
	flight_wall.add_child(collider)
	flight_wall.position = Vector3(0,220,furthest.position.z+0.8)
	wall_half_extents = box.size * 0.5
	scene.add_child(flight_wall)
	track_wall = true
	await ticks(2)
	print("BODY_CONTACT baseline furthest=",furthest.position," sample=",furthest.sample.mesh,":",furthest.sample.index," wing=",furthest.sample.wing," neck=",furthest.sample.neck," wall=",flight_wall.position)
	check(wall_penetrations == 0,"Body contact wall starts outside all visible skin")
	check(not furthest.sample.wing and not furthest.sample.neck,"Marginal body contact fixture isolates tail/body geometry")
	dragon.manual_move_input = -1
	await ticks(180)
	dragon.manual_move_input = 0
	await ticks(30)
	var stopped := dragon.global_position
	print("BODY_CONTACT held_reverse hits=",wall_penetrations," root=",stopped," gap=",flight_wall.position.z-.5-stopped.z)
	check(flight_wall.position.z-.5-stopped.z>4,"Body wall keeps root capsule clear")
	check(wall_penetrations == 0,"Sustained body contact keeps all25603 skin vertices outside wall")
	dragon.manual_move_input = 1
	await ticks(120)
	dragon.manual_move_input = 0
	check(stopped.z-dragon.global_position.z>3,"Body contact permits walking away from wall")
	check(wall_penetrations == 0,"Body contact retreat keeps all visible skin outside wall")
	check(maximum_ground_guard_error < .0001 and maximum_ground_executed_y < .0001,"Body wall executed horizontal motion matches guard and remains at fixed floor height")
	check(maximum_stance_slide <= .015,"Body wall walking and retreat preserve actual claw stance slide<=1.5cm")
	print("BODY_CONTACT final ",dragon.global_position," hits=",wall_penetrations," maxdepth=",maximum_box_penetration," stance_slide=",maximum_stance_slide," motion_error_xz=",maximum_ground_guard_error," floor_snap_y=",maximum_ground_snap_y," executed_y=",maximum_ground_executed_y)

func validate_stationary_pose(scene: Node3D) -> void:
	dragon.global_position = Vector3(0,203.5,100)
	dragon.rotation = Vector3.ZERO
	dragon.target_yaw = 0
	dragon.target_pitch = 0
	dragon.target_roll = 0
	dragon.velocity = Vector3.ZERO
	dragon.current_speed = 0
	dragon.locomotion_state = dragon.LocomotionState.GROUNDED
	dragon.ground_pose.reset()
	await ticks(180)
	all_contact_probe.configure(dragon,dragon.skeleton,1)
	full_contact_tracking = true
	await ticks(2)
	if "--stationary-free-data" in OS.get_cmdline_user_args():
		var data := {}
		for label in ["neutral","aim"]:
			if label == "aim":
				dragon.set_head_aim(-PI/4,0)
				await ticks(120)
			var cloud: Array = []
			for point in final_contact_points:
				cloud.append([point.position.x,point.position.y,point.position.z,point.sample.neck,point.sample.wing])
			data[label] = cloud
		var file := FileAccess.open("/tmp/anatomy-stationary-free-skin.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		return
	var head := final_head_position
	flight_wall = StaticBody3D.new()
	flight_wall.collision_layer = 2
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1,2,4)
	collider.shape = box
	flight_wall.add_child(collider)
	flight_wall.position = Vector3(1.4,203.5,93.3)
	wall_half_extents = box.size * 0.5
	scene.add_child(flight_wall)
	track_wall = true
	await ticks(2)
	print("STATIONARY baseline head=",head," wall=",flight_wall.global_position," hits=",wall_penetrations)
	check(wall_penetrations == 0,"Stationary head wall starts outside visible skin")
	wall_penetrations = 0
	var body_start := dragon.global_transform
	var toggle := InputEventKey.new()
	toggle.keycode = KEY_T
	toggle.pressed = true
	Input.parse_input_event(toggle)
	await ticks(2)
	dragon.set_head_aim(-PI/4,0)
	await ticks(120)
	print("STATIONARY HEAD hits=",wall_penetrations," maxdepth=",maximum_box_penetration," aim=",dragon.head_aim_yaw," actual=",dragon.head_rendered_direction)
	check(wall_penetrations == 0,"Stationary T head45deg: all visible neck/cranium/body/wing vertices remain outside wall")
	check(dragon.global_position.distance_to(body_start.origin) < 0.01 and dragon.global_basis.is_equal_approx(body_start.basis),"T head aim against wall does not move body")
	check(dragon.head_pose_blocked,"Stationary head aim reports anatomical obstacle limit")
	var breath: DragonBreath = dragon.get_node("DragonBreath")
	breath.manual_override = false
	var fire := InputEventKey.new()
	fire.keycode = KEY_F
	fire.pressed = true
	Input.parse_input_event(fire)
	await ticks(30)
	print("STATIONARY FIRE firing=",breath.is_firing," angle=",rad_to_deg(breath.breath_direction.angle_to(dragon.head_rendered_direction))," mouth_error=",breath.mouth_position.distance_to(breath.rendered_oral_center+breath.breath_direction*0.08)," skin_hits=",wall_penetrations)
	check(breath.is_firing and rad_to_deg(breath.breath_direction.angle_to(dragon.head_rendered_direction)) < 0.1,"F fire follows actual wall-limited head direction")
	check(breath.mouth_position.distance_to(breath.rendered_oral_center+breath.breath_direction*0.08) < 0.01,"F fire starts at actual final oral midpoint landmark")
	check(wall_penetrations == 0,"F wall-limited head keeps all visible skin outside wall")
	fire = InputEventKey.new()
	fire.keycode = KEY_F
	fire.pressed = false
	Input.parse_input_event(fire)
	negative_neck_probe = true
	await ticks(2)
	check(negative_neck_seen,"Independent neck skin probe rejects deliberate penetrating head pose")
	track_wall = false
	flight_wall.queue_free()
	maximum_head_step = 0
	previous_head = dragon.head_rendered_direction
	await ticks(30)
	print("STATIONARY RECOVERY maximum_head_step=",maximum_head_step)
	check(maximum_head_step < 5,"Removing head obstacle restores aim smoothly under5deg per60Hz frame")
	dragon.head_aim_active = false
	dragon.global_position = Vector3(0,203.5,100)
	dragon.velocity = Vector3.ZERO
	dragon.rotation = Vector3.ZERO
	dragon.target_yaw = 0
	dragon.ground_pose.reset()
	await ticks(180)
	var outer := -INF
	for point in final_contact_points: outer = maxf(outer,point.position.x)
	flight_wall = StaticBody3D.new()
	flight_wall.collision_layer = 2
	collider = CollisionShape3D.new()
	box = BoxShape3D.new()
	box.size = Vector3(2,50,120)
	collider.shape = box
	flight_wall.add_child(collider)
	flight_wall.position = Vector3(outer+1.0,220,100)
	wall_half_extents = box.size * 0.5
	scene.add_child(flight_wall)
	wall_penetrations = 0
	maximum_box_penetration = 0
	track_wall = true
	await ticks(2)
	check(wall_penetrations == 0,"Stationary turn wall starts outside visible skin")
	dragon.manual_turn_input = -1
	await ticks(180)
	print("STATIONARY TURN hits=",wall_penetrations," maxdepth=",maximum_box_penetration," root=",dragon.global_position," yaw=",dragon.rotation.y)
	check(wall_penetrations == 0,"Stationary turn: all visible skin remains outside lateral wall")
	track_wall = false
	dragon.manual_turn_input = 0
	flight_wall.queue_free()

func validate_enclosure_holdout() -> void:
	var second := "--holdout-second" in OS.get_cmdline_user_args()
	dragon.global_position = Vector3(0,340,100)
	dragon.rotation = Vector3.ZERO
	dragon.target_yaw = 0
	dragon.target_pitch = 0
	dragon.target_roll = 0
	dragon.locomotion_state = dragon.LocomotionState.FLYING
	dragon.ground_blend = 0
	dragon.ground_pose.reset()
	for index in 8:
		dragon.manual_climb = index%4==0
		dragon.manual_dive = index%4==1
		dragon.manual_brake = index%4==2
		dragon.glide_mode_active = index%4==3
		dragon.set_head_aim(deg_to_rad([27,-41,13,-19][index%4] if second else [-31,17,39,-23][index%4]),deg_to_rad([-17,25,-11,19][index%4] if second else [13,-27,21,-9][index%4]))
		await ticks([13,31,17,37,23,41,19,43][index] if second else [7,19,11,23,17,29,13,31][index])
		await snapshot(("holdout2_air_%d" if second else "holdout_air_%d") % index)
	dragon.manual_climb = false
	dragon.manual_dive = false
	dragon.manual_brake = false
	dragon.glide_mode_active = false
	dragon.global_position = Vector3(0,203.5,100)
	dragon.rotation = Vector3.ZERO
	dragon.target_yaw = 0
	dragon.target_pitch = 0
	dragon.target_roll = 0
	dragon.current_speed = 0
	dragon.velocity = Vector3.ZERO
	dragon.locomotion_state = dragon.LocomotionState.GROUNDED
	dragon.ground_blend = 1
	dragon.ground_pose.reset()
	await ticks(91 if second else 77)
	dragon.walk_forward(true)
	for index in 4:
		dragon.manual_turn_input = [-0.23,0.19,-0.11,0.29][index] if second else [0.17,-0.31,0.21,-0.13][index]
		dragon.set_head_aim(deg_to_rad([-29,33,-17,25][index] if second else [31,-37,9,-21][index]),deg_to_rad([17,-21,11,-19][index] if second else [-13,23,7,-26][index]))
		await ticks([23,37,47,61][index] if second else [17,29,41,53][index])
		await snapshot(("holdout2_ground_%d" if second else "holdout_ground_%d") % index)

func validate_foot_yaw() -> void:
	dragon.global_position = Vector3(0,203.5,100)
	dragon.rotation = Vector3.ZERO
	dragon.target_yaw = 0
	dragon.velocity = Vector3.ZERO
	dragon.current_speed = 0
	dragon.locomotion_state = dragon.LocomotionState.GROUNDED
	dragon.ground_blend = 1
	dragon.ground_pose.reset()
	await ticks(120)
	var initial := []
	for limb in dragon.ground_pose.limbs: initial.append(limb.foot_basis)
	dragon.manual_turn_input = -1
	for i in 360:
		await ticks(1)
		if absf(dragon.rotation.y)>=PI*.5: break
	dragon.manual_turn_input = 0
	dragon.walk_forward()
	await ticks(180)
	var maximum := 0.0
	for index in dragon.ground_pose.limbs.size():
		var limb: Dictionary = dragon.ground_pose.limbs[index]
		var wanted: Basis = Basis(Vector3.UP,dragon.rotation.y)*initial[index]
		maximum = maxf(maximum,rad_to_deg(wanted.get_rotation_quaternion().angle_to(limb.foot_basis.get_rotation_quaternion())))
	print("FOOT_YAW body_deg=",rad_to_deg(dragon.rotation.y)," maximum_orientation_error_deg=",maximum," stance_slide_m=",maximum_stance_slide)
	check(absf(dragon.rotation.y)>=deg_to_rad(80),"Foot yaw repro rotates actual body at least80deg")
	check(maximum<5,"Feet reorient to new walking heading during swing within5deg")
	check(maximum_stance_slide<=.015,"Turning keeps actual skin stance drift<=1.5cm")

func validate_real_terrain(scene: Node3D) -> void:
	var landscape: Node3D = dragon.landscape
	if "--export-terrain-grid" in OS.get_cmdline_user_args():
		var trees := []
		for transform in landscape._tree_transforms: trees.append({"origin":[transform.origin.x,transform.origin.y,transform.origin.z],"scale":[transform.basis.get_scale().x,transform.basis.get_scale().y,transform.basis.get_scale().z]})
		FileAccess.open("/tmp/dragon-terrain-freeze-grid.json",FileAccess.WRITE).store_string(JSON.stringify({"heights":Array(landscape._heights),"source_heights":landscape._source_heights,"trees":trees}))
	var slope_surface: Dictionary = landscape.ground_surface(Vector3(450,0,220))
	check(not slope_surface.is_empty(),"Real hillside450/220 has physical collision surface")
	dragon.global_position = slope_surface.position + Vector3.UP * 38
	dragon.rotation = Vector3(0,PI,0)
	dragon.target_yaw = PI
	dragon.head_aim_direction = Vector3.BACK
	dragon.head_rendered_direction = Vector3.BACK
	dragon.target_pitch = 0
	dragon.target_roll = 0
	dragon.velocity = Vector3.ZERO
	dragon.current_speed = 0
	dragon.trigger_landing()
	for i in 1400:
		await ticks(1)
		if dragon.ground_proximity < 10 and not full_snapshots.has("real_hill_low_approach"): await snapshot("real_hill_low_approach")
		if dragon.locomotion_state == dragon.LocomotionState.GROUNDED: break
	if "--body-terrain" in OS.get_cmdline_user_args(): start_body_terrain_tracking("real_hill_touchdown20",20)
	await ticks(60)
	if "--body-terrain" in OS.get_cmdline_user_args(): finish_body_terrain_tracking()
	check(dragon.locomotion_state == dragon.LocomotionState.GROUNDED,"Actual valley hillside landing reaches floor")
	await snapshot("real_hill_stance")
	if "--body-diagnostic-stop" in OS.get_cmdline_user_args(): return
	print("REAL_HILL_SURFACE ",slope_surface)
	# Continue from the actual clear touchdown. Repositioning450/220 put the
	# folded wing inside tree1241 and was not a valid movement fixture.
	await ticks(90)
	var start := dragon.global_position
	if "--body-terrain" in OS.get_cmdline_user_args(): start_body_terrain_tracking("real_hill_walk90",90)
	dragon.walk_forward()
	await ticks(90)
	if "--body-terrain" in OS.get_cmdline_user_args(): finish_body_terrain_tracking()
	print("REAL_HILL_WALK start=",start," end=",dragon.global_position," contact=",dragon.wing_contact.contact_details," max_guard_xz_error=",maximum_ground_guard_error," max_floor_snap_y=",maximum_ground_snap_y)
	check(dragon.global_position.distance_to(start) > 3,"Actual hillside walk advances over3m without false floor blocking")
	await snapshot("real_hill_walk")
	if "--body-diagnostic-first-hill" in OS.get_cmdline_user_args() or "--capture-real-motion" in OS.get_cmdline_user_args(): return
	dragon.stop_walking()
	await ticks(60)
	# Approach the formerly intersecting tree from the clear landing through
	# ordinary reverse walking, never by placing skin inside a collider.
	var retreat_start := dragon.global_position
	dragon.walk_backward()
	await ticks(540)
	if "--body-terrain" in OS.get_cmdline_user_args(): start_body_terrain_tracking("real_tree_reverse90",90)
	await ticks(90)
	if "--body-terrain" in OS.get_cmdline_user_args(): finish_body_terrain_tracking()
	check(dragon.global_position.distance_to(retreat_start)>3,"Real clear hillside approach and retreat advance over3m")
	print("REAL_TREE_APPROACH root=",dragon.global_position," contact=",dragon.wing_contact.contact_details)
	await snapshot("real_tree_reverse_contact")
	dragon.stop_walking()
	await ticks(60)
	# A second broad patch, changed by warp and checked without QA exemptions.
	var second: Dictionary = landscape.ground_surface(Vector3(240.625,0,-709.375))
	check(not second.is_empty(),"New warped hillside240.625/-709.375 has physical collision surface")
	print("REAL_SECOND_HILL_SURFACE ",second)
	var downhill := Vector3.FORWARD
	var downhill_yaw := 0.0
	dragon.ground_pose.reset()
	dragon.body_clearance_lift = 0.0
	dragon.global_position = second.position+Vector3.UP*10
	dragon.rotation = Vector3(0,downhill_yaw,0)
	dragon.target_yaw = downhill_yaw
	dragon.target_pitch = 0
	dragon.target_roll = 0
	dragon.head_aim_direction = downhill
	dragon.head_rendered_direction = downhill
	dragon.velocity = Vector3.ZERO
	dragon.current_speed = 0
	dragon.locomotion_state = dragon.LocomotionState.FLYING
	dragon.ground_blend = 0
	dragon.landing_target_active = false
	dragon.trigger_landing()
	for i in 1400:
		await ticks(1)
		if dragon.ground_proximity<10 and not full_snapshots.has("real_second_hill_low_approach"): await snapshot("real_second_hill_low_approach")
		if dragon.locomotion_state==dragon.LocomotionState.GROUNDED: break
	if "--body-terrain" in OS.get_cmdline_user_args(): start_body_terrain_tracking("real_second_hill_touchdown20",20)
	await ticks(60)
	if "--body-terrain" in OS.get_cmdline_user_args(): finish_body_terrain_tracking()
	check(dragon.locomotion_state==dragon.LocomotionState.GROUNDED,"New warped hillside landing reaches floor")
	await snapshot("real_second_hill_stance")
	await ticks(90)
	start = dragon.global_position
	if "--body-terrain" in OS.get_cmdline_user_args(): start_body_terrain_tracking("real_second_hill_walk90",90)
	dragon.walk_forward()
	await ticks(90)
	if "--body-terrain" in OS.get_cmdline_user_args(): finish_body_terrain_tracking()
	print("REAL_SECOND_HILL_WALK start=",start," end=",dragon.global_position," contact=",dragon.wing_contact.contact_details)
	check(dragon.global_position.distance_to(start)>3,"New warped hillside walk advances over3m")
	await snapshot("real_second_hill_walk")
	dragon.stop_walking()
	await ticks(60)
	var cliff: MeshInstance3D = landscape.get_node("GithubNamaqualandCliffScan")
	var cliff_box := AABB(cliff.to_global(cliff.get_aabb().get_endpoint(0)),Vector3.ZERO)
	for corner in 8: cliff_box = cliff_box.expand(cliff.to_global(cliff.get_aabb().get_endpoint(corner)))
	var y: float = cliff_box.get_center().y
	print("REAL_CLIFF_AABB ",cliff_box)
	dragon.global_position = Vector3(375,y,145)
	dragon.rotation = Vector3(0,-PI/2,0)
	dragon.target_yaw = -PI/2
	dragon.target_pitch = 0
	dragon.target_roll = 0
	dragon.head_aim_direction = Vector3.RIGHT
	dragon.head_rendered_direction = Vector3.RIGHT
	dragon.locomotion_state = dragon.LocomotionState.FLYING
	dragon.ground_blend = 0
	dragon.velocity = Vector3(34,0,0)
	dragon.current_speed = 34
	dragon.manual_move_input = 1
	var cliff_start := dragon.global_position
	var real_contact_seen := false
	for i in 240:
		await ticks(1)
		if dragon.wing_contact.predictive_contact: real_contact_seen = true
		if i in [30,120,230]: await snapshot("real_cliff_flight_%s" % i)
	var skin_bottom := INF
	if body_partition_probe.samples.is_empty(): body_partition_probe.configure(dragon,dragon.skeleton,1)
	for point in body_partition_probe.points(dragon.skeleton): skin_bottom = minf(skin_bottom,point.position.y)
	check(dragon.global_position.distance_to(cliff_start)>3 and (real_contact_seen or skin_bottom>cliff_box.end.y),"Fast actual scanned-rock approach advances and physically stops or clears its measured surface")
	print("REAL_CLIFF body=",dragon.global_position," contacts=",dragon.wing_contact.contact_details)
	dragon.manual_move_input = 0
	var face_start: Dictionary = landscape.ground_surface(Vector3(662.5,0,-387.5))
	check(not face_start.is_empty(),"Escarpment approach begins inside actual321x321 collision grid")
	dragon.global_position = face_start.position+Vector3.UP*22
	dragon.rotation = Vector3(0,PI/4,0)
	dragon.target_yaw = PI/4
	dragon.target_pitch = 0
	dragon.target_roll = 0
	dragon.head_aim_direction = Vector3(-1,0,-1).normalized()
	dragon.head_rendered_direction = dragon.head_aim_direction
	dragon.velocity = dragon.head_aim_direction*34
	dragon.current_speed = 34
	dragon.locomotion_state = dragon.LocomotionState.FLYING
	dragon.ground_blend = 0
	dragon.manual_move_input = 1
	dragon.ground_pose.reset()
	await snapshot("real_escarpment_initial_clear")
	var face_begin := dragon.global_position
	if "--body-terrain" in OS.get_cmdline_user_args(): start_body_terrain_tracking("real_escarpment_approach198",198)
	for i in 180:
		await ticks(1)
		if i in [30,100,170]: await snapshot("real_escarpment_flight_%s" % i)
	if "--body-terrain" in OS.get_cmdline_user_args():
		finish_body_terrain_tracking()
		check(body_terrain_track_metrics.observed_surface_vertices==body_terrain_track_metrics.frames*20191,"All20191 body vertices observe actual escarpment terrain in every tracked frame")
	dragon.manual_move_input = 0
	check(dragon.global_position.distance_to(face_begin)>3,"Clear escarpment approach executes actual continuous movement")
	print("REAL_ESCARPMENT body=",dragon.global_position," start=",face_begin," contacts=",dragon.wing_contact.contact_details)

func run() -> void:
	var real_mode := "--real-terrain" in OS.get_cmdline_user_args()
	var source: Node3D = load("res://scenes/main.tscn").instantiate()
	dragon = source.get_node("Dragon")
	source.remove_child(dragon)
	dragon.owner = null
	var scene := Node3D.new()
	var retained: Array = ["WorldEnvironment","DirectionalLight3D"]
	if real_mode: retained.append_array(["NaturalLandscape","SceneryCollisions"])
	for name in retained:
		var light := source.get_node(name)
		source.remove_child(light)
		light.owner = null
		scene.add_child(light)
	source.free()
	scene.add_child(dragon)
	root.add_child(scene)
	dragon.landscape = scene.get_node("NaturalLandscape") if real_mode else scene
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280,720)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(240,1,240)
	floor_shape.shape = shape
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0,199.5,100)
	if real_mode: floor_body.queue_free()
	else: scene.add_child(floor_body)
	var floor_mesh := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	floor_mesh.mesh = mesh
	floor_body.add_child(floor_mesh)
	camera = Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	camera.fov = 45.0
	dragon = scene.get_node("Dragon")
	await ticks(150)
	if "--runtime-benchmark" in OS.get_cmdline_user_args():
		await runtime_benchmark()
		quit()
		return
	dragon.has_taken_off = true
	dragon.manual_input_override = true
	probe.configure(dragon, dragon.skeleton, 1)
	probe.samples = probe.samples.filter(func(sample): return int(sample.claw) >= 0 or int(sample.index) % 12 == 0)
	for child in dragon.skeleton.get_children():
		if child is SkeletonModifier3D: modifier = child
	modifier.modification_processed.connect(record)
	print("PROBE meshes=", probe.mesh_count, " samples=", probe.samples.size())
	if "--locomotion-contract" in OS.get_cmdline_user_args():
		await validate_locomotion_contract()
		quit(0 if failures.is_empty() else 1)
		return
	if "--enclosure-holdout" in OS.get_cmdline_user_args():
		await validate_enclosure_holdout()
		FileAccess.open("res://docs/validation/v2/anatomy-holdout-full-skin.json",FileAccess.WRITE).store_string(JSON.stringify(full_snapshots))
		quit(0 if failures.is_empty() else 1)
		return
	if "--foot-yaw" in OS.get_cmdline_user_args():
		await validate_foot_yaw()
		quit(0 if failures.is_empty() else 1)
		return
	if "--body-contact" in OS.get_cmdline_user_args():
		await validate_body_contact(scene)
		quit(0 if failures.is_empty() else 1)
		return
	if "--stationary-pose" in OS.get_cmdline_user_args():
		await validate_stationary_pose(scene)
		if Probe.profiling: print("ANATOMY_PROFILE_STATIONARY ",JSON.stringify(Probe.costs))
		quit(0 if failures.is_empty() else 1)
		return
	if real_mode:
		await validate_real_terrain(scene)
		var real_path := "res://docs/validation/v2/anatomy-real-capture-skin.json" if "--capture-real-motion" in OS.get_cmdline_user_args() else "res://docs/validation/v2/anatomy-real-full-skin.json"
		var real_file := FileAccess.open(real_path,FileAccess.WRITE)
		real_file.store_string(JSON.stringify(full_snapshots))
		if not body_partition_snapshots.is_empty():
			FileAccess.open("res://docs/validation/v2/anatomy-body-partition-skin.json",FileAccess.WRITE).store_string(JSON.stringify({"triangles":dragon.wing_contact.body_triangles,"poses":body_partition_snapshots}))
		quit(0 if failures.is_empty() else 1)
		return
	if "--collect-extrema" in OS.get_cmdline_user_args() or "--collect-ground-extrema" in OS.get_cmdline_user_args():
		dragon.global_position = Vector3(0,340,100)
		dragon.locomotion_state = dragon.LocomotionState.FLYING
		var collect_modes: Array = [] if "--collect-ground-extrema" in OS.get_cmdline_user_args() else ["normal","climb","dive","brake","glide"]
		for mode in collect_modes:
			dragon.manual_climb = mode == "climb"
			dragon.manual_dive = mode == "dive"
			dragon.manual_brake = mode == "brake"
			dragon.glide_mode_active = mode == "glide"
			await ticks(60)
			for sample in 32:
				await snapshot("%s_%02d" % [mode,sample])
		for mode in ["ground","glide"]:
			dragon.locomotion_state = dragon.LocomotionState.GROUNDED if mode == "ground" else dragon.LocomotionState.FLYING
			dragon.global_position = Vector3(0,203.5,100) if mode == "ground" else Vector3(0,340,100)
			dragon.ground_pose.reset()
			dragon.ground_blend = 1 if mode == "ground" else 0
			dragon.wing_fold_blend = 1 if mode == "ground" else 0
			dragon.velocity = Vector3.ZERO
			dragon.current_speed = 0
			dragon.manual_climb = false
			dragon.manual_dive = false
			dragon.manual_brake = false
			dragon.glide_mode_active = true
			for aim in [Vector2(-45,-30),Vector2(45,-30),Vector2(-45,30),Vector2(45,30)]:
				dragon.set_head_aim(deg_to_rad(aim.x),deg_to_rad(aim.y))
				if mode == "ground": dragon.wing_fold_blend = 1
				await ticks(42)
				await snapshot("%s_aim_%s_%s" % [mode,aim.x,aim.y])
		var collection_path := "res://docs/validation/v2/anatomy-extrema-ground.json" if "--collect-ground-extrema" in OS.get_cmdline_user_args() else "res://docs/validation/v2/anatomy-extrema-poses.json"
		var collection := FileAccess.open(collection_path,FileAccess.WRITE)
		collection.store_string(JSON.stringify(full_snapshots))
		quit(0 if failures.is_empty() else 1)
		return
	for b in dragon.skeleton.get_bone_count():
		if b < 30 or b in [39,40,41,80,81,82,96,97,104,108,120,121,128,132]: print("BONE ", b," ",dragon.skeleton.get_bone_name(b))
	dragon.global_position = Vector3(0,235,100)
	dragon.velocity = Vector3.ZERO
	dragon.current_speed = 0
	dragon.trigger_landing()
	for i in 1000:
		await ticks(1)
		if dragon.ground_proximity < 10 and not full_snapshots.has("low_approach"):
			await snapshot("low_approach")
		if i % (3 if "--capture-motion-only" in OS.get_cmdline_user_args() else 15) == 0 and capture:
			camera.global_position = dragon.global_position + Vector3(38,10,8)
			camera.look_at(dragon.global_position)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/validation/v2/anatomy-land-%04d.png" % i)
		if dragon.locomotion_state == dragon.LocomotionState.GROUNDED: break
	await ticks(60)
	check(dragon.locomotion_state == dragon.LocomotionState.GROUNDED, "Landing reaches real collision ground")
	await snapshot("flat_land_stance")
	dragon.walk_forward()
	for i in 180:
		await ticks(1)
		if i % 6 == 0 and capture:
			camera.global_position = dragon.global_position + Vector3(30,7,0)
			camera.look_at(dragon.global_position + Vector3(0,0,-6))
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/validation/v2/anatomy-walk-%04d.png" % i)
	await snapshot("flat_walk")
	dragon.stop_walking()
	await ticks(60)
	var neutral_pitches: Array[float] = []
	for report in reports:
		if report.state == dragon.LocomotionState.GROUNDED and report.frame >= 480: neutral_pitches.append(float(report.muzzle_pitch))
	neutral_pitches.sort()
	check(neutral_pitches[0] >= -5 and neutral_pitches[-1] <= 15,"Visible muzzle neutral/walking pitch stays between-5and15deg")
	var idle_directions: Array[Vector3] = []
	for i in 720:
		await ticks(1)
		if i % 30 == 0: idle_directions.append(dragon.head_rendered_direction)
	var idle_range := 0.0
	for direction in idle_directions:
		for other in idle_directions: idle_range = maxf(idle_range,rad_to_deg(direction.angle_to(other)))
	print("HEAD_NEUTRAL pitch=",neutral_pitches[0],"..",neutral_pitches[-1]," idle_variation=",idle_range)
	check(idle_range >= 2 and idle_range <= 10,"Actual idle muzzle variation stays between2and10deg")
	var minimum := 0.0
	for r in reports: minimum = minf(minimum, r.minimum_wing_clearance)
	check(probe.samples.size() > 1000 and probe.mesh_count >= 2, "Probe skins both visible meshes through Skin bindings")
	check(minimum >= -0.05, "Wing visible vertices never penetrate collision ground over 5cm")
	var support_min := 4
	var claw_min := INF
	for r in reports:
		if r.state != dragon.LocomotionState.GROUNDED or r.frame < 480: continue
		var supports := 0
		for c in r.claw_clearance.values():
			claw_min = minf(claw_min, float(c))
			if float(c) >= -0.07 and float(c) <= 0.07: supports += 1
		support_min = mini(support_min, supports)
	check(claw_min >= -0.07, "Visible claw skin penetration under 7cm in flat walk")
	check(support_min >= 3, "At least three actual claw surfaces contact flat walk ground")
	if "--flat-support-only" in OS.get_cmdline_user_args():
		print("FLAT_SUPPORT minimum=",support_min," samples=",reports.size())
		quit(0 if failures.is_empty() else 1)
		return
	negative_probe = true
	await ticks(6)
	check(negative_seen, "Independent skin probe rejects deliberately penetrating render pose")
	for target in [Vector2(0,20),Vector2(0,-20),Vector2(20,0),Vector2(-20,0)]:
		dragon.set_head_aim(deg_to_rad(target.x),deg_to_rad(target.y))
		await ticks(42)
		check(rad_to_deg(dragon.head_rendered_direction.angle_to(dragon.head_aim_direction)) <= 3.0, "Muzzle follows independent target %s within3deg" % target)
		check(Vector2(dragon.head_aim_yaw,dragon.head_aim_pitch).distance_to(target * PI / 180.0) < deg_to_rad(3), "Head target %s converges under0.7s" % target)
	print("CLAW stance_slide=", maximum_stance_slide," steps=", visible_steps)
	check(maximum_stance_slide <= 0.015, "Actual fixed claw vertex slides at most1.5cm per60Hz stance frame")
	var complete_steps := visible_steps.filter(func(length): return length > 2.0)
	check(complete_steps.size() >= 4, "Actual claw stance-to-stance longitudinal strides exceed2m at7.5mps")
	check(maximum_head_step < 5, "Head actual render direction stays under5deg per60Hz frame")
	dragon.head_aim_active = false
	if capture:
		dragon.global_position = Vector3(0,203.5,100)
		dragon.velocity = Vector3.ZERO
		dragon.current_speed = 0
		dragon.rotation = Vector3.ZERO
		dragon.target_yaw = 0
		dragon.head_aim_direction = Vector3.FORWARD
		dragon.head_rendered_direction = Vector3.FORWARD
		dragon.ground_pose.reset()
		for i in 300:
			if i == 60: dragon.walk_forward()
			if i == 120: dragon.walk_forward(true)
			if i == 210: dragon.stop_walking()
			await ticks(1)
			if i % 3 == 0:
				camera.global_position = dragon.global_position + Vector3(30,7,0)
				camera.look_at(dragon.global_position + Vector3(0,0,-6))
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://docs/validation/v2/anatomy-gait-%04d.png" % i)
	if "--capture-motion-only" in OS.get_cmdline_user_args():
		var file := FileAccess.open("res://docs/validation/v2/anatomy-motion-full-skin.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(full_snapshots))
		quit(0 if failures.is_empty() else 1)
		return
	dragon.global_position = Vector3(0,340,100)
	dragon.ground_blend = 0
	dragon.locomotion_state = dragon.LocomotionState.FLYING
	dragon.ground_pose.reset()
	dragon.rotation = Vector3.ZERO
	dragon.target_pitch = 0
	dragon.target_roll = 0
	dragon.target_yaw = 0
	dragon.velocity = Vector3(0,0,-26)
	dragon.current_speed = 26
	dragon.glide_mode_active = true
	await ticks(120)
	glide_metrics.clear()
	if capture:
		await snapshot("neutral_glide")
	for i in 1200:
		await ticks(1)
		if capture and i % 30 == 0:
			var angles := [Vector3(0,10,90),Vector3(65,8,0),Vector3(0,65,45)]
			camera.global_position = dragon.global_position + angles[(i / 400) % 3]
			camera.look_at(dragon.global_position)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/validation/v2/anatomy-glide-%04d.png" % i)
	var maximum_tip := 0.0
	var maximum_roll := 0.0
	var span := 0.0
	for metric in glide_metrics:
		maximum_tip = maxf(maximum_tip, metric.tip_height_delta)
		maximum_roll = maxf(maximum_roll, metric.roll)
		span = maxf(span, metric.span)
	if not capture: await snapshot("neutral_glide")
	for marker in vertex_markers: marker.queue_free()
	vertex_markers.clear()
	print("GLIDE last ", glide_metrics[-1])
	print("GLIDE metrics tip=",maximum_tip," roll=",maximum_roll," span=",span)
	check(maximum_roll <= 2, "20s glide neutral body roll under 2deg")
	check(maximum_tip <= maxf(0.4,span * 0.03), "20s glide visible equivalent tips stay within 3percent span")
	flight_wall = StaticBody3D.new()
	flight_wall.collision_layer = 2
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(90,80,3)
	wall_shape.shape = wall_box
	flight_wall.add_child(wall_shape)
	flight_wall.position = Vector3(0,330,0)
	scene.add_child(flight_wall)
	dragon.global_position = Vector3(0,330,100)
	dragon.rotation = Vector3.ZERO
	dragon.target_yaw = 0
	dragon.target_pitch = 0
	dragon.target_roll = 0
	dragon.current_speed = 38
	dragon.velocity = Vector3(0,0,-38)
	dragon.manual_move_input = 1
	dragon.glide_mode_active = false
	await ticks(1)
	previous_body = dragon.global_position
	all_contact_probe.configure(dragon,dragon.skeleton,1)
	full_contact_tracking = true
	track_wall = true
	await ticks(360)
	track_wall = false
	await snapshot("frontal_prop")
	print("WALL penetration_samples=",wall_penetrations," max_tick=",max_tick_displacement," body=",dragon.global_position)
	check(wall_penetrations == 0, "Fast frontal approach: actual body/neck/wing skin never enters prop collider")
	check(dragon.global_position.z > 1.5, "Fast frontal approach never crosses wall")
	check(max_tick_displacement < 1.0, "Contact response has no body teleport at60Hz")
	wall_penetrations = 0
	flight_wall.position = Vector3(-24,330,100)
	wall_box.size = Vector3(3,80,240)
	wall_half_extents = wall_box.size * 0.5
	dragon.global_position = Vector3(0,330,100)
	dragon.rotation = Vector3.ZERO
	dragon.target_yaw = 0
	dragon.target_pitch = 0
	dragon.target_roll = 0
	dragon.manual_turn_input = 1.0
	dragon.velocity = Vector3(0,0,-34)
	dragon.current_speed = 34
	await ticks(1)
	previous_body = dragon.global_position
	track_wall = true
	await ticks(180)
	track_wall = false
	full_contact_tracking = false
	await snapshot("lateral_turn_prop")
	print("SIDE WALL penetration_samples=",wall_penetrations," body=",dragon.global_position)
	check(wall_penetrations == 0, "Fast lateral turn: actual wing/body skin never enters prop collider")
	flight_wall.queue_free()
	dragon.manual_turn_input = 0
	dragon.manual_move_input = 0
	var slope_body := StaticBody3D.new()
	slope_body.collision_layer = 1
	var slope_shape := CollisionShape3D.new()
	var slope_box := BoxShape3D.new()
	slope_box.size = Vector3(160,1,160)
	slope_shape.shape = slope_box
	slope_body.add_child(slope_shape)
	slope_body.position = Vector3(400,199.5,100)
	slope_body.rotation.z = deg_to_rad(15)
	scene.add_child(slope_body)
	dragon.global_position = Vector3(400,235,100)
	dragon.rotation = Vector3.ZERO
	dragon.target_yaw = 0
	dragon.target_pitch = 0
	dragon.target_roll = 0
	dragon.velocity = Vector3.ZERO
	dragon.current_speed = 0
	dragon.trigger_landing()
	var slope_report_start := reports.size()
	for i in 1000:
		await ticks(1)
		if dragon.locomotion_state == dragon.LocomotionState.GROUNDED: break
	await ticks(60)
	check(dragon.locomotion_state == dragon.LocomotionState.GROUNDED, "15deg slope landing reaches real collider")
	dragon.walk_forward()
	await ticks(180)
	dragon.stop_walking()
	await ticks(60)
	var slope_wing_min := 0.0
	var slope_claw_min := INF
	var slope_support_min := 4
	for r in reports.slice(slope_report_start):
		slope_wing_min = minf(slope_wing_min,float(r.minimum_wing_clearance))
		if r.state != dragon.LocomotionState.GROUNDED: continue
		var supports := 0
		for c in r.claw_clearance.values():
			slope_claw_min = minf(slope_claw_min,float(c))
			if float(c) >= -0.07 and float(c) <= 0.07: supports += 1
		slope_support_min = mini(slope_support_min,supports)
	await snapshot("15deg_slope_stance")
	print("SLOPE wing_min=",slope_wing_min," claw_min=",slope_claw_min," supports=",slope_support_min)
	check(slope_wing_min >= -0.05, "15deg slope landing and walking keeps membrane skin over ground")
	check(slope_claw_min >= -0.07, "15deg slope visible claws stay above penetration limit")
	DirAccess.make_dir_recursive_absolute("res://docs/validation/v2")
	var file := FileAccess.open("res://docs/validation/v2/anatomy-measurements.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(reports,"\t"))
	var full_file := FileAccess.open("res://docs/validation/v2/anatomy-full-skin.json",FileAccess.WRITE)
	full_file.store_string(JSON.stringify(full_snapshots))
	quit(0 if failures.is_empty() else 1)
