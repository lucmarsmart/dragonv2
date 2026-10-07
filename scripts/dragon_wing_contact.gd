extends RefCounted
const Probe = preload("res://scripts/dragon_pose_probe.gd")
const GroundContact = preload("res://scripts/dragon_ground_contact.gd")
var probe = Probe.new()
var body_probe = Probe.new()
var body_pose_safe: Dictionary = {}
var wing_pose_safe: Dictionary = {}
var wing_published: Dictionary = {}
var wing_pose_metrics := {"restored":0,"body_compensated":0,"folded":0,"uncleared":0}
var body_pose_blocked := false
var body_pose_valid := true
var body_pose_recovering := false
var extrema_ids: Dictionary = {}
var sample_categories := PackedInt32Array()
var contact_details: Array[Dictionary] = []
var hulls: Array[ConvexPolygonShape3D] = []
var frame := -1
var predictive_contact := false
var contact_normal := Vector3.ZERO
var diagnostic_probe = Probe.new()
const LIMB_SEGMENTS := [5,6,7,8,20,21,22,23,39,40,41,80,81,82]
var body_indices: Array[int] = [2]
var body_triangles: Array = []
var body_contact_index := -1
var torso_bones:Array[int]=[]
var jaw_probe=Probe.new()
var jaw_hull_slots:Dictionary={}
var final_hull_points:Array=[]
var tail_hull_slots:Array[int]=[]
var tail_published:Quaternion=Quaternion.IDENTITY
var tail_anchor:Quaternion=Quaternion.IDENTITY
var tail_frame:int=-1
var tail_initialized:=false
var bone_descendants: Dictionary = {}
var all_limb_bones: Array[int] = []
var body_query_cache: Dictionary = {}
var body_query_scope_active: bool = false
var body_query_actor: Transform3D = Transform3D.IDENTITY

func _configure_topology(sk: Skeleton3D) -> void:
	bone_descendants.clear()
	all_limb_bones.clear()
	# Preserve the original bone order; only the immutable ancestry lookup is cached.
	for root_bone in [96,120,5,20,39,80]:
		var descendants: Array[int] = []
		for bone in sk.get_bone_count():
			var ancestor: int = bone
			while ancestor>=0 and ancestor!=root_bone: ancestor=sk.get_bone_parent(ancestor)
			if ancestor==root_bone: descendants.append(bone)
		bone_descendants[root_bone]=descendants
	for bone in sk.get_bone_count():
		for root_bone in [5,20,39,80]:
			if bone in bone_descendants[root_bone]:
				all_limb_bones.append(bone)
				break

func _invalidate_body_query_cache() -> void:
	body_query_cache.clear()

func _begin_body_query_scope(dragon: Node3D) -> void:
	_invalidate_body_query_cache()
	body_query_actor=dragon.global_transform
	body_query_scope_active=true

func _end_body_query_scope() -> void:
	body_query_scope_active=false
	_invalidate_body_query_cache()

func _body_part(sample: Dictionary, sk: Skeleton3D) -> int:
	var weights := []
	for part in LIMB_SEGMENTS.size()+1: weights.append(0.0)
	for influence in sample.influence:
		var bone: int = influence.bone
		var part := 0
		while bone>=0:
			var limb := LIMB_SEGMENTS.find(bone)
			if limb>=0:
				part = limb+1
				break
			bone = sk.get_bone_parent(bone)
		weights[part] += influence.weight
	var largest := 0
	for part in weights.size():
		if weights[part]>weights[largest]: largest = part
	return 2 if largest==0 else largest+3

func _body_boundaries(dragon: Node3D, sk: Skeleton3D, original: Array) -> Array:
	var surfaces := {}
	for sample in original:
		var key := "%s:%d" % [sample.mesh,sample.surface]
		if not surfaces.has(key): surfaces[key] = {}
		surfaces[key][sample.index] = sample
	var boundary := {}
	var triangles := 0
	var other_triangles := 0
	for key in surfaces:
		var parts: PackedStringArray = key.split(":")
		var mesh_node := dragon.find_child(parts[0],true,false) as MeshInstance3D
		var arrays: Array = mesh_node.mesh.surface_get_arrays(int(parts[1]))
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for offset in range(0,indices.size(),3):
			var vertices := []
			var owners := []
			var body_corners := 0
			for corner in 3:
				var index := indices[offset+corner]
				if not surfaces[key].has(index): break
				var sample: Dictionary = surfaces[key][index]
				vertices.append(sample)
				owners.append(_body_part(sample,sk))
				if not sample.wing and not sample.neck: body_corners += 1
			if vertices.size()!=3: continue
			if body_corners==0:
				other_triangles += 1
				continue
			triangles += 1
			# One hull must contain all three original corners of each boundary
			# triangle. Duplicate exact original points, never reconstructed corners.
			var owner: int = owners[0]
			if owners[1]==owners[2]: owner = owners[1]
			body_triangles.append({"mesh":parts[0],"surface":int(parts[1]),"indices":[indices[offset],indices[offset+1],indices[offset+2]],"hull":owner})
			for corner in 3:
				if owners[corner]==owner and not vertices[corner].wing and not vertices[corner].neck: continue
				var id := "%s:%d:%d" % [key,vertices[corner].index,owner]
				boundary[id] = {"sample":vertices[corner],"part":owner}
	print("BODY_PARTITION lookup_all_skin=",original.size()," body_touching_triangles=",triangles," independent_neck_wing_triangles=",other_triangles," exact_boundary_points=",boundary.size())
	return boundary.values()

