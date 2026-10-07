extends SceneTree

const CollisionEffects = preload("res://scripts/collision_effects.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("--- RENDERIZANDO MUESTRAS CINEMATOGRÁFICAS DE IMPACTO (ALTA DEFINICIÓN) ---")
	root.size = Vector2i(1280, 720)
	
	var world := Node3D.new()
	world.name = "ShowcaseWorld"
	root.add_child(world)
	
	# Iluminación de alta definición con sol lateral para resaltar relieves volumétricos
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.58, 0.74)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.52, 0.58)
	env.ambient_light_energy = 1.0
	env_node.environment = env
	world.add_child(env_node)
	
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.75, -0.7, 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	world.add_child(sun)
	
	# Terreno con material físico contrastado
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.32, 0.26, 0.19)
	ground_mat.roughness = 0.95
	ground.material_override = ground_mat
	world.add_child(ground)
	
	# Muro de fortificación de fondo para escala arquitectónica
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(28.0, 9.0, 3.0)
	wall.mesh = box
	wall.position = Vector3(0, 4.5, -9.0)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.50, 0.48, 0.44)
	wall_mat.roughness = 0.88
	wall.material_override = wall_mat
	world.add_child(wall)
	
	# Pilar de escala (3.2m)
	var pillar := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.7
	cyl.height = 3.2
	pillar.mesh = cyl
	pillar.position = Vector3(-3.8, 1.6, -2.0)
	pillar.material_override = wall_mat
	world.add_child(pillar)
	
	# Cámara cinematográfica
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.look_at_from_position(Vector3(5.5, 2.8, 9.5), Vector3(0.0, 1.6, 0.0))
	camera.current = true
	
	# -------------------------------------------------------------
	# 1. IMPACTO TERRESTRE: Billowing Core + Shockwave Ring + Debris
	# -------------------------------------------------------------
	print("Capturando Escenario 1: Impacto Terrestre...")
	var dust_container := Node3D.new()
	world.add_child(dust_container)
	CollisionEffects.spawn_dust_impact(dust_container, Vector3.ZERO, Vector3.UP, 2.8)
	
	# 9 frames de desarrollo volumétrico
	for i in 9:
		await process_frame
	
	await RenderingServer.frame_post_draw
	var dust_img := root.get_texture().get_image()
	if dust_img:
		dust_img.save_png("res://docs/validation/v2/collision_dust_showcase.png")
		print("EXITO: Guardado docs/validation/v2/collision_dust_showcase.png")
	
	dust_container.free()
	
	# -------------------------------------------------------------
	# 2. IMPACTO ACUÁTICO: Géiser Vertical + Gotas Elípticas + Espuma
	# -------------------------------------------------------------
	print("Capturando Escenario 2: Impacto Acuático...")
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.14, 0.32, 0.48)
	water_mat.roughness = 0.35
	water_mat.metallic = 0.05
	ground.material_override = water_mat
	
	var water_container := Node3D.new()
	world.add_child(water_container)
	CollisionEffects.spawn_water_splash(water_container, Vector3.ZERO, Vector3.UP, 2.8, false)
	
	# 8 frames para capturar la ascensión del géiser y gotas
	for i in 8:
		await process_frame
	
	await RenderingServer.frame_post_draw
	var water_img := root.get_texture().get_image()
	if water_img:
		water_img.save_png("res://docs/validation/v2/collision_water_showcase.png")
		print("EXITO: Guardado docs/validation/v2/collision_water_showcase.png")
	
	world.free()
	print("--- RENDERIZADO COMPLETADO CON ÉXITO ---")
	quit(0)
