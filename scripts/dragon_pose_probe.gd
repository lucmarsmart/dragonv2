extends RefCounted
# CPU skinning of the visible mesh. Skin bind indices are resolved explicitly;
# bone origins alone cannot detect a membrane or claw crossing the collision surface.
static var profiling := OS.get_cmdline_user_args().has("--anatomy-profile")
static var costs: Dictionary = {}
var profile_label := "skin"

static func record(label: String, started: int) -> void:
	if not profiling: return
	var elapsed := Time.get_ticks_usec()-started
	var entry: Dictionary = costs.get(label,{"calls":0,"total_us":0,"max_us":0})
	entry.calls += 1
	entry.total_us += elapsed
	entry.max_us = maxi(entry.max_us,elapsed)
	costs[label] = entry

var samples: Array[Dictionary] = []
var bone_map: Dictionary = {}
var mesh_count := 0
var flat_count := -1
var flat_vertices := PackedVector3Array()
var flat_offsets := PackedInt32Array()
var flat_keys := PackedInt32Array()
var flat_weights := PackedFloat32Array()
var flat_bones := PackedInt32Array()
var flat_binds: Array[Transform3D] = []

func configure(dragon: Node3D, sk: Skeleton3D, stride: int = 12) -> void:
	samples.clear()
	flat_count = -1
	mesh_count = 0
	bone_map.clear()
	for b in sk.get_bone_count():
		var ancestor := b
		var wing := false
		var wing_side_mask := 0
		var claw := -1
		var neck := false
		while ancestor >= 0:
			if ancestor in [96,120]:
				wing = true
				wing_side_mask |= 1 if ancestor==96 else 2
			if ancestor in [8,23,41,82]: claw = ancestor
			if sk.get_bone_name(ancestor) in ["Bip001-Neck1_09","Bip001-Neck2_010","Bip001-Head_011"]: neck = true
			ancestor = sk.get_bone_parent(ancestor)
		bone_map[b] = {"wing":wing,"wing_side_mask":wing_side_mask,"claw":claw,"neck":neck}
	_collect(dragon, sk, stride)

func _collect(node: Node, sk: Skeleton3D, stride: int) -> void:
	if node is MeshInstance3D and node.mesh and node.skin:
		mesh_count += 1
		var skin: Skin = node.skin
		var binds: Array[Dictionary] = []
		for i in skin.get_bind_count():
			var b := skin.get_bind_bone(i)
			if not skin.get_bind_name(i).is_empty():
				b = sk.find_bone(skin.get_bind_name(i))
			binds.append({"bone": b, "pose": skin.get_bind_pose(i)})
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			if bones == null or weights == null:
				continue
			var influence_count: int = bones.size() / vertices.size()
			var surface_samples := {}
			for v in range(0, vertices.size(), stride):
				var influence: Array[Dictionary] = []
				var wing := false
				var wing_side_mask := 0
				var claw := -1
				var claw_weights: Dictionary = {}
				var neck_weight := 0.0
				for slot in influence_count:
					var offset := v * influence_count + slot
					if weights[offset] < 0.001:
						continue
					var bind: Dictionary = binds[bones[offset]]
					var b: int = bind.bone
					influence.append({"bone": b, "bind": bind.pose, "weight": weights[offset], "key": mesh_count * 1000 + int(bones[offset])})
					var flags: Dictionary = bone_map[b]
					wing = wing or flags.wing
					wing_side_mask |= int(flags.wing_side_mask)
					if int(flags.claw) >= 0: claw_weights[flags.claw] = float(claw_weights.get(flags.claw,0.0)) + float(weights[offset])
					if flags.neck: neck_weight += float(weights[offset])
				var limb_claw := -1
				var limb_weight := 0.0
				for candidate in claw_weights:
					if float(claw_weights[candidate])>limb_weight:
						limb_weight = float(claw_weights[candidate])
						limb_claw = int(candidate)
				var largest_weight := 0.64
				for candidate in claw_weights:
					if float(claw_weights[candidate]) > largest_weight:
						largest_weight = float(claw_weights[candidate])
						claw = int(candidate)
				if not influence.is_empty():
					var sample := {"vertex": vertices[v], "influence": influence, "wing": wing, "wing_root_mask":wing_side_mask,"wing_side_mask":wing_side_mask,"neck": neck_weight >= 0.65, "claw": claw, "limb_claw":limb_claw, "mesh": node.name, "surface": surface, "index": v}
					samples.append(sample)
					surface_samples[v]=sample
			# A face joining roots belongs completely to both pieces. Read immutable
			# root masks so duplication stays a single boundary ring, not a flood fill.
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			for offset in range(0,indices.size(),3):
				var root_mask := 0
				for corner in 3:
					if surface_samples.has(indices[offset+corner]): root_mask |= int(surface_samples[indices[offset+corner]].wing_root_mask)
				if root_mask!=3: continue
				for corner in 3:
					if surface_samples.has(indices[offset+corner]) and surface_samples[indices[offset+corner]].wing:
						surface_samples[indices[offset+corner]].wing_side_mask=3
	for child in node.get_children():
		_collect(child, sk, stride)