func _diagnostic_pose(dragon: Node3D, sk: Skeleton3D, stage: String) -> void:
	if not OS.get_cmdline_user_args().has("--body-pose-diagnostic"): return
	if diagnostic_probe.samples.is_empty():
		diagnostic_probe.configure(dragon,sk,1)
		diagnostic_probe.samples = diagnostic_probe.samples.filter(func(s): return (s.mesh=="Object_7" and s.index==3948) or (s.mesh=="Object_8" and s.index==4783))
	var values := []
	for point in diagnostic_probe.points(sk):
		var local: Vector3 = dragon.landscape.to_local(point.position)
		values.append({"index":point.sample.index,"point":str(point.position),"clearance":local.y-dragon.landscape.ground_height(local.x,local.z)})
	print("BODY_POSE_STAGE ",Engine.get_physics_frames()," ",stage," root=",dragon.global_position," visual=",dragon.visual_root.transform," ",JSON.stringify(values))

func configure(dragon: Node3D, sk: Skeleton3D) -> void:
	_configure_topology(sk)
	# Finite original vertex extrema; see the construction and independent holdout evidence.
	# It is independently checked against all5412 membrane vertices; it is not a stride sample.
	if FileAccess.file_exists("res://scripts/dragon_wing_extrema.json"):
		var selected = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/dragon_wing_extrema.json"))
		if selected is Array:
			for key in selected: extrema_ids[key] = true
	probe.profile_label = "wing_skin"
	probe.configure(dragon, sk, 1)
	var all_original: Array = probe.samples.duplicate()
	probe.samples = probe.samples.filter(func(sample):
		if sample.wing:
			return extrema_ids.is_empty() or extrema_ids.has("%s:%d:%d" % [sample.mesh,sample.surface,sample.index])
		return sample.neck or int(sample.claw) < 0)
	var matched := 0
	for sample in probe.samples:
		if sample.wing: matched += 1
	if matched < 500:
		# A different imported model must use the complete geometry until its extrema are audited.
		probe.configure(dragon,sk,1)
		probe.samples = probe.samples.filter(func(sample): return sample.wing or sample.neck or int(sample.claw) < 0)
	var neck_probe = Probe.new()
	neck_probe.profile_label = "neck_support"
	neck_probe.samples = probe.samples.filter(func(sample): return sample.neck)
	neck_probe.reduce_affine_support()
	probe.samples = probe.samples.filter(func(sample): return not sample.neck)
	probe.samples.append_array(neck_probe.samples)
	body_probe = Probe.new()
	body_probe.profile_label = "body_support"
	body_probe.samples = probe.samples.filter(func(sample): return not sample.wing and not sample.neck and int(sample.claw)<0)
	var boundaries := _body_boundaries(dragon,sk,all_original)
	body_probe.reduce_affine_support()
	var claws = Probe.new()
	claws.samples = all_original.filter(func(sample): return not sample.wing and not sample.neck and int(sample.claw)>=0)
	claws.profile_label = "body_claws"
	var claw_stats: Dictionary = claws.reduce_affine_support()
	print("BODY_CLAW_SUPPORT ",JSON.stringify(claw_stats))
	body_probe.samples.append_array(claws.samples)
	probe.samples = probe.samples.filter(func(sample): return sample.wing or sample.neck)
	probe.samples.append_array(body_probe.samples)
	for sample in probe.samples:
		# Wing membership follows the imported skeleton, so deformation across
		# the torso axis cannot transfer a vertex between collision hulls.
		var wing_mask := int(sample.get("wing_side_mask",3)) & 3
		if wing_mask==0: wing_mask=3
		sample_categories.append(-wing_mask if sample.wing else (3 if sample.neck else _body_part(sample,sk)))
	for boundary in boundaries:
		probe.samples.append(boundary.sample)
		sample_categories.append(boundary.part)
	for side in LIMB_SEGMENTS.size()+4:
		hulls.append(ConvexPolygonShape3D.new())
		if side>=4: body_indices.append(side)
	# Refresh only original points affected by the final jaw modifier.
	var offsets:Array[int]=[]
	for hull in hulls:offsets.append(0)
	var jaw:int=sk.find_bone("Bone015_012")
	for index in probe.samples.size():
		var sample:Dictionary=probe.samples[index]
		var category:int=sample_categories[index]
		var jaw_deformed:=false
		var tail_deformed:=false
		for influence in sample.influence:
			var bone:int=influence.bone
			var ancestor:=bone
			while ancestor>=0:
				if ancestor in dragon.bone_tail_indices:tail_deformed=true
				if ancestor==jaw:jaw_deformed=true;break
				ancestor=sk.get_bone_parent(ancestor)
		var jaw_index:int=jaw_probe.samples.size()
		if jaw_deformed:jaw_probe.samples.append(sample)
		var categories:Array[int]=[]
		if category>=0:categories.append(category)
		if category<0:
			if (-category&1)!=0:categories.append(0)
			if (-category&2)!=0:categories.append(1)
		for part in categories:
			if part==2 and tail_deformed:tail_hull_slots.append(offsets[part])
			if jaw_deformed:
				if not jaw_hull_slots.has(part):jaw_hull_slots[part]=[]
				jaw_hull_slots[part].append({"point":offsets[part],"jaw":jaw_index})
			offsets[part]+=1
	torso_bones=dragon.bone_spine_indices.duplicate()
	jaw_probe.prepare_coordinates()
	print("BODY_TORSO_RECOVERY bones=",torso_bones," jaw_hulls=",jaw_hull_slots.keys()," jaw_support_points=",jaw_probe.samples.size())

