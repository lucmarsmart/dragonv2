extends SceneTree

# Independent original skin oracle. The added pre-jaw modifier only reads skin;
# it does not modify bones, imported translations, geometry or production input.
const Probe = preload("res://scripts/dragon_pose_probe.gd")
const SOURCE_PATHS := ["res://scripts/anatomy_mouth_repro.gd", "res://scripts/dragon_breath.gd", "res://scripts/dragon_breath_modifier.gd", "res://scripts/dragon_pose_probe.gd", "res://scripts/dragon_controller.gd", "res://scripts/dragon_ground_pose.gd", "res://scripts/dragon_wing_contact.gd", "res://scripts/dragon_head_pose.gd", "res://assets/models/dragon.glb", "res://assets/models/dragon.glb.import"]
class PreJawProbe extends SkeletonModifier3D:
	var reader: Callable
	func _process_modification() -> void:
		if reader.is_valid(): reader.call()

var dragon: DragonController
var breath: DragonBreath
var scene: Node3D
var camera: Camera3D
var probe = Probe.new()
var upper: Dictionary = {}
var lower: Dictionary = {}
var before_upper := Vector3.ZERO
var before_lower := Vector3.ZERO
var before_frame := -1
var markers: Array[Node3D] = []
var rows: Array = []
var captures: Array = []
var failures: Array[String] = []
var checks := 0
var phase := ""
var observing := false
var current := {}
var latest := {}

