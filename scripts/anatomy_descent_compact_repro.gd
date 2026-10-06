extends SceneTree
const Probe = preload("res://scripts/dragon_pose_probe.gd")
var dragon: DragonController
var camera: Camera3D
var probe = Probe.new()
var all_probe = Probe.new()
var scene: Node3D
var phase := ""
var rows: Array = []
var clouds := {}
var dense_clouds := {}
var failures: Array[String] = []
var last_tick := -1
var modifier: SkeletonModifier3D
var joint_history := {}
var maximum_joint_step_deg := 0.0
var maximum_world_joint_step_deg := 0.0
var maximum_walk_joint_step_deg := 0.0
var maximum_walk_axis_step_deg := 0.0
var rear_release_observations: Dictionary={}
var translations := {}
var maximum_translation_change := 0.0
var pending_pose := ""
var minimum_ground_claw_clearance := INF
var maximum_stance_slip := 0.0
var maximum_walk_target_step := 0.0
var maximum_length_error_m := 0.0
var link_lengths: Dictionary={}
var stride_active:=false
var stride_feet: Dictionary={}
var stride_tick: int=-1
var stride_root:=Vector3.ZERO
func record_strides() -> void:
	if not stride_active: return
	var tick:=Engine.get_physics_frames()
	if tick<=stride_tick: return
	var duration:=float(tick-stride_tick)/Engine.physics_ticks_per_second
	var travel:=Vector2(dragon.global_position.x-stride_root.x,dragon.global_position.z-stride_root.z).length()
	var speed:=travel/duration
	stride_tick=tick
	stride_root=dragon.global_position
	for limb in dragon.ground_pose.limbs:
		var foot: Dictionary=stride_feet[limb.end]
		var point: Vector3=probe.point(dragon.skeleton,foot.sample)
		if foot.seeded:
			foot.travel+=travel
			foot.min_speed=minf(foot.min_speed,speed)
			foot.max_speed=maxf(foot.max_speed,speed)
		if foot.swing and not limb.swinging:
			if foot.seeded:
				var elapsed:=float(tick-foot.tick)/Engine.physics_ticks_per_second
				foot.events.append({"stride_m":absf((point-foot.position).dot(Vector3.FORWARD)),"speed_mps":foot.travel/elapsed,"minimum_speed_mps":foot.min_speed,"maximum_speed_mps":foot.max_speed})
			foot.seeded=true
			foot.position=point
			foot.tick=tick
			foot.travel=0.0
			foot.min_speed=INF
			foot.max_speed=0.0
		foot.swing=limb.swinging