func sample_final(dragon: Node3D, sk: Skeleton3D) -> void:
	_invalidate_body_query_cache()
	# SkeletonModifier may publish several distinct poses in one physics tick.
	# Every call follows a pose change; the resulting hull must match that render.
	frame = Engine.get_physics_frames()
	if hulls.is_empty(): configure(dragon, sk)
	var points: Array[PackedVector3Array] = []
	for side in hulls.size(): points.append(PackedVector3Array())
	var coordinates := probe.coordinates(sk,dragon)
	for index in coordinates.size():
		var local: Vector3 = coordinates[index]
		var category: int = sample_categories[index]
		if category>=0:
			points[category].append(local)
		else:
			var wing_mask := -category
			if (wing_mask & 1)!=0: points[0].append(local)
			if (wing_mask & 2)!=0: points[1].append(local)
	for side in hulls.size():
		var started := Time.get_ticks_usec() if Probe.profiling else 0
		if points[side].size() >= 4: hulls[side].points = points[side]
		Probe.record("wing_hull_%d" % side,started)
	final_hull_points=points

func sample_jaw_final(dragon:Node3D,sk:Skeleton3D) -> void:
	_invalidate_body_query_cache()
	if final_hull_points.is_empty() or jaw_probe.samples.is_empty():return
	# Only mandibular support points changed after the final body modifier.
	# Keep the other16/17 enclosures and all original point identities intact.
	var coordinates:PackedVector3Array=jaw_probe.coordinates(sk,dragon)
	for category in jaw_hull_slots:
		var points:PackedVector3Array=final_hull_points[category]
		for slot in jaw_hull_slots[category]:points[int(slot.point)]=coordinates[int(slot.jaw)]
		final_hull_points[category]=points
		if points.size()>=4:hulls[category].points=points

func constrain(dragon: Node3D, delta: float) -> void:
	predictive_contact = false
	contact_details.clear()
	if hulls.is_empty(): return
	var space := dragon.get_world_3d().direct_space_state
	if dragon.locomotion_state == dragon.LocomotionState.GROUNDED:
		var started := Time.get_ticks_usec() if Probe.profiling else 0
		var result := GroundContact.constrain_all(space,hulls,dragon.global_transform,dragon.get_rid(),dragon.velocity*delta)
		Probe.record("ground_contact_all",started)
		dragon.velocity = result.motion/maxf(delta,.00001)
		predictive_contact = result.blocked
		if predictive_contact:
			contact_details.append({"reason":result.reason,"pose_clearance":result.requires_pose_clearance})
		return
	var look_velocity: Vector3 = dragon.velocity
	var requested_velocity:Vector3=dragon.velocity
	if dragon.locomotion_state == dragon.LocomotionState.LANDING: contact_normal = Vector3.ZERO
	if look_velocity.length()<.1: return
	for hull_index in hulls.size():
		var hull: ConvexPolygonShape3D = hulls[hull_index]
		if hull.points.size() < 4: continue
		look_velocity = dragon.velocity
		if look_velocity.length()<.1: continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = hull
		query.transform = dragon.global_transform
		query.collision_mask = 3
		query.exclude = [dragon.get_rid()]
		query.margin = 0.25 if dragon.locomotion_state == dragon.LocomotionState.GROUNDED else 0.5
		var speed: float = look_velocity.length()
		# Grounded CharacterBody clips travel directly at this tick's swept contact.
		# In flight, query immediate frame displacement for wing fold detection without artificial mid-air braking.
		query.motion = look_velocity * delta
		var cast_started := Time.get_ticks_usec() if Probe.profiling else 0
		var cast := space.cast_motion(query)
		Probe.record("wing_cast_%d" % hull_index,cast_started)
		var overlap_started := Time.get_ticks_usec() if Probe.profiling else 0
		var overlapping := not space.intersect_shape(query, 1).is_empty()
		Probe.record("wing_overlap_%d" % hull_index,overlap_started)
		if overlapping or (cast.size() == 2 and cast[0] < 0.99):
			var contact := {}
			# LANDING uses the same sweep/overlap for clipping and folding below.
			# Its normal has no steering consumer; avoid EPA solely for diagnostics.
			if dragon.locomotion_state != dragon.LocomotionState.LANDING:
				var rest_started := Time.get_ticks_usec() if Probe.profiling else 0
				contact = space.get_rest_info(query)
				if contact.is_empty() and cast.size() == 2:
					query.transform.origin += query.motion * cast[1]
					contact = space.get_rest_info(query)
				Probe.record("wing_rest_%d" % hull_index,rest_started)
			if not contact.is_empty():
				contact_normal = contact.normal
				var collider := instance_from_id(contact.collider_id)
				if dragon.locomotion_state == dragon.LocomotionState.GROUNDED and contact_normal.y >= 0.985 and collider is CollisionObject3D and (collider.collision_layer & 1) != 0:
					continue
			# Grounded mode clips travel to prevent entering geometry.
			# Flight mode leaves collision and impacts to CharacterBody3D and physics simulation.
			if cast.size() == 2 and cast[0] < 1.0:
				var safe_speed: float = cast[0] * query.motion.length() / maxf(delta,0.0001)
				if speed > safe_speed and dragon.locomotion_state == dragon.LocomotionState.GROUNDED:
					var constrained: Vector3 = look_velocity.normalized() * safe_speed
					dragon.velocity.x = constrained.x
					dragon.velocity.z = constrained.z
			predictive_contact = true
			contact_details.append({"hull":hull_index,"normal":contact_normal,"normal_available":not contact.is_empty(),"collider":str(instance_from_id(contact.collider_id)) if not contact.is_empty() else "predicted", "cast_fraction":cast[0] if cast.size() == 2 else -1})
	if predictive_contact:
		dragon.contact_fold_requested = 1.0
		if dragon.locomotion_state == dragon.LocomotionState.GROUNDED:
			var horizontal := Vector3(dragon.velocity.x,0,dragon.velocity.z).move_toward(Vector3.ZERO,32.0 * delta)
			dragon.velocity.x = horizontal.x
			dragon.velocity.z = horizontal.z
			dragon.current_speed = move_toward(dragon.current_speed,0,32.0 * delta)

