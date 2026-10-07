extends RefCounted
# World-space planted feet; FABRIK preserves lengths and the published rear articulation branch.
const Probe = preload("res://scripts/dragon_pose_probe.gd")
const Biomechanics = preload("res://scripts/dragon_biomechanics.gd")
const NOMINAL_SWING_DURATION: float = 0.36
var claw_probe = Probe.new()
var limbs: Array[Dictionary] = []
var debug_contacts: Array[Vector3] = []
var debug_errors: Array[float] = []
var pose_blend := 1.0
var prepared_skeleton_id := 0
var prepared_probes: Dictionary = {}
var preparation_count := 0
var planning_frame := -1
var planned_move_direction := 0

func reset() -> void:
	planning_frame=-1
	planned_move_direction=0
	limbs.clear()
	debug_contacts.clear()
	debug_errors.clear()

# Metadata can be warmed before briefing. Contacts/orientation stay initialized
# by apply on its actual first pose; reset retains this same-skeleton cache.
func prepare(dragon: Node3D, sk: Skeleton3D) -> void:
	if prepared_skeleton_id == sk.get_instance_id() and not prepared_probes.is_empty(): return
	limbs.clear()
	prepared_probes.clear()
	claw_probe.configure(dragon,sk,1)
	claw_probe.samples = claw_probe.samples.filter(func(sample): return int(sample.limb_claw)>=0)
	for end in [8,82,23,41]:
		var foot := Probe.new()
		foot.samples = claw_probe.samples.filter(func(sample): return int(sample.limb_claw)==end)
		foot.profile_label = "claw_%d" % end
		# All original foot vertices: terrain height is not affine across cells.
		foot.prepare_coordinates()
		prepared_probes[end] = foot
	prepared_skeleton_id = sk.get_instance_id()
	preparation_count += 1

func _configure(sk: Skeleton3D) -> void:
	var specs := [
		[[5, 6, 7], 8, Vector3(-1.45, 0.0, 1.65), 0.0],
		[[80, 81], 82, Vector3(1.35, 0.0, -2.55), 0.75],
		[[20, 21, 22], 23, Vector3(1.45, 0.0, 1.65), 0.5],
		[[39, 40], 41, Vector3(-1.35, 0.0, -2.55), 0.25],
	]
	for spec in specs:
		limbs.append({"chain": spec[0], "end": spec[1], "home": spec[2], "phase": spec[3], "planted": Vector3.ZERO, "start": Vector3.ZERO, "finish": Vector3.ZERO, "swinging": false, "initialized": false, "foot_basis": Basis.IDENTITY, "repositioning": false, "step_t": 0.0, "actual": Vector3.ZERO, "clearance": 1.4, "probe": prepared_probes[spec[1]], "contact_sample": {}, "contact_anchor": Vector3.ZERO})