func points(sk: Skeleton3D, wings_only: bool = false) -> Array[Dictionary]:
	var started := Time.get_ticks_usec() if profiling else 0
	var poses: Dictionary = {}
	var result: Array[Dictionary] = []
	for sample in samples:
		if wings_only and not sample.wing: continue
		var p := Vector3.ZERO
		for influence in sample.influence:
			var key: int = influence.key
			if not poses.has(key): poses[key] = sk.get_bone_global_pose(influence.bone) * influence.bind
			p += poses[key] * sample.vertex * float(influence.weight)
		result.append({"position": sk.to_global(p), "sample": sample})
	record(profile_label,started)
	return result

func ground_report(dragon: Node3D, sk: Skeleton3D) -> Dictionary:
	var worst := 0.0
	var under := 0
	var checked := 0
	var worst_point := Vector3.ZERO
	var worst_collider := ""
	var claw_min: Dictionary = {}
	var prop_checked := 0
	var unsupported_props := 0
	var space := dragon.get_world_3d().direct_space_state
	for point in points(sk):
		var sample: Dictionary = point.sample
		if not sample.wing and int(sample.claw) < 0: continue
		var p: Vector3 = point.position
		# Terrain is a height surface. A trunk's upper cap is not the local
		# penetration depth of a membrane touching its side.
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 30.0, p + Vector3.DOWN * 40.0, 1)
		q.exclude = [dragon.get_rid()]
		var hit := dragon.get_world_3d().direct_space_state.intersect_ray(q)
		var clearance := INF
		if not hit.is_empty():
			checked += 1
			clearance = p.y-hit.position.y
		if sample.wing and clearance < worst:
			worst = clearance
			worst_point = p
			worst_collider = str(hit.collider.get_path())
		if sample.wing and clearance < -0.05: under += 1
		if int(sample.claw) >= 0:
			var c: int = sample.claw
			claw_min[c] = minf(float(claw_min.get(c, INF)), clearance)
		if sample.wing:
			var query := PhysicsPointQueryParameters3D.new()
			query.position = p
			query.collision_mask = 2
			query.exclude = [dragon.get_rid()]
			prop_checked += 1
			for contact in space.intersect_point(query,8):
				var body: CollisionObject3D = contact.collider
				var owner := body.shape_owner_get_owner(body.shape_find_owner(contact.shape)) as CollisionShape3D
				if not owner or not (owner.shape is CylinderShape3D):
					unsupported_props += 1
					under += 1 # An unmeasured solid contact cannot certify separation.
					continue
				var local := owner.to_local(p)
				var scale := owner.global_basis.get_scale()
				var depth := minf((owner.shape.radius-Vector2(local.x,local.z).length())*minf(scale.x,scale.z),(owner.shape.height*.5-absf(local.y))*scale.y)
				if depth>0 and -depth<worst:
					worst = -depth
					worst_point = p
					worst_collider = str(body.get_path())
				if depth>.05: under += 1
	return {"minimum_wing_clearance": worst, "penetrating_samples": under, "checked": checked, "worst_point": worst_point, "worst_collider":worst_collider, "claw_clearance": claw_min,"prop_vertices_checked":prop_checked,"unsupported_prop_contacts":unsupported_props}

# Convex-hull indices are ORIGINAL vertices from exact bind/weight groups.
# Each group's skinning is affine, so its support encloses all its vertices at
# every bone pose. The offline verifier checks every group; changed assets fall back.
static var affine_support: Dictionary = {}
static var affine_loaded := false