func _initialize() -> void: call_deferred("run")
func ticks(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func hashes() -> Dictionary:
	var result := {}
	for path in SOURCE_PATHS: result[path] = FileAccess.get_sha256(path)
	return result
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func array_point(point: Vector3) -> Array: return [point.x,point.y,point.z]

func read_before_jaw() -> void:
	if upper.is_empty() or lower.is_empty(): return
	before_upper = probe.point(dragon.skeleton,upper)
	before_lower = probe.point(dragon.skeleton,lower)
	before_frame = Engine.get_process_frames()

func read_final() -> void:
	if upper.is_empty() or lower.is_empty(): return
	var u: Vector3 = probe.point(dragon.skeleton,upper)
	var l: Vector3 = probe.point(dragon.skeleton,lower)
	var center := (u+l)*0.5
	var expected := center+breath.breath_direction*.08
	var nasal: Vector3 = dragon.skeleton.to_global(dragon.skeleton.get_bone_global_pose(breath.mouth_bone).origin)
	var expected_nasal := nasal+breath.breath_direction*.08
	latest = {"upper":u,"lower":l,"center":center,"nasal":nasal,"emitter":breath.mouth_position,"direction":breath.breath_direction}
	for i in markers.size(): markers[i].global_position = [u,l,center,nasal][i]
	if not observing: return
	current.frames += 1
	current.valid_frames += int(breath.mouth_landmarks_valid)
	current.firing_frames += int(breath.is_firing)
	current.maximum_oral_error_m = maxf(current.maximum_oral_error_m,breath.mouth_position.distance_to(expected))
	current.minimum_legacy_nasal_error_m = minf(current.minimum_legacy_nasal_error_m,expected_nasal.distance_to(expected))
	var actual_center: Vector3 = breath.mouth_position-breath.breath_direction*.08
	var gap := l-u
	if gap.length_squared()>0.000001:
		var ratio := (actual_center-u).dot(gap)/gap.length_squared()
		current.maximum_center_fraction_error = maxf(current.maximum_center_fraction_error,absf(ratio-.5))
	current.minimum_opening_m = minf(current.minimum_opening_m,gap.length())
	if before_frame == Engine.get_process_frames():
		current.prejaw_frames += 1
		current.maximum_upper_jaw_motion_m = maxf(current.maximum_upper_jaw_motion_m,u.distance_to(before_upper))
		var lower_motion := l-before_lower
		var center_motion := actual_center-(before_upper+before_lower)*.5
		current.maximum_jaw_center_error_m = maxf(current.maximum_jaw_center_error_m,center_motion.distance_to(lower_motion*.5))
		current.maximum_lower_jaw_motion_m = maxf(current.maximum_lower_jaw_motion_m,lower_motion.length())
	var head: Vector3 = dragon.skeleton.to_global(dragon.skeleton.get_bone_global_pose(dragon.bone_head_idx).origin)
	current.maximum_direction_error_deg = maxf(current.maximum_direction_error_deg,rad_to_deg(breath.breath_direction.angle_to((nasal-head).normalized())))

func add_marker(label: String, color: Color) -> void:
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = .045
	sphere.height = .09
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.albedo_color = color
	sphere.material = material
	marker.mesh = sphere
	var text := Label3D.new()
	text.text = label
	text.font_size = 24
	text.pixel_size = .0014
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text.no_depth_test = true
	text.modulate = color
	text.position.y = .15
	marker.add_child(text)
	scene.add_child(marker)
	marker.visible = false
	markers.append(marker)

func capture_pose(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	for view in ["front","side"]:
		var direction: Vector3 = latest.direction
		var right := direction.cross(Vector3.UP).normalized()
		var up := right.cross(direction).normalized()
		var target: Vector3 = latest.center
		camera.global_position = target+(direction*7.0+up*.6 if view=="front" else right*7.0+up*.4)
		camera.look_at(target,up)
		for marked in [false,true]:
			for marker in markers: marker.visible = marked
			await process_frame
			await RenderingServer.frame_post_draw
			var path := "res://docs/validation/v2/anatomy-mouth-%s-%s-%s.png" % [label,view,"landmarks" if marked else "clean"]
			root.get_texture().get_image().save_png(path)
			captures.append({"path":path,"view":view,"landmarks":marked,"oral_center":array_point(latest.center),"upper":array_point(latest.upper),"lower":array_point(latest.lower),"nasal":array_point(latest.nasal),"emitter":array_point(latest.emitter),"camera":array_point(camera.global_position),"target_pixel":array_point(Vector3(camera.unproject_position(target).x,camera.unproject_position(target).y,0)),"frame":Engine.get_physics_frames()})
	for marker in markers: marker.visible = false

func run() -> void:
	var source_before := hashes()
	var source: Node3D = load("res://scenes/main.tscn").instantiate()
	dragon = source.get_node("Dragon")
	source.remove_child(dragon)
	dragon.owner = null
	scene = Node3D.new()
	for node_name in ["WorldEnvironment","DirectionalLight3D"]:
		var node := source.get_node(node_name)
		source.remove_child(node)
		node.owner = null
		scene.add_child(node)
	source.free()
	scene.add_child(dragon)
	root.add_child(scene)
	dragon.landscape = scene
	var floor := StaticBody3D.new()
	floor.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(500,1,500)
	shape.shape = box
	floor.add_child(shape)
	floor.position.y = 199.5
	scene.add_child(floor)
	camera = Camera3D.new()
	camera.fov = 42
	scene.add_child(camera)
	camera.current = true
	root.size = Vector2i(1280,720)
	await ticks(150)
	dragon.global_position = Vector3(0,203.5,100)
	dragon.rotation = Vector3.ZERO
	dragon.target_yaw = 0
	dragon.target_pitch = 0
	dragon.target_roll = 0
	dragon.velocity = Vector3.ZERO
	dragon.current_speed = 0
	dragon.has_taken_off = true
	dragon.locomotion_state = dragon.LocomotionState.GROUNDED
	dragon.ground_pose.reset()
	breath = dragon.get_node("DragonBreath")
	await ticks(120)
	probe.configure(dragon,dragon.skeleton,1)
	# These are exact GLB POSITION accessor values, independently located in the
	# full imported skin oracle. Imported indices are not original GLB indices.
	var original_upper := Vector3(-3.76998233795166,0.6621770858764648,11.446301460266113)
	var original_lower := Vector3(-3.7699837684631348,0.5364508628845215,11.267938613891602)
	for sample in probe.samples:
		if sample.mesh == "Object_8" and int(sample.surface)==0:
			if sample.vertex == original_upper: upper = sample
			if sample.vertex == original_lower: lower = sample
	check(not upper.is_empty() and not lower.is_empty(),"Both original GLB oral POSITION values occur exactly in the imported Object_8 surface0 skin")
	if upper.is_empty() or lower.is_empty(): quit(1); return
	check(upper.influence.size()==1 and dragon.skeleton.get_bone_name(upper.influence[0].bone)=="Bip001-Head_011" and absf(float(upper.influence[0].weight)-1.0)<.000001,"Upper oral rim is rigidly bound to the original head")
	check(lower.influence.size()==1 and dragon.skeleton.get_bone_name(lower.influence[0].bone)=="Bone015_012" and absf(float(lower.influence[0].weight)-1.0)<.000001,"Lower oral rim is rigidly bound to the original mandible")
	var before := PreJawProbe.new()
	before.name = "IndependentOralPreJawProbe"
	before.reader = read_before_jaw
	dragon.skeleton.add_child(before)
	dragon.skeleton.move_child(before,breath.jaw_modifier.get_index())
	breath.jaw_modifier.modification_processed.connect(read_final)
	add_marker("upper oral / head",Color.GREEN)
	add_marker("lower oral / jaw",Color.CYAN)
	add_marker("oral center",Color.WHITE)
	add_marker("old nasal source",Color.MAGENTA)
	dragon.head_aim_active = true
	for aim in [{"label":"neutral","yaw":0.0,"pitch":0.0},{"label":"up","yaw":0.0,"pitch":20.0},{"label":"down","yaw":0.0,"pitch":-20.0},{"label":"left","yaw":30.0,"pitch":0.0},{"label":"right","yaw":-30.0,"pitch":0.0}]:
		dragon.set_head_aim(deg_to_rad(aim.yaw),deg_to_rad(aim.pitch))
		for firing in [false,true]:
			key(KEY_F,firing)
			breath.fuel = 1.0
			breath.exhausted = false
			await ticks(35)
			phase = aim.label+("_fire_on" if firing else "_fire_off")
			current = {"label":phase,"frames":0,"valid_frames":0,"prejaw_frames":0,"firing_frames":0,"maximum_oral_error_m":0.0,"minimum_legacy_nasal_error_m":INF,"maximum_center_fraction_error":0.0,"minimum_opening_m":INF,"maximum_upper_jaw_motion_m":0.0,"maximum_jaw_center_error_m":0.0,"maximum_lower_jaw_motion_m":0.0,"maximum_direction_error_deg":0.0}
			observing = true
			await ticks(20)
			observing = false
			check(current.frames>=20 and current.valid_frames==current.frames and current.prejaw_frames==current.frames,phase+": original skin observed before and after every jaw modifier")
			check(current.maximum_oral_error_m<.001 and current.maximum_center_fraction_error<.001,phase+": emitter is within1mm of the actual oral midpoint plus8cm forward")
			check(current.minimum_legacy_nasal_error_m>.1,phase+": old nasal source fails the same1mm oral oracle")
			check(current.maximum_upper_jaw_motion_m<.001 and current.maximum_jaw_center_error_m<.001,phase+": jaw moves the oral center by half the independently measured lower-rim displacement")
			check(current.maximum_direction_error_deg<.1,phase+": fire direction follows the actual rendered head")
			check(current.firing_frames==current.frames if firing else current.firing_frames==0,phase+": F input controls firing")
			if firing: check(current.maximum_lower_jaw_motion_m>.01,phase+": real mandibular opening is observed")
			rows.append(current.duplicate(true))
			print("MOUTH_CASE ",JSON.stringify(current))
			await capture_pose(phase)
		key(KEY_F,false)
	key(KEY_F,false)
	var source_after := hashes()
	check(source_before==source_after,"All observed source and original asset hashes remain unchanged")
	var report := {"source_sha256_before":source_before,"source_sha256_after":source_after,"sources_unchanged":source_before==source_after,"asset_landmarks":{"mesh":"Object_8","surface":0,"upper_original_glb_index":6748,"lower_original_glb_index":1653,"upper_imported_index":upper.index,"lower_imported_index":lower.index,"upper_original_position":array_point(original_upper),"lower_original_position":array_point(original_lower),"upper_uv_duplicate_glb_index":4530,"lower_uv_duplicate_glb_index":4666,"direction_only_nasal_bone":"Point021_018","import_mapping":"Exact original POSITION plus rigid Head/Jaw identity; importer vertex ordering is independent"},"oracle":"Independent Probe original skin, read before and after production jaw; oral midpoint+0.08m actual head direction; 0.001m position threshold","cases":rows,"captures":captures,"checks":checks,"failures":failures,"display_server":DisplayServer.get_name(),"native_fps_claimed":false,"skin_semantics_require_front_and_side_visual_review":true}
	FileAccess.open("res://docs/validation/v2/anatomy-mouth-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("RESULT ",checks-failures.size(),"/",checks," oral checks; failures=",failures)
	quit(0 if failures.is_empty() else 1)
