extends SceneTree
const Probe = preload("res://scripts/dragon_pose_probe.gd")
var scene: Node3D
var dragon: DragonController
var rows: Array = []
var last_us := 0
var begun := false
var on_ground_frames := 0
var preparation_before_input := 0
func _initialize() -> void: call_deferred("run")
func key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)
func tick() -> void:
	await physics_frame
	await process_frame
func pulse(code: Key) -> void:
	key(code,true)
	await tick()
	key(code,false)
func measure() -> void:
	if not begun: return
	var now := Time.get_ticks_usec()
	if last_us>0:
		rows.append({"frame_ms":float(now-last_us)/1000,"state":dragon.locomotion_state,"proximity":dragon.ground_proximity,"blend":dragon.ground_blend,"position":str(dragon.global_position),"costs":Probe.costs.duplicate(true)})
	Probe.costs = {}
	last_us = now
func run() -> void:
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	dragon = scene.get_node("Dragon")
	# Native renderer warmup with the real scene, before activating the mission.
	for index in 360: await tick()
	preparation_before_input = dragon.ground_pose.preparation_count
	await pulse(KEY_ENTER)
	await pulse(KEY_T)
	await pulse(KEY_L)
	Probe.costs = {}
	begun = true
	process_frame.connect(measure)
	var start := Time.get_ticks_usec()
	for index in 2400:
		await tick()
		if dragon.locomotion_state==dragon.LocomotionState.GROUNDED:
			on_ground_frames += 1
			if on_ground_frames>=30: break
		if Time.get_ticks_usec()-start>35000000: break
	begun = false
	var tag := "baseline" if "--baseline" in OS.get_cmdline_user_args() else "optimized"
	# After all measured/native frames, verify the shared reset path retains
	# immutable probes without applying a pose or running another frame.
	var metadata_ids := []
	for end in [8,82,23,41]: metadata_ids.append(dragon.ground_pose.prepared_probes[end].get_instance_id())
	var count_before_reset: int = dragon.ground_pose.preparation_count
	for check_reset in 3:
		dragon.ground_pose.reset()
		dragon.ground_pose.prepare(dragon,dragon.skeleton)
	var ids_after := []
	for end in [8,82,23,41]: ids_after.append(dragon.ground_pose.prepared_probes[end].get_instance_id())
	var metadata_reused: bool = count_before_reset==dragon.ground_pose.preparation_count and metadata_ids==ids_after
	var result := {"diagnostic_only":true,"native_controls":"Enter,T,L; no teleport/state/pose overrides","display":DisplayServer.get_name(),"device":RenderingServer.get_video_adapter_name(),"ground_reached":on_ground_frames>0,"metadata_prepared_before_input":preparation_before_input,"metadata_post_measurement_reset_check":{"preparations_before":count_before_reset,"preparations_after_three_resets":dragon.ground_pose.preparation_count,"same_four_probe_instances":metadata_ids==ids_after,"passed":metadata_reused},"rows":rows}
	FileAccess.open("res://docs/validation/v2/anatomy-landing-profile-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(result))
	print("LANDING_PROFILE frames=",rows.size()," ground=",on_ground_frames," file=",tag)
	scene.free()
	quit(0 if on_ground_frames>0 and metadata_reused and preparation_before_input==1 else 1)