func reduce_affine_support() -> Dictionary:
	if not affine_loaded:
		affine_loaded = true
		if FileAccess.file_exists("res://scripts/dragon_affine_support.json"):
			var data = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/dragon_affine_support.json"))
			if data is Dictionary and data.get("source_sha256","") == FileAccess.get_sha256("res://assets/models/dragon.glb"):
				affine_support = data.get("groups",{})
	var before := samples.size()
	var groups := {}
	for sample in samples:
		var identity: Array = [sample.mesh]
		for influence in sample.influence:
			identity.append([influence.key,influence.bone,influence.bind,influence.weight])
		var key := var_to_bytes(identity).hex_encode()
		if not groups.has(key): groups[key] = []
		groups[key].append(sample)
	if OS.get_cmdline_user_args().has("--collect-affine"):
		var audit: Array = []
		for key in groups:
			var cloud: Array = []
			for sample in groups[key]: cloud.append([sample.vertex.x,sample.vertex.y,sample.vertex.z])
			audit.append({"identity_hex":key,"full":cloud,"support":cloud})
		var output := FileAccess.open("res://docs/validation/v2/anatomy-affine-%s.json" % profile_label,FileAccess.WRITE)
		output.store_string(JSON.stringify({"stats":{"original":before,"groups":groups.size()},"groups":audit}))
	var reduced: Array[Dictionary] = []
	for key in groups:
		var group: Array = groups[key]
		var support: Dictionary = affine_support.get(key,{})
		var indices: Array = support.get("indices",[])
		var valid := not indices.is_empty() and int(support.get("count",-1)) == group.size()
		for index in indices:
			if int(index)<0 or int(index)>=group.size(): valid = false
		if valid:
			for index in indices: reduced.append(group[int(index)])
		else: reduced.append_array(group)
	samples = reduced
	flat_count = -1
	var stats := {"original":before,"support":samples.size(),"groups":groups.size()}
	if profiling: print("AFFINE_SUPPORT ",profile_label," ",JSON.stringify(stats))
	return stats

func point(sk: Skeleton3D, sample: Dictionary) -> Vector3:
	var p := Vector3.ZERO
	for influence in sample.influence:
		p += (sk.get_bone_global_pose(influence.bone) * influence.bind) * sample.vertex * float(influence.weight)
	return sk.to_global(p)

# Production volumes need coordinates only. Avoid two per-vertex world/local node
# calls and dictionary allocation; diagnostic points() retains independent samples.
func _flatten_coordinates() -> void:
	flat_count = samples.size()
	flat_vertices.clear()
	flat_offsets.clear()
	flat_keys.clear()
	flat_weights.clear()
	flat_bones.clear()
	flat_binds.clear()
	var indices := {}
	for sample in samples:
		flat_vertices.append(sample.vertex)
		flat_offsets.append(flat_keys.size())
		for influence in sample.influence:
			var source: int = influence.key
			if not indices.has(source):
				indices[source] = flat_bones.size()
				flat_bones.append(influence.bone)
				flat_binds.append(influence.bind)
			flat_keys.append(indices[source])
			# GLB weights are float32; packing preserves every original bit.
			flat_weights.append(influence.weight)
	flat_offsets.append(flat_keys.size())

# Only immutable vertices/binds/weights are flattened here; no current bone pose.
func prepare_coordinates() -> void:
	if flat_count != samples.size(): _flatten_coordinates()

func coordinates(sk: Skeleton3D, relative: Node3D = null) -> PackedVector3Array:
	var started := Time.get_ticks_usec() if profiling else 0
	if flat_count != samples.size(): _flatten_coordinates()
	var poses: Array[Transform3D] = []
	poses.resize(flat_bones.size())
	for index in flat_bones.size():
		poses[index] = sk.get_bone_global_pose(flat_bones[index])*flat_binds[index]
	var result := PackedVector3Array()
	result.resize(flat_vertices.size())
	var placement := sk.global_transform
	if relative != null: placement = relative.global_transform.affine_inverse()*placement
	for index in flat_vertices.size():
		var vertex := flat_vertices[index]
		var p := Vector3.ZERO
		for influence in range(flat_offsets[index],flat_offsets[index+1]):
			p += poses[flat_keys[influence]]*vertex*flat_weights[influence]
		result[index] = placement*p
	record(profile_label,started)
	return result
