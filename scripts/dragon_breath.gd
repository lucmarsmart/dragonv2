extends Node3D
class_name DragonBreath

## Bounded breath: a head-mounted emitter, occlusion ray fan and a recoverable fuel reserve.
@export var max_reach: float = 26.0
@export var drain_per_second: float = 0.19
@export var recover_per_second: float = 0.12
var fuel: float = 1.0
var exhausted: bool = false
var intensity: float = 0.0
var is_firing: bool = false
var requested: bool = false
var manual_override: bool = false
var manual_fire: bool = false
var hit_distance: float = 26.0
var hit_position: Vector3 = Vector3.ZERO
var hit_normal: Vector3 = Vector3.UP
var impact_active: bool = false
var hit_collider_id: int = 0
var core_distance: float = 26.0
var core_impact_active: bool = false
var core_impact_point := Vector3.ZERO
var core_impact_normal := Vector3.UP
var effect_resets: int = 0
var mouth_position: Vector3 = Vector3.ZERO
var mouth_actor_local := Vector3.ZERO
var direction_actor_local := Vector3.FORWARD
var mouth_pose_cached := false
var rendered_snout_tip: Vector3 = Vector3.ZERO
var rendered_oral_upper: Vector3 = Vector3.ZERO
var rendered_oral_lower: Vector3 = Vector3.ZERO
var rendered_oral_center: Vector3 = Vector3.ZERO
var mouth_landmarks_valid := false
var mouth_samples: Array[Dictionary] = []
var breath_direction: Vector3 = Vector3.FORWARD
var flames: CPUParticles3D
var smoke: CPUParticles3D
var embers: CPUParticles3D
var impact: CPUParticles3D
var glow: OmniLight3D
var impact_glow: OmniLight3D
var flame_material: ShaderMaterial
var smoke_material: ShaderMaterial
var dragon: CharacterBody3D
var sound: AudioStreamPlayer3D
var noise_rng := RandomNumberGenerator.new()
var mouth_bone: int = -1
var jaw_modifier: SkeletonModifier3D
var jet_probe := SphereShape3D.new()

func _ready() -> void:
	dragon = get_parent() as CharacterBody3D
	set_as_top_level(true)
	flame_material = ShaderMaterial.new()
	flame_material.shader = preload("res://shaders/flame.gdshader")
	smoke_material = ShaderMaterial.new()
	smoke_material.shader = preload("res://shaders/smoke.gdshader")
	flames = _particles("Flame", 200, 0.65, 35.0, 43.0, 7.0, 0.65, 2.6, flame_material, false)
	flames.color_ramp = _ramp([Color(1.0,0.88,0.45,0.7),Color(1.0,0.82,0.34,0.85),Color(1.0,0.28,0.025,0.9),Color(0.32,0.035,0.005,0.0)], [0.0,0.09,0.48,1.0])
	smoke = _particles("Smoke", 52, 0.85, 18.0, 29.0, 9.0, 1.3, 3.8, smoke_material, false)
	smoke.gravity = Vector3(0,4,0)
	smoke.color_ramp = _ramp([Color(0.2,0.14,0.1,0),Color(0.18,0.15,0.13,0.7),Color(0.26,0.25,0.24,0)], [0.0,0.3,1.0])
	embers = _particles("Embers", 64, 0.75, 28.0, 44.0, 13.0, 0.05, 0.14, flame_material, false)
	embers.gravity = Vector3(0,-2,0)
	embers.color_ramp = _ramp([Color(1,0.66,0.14,1),Color(1,0.15,0.01,0)], [0.0,1.0])
	var impact_mat := StandardMaterial3D.new()
	impact_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	impact_mat.albedo_color = Color(1,0.37,0.025)
	impact_mat.emission_enabled = true
	impact_mat.emission = Color(1,0.22,0.01)
	impact_mat.emission_energy_multiplier = 3.0
	impact = _particles("ImpactSparks", 48, 0.45, 2.0, 8.0, 75.0, 0.04, 0.12, impact_mat, true)
	impact.set_as_top_level(true)
	impact.gravity = Vector3(0,-8,0)
	glow = OmniLight3D.new()
	glow.name = "BreathLight"
	glow.light_color = Color(1.0,0.38,0.07)
	glow.omni_range = 18.0
	glow.light_energy = 0.0
	add_child(glow)
	impact_glow = OmniLight3D.new()
	impact_glow.light_color = Color(1.0,0.28,0.025)
	impact_glow.omni_range = 9.0
	impact_glow.light_energy = 0.0
	add_child(impact_glow)
	impact_glow.set_as_top_level(true)
	_setup_audio()

