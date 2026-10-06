extends SceneTree
var world: Node3D
var camera: Camera3D
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1280,720)
	world=Node3D.new()
	root.add_child(world)
	var env_node=WorldEnvironment.new()
	env_node.name="WorldEnvironment"
	env_node.environment=Environment.new()
	env_node.environment.background_mode=Environment.BG_SKY
	world.add_child(env_node)
	var sun=DirectionalLight3D.new()
	sun.name="DirectionalLight3D"
	world.add_child(sun)
	var terrain=load("res://assets/models/terrain.glb").instantiate()
	terrain.set_script(load("res://scripts/terrain.gd"))
	world.add_child(terrain)
	var siege=load("res://scripts/siege_environment.gd").new()
	world.add_child(siege)
	camera=Camera3D.new()
	camera.fov=67
	camera.far=5000
	world.add_child(camera)
	camera.current=true
	for data in [["fortress",Vector3(295,36,222),Vector3(300,29,90)],["fortress-air",Vector3(443,167,298),Vector3(285,22,100)],["river",Vector3(118,18,-95),Vector3(38,1,-215)],["river-close",Vector3(-7,8,-150),Vector3(-38,0.7,-130)],["mountain",Vector3(670,145,-360),Vector3(1800,450,-1400)],["pine",Vector3(180,40,125),Vector3(185,35,145)]]:
		camera.position=data[1]
		camera.position.y=maxf(camera.position.y,terrain.ground_height(camera.position.x,camera.position.z)+8.0)
		camera.look_at(data[2])
		terrain._update_forest_lods()
		for i in 18:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/validation/v2/environment-"+data[0]+".png")
		print("ENV_CAPTURE ",data[0])
	camera.position=Vector3(309,29,98)
	camera.look_at(Vector3(300,26,82))
	for phase in ["nest-captive", "nest-free"]:
		if phase == "nest-free":
			siege.liberate_nest()
		for i in 18:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/validation/v2/environment-"+phase+".png")
		print("ENV_CAPTURE ",phase)
	quit()