func apply(dragon: Node3D, sk: Skeleton3D, recovery: bool = false) -> void:
	pose_blend = dragon.ground_blend
	if dragon.locomotion_state == dragon.LocomotionState.LANDING:
		pose_blend = maxf(pose_blend,1.0-smoothstep(5.0,12.0,dragon.ground_proximity))
	elif dragon.locomotion_state == dragon.LocomotionState.GROUNDED:
		pose_blend = 1.0
	prepare(dragon,sk)
	if limbs.is_empty(): _configure(sk)
	debug_contacts.clear()
	debug_errors.clear()
	# The same terrain transform is used for every original claw vertex in
	# this synchronous solve. Compute its inverse once, retaining exact cells.
	var use_landscape:bool=is_instance_valid(dragon.landscape) and dragon.landscape.has_method("ground_height")
	var landscape_transform:Transform3D=dragon.landscape.global_transform if use_landscape else Transform3D.IDENTITY
	var landscape_inverse:Transform3D=landscape_transform.affine_inverse()
	var requested_step: bool = absf(dragon.manual_move_input)>0.01 or absf(dragon.manual_turn_input)>0.01 if dragon.manual_input_override else (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_D) or (not dragon.head_aim_active and (Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_RIGHT))))
	var requested_move:float=dragon.manual_move_input if dragon.manual_input_override else float(Input.is_key_pressed(KEY_W) or (Input.is_key_pressed(KEY_UP) and not dragon.head_aim_active))-float(Input.is_key_pressed(KEY_S) or (Input.is_key_pressed(KEY_DOWN) and not dragon.head_aim_active))
	requested_step=requested_step or absf(dragon.ground_yaw_motion)>.0001
	requested_step=requested_step or (dragon.attack_mode_active and absf(wrapf(dragon.target_yaw-dragon.rotation.y,-PI,PI))>.001)
	var moving: bool = (requested_step or absf(dragon.ground_motion_speed) > 0.12 or absf(dragon.smoothed_turn_rate) > 0.03) and dragon.locomotion_state == dragon.LocomotionState.GROUNDED
	var heading := Basis(Vector3.UP, dragon.rotation.y)
	var move_sign:=signf(dragon.ground_motion_speed) if absf(dragon.ground_motion_speed)>.12 else signf(requested_move)
	var forward := -heading.z * move_sign
	# A previous idle correction must not count as the first requested walking
	# cycle. Queue every foot once at translation start/reversal, before solves.
	if not recovery and planning_frame!=Engine.get_physics_frames():
		planning_frame=Engine.get_physics_frames()
		var move_direction:=int(move_sign) if requested_step and dragon.locomotion_state==dragon.LocomotionState.GROUNDED else 0
		if move_direction!=0 and move_direction!=planned_move_direction:
			for pending in limbs:
				pending.last_swing_cycle=int(floor(dragon.walk_cycle_phase/TAU+float(pending.phase)))-1
				pending.startup_pending=true
				# Finish the foot already lifted by a pivot when translation starts
				# or reverses. Its old slow turn clock must not depend on body
				# travel that the same unfinished support step is preventing.
				if pending.swinging and not pending.repositioning and not bool(pending.get("support_pending",false)):
					pending.startup_step=true
					pending.startup_pending=false
		planned_move_direction=move_direction
	# Advance/complete every primary clock before choosing a support owner.
	# Completing the last array entry must not delay the first one a frame.
	var plan_frame:=Engine.get_physics_frames()
	if not recovery:
		for candidate in limbs:
			if bool(candidate.get("support_pending",false)): continue
			var cycle:float=dragon.walk_cycle_phase/TAU+float(candidate.phase)
			if int(candidate.get("swing_clock_frame",-1))!=plan_frame:
				var elapsed_s:=float(maxi(1,plan_frame-int(candidate.get("swing_clock_frame",plan_frame-1))))/Engine.physics_ticks_per_second
				var advance:=maxf(0,cycle-float(candidate.get("swing_clock_cycle",cycle)))
				# A planted-support limit may stop body travel while the lifted foot
				# is still moving. Keep its nominal clock independent of that stop;
				# recycling the last tiny body rate can make a step take20seconds.
				if candidate.swinging and not candidate.repositioning:
					advance=maxf(advance,dragon.walk_speed/3.5*elapsed_s)
				if candidate.swinging and not candidate.repositioning:
					advance/=float(candidate.get("startup_distance_scale",1.0))
				if advance>0: candidate.swing_clock_rate=advance/elapsed_s
				if candidate.swinging and not candidate.repositioning:
					candidate.swing_elapsed=float(candidate.get("swing_elapsed",0))+(advance if advance>0 else float(candidate.get("swing_clock_rate",0))*elapsed_s)
				candidate.swing_clock_frame=plan_frame
				candidate.swing_clock_cycle=cycle
			if candidate.swinging and not candidate.repositioning and float(candidate.get("swing_elapsed",0))>=NOMINAL_SWING_DURATION and not bool(candidate.get("support_limited",false)):
				candidate.swinging=false
				candidate.planted=candidate.finish
				candidate.swing_elapsed=0.0
			if candidate.repositioning:
				if int(candidate.get("reposition_frame",-1))!=plan_frame:
					candidate.step_t=minf(1,candidate.step_t+float(maxi(1,plan_frame-int(candidate.get("reposition_frame",plan_frame-1))))/Engine.physics_ticks_per_second/.18)
					candidate.reposition_frame=plan_frame
				if candidate.step_t>=1:
					candidate.planted=candidate.finish
					candidate.repositioning=false
					candidate.swinging=false
					candidate.last_swing_cycle=int(floor(cycle))
					candidate.swing_elapsed=0.0
	var sequential_support: bool = dragon.locomotion_state==dragon.LocomotionState.GROUNDED
	var grounded_step_ready: bool = sequential_support and dragon.ground_blend>.99
	var swing_owner := -1
	for candidate in limbs:
		if candidate.swinging or candidate.repositioning:
			swing_owner=int(candidate.end)
			break
	var planned_start := -1
	var oldest_start := 2147483647
	var most_extended := -INF
	var blocking_support := false
	if not recovery and swing_owner<0 and moving and grounded_step_ready:
		for candidate in limbs:
			var cycle:float=dragon.walk_cycle_phase/TAU+float(candidate.phase)
			var started:int=int(candidate.get("last_swing_started_frame",-1))
			var extension:float=-INF
			var blocks_motion := false
			if requested_step and candidate.has("published_hip_actor"):
				var hip:Vector3=dragon.to_global(candidate.published_hip_actor)
				extension=hip.distance_to(candidate.published_wrist)-(float(candidate.published_reach)-.14)
				# Release the leg opposing the requested translation first. A more
				# extended leg on the other side may shorten naturally during retreat.
				blocks_motion=extension>=0 and (hip-(candidate.published_wrist as Vector3)).dot(forward)>0
			# Release the support currently stopping the body before taking an
			# ordinary queued step. Three other feet remain planted throughout.
			if extension>=0 and ((blocks_motion and not blocking_support) or (blocks_motion==blocking_support and extension>most_extended)):
				planned_start=int(candidate.end)
				most_extended=extension
				blocking_support=blocks_motion
			elif most_extended<0 and int(candidate.get("last_swing_cycle",-999))!=int(floor(cycle)) and started<oldest_start:
				planned_start=int(candidate.end)
				oldest_start=started
	for limb in limbs:
		# Continue rear support from its published articulated branch. Starting each
		# FABRIK solve from the next imported flight frame can invert the hock when
		# LANDING becomes GROUNDED, despite an unchanged ankle target.
		var rear: bool = int(limb.end) in [8,23]
		var previous_support_limited:bool=bool(limb.get("support_limited",false))
		limb.actor_basis=dragon.global_basis
		if rear and dragon.locomotion_state == dragon.LocomotionState.LANDING:
			limb.support_transition=true
		if rear:
			if int(limb.get("support_frame",-1))!=Engine.get_physics_frames():
				limb.support_frame=Engine.get_physics_frames()
				var anchors := {}
				for b in limb.chain:
					anchors[b]=limb.support_rotations[b] if limb.has("support_rotations") else (dragon.global_basis.inverse()*sk.global_basis*sk.get_bone_global_pose(b).basis).get_rotation_quaternion()
				limb.support_anchors=anchors
				limb.support_body_basis=dragon.global_basis
				limb.support_limited=false
		var home: Vector3 = dragon.global_position + heading * limb.home
		var hit := _ray(dragon, home)
		if hit.is_empty():
			continue
		# Wrist/ankle joints sit above the toe/claw tips in this asset.
		var clearance: float = limb.clearance
		home.y = hit.position.y + clearance
		var phase := fposmod(dragon.walk_cycle_phase / TAU + float(limb.phase), 1.0)
		if recovery and limb.has("recovery_phase"): phase = limb.recovery_phase
		var raw_cycle: float=dragon.walk_cycle_phase/TAU+float(limb.phase)
		var frame:=Engine.get_physics_frames()
		var swing_t:=clampf(float(limb.get("swing_elapsed",0))/NOMINAL_SWING_DURATION,0,1)
		var continuing_swing: bool=limb.swinging and not bool(limb.get("support_pending",false)) and not limb.repositioning and (swing_t<1 or previous_support_limited)
		var swing_now: bool=continuing_swing or (not recovery and int(limb.end)==planned_start)
		if not limb.initialized:
			if rear:
				var origin: Vector3 = sk.get_bone_global_pose(limb.chain[0]).origin
				var end_origin: Vector3 = sk.get_bone_global_pose(limb.end).origin
				var axis: Vector3 = (end_origin-origin).normalized()
				var knee: Vector3 = sk.get_bone_global_pose(limb.chain[1]).origin-origin
				var branch: Vector3 = (knee-axis*knee.dot(axis)).normalized()
				if not branch.is_zero_approx(): limb.pole_world=(sk.global_basis*branch).normalized()
			limb.planted = home
			limb.start = home
			limb.finish = home
			var foot_world := sk.global_basis * sk.get_bone_global_pose(limb.end).basis
			var digit_sum := Vector3.ZERO
			var digit_count := 0
			for digit in sk.get_bone_count():
				if sk.get_bone_parent(digit) == int(limb.end):
					digit_sum += sk.to_global(sk.get_bone_global_pose(digit).origin)
					digit_count += 1
			var toe_direction := (digit_sum / maxf(1, digit_count) - sk.to_global(sk.get_bone_global_pose(limb.end).origin)).normalized()
			var wanted_toes := (heading * Vector3(0,-0.15,-1)).normalized()
			limb.foot_basis = Basis(Quaternion(toe_direction, wanted_toes)) * foot_world
			limb.foot_yaw = dragon.rotation.y
			limb.actual = home
			limb.initialized = true
		if swing_now and not limb.swinging:
			swing_owner=int(limb.end)
			limb.last_swing_started_frame=frame
			limb.startup_step=bool(limb.get("startup_pending",false))
			limb.startup_pending=false
			limb.swing_elapsed=0.0
			swing_t=0.0
			limb.last_swing_cycle=int(floor(raw_cycle))
			limb.start = limb.planted
			limb.finish = home + forward * 1.32
			var finish_hit := _ray(dragon, limb.finish)
			if finish_hit:
				limb.finish.y = finish_hit.position.y + clearance
			# Every normal reach has the same foot speed as the nominal 3.5 m step.
			limb.startup_distance_scale=maxf(1.0,(limb.finish as Vector3).distance_to(limb.start)/3.5)
		var target: Vector3 = limb.planted
		var support_near_extension:=false
		if requested_step and limb.has("published_hip_actor"):
			var hip:Vector3=dragon.to_global(limb.published_hip_actor)
			support_near_extension=hip.distance_to(limb.published_wrist)>=float(limb.published_reach)-.14
		# A planted foot must lift before a pivot stretches the leg beyond its support.
		if not recovery and (not sequential_support or (grounded_step_ready and swing_owner<0)) and planned_start<0 and not swing_now and not limb.repositioning and ((limb.planted as Vector3).distance_to(home) > 2.3 or support_near_extension):
			swing_owner=int(limb.end)
			limb.last_swing_started_frame=frame
			limb.repositioning = true
			limb.step_t = 0.0
			limb.reposition_frame=frame
			limb.start = limb.actual
			limb.finish = home + forward * 0.45
			var corrective_hit := _ray(dragon, limb.finish)
			if corrective_hit:
				limb.finish.y = corrective_hit.position.y + clearance
		if limb.repositioning:
			var t: float = limb.step_t
			swing_t=t
			target = (limb.start as Vector3).lerp(limb.finish, t * t * (3.0 - 2.0 * t))
			target.y += sin(pow(t, 0.85) * PI) * 0.42
			swing_now = true
		elif swing_now:
			var t := swing_t
			var smooth_t := t * t * (3.0 - 2.0 * t)
			target = (limb.start as Vector3).lerp(limb.finish, smooth_t)
			target.y += sin(pow(t, 0.85) * PI) * (0.65 if rear else 0.55)
			limb.planted = limb.finish
		elif not moving and (limb.planted as Vector3).distance_to(home) > 1.8:
			# Reposition when turning in place; avoid stretching limbs through the body.
			limb.planted = (limb.planted as Vector3).lerp(home, 0.0 if recovery else 0.12)
			target = limb.planted
		if swing_now and not recovery:
			var yaw_step := clampf(wrapf(dragon.rotation.y-float(limb.get("foot_yaw",dragon.rotation.y)),-PI,PI),-deg_to_rad(4),deg_to_rad(4))
			limb.foot_basis = Basis(Vector3.UP,yaw_step)*limb.foot_basis
			limb.foot_yaw = float(limb.get("foot_yaw",dragon.rotation.y))+yaw_step
		limb.swinging = swing_now
		# Limit the first lifted step, including a corrective reposition. A
		# planted foot outside touchdown must solve its world anchor exactly.
		limb.limit_stationary_motion=rear and requested_step and dragon.locomotion_state==dragon.LocomotionState.GROUNDED and absf(dragon.ground_motion_speed)<.12 and swing_now
		if recovery and limb.has("recovery_target"): target = limb.recovery_target
		if int(limb.get("primary_frame",-1))!=frame:
			var target_jump: float=target.distance_to(limb.get("previous_primary_target",target))
			limb.primary_step_world=target_jump
			if OS.get_cmdline_user_args().has("--leg-diagnostic") and target_jump>.5: print("PRIMARY_JUMP frame=",frame," end=",limb.end," jump=",target_jump," phase=",phase," swing_t=",swing_t," swing=",swing_now," was=",limb.swinging," reposition=",limb.repositioning," startup=",limb.get("startup_step",false)," scale=",limb.get("startup_distance_scale",1.0)," target=",target," previous=",limb.get("previous_primary_target",target)," start=",limb.start," finish=",limb.finish," planted=",limb.planted)
			limb.primary_frame=frame
			limb.previous_primary_target=target
		var actual := sk.to_global(sk.get_bone_global_pose(limb.end).origin)
		var blend_target := actual.lerp(target, pose_blend)
		_solve_limb(sk, limb.chain, limb.end, sk.to_local(blend_target),limb)
		# Preserve authored foot orientation rather than inheriting every knee rotation.
		var end_pose := sk.get_bone_global_pose(limb.end)
		var desired_basis: Basis = sk.global_basis.inverse() * limb.foot_basis
		var parent := sk.get_bone_parent(limb.end)
		var parent_basis := sk.get_bone_global_pose(parent).basis.orthonormalized()
		var local_basis := parent_basis.inverse() * desired_basis.orthonormalized()
		sk.set_bone_pose_rotation(limb.end, sk.get_bone_pose_rotation(limb.end).slerp(local_basis.get_rotation_quaternion(), pose_blend))
		# Calibrate from the actual claw skin after orientation, then solve its surface contact.
		# An ankle target may be exact while the visible toes still float or penetrate.
		# Reuse a measured clearance only while this limb's exact FK stays
		# unchanged within this synchronous solve; every solve invalidates it.
		var clearance_valid:bool=false
		var measured_clearance:float=INF
		if pose_blend > 0.01:
			for correction_pass in 3:
				var lowest := INF
				for point in limb.probe.coordinates(sk):
					# The support ray supplies the collider triangle's plane; skin contacts use it directly.
					# Independent validation still raycasts each claw vertex against the real collider.
					var plane_clearance: float = (point - hit.position).dot(hit.normal) / maxf(hit.normal.y,0.1)
					if use_landscape:
						# The landscape exposes the exact same piecewise triangles as its collider.
						# A single support plane misses a cell boundary under a mixed foot/hock vertex.
						var local: Vector3 = landscape_inverse*point
						var surface: Vector3 = (landscape_transform*Vector3(local.x,dragon.landscape.ground_height(local.x,local.z),local.z))
						plane_clearance = point.y-surface.y
					lowest = minf(lowest,plane_clearance)
				if OS.get_cmdline_user_args().has("--claw-diagnostic") and lowest<-.1:
					print("CLAW_SOLVE frame=",Engine.get_physics_frames()," end=",limb.end," blend=",dragon.ground_blend," pass=",correction_pass," lowest=",lowest," target=",target," actual=",sk.to_global(sk.get_bone_global_pose(limb.end).origin)," clearance=",limb.clearance," recovery=",recovery)
				measured_clearance=lowest
				clearance_valid=true
				if is_inf(lowest): break
				var wanted_clearance := 0.025 + float(limb.get("terrain_hull_clearance",0.0)) + (sin(pow(swing_t, 0.85) * PI) * (0.42 if limb.repositioning else (0.65 if rear else 0.55)) if swing_now else 0.0)
				var correction := wanted_clearance - lowest
				if dragon.locomotion_state == dragon.LocomotionState.LANDING: correction = maxf(0.0,correction)
				if absf(correction) < 0.006: break
				# Stance correction moves vertically; the planted horizontal contact remains locked.
				var previous_target_y := target.y
				target.y = sk.to_global(sk.get_bone_global_pose(limb.end).origin).y+correction
				var target_change := target.y-previous_target_y
				limb.clearance += target_change
				limb.planted.y += target_change
				limb.finish.y += target_change
				limb.start.y += target_change
				clearance_valid=false
				_solve_limb(sk, limb.chain, limb.end, sk.to_local(target),limb)
				parent_basis = sk.get_bone_global_pose(parent).basis.orthonormalized()
				local_basis = parent_basis.inverse() * desired_basis.orthonormalized()
				sk.set_bone_pose_rotation(limb.end, local_basis.get_rotation_quaternion())
		var support_pending:=false
		if rear and not swing_now and bool(limb.get("support_transition",false)):
			var contact_clearance:float=measured_clearance
			if not clearance_valid:
				contact_clearance=INF
				for point in limb.probe.coordinates(sk):
					var below:float=(point-hit.position).dot(hit.normal)/maxf(hit.normal.y,.1)
					if use_landscape:
						var lp:Vector3=landscape_inverse*point
						below=point.y-(landscape_transform*Vector3(lp.x,dragon.landscape.ground_height(lp.x,lp.z),lp.z)).y
					contact_clearance=minf(contact_clearance,below)
				measured_clearance=contact_clearance
				clearance_valid=true
			support_pending=contact_clearance>.031+float(limb.get("terrain_hull_clearance",0.0))
		limb.support_pending=support_pending
		limb.swinging=swing_now or support_pending
		if swing_now or support_pending:
			limb.contact_sample = {}
		elif dragon.ground_blend > 0.99:
			for anchor_pass in 3:
				var contact_points: Array = limb.probe.points(sk) if limb.contact_sample.is_empty() else [{"position":limb.probe.point(sk,limb.contact_sample),"sample":limb.contact_sample}]
				if limb.contact_sample.is_empty():
					var lowest_point: Dictionary = {}
					for point in contact_points:
						if lowest_point.is_empty() or point.position.y < lowest_point.position.y: lowest_point = point
					if not lowest_point.is_empty():
						limb.contact_sample = lowest_point.sample
						limb.contact_anchor = lowest_point.position
				for point in contact_points:
					if int(point.sample.index) != int(limb.contact_sample.get("index",-1)) or point.sample.mesh != limb.contact_sample.get("mesh",""): continue
					var offset: Vector3 = limb.contact_anchor - point.position
					# Reconstruct the wrist goal from the achieved pose. Integrating
					# an unreachable residual into last frame's goal creates windup
					# and an arbitrarily long next step after a body pivot. Preserve
					# the complete contact: a stale unreachable y also moves x/z
					# when a fully extended leg becomes reachable on a slope.
					var wrist:Vector3=sk.to_global(sk.get_bone_global_pose(limb.end).origin)
					var anchor_y_change:float=wrist.y+offset.y-target.y
					target=wrist+offset
					limb.planted=target
					limb.clearance+=anchor_y_change
					limb.start.y+=anchor_y_change
					limb.finish.y+=anchor_y_change
					if offset.length() < 0.002: break
					clearance_valid=false
					_solve_limb(sk, limb.chain, limb.end, sk.to_local(target),limb)
					parent_basis = sk.get_bone_global_pose(parent).basis.orthonormalized()
					local_basis = parent_basis.inverse() * desired_basis.orthonormalized()
					sk.set_bone_pose_rotation(limb.end,local_basis.get_rotation_quaternion())
					break
		if pose_blend>.01:
			for final_pass in 3:
				var minimum:float=measured_clearance
				if not clearance_valid:
					minimum=INF
					for point in limb.probe.coordinates(sk):
						var below: float = (point-hit.position).dot(hit.normal)/maxf(hit.normal.y,.1)
						if use_landscape:
							var lp: Vector3 = landscape_inverse*point
							below = point.y-(landscape_transform*Vector3(lp.x,dragon.landscape.ground_height(lp.x,lp.z),lp.z)).y
						minimum = minf(minimum,below)
					measured_clearance=minimum
					clearance_valid=true
				var terrain_clearance := .025+float(limb.get("terrain_hull_clearance",0.0))
				if minimum>=terrain_clearance-.006: break
				var correction := terrain_clearance-minimum
				var previous_target_y:=target.y
				target.y = sk.to_global(sk.get_bone_global_pose(limb.end).origin).y+correction
				var target_change:=target.y-previous_target_y
				limb.planted.y += target_change
				limb.finish.y += target_change
				limb.start.y += target_change
				limb.clearance += target_change
				clearance_valid=false
				_solve_limb(sk,limb.chain,limb.end,sk.to_local(target),limb)
				parent_basis = sk.get_bone_global_pose(parent).basis.orthonormalized()
				local_basis = parent_basis.inverse()*desired_basis.orthonormalized()
				sk.set_bone_pose_rotation(limb.end,local_basis.get_rotation_quaternion())
		if OS.get_cmdline_user_args().has("--claw-diagnostic"):
			var final_low := INF
			for point in limb.probe.coordinates(sk):
				var lp: Vector3 = landscape_inverse*point
				final_low = minf(final_low,lp.y-dragon.landscape.ground_height(lp.x,lp.z))
			if final_low<-.05: print("CLAW_FINAL frame=",Engine.get_physics_frames()," end=",limb.end," poseblend=",pose_blend," min=",final_low," target=",target," recovery=",recovery)
		limb.actual = sk.to_global(sk.get_bone_global_pose(limb.end).origin)
		if rear:
			var rotations := {}
			for b in limb.chain:
				rotations[b]=(dragon.global_basis.inverse()*sk.global_basis*sk.get_bone_global_pose(b).basis).get_rotation_quaternion()
			limb.support_rotations=rotations
			# A converged solve does not end touchdown: the stabilizer still moves
			# on subsequent idle frames. Keep the published stance budget until
			# this limb actually lifts into its first walking swing.
			if not recovery and not dragon.wing_contact.body_pose_recovering and dragon.locomotion_state == dragon.LocomotionState.GROUNDED and dragon.ground_blend>.99 and swing_now and requested_step and not bool(limb.get("support_limited",false)):
				limb.support_transition=false
		debug_contacts.append(target)
		debug_errors.append(sk.to_global(sk.get_bone_global_pose(limb.end).origin).distance_to(target))