# A translation sweep covers the previous pose. Check the new rendered body
# before committing its tail motion, including the model stabilizer's offset.
func smooth_body_recovery(dragon: Node3D, sk: Skeleton3D) -> void:
	if not body_pose_recovering or body_pose_safe.is_empty(): return
	var remaining := false
	var step := deg_to_rad(60.0)*dragon.get_process_delta_time()
	var rotations: Dictionary = body_pose_safe.tail.duplicate()
	rotations.merge(body_pose_safe.get("spine",{}))
	for bone in rotations:
		var previous: Quaternion = rotations[bone]
		var wanted := sk.get_bone_pose_rotation(int(bone))
		var angle := previous.angle_to(wanted)
		if angle>step:
			remaining = true
			sk.set_bone_pose_rotation(int(bone),previous.slerp(wanted,step/angle))
	body_pose_recovering = remaining

func guard_body_pose(dragon: Node3D, sk: Skeleton3D) -> void:
	_begin_body_query_scope(dragon)
	body_pose_blocked = false
	guard_tail_terrain(dragon,sk)
	if dragon.locomotion_state != dragon.LocomotionState.GROUNDED:
		body_pose_safe.clear()
		body_pose_recovering = false
		if dragon.locomotion_state==dragon.LocomotionState.FLYING and predictive_contact:
			# Rigid rotation/sweeps precede animation. A new wing beat also needs
			# a final physical pose check beside an obstacle while climbing away.
			guard_grounded_wings(dragon,sk)
		else:
			wing_pose_safe.clear()
			wing_published.clear()
		publish_tail(dragon,sk)
		_end_body_query_scope()
		return
	# Raising the torso while retaining world stance targets clears a low belly
	# on a changing slope. It preserves authored links and avoids asking a
	# translation sweep to escape an already intersecting terrain pose.
	if dragon.ground_blend>.99:
		# The convex foot enclosure can bridge empty space between original toes
		# above a terrain cell boundary. Resolve that physical contact through IK
		# before the motion guard runs; retain every hull and collision layer.
		for attempt in 3:
			if not _body_contact(dragon,1) or body_contact_index<4:break
			var contacted_bone:int=LIMB_SEGMENTS[body_contact_index-4]
			var adjusted:=false
			for limb in dragon.ground_pose.limbs:
				if contacted_bone not in limb.chain and contacted_bone!=int(limb.end):continue
				var extra:float=float(limb.get("terrain_hull_clearance",0.0))
				if extra>=.036:continue
				limb.terrain_hull_clearance=minf(.036,extra+.012)
				adjusted=true
			if not adjusted:break
			dragon.ground_pose.apply(dragon,sk,true)
			sample_final(dragon,sk)
		for attempt in 4:
			if not _body_contact(dragon,1): break
			# A fixed torso-height ceiling can leave a millimetric belly contact
			# permanently blocking both directions on a slope. Beyond the ordinary
			# correction use small increments bounded by the planted legs' reach.
			var raise:float=.005 if dragon.body_clearance_lift>=.3 else .05
			for limb in dragon.ground_pose.limbs:
				if limb.swinging or not limb.has("published_reach"):continue
				var hip:Vector3=sk.to_global(sk.get_bone_global_pose(limb.chain[0]).origin)
				var wrist:Vector3=sk.to_global(sk.get_bone_global_pose(limb.end).origin)
				if not limb.contact_sample.is_empty():wrist+=limb.contact_anchor-limb.probe.point(sk,limb.contact_sample)
				var offset:Vector3=hip-wrist
				var radius:float=maxf(.1,float(limb.published_reach)-.12)
				var vertical_room:float=sqrt(maxf(0.0,radius*radius-offset.x*offset.x-offset.z*offset.z))-offset.y
				raise=minf(raise,maxf(0.0,vertical_room))
			if raise<.0001:break
			dragon.visual_root.global_position += Vector3.UP*raise
			dragon.body_clearance_lift += raise
			dragon.ground_pose.apply(dragon,sk,true)
			sample_final(dragon,sk)
	# Preserve the measured fore branch and the incoming world wrist before
	# attempting the existing body rollback. Failed refits restore the input pose.
	var body_contact_before_recovery:bool=_body_contact(dragon)
	if body_contact_before_recovery and body_contact_index>=4:
		var contacted_bone:int=LIMB_SEGMENTS[body_contact_index-4]
		for limb in dragon.ground_pose.limbs:
			if limb.chain.size()==2 and (contacted_bone in limb.chain or contacted_bone==int(limb.end)):
				if dragon.ground_pose.recover_fore_seed(dragon,sk,limb,body_pose_safe):body_contact_before_recovery=false
	if body_contact_before_recovery and not body_pose_safe.is_empty():
		_diagnostic_pose(dragon,sk,"original")
		for bone in body_pose_safe.tail:
			sk.set_bone_pose_rotation(int(bone),body_pose_safe.tail[bone])
		sample_final(dragon,sk)
		_diagnostic_pose(dragon,sk,"tail_only")
		# Tail-only contact does not change any parent of feet or neck. Preserve
		# their freshly solved pose whenever restoring those8 rotations suffices.
		if _body_contact(dragon):
			for bone in body_pose_safe.get("spine",{}):
				sk.set_bone_pose_rotation(int(bone),body_pose_safe.spine[bone])
			var rendered_head: Vector3 = dragon.head_rendered_direction
			_diagnostic_pose(dragon,sk,"spine_restored")
			var requested_head: Vector3 = dragon.head_aim_direction
			dragon.head_aim_direction = rendered_head
			dragon.head_pose.apply(dragon,sk)
			dragon.head_aim_direction = requested_head
			dragon._refit_compact_wings(sk)
			# Re-solving contacts after a parent offset is not a second gait tick.
			dragon.ground_pose.apply(dragon,sk,true)
			sample_final(dragon,sk)
			_diagnostic_pose(dragon,sk,"resolved")
			if _body_contact(dragon):
				if body_pose_safe.has("feet"):
					for limb_index in dragon.ground_pose.limbs.size():
						var limb: Dictionary = dragon.ground_pose.limbs[limb_index]
						var saved: Dictionary = body_pose_safe.feet[limb_index]
						limb.recovery_target = saved.target
						limb.recovery_phase = saved.phase
						limb.foot_basis = saved.basis
						limb.foot_yaw = saved.yaw
						limb.pole_world = saved.pole
						limb.pole_frame = Engine.get_process_frames()
					dragon.ground_pose.apply(dragon,sk,true)
					sample_final(dragon,sk)
			if _body_contact(dragon):
				dragon.visual_root.position = body_pose_safe.visual.origin
				dragon.head_aim_direction = rendered_head
				dragon.head_pose.apply(dragon,sk)
				dragon.head_aim_direction = requested_head
				dragon._refit_compact_wings(sk)
				dragon.ground_pose.apply(dragon,sk,true)
				sample_final(dragon,sk)
		# A target and pole do not uniquely preserve a source IK branch near extension.
		# Reject an intersecting limb pose by restoring its measured safe rotations.
		if _body_contact(dragon,2) and body_contact_index>=4:
			var root_bone: int = LIMB_SEGMENTS[body_contact_index-4]
			for limb in dragon.ground_pose.limbs:
				if root_bone not in limb.chain and root_bone!=int(limb.end): continue
				for bone in bone_descendants[int(limb.chain[0])]:
					if body_pose_safe.get("limb_rotations",{}).has(bone):
						sk.set_bone_pose_rotation(int(bone),body_pose_safe.limb_rotations[bone])
				limb.actual = sk.to_global(sk.get_bone_global_pose(limb.end).origin)
			sample_final(dragon,sk)
		for limb in dragon.ground_pose.limbs:
			limb.erase("recovery_target")
			limb.erase("recovery_phase")
		# Reject a physics step that becomes unsafe after the stance refit.
		# This bounded collision response returns to the last published pose;
		# it never relocates the dragon across an obstacle or over a long gap.
		if _body_contact(dragon,2) and body_pose_safe.has("actor"):
			var safe_actor:Transform3D=body_pose_safe.actor
			var maximum_step:float=dragon.walk_speed/Engine.physics_ticks_per_second+.05
			if dragon.global_position.distance_to(safe_actor.origin)<=maximum_step:
				var turn_angle:=dragon.global_basis.get_rotation_quaternion().angle_to(safe_actor.basis.get_rotation_quaternion())
				if turn_angle<=deg_to_rad(5.0):
					dragon.global_transform=safe_actor
					dragon.velocity=Vector3.ZERO
					dragon.current_speed=0.0
					dragon.ground_motion_speed=0.0
					dragon.target_yaw=dragon.rotation.y
					dragon.smoothed_turn_rate=0.0
					dragon.pose_turn_blocked=true
					dragon.visual_root.transform=body_pose_safe.visual
					for bone in body_pose_safe.rotations:sk.set_bone_pose_rotation(int(bone),body_pose_safe.rotations[bone])
					# The rejected foot pose must not complete its logical step.
					# Restore the published gait state too, without accumulating
					# elapsed time while that articulation is physically blocked.
					dragon.ground_pose.limbs=body_pose_safe.gait.duplicate(true)
					for limb in dragon.ground_pose.limbs:
						limb.swing_clock_frame=Engine.get_physics_frames()
						limb.reposition_frame=Engine.get_physics_frames()
						limb.swing_clock_cycle=dragon.walk_cycle_phase/TAU+float(limb.phase)
					for limb in dragon.ground_pose.limbs:limb.actual=sk.to_global(sk.get_bone_global_pose(limb.end).origin)
					var muzzle:int=sk.find_bone("Point021_018")
					dragon.head_rendered_direction=(sk.to_global(sk.get_bone_global_pose(muzzle).origin)-sk.to_global(sk.get_bone_global_pose(dragon.bone_head_idx).origin)).normalized()
					sample_final(dragon,sk)
		body_pose_blocked = true
		body_pose_recovering = true
	guard_grounded_wings(dragon,sk)
	body_pose_valid = not _body_contact(dragon)
	if body_pose_valid:
		var tail := {}
		for bone in dragon.bone_tail_indices:
			if bone>=0: tail[bone] = sk.get_bone_pose_rotation(bone)
		var spine := {}
		for bone in torso_bones: spine[bone] = sk.get_bone_pose_rotation(bone)
		var feet := []
		for limb in dragon.ground_pose.limbs:
			feet.append({"target":limb.actual,"phase":fposmod(dragon.walk_cycle_phase/TAU+float(limb.phase),1.0),"pole":limb.get("pole_world",Vector3.UP),"basis":limb.foot_basis,"yaw":limb.get("foot_yaw",dragon.rotation.y)})
		var limb_rotations := {}
		for bone in all_limb_bones:
			limb_rotations[bone] = sk.get_bone_pose_rotation(bone)
		var rotations:Dictionary={}
		for bone in sk.get_bone_count():rotations[bone]=sk.get_bone_pose_rotation(bone)
		body_pose_safe = {"tail":tail,"spine":spine,"visual":dragon.visual_root.transform,"feet":feet,"limb_rotations":limb_rotations,"actor":dragon.global_transform,"rotations":rotations,"gait":dragon.ground_pose.limbs.duplicate(true)}
	# Publish support geometry after every body/wing recovery has finished.
	for limb in dragon.ground_pose.limbs:
		if int(limb.end) in [8,23]:
			# Recovery can change the solved articulation. Continue from the
			# final rendered pose rather than an earlier, rejected IK pass.
			var published_rotations:Dictionary={}
			for bone in limb.chain:
				published_rotations[bone]=(dragon.global_basis.inverse()*sk.global_basis*sk.get_bone_global_pose(bone).basis).get_rotation_quaternion()
			limb.support_rotations=published_rotations
		limb.published_hip_actor=dragon.to_local(sk.to_global(sk.get_bone_global_pose(limb.chain[0]).origin))
		limb.published_wrist=sk.to_global(sk.get_bone_global_pose(limb.end).origin)
		if not limb.swinging and not limb.contact_sample.is_empty():
			# A blocked pose can lift a foot: constrain to the true planted skin
			# anchor, never let its displaced rendered wrist redefine support.
			limb.published_wrist+=limb.contact_anchor-limb.probe.point(sk,limb.contact_sample)
		var reach:=0.0
		for index in limb.chain.size():
			var child:int=int(limb.chain[index+1]) if index+1<limb.chain.size() else int(limb.end)
			reach+=sk.to_global(sk.get_bone_global_pose(limb.chain[index]).origin).distance_to(sk.to_global(sk.get_bone_global_pose(child).origin))
		limb.published_reach=reach
	publish_tail(dragon,sk)
	_end_body_query_scope()

