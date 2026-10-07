extends SceneTree

const CollisionEffects = preload("res://scripts/collision_effects.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("--- TEST INICIADO: CONSECUENCIAS DE COLISIONES ---")
	
	# 1. Test Detección de Superficie (Terreno vs Agua)
	var terrain_script = load("res://scripts/terrain.gd")
	var terrain = Node3D.new()
	terrain.set_script(terrain_script)
	root.add_child(terrain)
	
	# Lago en (0, 0, 0) radio 70
	var water_pos := Vector3(0.0, 0.7, 0.0)
	var dry_pos := Vector3(300.0, 24.0, 120.0) # Patio del castillo / tierra
	
	var is_w := CollisionEffects.is_water_surface(water_pos, terrain)
	var is_d := CollisionEffects.is_water_surface(dry_pos, terrain)
	print("Detección de agua en Lago (0, 0.7, 0): ", is_w, " (esperado: true)")
	print("Detección de agua en Tierra (300, 24, 120): ", is_d, " (esperado: false)")
	assert(is_w == true, "Debe detectar superficie de agua en lago")
	assert(is_d == false, "No debe detectar agua en patio de tierra")
	
	# 2. Test Generación de Efecto Polvo
	var dust_parent := Node3D.new()
	dust_parent.name = "DustTestParent"
	root.add_child(dust_parent)
	
	var children_before := dust_parent.get_child_count()
	CollisionEffects.spawn_dust_impact(dust_parent, dry_pos, Vector3.UP, 2.5)
	var children_after := dust_parent.get_child_count()
	print("Nodos generados por spawn_dust_impact: ", children_after - children_before)
	assert(children_after >= 3, "Debe instanciar nube volumétrica, onda de choque y escombros")
	
	# Verificar que tiene los 3 componentes: Billowing core, shockwave ring, debris
	var has_dust_core := false
	var has_shockwave := false
	var has_debris := false
	for child in dust_parent.get_children():
		if child is CPUParticles3D:
			if child.mesh is BoxMesh:
				has_debris = true
			elif child.mesh is QuadMesh:
				if child.flatness > 0.5:
					has_shockwave = true
				else:
					has_dust_core = true
	print("Componentes de polvo: Core=", has_dust_core, " Shockwave=", has_shockwave, " Debris=", has_debris)
	assert(has_dust_core and has_shockwave and has_debris, "Todos los componentes de impacto terrestre deben estar activos")
	
	# 3. Test Generación de Efecto Agua
	var water_parent := Node3D.new()
	water_parent.name = "WaterTestParent"
	root.add_child(water_parent)
	
	var w_children_before := water_parent.get_child_count()
	CollisionEffects.spawn_water_splash(water_parent, water_pos, Vector3.UP, 2.5, false)
	var w_children_after := water_parent.get_child_count()
	print("Nodos generados por spawn_water_splash: ", w_children_after - w_children_before)
	assert(w_children_after >= 3, "Debe instanciar géiser vertical, corona de splash y vaho")
	
	# 4. Test Síntesis de Audio Procedural
	var earth_audio = CollisionEffects._get_earth_sound()
	var water_audio = CollisionEffects._get_water_sound()
	print("Audio tierra sintetizado: samples=", earth_audio.data.size() / 2, " mix_rate=", earth_audio.mix_rate)
	print("Audio agua sintetizado: samples=", water_audio.data.size() / 2, " mix_rate=", water_audio.mix_rate)
	assert(earth_audio.data.size() > 1000, "Audio de tierra debe contener PCM generado")
	assert(water_audio.data.size() > 1000, "Audio de agua debe contener PCM generado")
	
	# 5. Test Surface Wash (Vuelo rasante)
	var wash_parent := Node3D.new()
	root.add_child(wash_parent)
	CollisionEffects.spawn_surface_wash(wash_parent, dry_pos, Vector3(0, 0, 20), false)
	assert(wash_parent.get_child_count() > 0, "Debe generar estela de vuelo rasante sobre tierra")
	
	CollisionEffects.spawn_surface_wash(wash_parent, water_pos, Vector3(0, 0, 20), true)
	assert(wash_parent.get_child_count() > 1, "Debe generar estela de vuelo rasante sobre agua")
	
	print("--- TODOS LOS TESTS DE CONSECUENCIAS DE COLISIÓN PASARON EXITOSAMENTE ---")
	
	terrain.free()
	dust_parent.free()
	water_parent.free()
	wash_parent.free()
	quit(0)