# Rotation moves each hip too. A planted wrist must remain reachable while
# the next foot lifts; translation limits alone cannot protect a stationary pivot.
func constrain_support_rotation(dragon: Node3D, previous_yaw: float) -> void:
	if dragon.locomotion_state!=dragon.LocomotionState.GROUNDED or dragon.ground_blend<=.99:return
	var yaw_step:float=wrapf(dragon.rotation.y-previous_yaw,-PI,PI)
	if absf(yaw_step)<.000001:return
	var wanted:Basis=dragon.global_basis.orthonormalized()
	# Keep this tick's pitch/roll terrain adaptation. Only the requested pivot
	# is shortened; blocking pitch also prevents stable footing on a hillside.
	var previous:Basis=wanted.rotated(Vector3.UP,-yaw_step)
	if _support_rotation_reachable(dragon,previous,wanted):return
	var low:=0.0
	var high:=1.0
	for attempt in 10:
		var fraction:float=(low+high)*.5
		var candidate:Basis=previous.rotated(Vector3.UP,yaw_step*fraction)
		if _support_rotation_reachable(dragon,previous,candidate):low=fraction
		else:high=fraction
	dragon.global_basis=previous.rotated(Vector3.UP,yaw_step*low)

func _support_rotation_reachable(dragon:Node3D,previous:Basis,candidate:Basis) -> bool:
	for limb in limbs:
		if limb.swinging or not limb.has("published_hip_actor"):continue
		var wrist:Vector3=limb.published_wrist
		var prior_distance:float=(dragon.global_position+previous*limb.published_hip_actor).distance_to(wrist)
		var next_distance:float=(dragon.global_position+candidate*limb.published_hip_actor).distance_to(wrist)
		var radius:float=maxf(.1,float(limb.published_reach)-.12)
		if next_distance>maxf(radius,prior_distance)+.000001:return false
	return true