func publish_tail(dragon:Node3D,sk:Skeleton3D) -> void:
	if dragon.bone_tail_indices.is_empty():return
	tail_published=(sk.global_basis*sk.get_bone_global_pose(dragon.bone_tail_indices[0]).basis).orthonormalized().get_rotation_quaternion()
	tail_initialized=true

func guard_tail_terrain(dragon:Node3D,sk:Skeleton3D) -> void:
	if dragon.bone_tail_indices.is_empty() or final_hull_points.is_empty():return
	# Analytic clearance is available on the landscape, while flat test floors
	# use ordinary physics bodies and retain the final physical body guard.
	if not is_instance_valid(dragon.landscape) or not dragon.landscape.has_method("ground_height"):return
	if dragon.locomotion_state not in [dragon.LocomotionState.LANDING,dragon.LocomotionState.GROUNDED]:return
	if dragon.locomotion_state==dragon.LocomotionState.LANDING and dragon.ground_proximity>12:return
	var bone:int=dragon.bone_tail_indices[0]
	var current:Quaternion=(sk.global_basis*sk.get_bone_global_pose(bone).basis).orthonormalized().get_rotation_quaternion()
	if tail_frame!=Engine.get_physics_frames():
		tail_frame=Engine.get_physics_frames()
		tail_anchor=tail_published if tail_initialized else current
	var worst:=INF
	var lowest:=Vector3.ZERO
	var points:PackedVector3Array=final_hull_points[2]
	for slot in tail_hull_slots:
		var world:Vector3=dragon.to_global(points[slot])
		var local:Vector3=dragon.landscape.to_local(world)
		var ground:float=dragon.landscape.to_global(Vector3(local.x,dragon.landscape.ground_height(local.x,local.z),local.z)).y
		if world.y-ground<worst:worst=world.y-ground;lowest=world
	# Begin lifting before touchdown; reserve room for the next descent tick
	# instead of waiting until a low tail has already crossed the surface.
	if worst>=.12:return
	var pivot:Vector3=sk.to_global(sk.get_bone_global_pose(bone).origin)
	var wanted:Quaternion=Quaternion((lowest-pivot).normalized(),(lowest+Vector3.UP*(.12-worst)-pivot).normalized())*current
	var angle:float=tail_anchor.angle_to(wanted)
	var accepted:Quaternion=tail_anchor.slerp(wanted,minf(1.0,deg_to_rad(4.0)/maxf(angle,.000001)))
	var parent:int=sk.get_bone_parent(bone)
	var parent_q:Quaternion=(sk.global_basis*sk.get_bone_global_pose(parent).basis).orthonormalized().get_rotation_quaternion()
	sk.set_bone_pose_rotation(bone,parent_q.inverse()*accepted)
	sample_final(dragon,sk)