func _particles(label: String, count: int, life: float, speed_min: float, speed_max: float, spread_angle: float, scale_min: float, scale_max: float, material: Material, sparks: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = label
	p.amount = count
	p.lifetime = life
	p.emitting = false
	p.local_coords = false
	p.direction = Vector3.FORWARD
	p.spread = spread_angle
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.gravity = Vector3(0,1.2,0)
	p.scale_amount_min = scale_min
	p.scale_amount_max = scale_max
	p.randomness = 0.45
	if sparks:
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		m.radial_segments = 6
		m.rings = 3
		m.material = material
		p.mesh = m
	else:
		var m := QuadMesh.new()
		m.size = Vector2(1.0,1.0)
		m.material = material
		p.mesh = m
	var c := Curve.new()
	c.add_point(Vector2(0,0.35))
	c.add_point(Vector2(0.4,1))
	c.add_point(Vector2(1,1.5))
	p.scale_amount_curve = c
	add_child(p)
	return p

func _ramp(colors: Array[Color], offsets: Array[float]) -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray(colors)
	g.offsets = PackedFloat32Array(offsets)
	return g

func set_firing(active: bool) -> void:
	requested = active

func _physics_process(delta: float) -> void:
	if not dragon or dragon.calibrating or not dragon.skeleton:
		return
	if not jaw_modifier:
		jaw_modifier = preload("res://scripts/dragon_breath_modifier.gd").new()
		jaw_modifier.breath = self
		jaw_modifier.name = "BreathJawModifier"
		dragon.skeleton.add_child(jaw_modifier)
		mouth_bone = dragon.skeleton.find_bone("Point021_018")
		_configure_mouth_landmarks(dragon, dragon.skeleton)
	var input_active: bool = manual_fire if manual_override else (requested or Input.is_key_pressed(KEY_F) or (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and dragon.mouse_captured))
	if exhausted and fuel >= 0.3:
		exhausted = false
	is_firing = input_active and not exhausted and fuel > 0.0
	if is_firing:
		fuel = maxf(0, fuel - drain_per_second * delta)
		if fuel <= 0:
			exhausted = true
			is_firing = false
	else:
		fuel = minf(1, fuel + recover_per_second * delta)
	intensity = move_toward(intensity, 1.0 if is_firing else 0.0, delta * (7.0 if is_firing else 4.0))
	var previous_impact := impact_active
	var previous_point := hit_position
	var previous_normal := hit_normal
	_detect_impact()
	# World-space particles hidden behind an old plane must not reappear after turning away.
	if previous_impact and (not impact_active or previous_normal.dot(hit_normal) < 0.9 or previous_point.distance_to(hit_position) > 4.0):
		for emitter in [flames, smoke, embers]:
			emitter.restart()
		effect_resets += 1
	for mat in [flame_material, smoke_material]:
		mat.set_shader_parameter("attack_view", dragon.attack_mode_active)
		mat.set_shader_parameter("mouth_position", mouth_position)
		mat.set_shader_parameter("breath_direction", breath_direction)
		mat.set_shader_parameter("reach", core_distance)
		mat.set_shader_parameter("has_impact", core_impact_active)
		mat.set_shader_parameter("impact_point", core_impact_point)
		mat.set_shader_parameter("impact_normal", core_impact_normal)
	flames.emitting = is_firing
	smoke.emitting = is_firing
	embers.emitting = is_firing
	flames.initial_velocity_min = 35.0 + maxf(0, dragon.velocity.dot(breath_direction)) * 0.45
	flames.initial_velocity_max = flames.initial_velocity_min + 8.0
	glow.position = Vector3(0,0,-1.5)
	glow.light_energy = intensity * (3.0 + sin(Time.get_ticks_msec() * 0.027) * 0.35)
	impact.emitting = is_firing and impact_active
	impact_glow.light_energy = intensity * 2.5 if impact_active else 0.0

func _configure_mouth_landmarks(node: Node, sk: Skeleton3D) -> void:
	# Original CC-BY asset vertices: upper oral rim, then mandibular oral rim.
	# Point021_018 lies at the nasal socket and remains a direction landmark only.
	if node is MeshInstance3D and node.name == "Object_8" and node.mesh and node.skin:
		mouth_samples.clear()
		var arrays: Array = node.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones = arrays[Mesh.ARRAY_BONES]
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		if bones == null or weights == null or vertices.size() <= 6748: return
		var slots: int = bones.size() / vertices.size()
		# The importer reorders vertices. Resolve the exact original POSITION and
		# rigid bone identity, rather than treating a GLB index as an imported index.
		var positions: Array[Vector3] = [Vector3(-3.76998233795166,0.6621770858764648,11.446301460266113),Vector3(-3.7699837684631348,0.5364508628845215,11.267938613891602)]
		var names := ["Bip001-Head_011","Bone015_012"]
		var original_indices := [6748,1653]
		for landmark in 2:
			var index: int = vertices.find(positions[landmark])
			while index >= 0:
				var influence: Array[Dictionary] = []
				for slot in slots:
					var offset: int = index*slots+slot
					if weights[offset] <= 0.0: continue
					var bind_index: int = bones[offset]
					var bone: int = node.skin.get_bind_bone(bind_index)
					var bind_name: StringName = node.skin.get_bind_name(bind_index)
					if not bind_name.is_empty(): bone = sk.find_bone(bind_name)
					if bone < 0: continue
					influence.append({"bone":bone,"bind":node.skin.get_bind_pose(bind_index),"weight":weights[offset]})
				if influence.size()==1 and sk.get_bone_name(influence[0].bone)==names[landmark] and float(influence[0].weight)==1.0:
					mouth_samples.append({"original_index":original_indices[landmark],"imported_index":index,"vertex":vertices[index],"influence":influence})
					break
				index = vertices.find(positions[landmark],index+1)
		return
	for child in node.get_children():
		_configure_mouth_landmarks(child,sk)

func _mouth_skin_point(sk: Skeleton3D, sample: Dictionary) -> Vector3:
	var point := Vector3.ZERO
	for influence in sample.influence:
		point += (sk.get_bone_global_pose(influence.bone)*influence.bind)*sample.vertex*float(influence.weight)
	return sk.to_global(point)

func _update_mouth() -> void:
	var sk: Skeleton3D = dragon.skeleton
	var head: int = dragon.bone_head_idx
	if head < 0:
		return
	var head_pos: Vector3 = sk.global_transform * sk.get_bone_global_pose(head).origin
	var neck_pos: Vector3 = head_pos + dragon.global_basis.z
	if not dragon.bone_neck_indices.is_empty():
		neck_pos = sk.global_transform * sk.get_bone_global_pose(dragon.bone_neck_indices.back()).origin
	breath_direction = (head_pos - neck_pos).normalized()
	if breath_direction.length_squared() < 0.1:
		breath_direction = -dragon.global_basis.z.normalized()
	if mouth_bone >= 0:
		var snout := sk.to_global(sk.get_bone_global_pose(mouth_bone).origin)
		breath_direction = (snout - head_pos).normalized()
	mouth_landmarks_valid = mouth_samples.size() == 2
	if mouth_landmarks_valid:
		# Called after the mandibular modifier: the emitter follows both actual rims.
		rendered_oral_upper = _mouth_skin_point(sk,mouth_samples[0])
		rendered_oral_lower = _mouth_skin_point(sk,mouth_samples[1])
		rendered_oral_center = (rendered_oral_upper+rendered_oral_lower)*0.5
		mouth_position = rendered_oral_center + breath_direction * 0.08
	else:
		mouth_position = head_pos + breath_direction * 1.1 + Vector3.DOWN * 0.12
	# Carry the last final rendered pose with the actor between modifier ticks.
	# Consumers must not read a stale world point after actor translation/turn.
	mouth_actor_local = dragon.to_local(mouth_position)
	direction_actor_local = dragon.global_basis.inverse()*breath_direction
	mouth_pose_cached = true
	global_position = mouth_position
	var up := Vector3.UP if absf(breath_direction.y) < 0.95 else Vector3.RIGHT
	global_basis = Basis.looking_at(breath_direction, up)

func _detect_impact() -> void:
	hit_distance = max_reach
	core_distance = max_reach
	core_impact_active = false
	impact_active = false
	hit_collider_id = 0
	if not is_firing and intensity < 0.01:
		return
	var space := get_world_3d().direct_space_state
	var core_query := PhysicsRayQueryParameters3D.create(mouth_position, mouth_position + breath_direction * max_reach, 7)
	core_query.exclude = [dragon.get_rid()]
	var core_contact := space.intersect_ray(core_query)
	if not core_contact.is_empty():
		core_distance = maxf(0.05,(core_contact.position-mouth_position).dot(breath_direction))
		core_impact_active = true
		core_impact_point = core_contact.position
		core_impact_normal = core_contact.normal
	var right := global_basis.x
	var up := global_basis.y
	# Narrow fan catches obstacles inside the widening jet, including near the muzzle.
	for offset in [Vector3.ZERO, right * 0.07, -right * 0.07, up * 0.07, -up * 0.07]:
		var direction: Vector3 = (breath_direction + offset).normalized()
		var query := PhysicsRayQueryParameters3D.create(mouth_position, mouth_position + direction * max_reach, 7)
		query.exclude = [dragon.get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var distance_to_hit: float = (hit.position - mouth_position).dot(breath_direction)
			if distance_to_hit < hit_distance:
				hit_distance = maxf(0.05,distance_to_hit)
				hit_position = hit.position
				hit_normal = hit.normal
				impact_active = true
				hit_collider_id = hit.collider_id
				impact.global_position = hit.position + hit.normal * 0.08
				impact.global_basis = Basis.looking_at(hit.normal, Vector3.RIGHT if absf(hit.normal.y) > 0.95 else Vector3.UP)
				impact_glow.global_position = hit.position + hit.normal * 0.65
	# Sweep the jet volume as well: isolated rays miss slender offset trunks.
	for segment in 4:
		var start_distance := float(segment) * max_reach / 4.0
		var segment_length := max_reach / 4.0
		# Cover 7-degree flame spread plus its maximum 1.95m card radius,
		# and the wider 13-degree (small) ember trajectory. Conservative at each segment end.
		var end_distance := start_distance + segment_length
		jet_probe.radius = maxf(2.0 + end_distance * tan(deg_to_rad(7.0)), 0.22 + end_distance * tan(deg_to_rad(13.0)))
		var probe := PhysicsShapeQueryParameters3D.new()
		probe.shape = jet_probe
		probe.transform = Transform3D(Basis.IDENTITY, mouth_position + breath_direction * start_distance)
		probe.motion = breath_direction * segment_length
		probe.collision_mask = 7
		probe.exclude = [dragon.get_rid()]
		var sweep_motion := probe.motion
		probe.motion = Vector3.ZERO
		var contact := space.get_rest_info(probe)
		if contact.is_empty():
			probe.motion = sweep_motion
			var fractions := space.cast_motion(probe)
			if fractions.size() != 2 or fractions[1] >= 1.0:
				continue
			probe.transform.origin += sweep_motion * minf(1.0, fractions[1] + 0.005)
			probe.motion = Vector3.ZERO
			contact = space.get_rest_info(probe)
		if contact.is_empty():
			continue
		# Outer flames may graze a finite plinth or flow around a narrow trunk.
		# Record that contact for sparks; only the axis ray stops the whole core.
		var contact_distance := clampf((contact.point-mouth_position).dot(breath_direction),0.05,max_reach)
		if contact_distance < hit_distance:
			hit_distance = contact_distance
			hit_position = contact.point
			hit_normal = contact.normal
			impact_active = true
			hit_collider_id = contact.collider_id
			impact.global_position = hit_position + hit_normal * 0.08
			impact.global_basis = Basis.looking_at(hit_normal, Vector3.RIGHT if absf(hit_normal.y) > 0.95 else Vector3.UP)
			impact_glow.global_position = hit_position + hit_normal * 0.65

func _setup_audio() -> void:
	if DisplayServer.get_name() == "headless":
		return
	# A short procedural PCM loop avoids a streaming buffer allocation every frame.
	noise_rng.seed = 772
	sound = AudioStreamPlayer3D.new()
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = 44100
	var pcm := PackedByteArray()
	pcm.resize(88200)
	var low_noise := 0.0
	for i in 44100:
		low_noise = low_noise * 0.82 + noise_rng.randf_range(-1,1) * 0.18
		var phase := TAU * 72.0 * float(i) / 22050.0
		var value := (low_noise * 0.8 + sin(phase) * 0.16 + sin(phase * 0.5) * 0.07) * 18000.0
		pcm.encode_s16(i * 2, int(value))
	stream.data = pcm
	sound.stream = stream
	sound.max_distance = 90.0
	sound.unit_size = 12.0
	sound.volume_db = -80.0
	add_child(sound)
	sound.play()

func _process(_delta: float) -> void:
	if sound:
		sound.volume_db = linear_to_db(maxf(intensity, 0.0001)) - 10.0

func _exit_tree() -> void:
	if sound:
		sound.stop()
		sound.stream = null