# The actor cannot outrun the reach of its three planted support legs.
# These are measured FINAL-pose joints, not the imported animation between modifiers.
func constrain_support_motion(dragon: Node3D, delta: float) -> bool:
	if dragon.locomotion_state!=dragon.LocomotionState.GROUNDED or dragon.ground_blend<=.99:return false
	# On a support surface, y is the slope component of this walking step.
	# Limiting only x/z lets a blocked animal climb vertically every tick.
	# Preserve independent falling velocity when there is no walkable support.
	var slope_motion:bool=dragon.is_on_floor() or (dragon.ground_proximity<6.0 and dragon._ground_is_walkable())
	var motion:Vector3=dragon.velocity*delta
	if not slope_motion:motion.y=0.0
	var a:=motion.length_squared()
	if a<.000000001:return false
	var fraction:=1.0
	var established_supports:=0
	for limb in limbs:
		if not limb.swinging: established_supports+=1
	if established_supports<3: fraction=0.0
	for limb in limbs:
		if limb.swinging or not limb.has("published_hip_actor"):continue
		if bool(limb.get("support_limited",false)):
			# Do not drag a planted claw while its landing articulation catches up.
			fraction=0.0
			break
		var hip:Vector3=dragon.to_global(limb.published_hip_actor)
		var offset:Vector3=hip-(limb.published_wrist as Vector3)
		var radius:float=maxf(.1,float(limb.published_reach)-.12)
		var b:=2.0*offset.dot(motion)
		var c:=offset.length_squared()-radius*radius
		if c>0:
			if b>=0:fraction=0.0
			continue
		var discriminant:=maxf(0,b*b-4*a*c)
		fraction=minf(fraction,clampf((-b+sqrt(discriminant))/(2*a),0,1))
	if fraction>=.999999:return false
	dragon.velocity.x*=fraction
	dragon.velocity.z*=fraction
	if slope_motion:dragon.velocity.y*=fraction
	dragon.current_speed=minf(dragon.current_speed,Vector2(dragon.velocity.x,dragon.velocity.z).length())
	return true