func _wing_contact(dragon: Node3D, side: int) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = hulls[side]
	query.transform = dragon.global_transform
	query.exclude = [dragon.get_rid()]
	query.collision_mask = 3
	query.margin = 0.0
	return not dragon.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func guard_grounded_wings(dragon: Node3D, sk: Skeleton3D) -> void:
	# The translation sweep used the previously rendered pose. Reject only a
	# new wing articulation that intersects after that sweep; feet and free
	# head retain this tick's world targets and freshly solved rotations.
	for side in 2:
		var root_bone: int = 96 if side==0 else 120
		if _limit_wing_frame(sk,root_bone): sample_final(dragon,sk)
		if _wing_contact(dragon,side) and wing_pose_safe.has(side):
			var saved: Dictionary = wing_pose_safe[side]
			for bone in saved.rotations:
				sk.set_bone_pose_rotation(int(bone),saved.rotations[bone])
			_limit_wing_frame(sk,root_bone)
			sample_final(dragon,sk)
			wing_pose_metrics.restored += 1
			if _wing_contact(dragon,side):
				# A changed body parent must not drag the cached wing angle into
				# the wall. Preserve its actor-relative orientation at the real
				# current root, changing only this wing root's pose rotation.
				var parent: int = sk.get_bone_parent(root_bone)
				var parent_basis := sk.get_bone_global_pose(parent).basis.orthonormalized() if parent>=0 else Basis.IDENTITY
				var desired_basis: Basis = sk.global_basis.orthonormalized().inverse()*dragon.global_basis.orthonormalized()*saved.body_basis
				var local_basis: Basis = parent_basis.inverse()*desired_basis
				sk.set_bone_pose_rotation(root_bone,local_basis.orthonormalized().get_rotation_quaternion())
				_limit_wing_frame(sk,root_bone)
				sample_final(dragon,sk)
				wing_pose_metrics.body_compensated += 1
		# The first grounded frame may not have a saved wing pose yet.
		# Its real contact still needs the same bounded fold correction.
		if _wing_contact(dragon,side) and _fold_wing_away(dragon,sk,side,root_bone):
			wing_pose_metrics.folded += 1
		if _wing_contact(dragon,side):
			wing_pose_metrics.uncleared += 1
			dragon.contact_fold_requested = 1.0
		for bone in bone_descendants[root_bone]:
			wing_published[bone]=(sk.global_basis*sk.get_bone_global_pose(bone).basis).orthonormalized().get_rotation_quaternion()
		if _wing_contact(dragon,side): continue
		var rotations := {}
		for bone in bone_descendants[root_bone]:
			rotations[bone]=sk.get_bone_pose_rotation(bone)
		var body_basis: Basis = dragon.global_basis.orthonormalized().inverse()*sk.global_basis.orthonormalized()*sk.get_bone_global_pose(root_bone).basis.orthonormalized()
		wing_pose_safe[side]={"rotations":rotations,"body_basis":body_basis}