func _initialize() -> void: call_deferred("run")
func ticks(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func key(code: Key, pressed: bool) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
func capture_authored_translations() -> void:
	for b in [5,6,7,20,21,22]: translations[b]=dragon.skeleton.get_bone_pose_position(b)
func measure() -> void:
	if phase.is_empty() or last_tick==Engine.get_physics_frames(): return
	last_tick=Engine.get_physics_frames()
	record_strides()
	for limb in dragon.ground_pose.limbs:
		maximum_length_error_m=maxf(maximum_length_error_m,float(limb.get("analytic_length_error",0))*dragon.skeleton.global_basis.x.length())
		if phase.begins_with("brake_descent_first_"): maximum_walk_target_step=maxf(maximum_walk_target_step,float(limb.get("primary_step_world",0)))
	if not pending_pose.is_empty():
		collect_pose(pending_pose)
		pending_pose=""
	for b in [5,6,7,20,21,22]:
		var child: int={5:6,6:7,7:8,20:21,21:22,22:23}[b]
		var actual_length: float=dragon.skeleton.to_global(dragon.skeleton.get_bone_global_pose(child).origin).distance_to(dragon.skeleton.to_global(dragon.skeleton.get_bone_global_pose(b).origin))
		if not link_lengths.has(b): link_lengths[b]=actual_length
		maximum_length_error_m=maxf(maximum_length_error_m,absf(actual_length-float(link_lengths[b])))
		var axis: Vector3=(dragon.skeleton.get_bone_global_pose(child).origin-dragon.skeleton.get_bone_global_pose(b).origin).normalized()
		var ordinary_walking:=false
		for limb in dragon.ground_pose.limbs:
			if b not in limb.chain: continue
			ordinary_walking=dragon.locomotion_state==dragon.LocomotionState.GROUNDED and dragon.ground_blend>.99 and absf(dragon.ground_motion_speed)>.12 and not bool(limb.get("support_transition",false))
			if ordinary_walking and not rear_release_observations.has(limb.end): rear_release_observations[limb.end]={"tick":last_tick,"ground_blend":dragon.ground_blend,"actual_speed_mps":dragon.ground_motion_speed,"phase":phase}
		var world_orientation := (dragon.skeleton.global_basis*dragon.skeleton.get_bone_global_pose(b).basis).get_rotation_quaternion()
		var orientation := (dragon.global_basis.inverse()*dragon.skeleton.global_basis*dragon.skeleton.get_bone_global_pose(b).basis).get_rotation_quaternion()
		if phase.begins_with("brake_descent") and not ordinary_walking and joint_history.has(b) and last_tick-int(joint_history[b].tick)<6:
			var prior: Dictionary=joint_history[b]
			var step_deg := rad_to_deg(orientation.angle_to(prior.orientation))/maxi(1,last_tick-prior.tick)
			maximum_world_joint_step_deg=maxf(maximum_world_joint_step_deg,rad_to_deg(world_orientation.angle_to(prior.world_orientation))/maxi(1,last_tick-prior.tick))
			if step_deg>maximum_joint_step_deg:
				maximum_joint_step_deg=step_deg
				var cache: Dictionary=dragon.get_meta("air_rear_joint_pose",{})
				for limb in dragon.ground_pose.limbs:
					if b in limb.chain: print("JOINT_SUPPORT b=",b," limited=",limb.get("support_limited",false)," transition=",limb.get("support_transition",false)," support_frame=",limb.get("support_frame",-1)," anchor_error=",rad_to_deg(orientation.angle_to(limb.get("support_anchors",{}).get(b,orientation)))," cache_error=",rad_to_deg(orientation.angle_to(limb.get("support_rotations",{}).get(b,orientation)))," recovering=",dragon.wing_contact.body_pose_recovering," blocked=",dragon.wing_contact.body_pose_blocked," hock=",limb.get("hock_distance",0)," hock_min=",limb.get("hock_minimum",0)," foot_dist=",limb.get("foot_reach_distance",0)," foot_max=",limb.get("foot_reach_total",0)," target_change=",limb.get("target_change",0)," swing_elapsed=",limb.get("swing_elapsed",0)," reposition=",limb.repositioning," length_error=",limb.get("analytic_length_error",0))
				print("JOINT_WORST b=",b," tick=",last_tick," proximity=",dragon.ground_proximity," step_deg=",step_deg," cache_error_deg=",rad_to_deg(orientation.angle_to(cache[b].rotation)) if cache.has(b) else -1," phase=",phase)
		if phase.begins_with("brake_descent") and ordinary_walking and joint_history.has(b):
			maximum_walk_axis_step_deg=maxf(maximum_walk_axis_step_deg,rad_to_deg(axis.angle_to(joint_history[b].axis)))
			maximum_walk_joint_step_deg=maxf(maximum_walk_joint_step_deg,rad_to_deg(orientation.angle_to(joint_history[b].orientation))/maxi(1,last_tick-joint_history[b].tick))
		joint_history[b]={"orientation":orientation,"world_orientation":world_orientation,"axis":axis,"tick":last_tick}
		if translations.has(b): maximum_translation_change=maxf(maximum_translation_change,dragon.skeleton.get_bone_pose_position(b).distance_to(translations[b]))
	if last_tick%3!=0: return
	var skin: Array = probe.points(dragon.skeleton)
	var wing_min_x := INF
	var wing_max_x := -INF
	var feet := {}
	var trunk := Vector3.ZERO
	var trunk_count := 0
	var dense: bool = OS.get_cmdline_user_args().has("--construction-dense") and phase=="brake_descent" and dragon.ground_proximity<30.0
	var dense_vertices: Array=[[],[]]
	var dense_ids: Array=[[],[]]
	for point in skin:
		var p: Vector3 = dragon.to_local(point.position)
		if point.sample.wing:
			wing_min_x=minf(wing_min_x,p.x)
			wing_max_x=maxf(wing_max_x,p.x)
			if dense:
				for side in 2:
					if int(point.sample.wing_side_mask)&(1<<side):
						dense_vertices[side].append([p.x,p.y,p.z])
						dense_ids[side].append("%s:%d:%d" % [point.sample.mesh,point.sample.surface,point.sample.index])
		if point.sample.claw>=0:
			var key := str(point.sample.claw)
			if not feet.has(key): feet[key]={"sum_y":0.0,"count":0,"minimum_y":INF,"maximum_y":-INF,"ground_clearance_m":INF}
			feet[key].sum_y+=p.y
			feet[key].count+=1
			feet[key].minimum_y=minf(feet[key].minimum_y,p.y)
			feet[key].maximum_y=maxf(feet[key].maximum_y,p.y)
			feet[key].ground_clearance_m=minf(feet[key].ground_clearance_m,point.position.y-200.0)
		if point.sample.get("trunk",false): trunk+=p; trunk_count+=1
	var center := trunk/float(maxi(1,trunk_count))
	for foot in feet.values(): foot.center_y=foot.sum_y/float(foot.count); foot.above_torso_m=foot.center_y-center.y
	if phase.begins_with("brake_descent") and dragon.locomotion_state==dragon.LocomotionState.GROUNDED:
		for foot in feet.values(): minimum_ground_claw_clearance=minf(minimum_ground_claw_clearance,foot.ground_clearance_m)
		for limb in dragon.ground_pose.limbs:
			if limb.contact_sample.is_empty() or limb.swinging: continue
			var current: Vector3=limb.probe.point(dragon.skeleton,limb.contact_sample)
			var difference: Vector3=current-limb.contact_anchor
			difference.y=0
			if difference.length()>maximum_stance_slip and difference.length()>.015 and OS.get_cmdline_user_args().has("--leg-diagnostic"):
				var limb_root:Vector3=dragon.skeleton.to_global(dragon.skeleton.get_bone_global_pose(limb.chain[0]).origin)
				var available:=0.0
				for link_index in limb.chain.size():
					var a:Vector3=dragon.skeleton.to_global(dragon.skeleton.get_bone_global_pose(limb.chain[link_index]).origin)
					var b:Vector3=dragon.skeleton.to_global(dragon.skeleton.get_bone_global_pose(limb.chain[link_index+1] if link_index+1<limb.chain.size() else limb.end).origin)
					available+=a.distance_to(b)
				print("STANCE_REACH root=",limb_root," target_distance=",limb_root.distance_to(limb.previous_primary_target)," reach=",available," actual=",limb.actual)
				print("STANCE_WORST tick=",last_tick," end=",limb.end," slip=",difference.length()," current=",current," anchor=",limb.contact_anchor," planted=",limb.planted," finish=",limb.finish," target=",limb.get("previous_primary_target",Vector3.ZERO)," transition=",limb.get("support_transition",false)," limited=",limb.get("support_limited",false)," reposition=",limb.repositioning," step_t=",limb.step_t," blend=",dragon.ground_blend," speed=",dragon.ground_motion_speed," recovering=",dragon.wing_contact.body_pose_recovering," blocked=",dragon.wing_contact.body_pose_blocked)
			maximum_stance_slip=maxf(maximum_stance_slip,difference.length())
	rows.append({"tick":last_tick,"phase":phase,"state":dragon.locomotion_state,"proximity":dragon.ground_proximity,"ground_blend":dragon.ground_blend,"fold_blend":dragon.wing_fold_blend,"brake_blend":dragon.brake_blend,"dive_blend":dragon.dive_fold_blend,"torso_skin_center":str(center),"torso_center_array":[center.x,center.y,center.z],"torso_y":center.y,"feet":feet,"wing_width_m":wing_max_x-wing_min_x,"wing_min_x":wing_min_x,"wing_max_x":wing_max_x,"position":str(dragon.global_position),"rotation":str(dragon.rotation)})
	if dense:
		var actual_hulls: Array=[]
		for side in 2:
			var hull_points: Array=[]
			for p in dragon.wing_contact.hulls[side].points: hull_points.append([p.x,p.y,p.z])
			actual_hulls.append(hull_points)
		dense_clouds[("holdout3_dense_%d" if OS.get_cmdline_user_args().has("--holdout3") else "compact_dense_%d") % last_tick]={"wing_partition":"rig-root96-120-boundary-v1","vertices":dense_vertices,"vertex_ids":dense_ids,"hulls":actual_hulls,"physics_frame":last_tick,"process_frame":Engine.get_process_frames(),"proximity":dragon.ground_proximity,"margin":0.0 if dragon.locomotion_state==dragon.LocomotionState.GROUNDED else 1.2}
func collect_pose(label: String) -> void:
	var world_cloud: Array=[]
	var wing_cloud: Array=[[],[]]
	var wing_ids: Array=[[],[]]
	for point in all_probe.points(dragon.skeleton):
		world_cloud.append([point.position.x,point.position.y,point.position.z])
		if point.sample.wing:
			var p: Vector3=dragon.to_local(point.position)
			for side in 2:
				if int(point.sample.wing_side_mask)&(1<<side):
					wing_cloud[side].append([p.x,p.y,p.z])
					wing_ids[side].append("%s:%d:%d" % [point.sample.mesh,point.sample.surface,point.sample.index])
	var hulls: Array=[]
	for side in 2:
		var points: Array=[]
		for p in dragon.wing_contact.hulls[side].points: points.append([p.x,p.y,p.z])
		hulls.append(points)
	clouds[label]={"wing_partition":"rig-root96-120-boundary-v1","vertices":wing_cloud,"vertex_ids":wing_ids,"hulls":hulls,"world_vertices":world_cloud,"root_transform":str(dragon.global_transform),"physics_frame":Engine.get_physics_frames(),"process_frame":Engine.get_process_frames(),"last_metrics":rows.back() if not rows.is_empty() else {},"margin":0.0 if dragon.locomotion_state==dragon.LocomotionState.GROUNDED else 1.2}
func export_pose(label: String) -> void:
	if OS.get_cmdline_user_args().has("--holdout3"): label="holdout3_"+label
	elif OS.get_cmdline_user_args().has("--holdout2"): label="holdout2_"+label
	elif OS.get_cmdline_user_args().has("--holdout"): label="holdout_"+label
	pending_pose=label
	await ticks(3)
	if OS.get_cmdline_user_args().has("--capture"):
		var captures:=[]
		for view in ["side","front"]:
			var local_center: Array=rows.back().torso_center_array
			var target:=dragon.to_global(Vector3(local_center[0],local_center[1],local_center[2]))
			camera.global_position=target+Basis(Vector3.UP,dragon.rotation.y)*(Vector3(-35,8,8) if view=="side" else Vector3(0,7,-35))
			camera.look_at(target)
			await process_frame
			await RenderingServer.frame_post_draw
			var path: String="res://docs/validation/v2/anatomy-descent-compact-"+label+"-"+view+".png"
			root.get_texture().get_image().save_png(path)
			captures.append({"view":view,"path":path,"target":str(target),"target_pixel":str(camera.unproject_position(target)),"viewport":str(root.size)})
		clouds[label].captures=captures

func run() -> void:
	var source: Node3D=load("res://scenes/main.tscn").instantiate()
	dragon=source.get_node("Dragon")
	source.remove_child(dragon)
	dragon.owner=null
	scene=Node3D.new()
	for name in ["WorldEnvironment","DirectionalLight3D"]:
		var node=source.get_node(name); source.remove_child(node); node.owner=null; scene.add_child(node)
	source.free()
	scene.add_child(dragon)
	root.add_child(scene)
	dragon.landscape=scene
	var floor=StaticBody3D.new()
	floor.collision_layer=1
	var shape=CollisionShape3D.new()
	var box=BoxShape3D.new(); box.size=Vector3(1000,1,1000); shape.shape=box
	floor.add_child(shape); floor.position=Vector3(0,199.5,0); scene.add_child(floor)
	var mesh=MeshInstance3D.new(); var visual=BoxMesh.new(); visual.size=box.size; mesh.mesh=visual; floor.add_child(mesh)
	camera=Camera3D.new(); scene.add_child(camera); camera.current=true
	root.size=Vector2i(1280,720)
	await ticks(150)
	dragon.has_taken_off=true
	dragon.manual_input_override=true
	all_probe.configure(dragon,dragon.skeleton,1)
	probe.configure(dragon,dragon.skeleton,1)
	for sample in probe.samples:
		var trunk:=false
		for influence in sample.influence:
			if influence.bone in dragon.bone_spine_indices and influence.weight>.65: trunk=true
		sample.trunk=trunk and not sample.wing and sample.claw<0 and not sample.neck
	probe.samples=probe.samples.filter(func(sample):return sample.wing or sample.claw>=0 or sample.trunk)
	for child in dragon.skeleton.get_children():
		if child is SkeletonModifier3D: modifier=child
	dragon.anim_player.mixer_applied.connect(capture_authored_translations)
	modifier.modification_processed.connect(measure)
	for mode in ["brake_descent","dive"]:
		phase=""
		joint_history.clear()
		dragon.global_position=Vector3(0,280,100)
		dragon.rotation=Vector3.ZERO
		dragon.target_yaw=0; dragon.target_pitch=0; dragon.target_roll=0
		dragon.velocity=Vector3(0,0,-26); dragon.current_speed=26
		dragon.locomotion_state=dragon.LocomotionState.FLYING
		dragon.ground_blend=0; dragon.wing_fold_blend=0
		dragon.ground_pose.reset()
		dragon.manual_dive=false; dragon.manual_brake=false
		dragon.is_diving=false
		await ticks(211 if OS.get_cmdline_user_args().has("--holdout3") else (173 if OS.get_cmdline_user_args().has("--holdout2") else (137 if OS.get_cmdline_user_args().has("--holdout") else 90)))
		phase=mode
		if mode=="brake_descent": dragon.trigger_landing()
		else: dragon.manual_dive=true
		await ticks(83 if OS.get_cmdline_user_args().has("--holdout3") else (61 if OS.get_cmdline_user_args().has("--holdout2") else (73 if OS.get_cmdline_user_args().has("--holdout") else 90)))
		await export_pose(mode+"_90")
		await ticks(137 if OS.get_cmdline_user_args().has("--holdout3") else (127 if OS.get_cmdline_user_args().has("--holdout2") else (113 if OS.get_cmdline_user_args().has("--holdout") else 90)))
		await export_pose(mode+"_180")
		if mode=="brake_descent":
			var ground_frames:=0
			var exported: Dictionary={}
			for i in 1200:
				await ticks(1)
				for proximity in [24,12,6]:
					if dragon.ground_proximity<float(proximity) and not exported.has(proximity):
						exported[proximity]=true
						if proximity==12 and OS.get_cmdline_user_args().has("--holdout3"):
							dragon.manual_input_override=false
							key(KEY_W,true)
						await export_pose("brake_approach_%d" % proximity)
				if dragon.locomotion_state==dragon.LocomotionState.GROUNDED:
					ground_frames+=1
					if ground_frames>=30: break
			await export_pose("brake_touchdown")
			check(ground_frames>=30,"Continuous brake descent reaches stable ground without fixture repositioning")
			var whole: Array=rows.filter(func(row):return row.phase==mode)
			var first_tick: int=whole[0].tick
			var whole_worst:=-INF
			var last_raised_tick:=first_tick
			var raised_samples:=0
			for row in whole:
				var raised:=false
				for foot in row.feet.values():
					whole_worst=maxf(whole_worst,foot.above_torso_m)
					if foot.above_torso_m>0: raised=true
				if raised: raised_samples+=1;last_raised_tick=row.tick
			print("WHOLE_DESCENT frames=",whole.size()," worst_foot_above_torso_m=",whole_worst," raised_samples=",raised_samples," last_raised_elapsed_s=",float(last_raised_tick-first_tick)/Engine.physics_ticks_per_second," final_proximity=",dragon.ground_proximity)
		if mode=="brake_descent":
			key(KEY_W,false)
			dragon.manual_input_override=false
			phase="brake_descent_idle"
			await ticks(120)
			for command in [KEY_W,KEY_S]:
				phase="brake_descent_first_"+str(command)
				var start_position:=dragon.global_position
				key(command,true)
				await ticks(90)
				await export_pose("first_walk" if command==KEY_W else "first_reverse")
				if command==KEY_W:
					var points: Array=probe.points(dragon.skeleton)
					for limb in dragon.ground_pose.limbs:
						var selected: Dictionary={}
						for point in points:
							if point.sample.claw==limb.end and (selected.is_empty() or point.position.y<selected.position.y): selected=point
						stride_feet[limb.end]={"sample":selected.sample,"seeded":false,"position":selected.position,"tick":0,"travel":0.0,"min_speed":INF,"max_speed":0.0,"swing":limb.swinging,"events":[]}
					stride_tick=Engine.get_physics_frames()
					stride_root=dragon.global_position
					stride_active=true
					await ticks(480)
					stride_active=false
					for end in stride_feet:
						var foot: Dictionary=stride_feet[end]
						var passed: bool=foot.events.size()>=4
						for event in foot.events:
							passed=passed and event.stride_m>=2 and absf(event.speed_mps-7.5)<=.05 and event.minimum_speed_mps>=7.45 and event.maximum_speed_mps<=7.55
						print("POST_LANDING_PER_FOOT end=",end," events=",JSON.stringify(foot.events))
						check(passed,"Post landing >=4complete strides >=2m at actual7.5m/s for "+str(end))
				key(command,false)
				var distance:=Vector2(dragon.global_position.x-start_position.x,dragon.global_position.z-start_position.z).length()
				print("FIRST_GROUND_STEP key=",command," distance_m=",distance)
				check(distance>1.0,"First real ground input moves after touchdown: "+str(command))
				await ticks(30)
			dragon.manual_input_override=true
		var observed: Array=rows.filter(func(row):return row.phase==mode and row.brake_blend>.95 if mode=="brake_descent" else row.phase==mode and row.dive_blend>.95)
		var worst := -INF
		for row in observed:
			for foot in row.feet.values(): worst=maxf(worst,foot.above_torso_m)
		print("DESCENT_FEET ",mode," frames=",observed.size()," worst_foot_above_torso_m=",worst)
		check(not observed.is_empty() and worst<=-.25,"All actual claw centers remain below torso when "+mode+" is established")
	phase="ground_compact"
	dragon.manual_dive=false; dragon.is_diving=false
	dragon.global_position=Vector3(0,203.5,100)
	dragon.rotation=Vector3.ZERO
	dragon.target_yaw=0; dragon.target_pitch=0; dragon.target_roll=0
	dragon.velocity=Vector3.ZERO; dragon.current_speed=0
	dragon.locomotion_state=dragon.LocomotionState.GROUNDED
	dragon.ground_pose.reset()
	await ticks(180)
	await export_pose("ground_compact")
	var grounded: Array=rows.filter(func(row):return row.phase=="ground_compact" and row.ground_blend>.99 and row.fold_blend>.99)
	var width:=0.0
	for row in grounded: width=maxf(width,row.wing_width_m)
	print("COMPACT_WING all_original5412 width_m=",width)
	check(not grounded.is_empty() and width<=8.0,"Grounded original membrane width<=8m (provisional corridor target, pending measured aperture)")
	print("REAR_RELEASE ",JSON.stringify(rear_release_observations))
	print("REAR_JOINT_CONTINUITY max_deg_per_tick=",maximum_joint_step_deg," world_deg_per_tick=",maximum_world_joint_step_deg," pose_translation_change_m=",maximum_translation_change," ordinary_first_walk_max_deg=",maximum_walk_joint_step_deg," ordinary_walk_axis_max_deg=",maximum_walk_axis_step_deg)
	check(maximum_joint_step_deg<=5.0,"Rear link orientations remain continuous<=5deg per tick")
	check(maximum_world_joint_step_deg<=5.0,"Rear link world orientations remain continuous<=5deg per tick")
	check(maximum_translation_change<.000001,"Rear bone pose translations remain original")
	print("TOUCHDOWN_CONTACT full_original2430_claw_min_m=",minimum_ground_claw_clearance," original_stance_slip_m=",maximum_stance_slip)
	check(minimum_ground_claw_clearance>=-.05,"Ground transition original claw skin does not penetrate floor>5cm")
	check(maximum_stance_slip<=.015,"Ground transition original planted claw stays within15mm anchor")
	print("WALK_TARGET_CONTINUITY max_primary_step_m=",maximum_walk_target_step," published_link_change_m=",maximum_length_error_m)
	check(maximum_walk_target_step<=.85,"First W/S target trajectory step<=.85m including start/completion (old2.7m fails)")
	check(maximum_length_error_m<=.0001,"Published original rear link length change<=0.1mm (world float precision)")
	var tag: String="red" if OS.get_cmdline_user_args().has("--baseline") else ("holdout3" if OS.get_cmdline_user_args().has("--holdout3") else ("holdout2" if OS.get_cmdline_user_args().has("--holdout2") else ("holdout" if OS.get_cmdline_user_args().has("--holdout") else "candidate")))
	FileAccess.open("res://docs/validation/v2/anatomy-descent-compact-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify({"diagnostic":true,"vertices":all_probe.samples.size(),"rows":rows,"maximum_joint_step_deg":maximum_joint_step_deg,"maximum_world_joint_step_deg":maximum_world_joint_step_deg,"ordinary_first_walk_joint_step_deg":maximum_walk_joint_step_deg,"ordinary_first_walk_axis_step_deg":maximum_walk_axis_step_deg,"maximum_translation_change":maximum_translation_change,"minimum_ground_claw_clearance_m":minimum_ground_claw_clearance,"maximum_stance_slip_m":maximum_stance_slip,"maximum_walk_target_step_m":maximum_walk_target_step,"maximum_length_error_m":maximum_length_error_m,"post_landing_stride":stride_feet,"rear_release_observations":rear_release_observations,"failures":failures},"  "))
	FileAccess.open("res://docs/validation/v2/anatomy-descent-compact-"+tag+"-poses.json",FileAccess.WRITE).store_string(JSON.stringify(clouds))
	if OS.get_cmdline_user_args().has("--construction-dense"):
		FileAccess.open("/tmp/dragon-anatomy-compact-dense.json",FileAccess.WRITE).store_string(JSON.stringify(dense_clouds))
		print("DENSE_CONSTRUCTION wing_only_poses=",dense_clouds.size()," wing_originals_per_pose=5412 temporary_raw=/tmp/dragon-anatomy-compact-dense.json")
	quit(0 if failures.is_empty() else 1)