func _ray(dragon: Node3D, point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 12.0, point + Vector3.DOWN * 18.0, 1)
	query.exclude = [dragon.get_rid()]
	return dragon.get_world_3d().direct_space_state.intersect_ray(query)

# A two-link elbow has one redundant bend plane. Swivel that plane about the
# hip/wrist line instead of carrying a planted wrist with a local-pose rollback.
# Refit the last physically published fore branch to the incoming world wrist.
# The normal solve's UP arc must not erase this measured collision-free seed.
func recover_fore_seed(dragon: Node3D, sk: Skeleton3D, limb: Dictionary, safe_pose: Dictionary) -> bool:
	var safe: Dictionary=safe_pose.get("limb_rotations",{})
	if limb.chain.size()!=2 or safe.is_empty(): return false
	var bones: Array=limb.chain.duplicate()
	bones.append(limb.end)
	var original: Dictionary={}
	for bone in bones: original[bone]=sk.get_bone_pose_rotation(bone)
	var incoming_world: Vector3=sk.to_global(sk.get_bone_global_pose(limb.end).origin)
	var wrist_basis: Basis=sk.get_bone_global_pose(limb.end).basis.orthonormalized()
	var prior_pole: Vector3=limb.get("pole_world",Vector3.UP)
	var prior_pole_frame: int=int(limb.get("pole_frame",-1))
	for bone in limb.chain:
		if not safe.has(bone): return false
	var targets: Array[Vector3]=[incoming_world]
	var limb_index: int=limbs.find(limb)
	# A swing goal can put the fingers inside a wall even while its wrist is
	# outside. Shorten that unplanted step to the last physically safe world XZ.
	# Keep the descent's current Y and the distinct finish Y at surface contact.
	if limb.swinging and limb_index>=0 and safe_pose.get("feet",[]).size()>limb_index:
		var saved: Vector3=safe_pose.feet[limb_index].target
		targets.append(Vector3(saved.x,incoming_world.y,saved.z))
	for target_index in targets.size():
		limb.pole_world=prior_pole
		limb.pole_frame=prior_pole_frame
		for bone in bones: sk.set_bone_pose_rotation(bone,original[bone])
		for bone in limb.chain: sk.set_bone_pose_rotation(bone,safe[bone])
		_solve_limb(sk,limb.chain,limb.end,sk.to_local(targets[target_index]),limb,true)
		var parent: int=sk.get_bone_parent(limb.end)
		sk.set_bone_pose_rotation(limb.end,(sk.get_bone_global_pose(parent).basis.orthonormalized().inverse()*wrist_basis).get_rotation_quaternion())
		var endpoint_error: float=sk.to_global(sk.get_bone_global_pose(limb.end).origin).distance_to(targets[target_index])
		var anchor_error:=Vector2.ZERO
		if not limb.swinging and not limb.contact_sample.is_empty():
			var offset: Vector3=limb.probe.point(sk,limb.contact_sample)-limb.contact_anchor
			anchor_error=Vector2(offset.x,offset.z)
		dragon.wing_contact.sample_final(dragon,sk)
		if endpoint_error<=.004 and anchor_error.length()<=.015 and not dragon.wing_contact._body_contact(dragon):
			limb.actual=sk.to_global(sk.get_bone_global_pose(limb.end).origin)
			if target_index>0:
				var finish: Vector3=limb.finish
				finish.x=limb.actual.x
				finish.z=limb.actual.z
				limb.finish=finish
				limb.planted=finish
			var hip: Vector3=sk.get_bone_global_pose(limb.chain[0]).origin
			var knee: Vector3=sk.get_bone_global_pose(limb.chain[1]).origin
			var axis: Vector3=(sk.get_bone_global_pose(limb.end).origin-hip).normalized()
			var pole: Vector3=knee-hip
			limb.pole_world=(sk.global_basis*(pole-axis*pole.dot(axis)).normalized()).normalized()
			limb.pole_frame=Engine.get_process_frames()
			if OS.get_cmdline_user_args().has("--leg-diagnostic"):
				print("FORE_SEED_RECOVERY frame=",Engine.get_physics_frames()," end=",limb.end," swinging=",limb.swinging," shortened=",target_index>0," endpoint_error_m=",endpoint_error," anchor_error_m=",anchor_error.length())
			return true
	for bone in bones: sk.set_bone_pose_rotation(bone,original[bone])
	limb.pole_world=prior_pole
	limb.pole_frame=prior_pole_frame
	dragon.wing_contact.sample_final(dragon,sk)
	return false