func _limit_wing_frame(sk: Skeleton3D, root_bone: int) -> bool:
	var changed := false
	var desired := {}
	for bone in bone_descendants[root_bone]:
		desired[bone]=(sk.global_basis*sk.get_bone_global_pose(bone).basis).orthonormalized().get_rotation_quaternion()
	for bone in desired:
		if not wing_published.has(bone): continue
		var previous: Quaternion = wing_published[bone]
		var wanted: Quaternion = desired[bone]
		var angle := previous.angle_to(wanted)
		if angle<=deg_to_rad(4.0): continue
		var target := previous.slerp(wanted,deg_to_rad(4.0)/angle)
		var parent: int = sk.get_bone_parent(bone)
		var parent_world := (sk.global_basis*sk.get_bone_global_pose(parent).basis).orthonormalized().get_rotation_quaternion() if parent>=0 else sk.global_basis.orthonormalized().get_rotation_quaternion()
		sk.set_bone_pose_rotation(bone,parent_world.inverse()*target)
		changed = true
	return changed

func _fold_wing_away(dragon: Node3D, sk: Skeleton3D, side: int, root_bone: int) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=hulls[side]
	query.transform=dragon.global_transform
	query.exclude=[dragon.get_rid()]
	query.collision_mask=3
	query.margin=0.0
	var pairs := dragon.get_world_3d().direct_space_state.collide_shape(query,32)
	var deepest := 0.0
	var contact := Vector3.ZERO
	var normal := Vector3.ZERO
	for index in range(0,pairs.size()-1,2):
		var separation: Vector3 = pairs[index+1]-pairs[index]
		if separation.length()>deepest:
			deepest=separation.length()
			contact=pairs[index]
			normal=separation.normalized()
	# A zero-depth tangent can intersect without a usable contact normal.
	# The 1mm witness is diagnostic only; every accepted pose is rechecked
	# against the original zero-margin hull and both terrain/prop layers.
	if deepest<=.0001:
		# World-space float witnesses at this scene scale vary by 15–34um.
		# Obtain a stable normal instead of steering by that numerical residue.
		deepest=0.0
		contact=Vector3.ZERO
		normal=Vector3.ZERO
		query.margin=.001
		pairs=dragon.get_world_3d().direct_space_state.collide_shape(query,32)
		for index in range(0,pairs.size()-1,2):
			var separation: Vector3=pairs[index+1]-pairs[index]
			if separation.length()>deepest:
				deepest=separation.length()
				contact=pairs[index]
				normal=separation.normalized()
	var diagnostic := OS.get_cmdline_user_args().has("--wing-tangency-diagnostic")
	var pivot := sk.to_global(sk.get_bone_global_pose(root_bone).origin)
	var axis := (contact-pivot).cross(normal)
	if diagnostic: print("WING_WITNESS frame=",Engine.get_physics_frames()," side=",side," depth=",deepest," pairs=",pairs.size()," normal=",normal," axis=",axis," margin=",query.margin)
	if axis.length_squared()<.000001: return false
	var baseline := {}
	for bone in bone_descendants[root_bone]:
		baseline[bone]=sk.get_bone_pose_rotation(bone)
	var baseline_world := (sk.global_basis*sk.get_bone_global_pose(root_bone).basis).orthonormalized().get_rotation_quaternion()
	for step in range(1,17):
		for bone in baseline: sk.set_bone_pose_rotation(int(bone),baseline[bone])
		dragon._rotate_bone_world(sk,root_bone,axis.normalized(),deg_to_rad(float(step)*.25))
		_limit_wing_frame(sk,root_bone)
		sample_final(dragon,sk)
		if not _wing_contact(dragon,side):
			if diagnostic: print("WING_FOLD_CLEAR frame=",Engine.get_physics_frames()," side=",side," trial_deg=",float(step)*.25)
			return true
		if diagnostic and step in [1,16]:
			var published: Quaternion = wing_published.get(root_bone,baseline_world)
			var actual := (sk.global_basis*sk.get_bone_global_pose(root_bone).basis).orthonormalized().get_rotation_quaternion()
			print("WING_FOLD_BLOCKED frame=",Engine.get_physics_frames()," side=",side," trial_deg=",float(step)*.25," world_step_deg=",rad_to_deg(published.angle_to(actual)))
	for bone in baseline: sk.set_bone_pose_rotation(int(bone),baseline[bone])
	sample_final(dragon,sk)
	return false


