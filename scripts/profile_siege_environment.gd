extends SceneTree
var samples: Array[float] = []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var args=OS.get_cmdline_user_args()
	var fire_enabled="--fire" in args
	var variant="runtime"
	for arg in args:
		if arg.begins_with("--variant="):variant=arg.get_slice("=",1)
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for _i in 180:await process_frame
	var combat=scene.get_node("SiegeCombat")
	var dragon=scene.get_node("Dragon")
	var terrain=get_first_node_in_group("landscape")
	combat.start_mission()
	dragon.manual_input_override=true
	dragon.manual_turn_input=0.65
	var started=Time.get_ticks_usec()
	while Time.get_ticks_usec()-started<5000000:await process_frame
	# Diagnostic-only overrides isolate rendering components; production state is untouched.
	if variant=="freeze_lod":terrain.set_process(false)
	if variant=="no_forest":
		for node in terrain._forest_nodes:node.visible=false
	if variant=="no_shadow":scene.get_node("DirectionalLight3D").shadow_enabled=false
	if variant=="no_post":
		var env=scene.get_node("WorldEnvironment").environment
		env.ssao_enabled=false
		env.ssil_enabled=false
	if variant=="cheap_far":
		for node in terrain._forest_nodes:
			if String(node.name).begins_with("Forest_LOD2_") or String(node.name).begins_with("Forest_LOD3_"):
				for i in node.multimesh.mesh.get_surface_count():
					var mat=node.multimesh.mesh.surface_get_material(i)
					if mat is StandardMaterial3D:
						mat.normal_enabled=false
						mat.roughness_texture=null
	if variant=="no_near":
		for node in terrain._forest_nodes:
			if String(node.name).begins_with("Forest_LOD0_") or String(node.name).begins_with("Forest_LOD1_"):node.visible=false
	var previous=Time.get_ticks_usec()
	started=previous
	var firing=false
	var cpu=0.0
	var physics=0.0
	var render_cpu=0.0
	var render_gpu=0.0
	var draws=0.0
	var primitives=0.0
	while Time.get_ticks_usec()-started<10000000:
		await process_frame
		var now=Time.get_ticks_usec()
		var next_fire=fire_enabled and fmod(float(now-started)/1000000.0,4.0)<0.8
		if firing!=next_fire:
			firing=next_fire
			var event=InputEventKey.new()
			event.keycode=KEY_F
			event.physical_keycode=KEY_F
			event.pressed=firing
			Input.parse_input_event(event)
		samples.append(float(now-previous)/1000.0)
		previous=now
		cpu+=Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
		physics+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
		render_cpu+=RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		render_gpu+=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var elapsed=float(Time.get_ticks_usec()-started)/1000000.0
	var n=float(samples.size())
	samples.sort()
	var pipelines={}
	for key in ClassDB.class_get_integer_constant_list("Performance"):
		if "PIPELINE" in key:pipelines[key]=Performance.get_monitor(ClassDB.class_get_integer_constant("Performance",key))
	var lod_counts={}
	for node in terrain._forest_nodes:
		var lod=String(node.name).get_slice("_",1)
		lod_counts[lod]=lod_counts.get(lod,0)+node.multimesh.instance_count
	var mesh_triangles=[]
	for mesh in terrain._tree_lods:
		var count=0
		for surface in mesh.get_surface_count():
			var arrays=mesh.surface_get_arrays(surface)
			count+=arrays[Mesh.ARRAY_INDEX].size()/3 if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size()/3
		mesh_triangles.append(count)
	var result={"terrain_sha256":FileAccess.get_sha256("res://scripts/terrain.gd"),"mesh_triangles":mesh_triangles,"variant":variant,"fire":fire_enabled,"elapsed_s":elapsed,"fps":n/elapsed,"p95_ms":samples[int(n*0.95)],"process_ms":cpu/n,"physics_ms":physics/n,"render_cpu_ms":render_cpu/n,"render_gpu_ms":render_gpu/n,"draw_calls":draws/n,"primitives":primitives/n,"pipeline_compilations":pipelines,"lod_counts":lod_counts}
	print("ENV_PROFILE ",JSON.stringify(result))
	FileAccess.open("res://docs/validation/v2/environment-profile-%s-%s.json"%[variant,"fire" if fire_enabled else "no-fire"],FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	quit()