func _solve_limb(sk: Skeleton3D, chain: Array, end: int, target: Vector3, limb: Dictionary, preserve_seed: bool = false) -> void:
	var joints := PackedVector3Array()
	for bone in chain: joints.append(sk.get_bone_global_pose(int(bone)).origin)
	joints.append(sk.get_bone_global_pose(end).origin)
	var lengths := PackedFloat32Array()
	var total := 0.0
	for index in chain.size():
		var length := joints[index].distance_to(joints[index+1])
		lengths.append(length)
		total += length
	var origin := joints[0]
	var axis := (target-origin).normalized()
	var up := (sk.global_basis.inverse()*Vector3.UP).normalized()
	var projected_up := up-axis*up.dot(axis)
	var side := axis.cross(up).normalized()
	if limb.has("pole_world"):
		var old: Vector3 = sk.global_basis.inverse()*limb.pole_world
		if side.dot(old)<0: side = -side
	if side.is_zero_approx(): side = (Vector3.FORWARD-axis*Vector3.FORWARD.dot(axis)).normalized()
	# A horizontal perpendicular bias removes the vertical singularity without
	# choosing a downward elbow or changing any bone length.
	var pole := (projected_up+side*.35*(1.0-smoothstep(.05,.35,projected_up.length()))).normalized()
	if limb.has("pole_world"):
		var previous: Vector3 = sk.global_basis.inverse()*limb.pole_world
		previous = (previous-axis*previous.dot(axis)).normalized()
		if not previous.is_zero_approx() and (end in [8,23] or previous.dot(up)>=0):
			# Near a vertical root/foot line, UP provides no stable elbow side.
			# Retain the previous branch and budget one angular step per render.
			if projected_up.length()<.1 or int(limb.get("pole_frame",-1))==Engine.get_process_frames():
				pole = previous
			else:
				var angle := previous.signed_angle_to(pole,axis)
				pole = previous.rotated(axis,clampf(angle,-deg_to_rad(4),deg_to_rad(4))).normalized()
	if pole.is_zero_approx(): pole = (Vector3.FORWARD-axis*Vector3.FORWARD.dot(axis)).normalized()
	limb.pole_world = (sk.global_basis*pole).normalized()
	limb.pole_frame = Engine.get_process_frames()
	var rear_solution := PackedVector3Array()
	if end in [8,23] and chain.size()==3:
		var actor_to_skeleton: Basis=sk.global_basis.inverse()*(limb.actor_basis as Basis)
		var rear_seed: PackedVector3Array=joints.duplicate()
		var thigh_bone: int=chain[0]
		if limb.get("support_rotations",{}).has(thigh_bone):
			# The incoming AnimationPlayer pose is not the last planted knee
			# plane. Reconstruct that plane from its published actor rotation
			# and the original child axis before choosing the analytic branch.
			var original_thigh_axis: Vector3=(sk.get_bone_global_pose(thigh_bone).basis.inverse()*(joints[1]-joints[0])).normalized()
			var prior_thigh: Quaternion=limb.support_rotations[thigh_bone]
			var prior_direction: Vector3=(actor_to_skeleton*Basis(prior_thigh)*original_thigh_axis).normalized()
			rear_seed[1]=joints[0]+prior_direction*lengths[0]
			var shin_bone:int=chain[1]
			if limb.support_rotations.has(shin_bone):
				var original_shin_axis:Vector3=(sk.get_bone_global_pose(shin_bone).basis.inverse()*(joints[2]-joints[1])).normalized()
				var prior_shin:Quaternion=limb.support_rotations[shin_bone]
				rear_seed[2]=rear_seed[1]+(actor_to_skeleton*Basis(prior_shin)*original_shin_axis).normalized()*lengths[1]
		# The metatarsus follows the moving foot, with a bounded return to the
		# upright anatomical stance. One budget covers every calibration pass.
		if int(limb.get("distal_frame",-1))!=Engine.get_physics_frames():
			limb.distal_frame=Engine.get_physics_frames()
			var previous_distal:Vector3=(limb.actor_basis as Basis).inverse()*sk.global_basis*(rear_seed[2]-joints[3])
			var hock_bone:int=chain[2]
			if limb.get("support_rotations",{}).has(hock_bone):
				var original_foot_axis:Vector3=(sk.get_bone_global_pose(hock_bone).basis.inverse()*(joints[3]-joints[2])).normalized()
				previous_distal=-(Basis(limb.support_rotations[hock_bone])*original_foot_axis)
			previous_distal=previous_distal.normalized()
			var preferred:Vector3=Vector3(0,.9,.35).normalized()
			var rotation_to_stance:=Quaternion(previous_distal,preferred)
			var angle:float=previous_distal.angle_to(preferred)
			limb.distal_actor=Basis(Quaternion.IDENTITY.slerp(rotation_to_stance,minf(1.0,deg_to_rad(2)/maxf(angle,.000001))))*previous_distal
		rear_solution=Biomechanics.rear_joints(rear_seed,lengths,target,actor_to_skeleton,actor_to_skeleton*limb.distal_actor)
		if rear_solution.is_empty() and OS.get_cmdline_user_args().has("--leg-diagnostic"):
			print("REAR_ANALYTIC_FALLBACK tick=",Engine.get_physics_frames()," end=",end," lengths=",lengths," seed=",rear_seed," target=",target," basis=",actor_to_skeleton)
	if not rear_solution.is_empty():
		joints=rear_solution
	else:
		# Forelimb two-link solve and unreachable-rear fallback keep their
		# original pole, seed recovery and segment-length FABRIK behavior.
		var accumulated := 0.0
		for index in range(1,chain.size()):
			accumulated += lengths[index-1]
			var fraction := accumulated/maxf(total,0.000001)
			var arc := origin.lerp(target,fraction)+pole*(total*.35*sin(fraction*PI))
			if not preserve_seed: joints[index] = joints[index].lerp(arc,smoothstep(0.0,1.0,pose_blend))
		for iteration in 32:
			joints[-1] = target
			for index in range(chain.size()-1,-1,-1):
				joints[index] = joints[index+1]+(joints[index]-joints[index+1]).normalized()*lengths[index]
			joints[0] = origin
			for index in chain.size():
				joints[index+1] = joints[index]+(joints[index+1]-joints[index]).normalized()*lengths[index]
			if joints[-1].distance_to(target)<0.004: break
	for index in chain.size():
		var bone: int = chain[index]
		var child: int = int(chain[index+1]) if index+1<chain.size() else end
		var pose := sk.get_bone_global_pose(bone)
		var current := sk.get_bone_global_pose(child).origin-pose.origin
		var wanted := joints[index+1]-joints[index]
		if current.length_squared()<0.00000001 or wanted.length_squared()<0.00000001: continue
		var correction := Quaternion(current.normalized(),wanted.normalized())
		var global_rotation := correction*pose.basis.orthonormalized().get_rotation_quaternion()
		# Keep the published twist while aiming the unchanged original child axis.
		# Imported flight roll is unrelated to the terrestrial knee/hock direction.
		if end in [8,23] and limb.get("support_rotations",{}).has(bone):
			var previous_actor: Quaternion=limb.support_rotations[bone]
			var original_child_axis: Vector3=(pose.basis.inverse()*current).normalized()
			var previous_axis: Vector3=(Basis(previous_actor)*original_child_axis).normalized()
			var wanted_axis: Vector3=((limb.actor_basis as Basis).inverse()*sk.global_basis*wanted).normalized()
			var transported: Quaternion=Quaternion(previous_axis,wanted_axis)*previous_actor
			global_rotation=(sk.global_basis.inverse()*(limb.actor_basis as Basis)*Basis(transported)).orthonormalized().get_rotation_quaternion()

		# All calibration passes share the same published-frame budget; a pass
		# must not add another angular step or discard the prepared rear branch.
		if (bool(limb.get("support_transition",false)) or bool(limb.get("limit_stationary_motion",false))) and limb.get("support_anchors",{}).has(bone):
			var previous: Quaternion = limb.support_anchors[bone]
			var wanted_rotation: Quaternion = ((limb.support_body_basis as Basis).inverse()*sk.global_basis*Basis(global_rotation)).get_rotation_quaternion()
			var angle := previous.angle_to(wanted_rotation)
			# Leave angular room for the torso's simultaneous landing rotation.
			limb.support_limited=bool(limb.get("support_limited",false)) or angle>deg_to_rad(3.0)
			var published: Quaternion = previous.slerp(wanted_rotation,minf(1.0,deg_to_rad(3.0)/maxf(angle,.000001)))
			global_rotation=(sk.global_basis.inverse()*(limb.support_body_basis as Basis)*Basis(published)).get_rotation_quaternion()
		var parent := sk.get_bone_parent(bone)
		var parent_rotation := sk.get_bone_global_pose(parent).basis.orthonormalized().get_rotation_quaternion()
		sk.set_bone_pose_rotation(bone,parent_rotation.inverse()*global_rotation)