func _body_contact(dragon: Node3D, mask: int = 3) -> bool:
	# Reuse only identical queries inside this synchronous body modifier. Any
	# published pose, jaw update or actor transform change invalidates the results.
	if body_query_scope_active and body_query_actor!=dragon.global_transform:
		_invalidate_body_query_cache()
		body_query_actor=dragon.global_transform
	var space: PhysicsDirectSpaceState3D = dragon.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.transform = dragon.global_transform
	query.exclude = [dragon.get_rid()]
	for index in body_indices:
		query.shape = hulls[index]
		for layer in [1,2]:
			if (mask&layer)==0:continue
			query.collision_mask=layer
			# Convex queries with an inflated margin can miss a contact that
			# the original shape detects. Certify both the skin enclosure and
			# its existing 3 mm reserve before saving a safe pose.
			for margin_index in range(2 if layer==2 else 1):
				query.margin=.003 if margin_index==1 else 0.0
				var key: int = index*3+(1+margin_index if layer==2 else 0)
				var hits: Array[Dictionary] = []
				if body_query_scope_active and body_query_cache.has(key):
					hits=body_query_cache[key]
				else:
					hits=space.intersect_shape(query,1)
					if body_query_scope_active: body_query_cache[key]=hits
				if not hits.is_empty():
					body_contact_index = index
					if OS.get_cmdline_user_args().has("--body-pose-diagnostic"):
						print("BODY_HULL_CONTACT frame=",Engine.get_physics_frames()," hull=",index," collider=",hits[0].collider.get_path()," pairs=",space.collide_shape(query,4))
					return true
	return false

func _rotation_contact(dragon: Node3D, mask: int = 3) -> bool:
	var space := dragon.get_world_3d().direct_space_state
	for index in hulls.size():
		if hulls[index].points.size() < 4: continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = hulls[index]
		query.transform = dragon.global_transform
		query.exclude = [dragon.get_rid()]
		query.margin = 0.003 # Reserve clearance for final stabilizer/IK and float32 skin coordinates.
		query.collision_mask = mask
		if not space.intersect_shape(query,1).is_empty(): return true
	return false

func constrain_rotation(dragon: Node3D, previous: Vector3) -> void:
	dragon.pose_turn_blocked = false
	if hulls.is_empty(): return
	var wanted: Vector3 = dragon.rotation
	var yaw_delta := wrapf(wanted.y-previous.y,-PI,PI)
	var angular_change := Vector3(wanted.x-previous.x,yaw_delta,wanted.z-previous.z).length()
	if angular_change<0.00001 or not _rotation_contact(dragon): return
	# Landing changes the stabilizer and limb pose after this rigid check. An
	# already overlapping predecessor cannot certify a safe rigid interpolation.
	# Let the final skinned-pose guard resolve that transition instead of freezing
	# an airborne bank while the grounded stabilizer is still blending.
	if absf(yaw_delta)<0.00001:
		if dragon.locomotion_state==dragon.LocomotionState.GROUNDED and dragon.ground_blend<0.99: return
		dragon.rotation = previous
		var previous_contact := _rotation_contact(dragon)
		var previous_prop_contact := _rotation_contact(dragon,2)
		dragon.rotation = wanted
		# Terrain penetration needs an IK refit; a trunk never authorizes an
		# unchecked pitch/roll after yaw has reached its collision limit.
		if previous_contact and not previous_prop_contact: return
	var low := 0.0
	var high := 1.0
	for attempt in 8:
		var amount := (low+high)*0.5
		var candidate := previous.lerp(wanted,amount)
		candidate.y = previous.y + yaw_delta*amount
		dragon.rotation = candidate
		if _rotation_contact(dragon): high = amount
		else: low = amount
	var safe := previous.lerp(wanted,low)
	safe.y = previous.y + yaw_delta*low
	dragon.rotation = safe
	dragon.target_yaw = safe.y
	dragon.smoothed_turn_rate = 0.0
	dragon.pose_turn_blocked = true
