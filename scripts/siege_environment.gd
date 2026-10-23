extends Node3D

## CC0 modular fort, castle door and Github Khronos lanterns. All gameplay
## positions are world coordinates grounded on the terrain's actual surface.
var arena_center := Vector3(300.0, 24.0, 120.0)
var knight_spawn_points: Array[Vector3] = []
var turret_spawn_points: Array[Vector3] = []
var rescue_point := Vector3.ZERO
var escape_point := Vector3.ZERO
var approach_spawn := Vector3.ZERO
var _landscape: Node3D
var _chains: MultiMeshInstance3D
var _egg_material: ShaderMaterial
var _nest_freed := false

func _ready() -> void:
	add_to_group("siege_environment")
	_landscape = get_tree().get_first_node_in_group("landscape")
	if not _landscape:
		push_error("Fortress requires landscape before SiegeEnvironment")
		return
	arena_center = _landscape.to_global(Vector3(300.0, _landscape.ground_height(300.0, 120.0), 120.0))
	_build_fortress()
	_build_positions()
	_build_captive_egg()
	_build_sentinels_and_relics()
	
	_build_ground_catapults()
	_build_leaning_wall_props()
	print("SIEGE ENVIRONMENT arena=", arena_center, " unified castle citadel integrated (1 draw call)")

func _build_fortress() -> void:
	var c := arena_center
	# Opción A: Unified Medieval Castle Citadel (Single Draw Call, 1K PBR textures)
	var castle_path := "res://assets/siege/environment/castle_citadel.glb"
	if ResourceLoader.exists(castle_path):
		var castle_scene := load(castle_path) as PackedScene
		var castle := castle_scene.instantiate() as Node3D
		castle.name = "MedievalCastleCitadel"
		castle.position = c + Vector3(0.0, -1.2, 0.0)
		castle.rotation.y = -PI * 0.5
		add_child(castle)
		for child: MeshInstance3D in castle.find_children("*", "MeshInstance3D", true, false):
			child.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			child.visibility_range_end = 380.0
		_add_mesh_collisions(castle)

	# Torches / Lanterns flanking the castle breach
	for offset in [Vector3(-18, 0, 52), Vector3(18, 0, 52)]:
		var lantern := (load("res://assets/siege/environment/lantern.glb") as PackedScene).instantiate() as Node3D
		lantern.name = "GitHubCC0WoodenLantern"
		add_child(lantern)
		lantern.position = c + offset
		lantern.scale = Vector3.ONE * 0.15
		for child: MeshInstance3D in lantern.find_children("*", "MeshInstance3D", true, false):
			child.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			child.visibility_range_end = 140.0
		_add_mesh_collisions(lantern)

	# Defensive artillery positions remain low enough to be attacked from the court.
	for offset in [Vector3(-49, 0, -30), Vector3(49, 0, -30), Vector3(62, 0, 35)]:
		_platform(c + offset)

	# Eroded stone nests, assembled from scanned geometry; central approach stays clear.
	var scan_scene := (load("res://assets/environment/rock/rock_lod1.glb") as PackedScene).instantiate() as Node3D
	for i in 7:
		if i in [0, 1, 6]:
			continue
		var stone := scan_scene.duplicate() as Node3D
		stone.name = "ScannedSanctumNestStone"
		add_child(stone)
		var angle := i * TAU / 7.0
		stone.position = c + Vector3(sin(angle) * 7.0, -0.10, -38.0 + cos(angle) * 6.0)
		stone.rotation.y = angle
		stone.scale = Vector3(0.72, 0.90, 0.70)
		for child: MeshInstance3D in stone.find_children("*", "MeshInstance3D", true, false):
			child.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			child.visibility_range_end = 180.0
		_add_mesh_collisions(stone)
	scan_scene.free()

func _platform(p: Vector3) -> void:
	# One solid sloped plinth rather than an inaccessible castle rooftop.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts := [Vector3(-5, 0, -5), Vector3(5, 0, -5), Vector3(-5, 4.5, -5), Vector3(5, 4.5, -5), Vector3(-5, 4.5, 5), Vector3(5, 4.5, 5), Vector3(-5, 0, 17), Vector3(5, 0, 17)]
	for tri in [[0, 2, 1], [1, 2, 3], [2, 4, 3], [3, 4, 5], [4, 6, 5], [5, 6, 7], [0, 6, 2], [2, 6, 4], [1, 3, 7], [3, 5, 7], [0, 1, 6], [1, 7, 6]]:
		for index in [tri[0], tri[2], tri[1]]:
			st.add_vertex(verts[index])
	st.generate_normals()
	var platform := MeshInstance3D.new()
	platform.name = "SlopedArtilleryPlinth"
	platform.mesh = st.commit()
	platform.material_override = _landscape.get("_terrain_material")
	platform.position = p
	add_child(platform)
	platform.create_trimesh_collision()
	for body in platform.get_children():
		if body is StaticBody3D:
			# Walkable platform belongs to ground AND obstacle so LOS and claw rays agree.
			body.collision_layer = 3
			body.collision_mask = 0
			body.add_to_group("scenery_obstacle")

func _add_mesh_collisions(node: Node) -> void:
	if node is MeshInstance3D:
		node.create_trimesh_collision()
		for body in node.get_children():
			if body is StaticBody3D:
				body.collision_layer = 2
				body.collision_mask = 0
				body.add_to_group("scenery_obstacle")
	for child in node.get_children():
		if not child is StaticBody3D:
			_add_mesh_collisions(child)

func _build_positions() -> void:
	# El Capitán blanco templario en la puerta de honor (índice 0), y soldados grises distribuidos
	for offset in [Vector3(0, 0, 32), Vector3(-24, 0, 12), Vector3(24, 0, 12), Vector3(-18, 0, -16), Vector3(18, 0, -16), Vector3(-28, 0, 44), Vector3(28, 0, 44), Vector3(0, 0, 52)]:
		knight_spawn_points.append(arena_center + offset)
	# BALLESTAS EN LO ALTO DE LAS TORRES REDONDAS DEL CASTILLO (Foto de torre almenada)
	turret_spawn_points = [
		Vector3(259.18, 50.35, 163.71),
		Vector3(340.65, 50.35, 164.17),
		Vector3(340.65, 50.35, 76.52),
		Vector3(259.34, 50.35, 76.52)
	]
	rescue_point = arena_center + Vector3(0, 0, -38)
	escape_point = _landscape.to_global(Vector3(300, _landscape.ground_height(300, 275), 275))
	approach_spawn = arena_center + Vector3(0, 76, 230)

func _build_captive_egg() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SIDES := 64
	const RINGS := 48
	for ring in RINGS:
		for side in SIDES:
			var vertices: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for offset in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1)]:
				var v := float(ring + offset.x) / RINGS
				var u := float(side + offset.y) / SIDES
				var radius := sin(v * PI) * 1.35 * (1.1 - v * 0.4)
				vertices.append(Vector3(cos(u * TAU) * radius, v * 3.7, sin(u * TAU) * radius))
				uvs.append(Vector2(u,v))
			for tri in [[0,1,2],[1,3,2]]:
				for index in tri:
					st.set_uv(uvs[index])
					st.add_vertex(vertices[index])
	st.index()
	st.generate_normals()
	st.generate_tangents()
	var egg := MeshInstance3D.new()
	egg.name = "LastCaptiveDragonEgg"
	egg.mesh = st.commit()
	_egg_material = ShaderMaterial.new()
	_egg_material.shader = load("res://shaders/siege_egg.gdshader")
	_egg_material.set_shader_parameter("shell_normal",load("res://assets/environment/rocky_terrain_02_nor_gl.jpg"))
	egg.material_override = _egg_material
	egg.position = rescue_point
	add_child(egg)
	# The closed shell needs a solid collider; its conservative profile hull is
	# independently checked against all visual faces (anatomy-egg-hull-enclosure).
	var egg_body := StaticBody3D.new()
	egg_body.name = "LastCaptiveDragonEgg_col"
	var egg_collision := CollisionShape3D.new()
	# Derive a conservative low-poly hull from the full64x48 radial profile.
	# Every visual ring breakpoint is checked against the16-ring interpolation.
	# A circumscribed16-gon and that measured radial deficit contain all source faces.
	const PHYSICS_SIDES := 16
	const PHYSICS_RINGS := 16
	var coarse_radii: Array[float] = []
	for ring in PHYSICS_RINGS+1:
		var v := float(ring)/PHYSICS_RINGS
		coarse_radii.append(sin(v*PI)*1.35*(1.1-v*.4))
	var radial_deficit := 0.0
	for ring in RINGS+1:
		var v := float(ring)/RINGS
		var cell := mini(floori(v*PHYSICS_RINGS),PHYSICS_RINGS-1)
		var interpolated := lerpf(coarse_radii[cell],coarse_radii[cell+1],v*PHYSICS_RINGS-cell)
		radial_deficit = maxf(radial_deficit,sin(v*PI)*1.35*(1.1-v*.4)-interpolated)
	var hull_points := PackedVector3Array()
	for ring in PHYSICS_RINGS+1:
		var radius := (coarse_radii[ring]+radial_deficit+.0002)/cos(PI/PHYSICS_SIDES)
		for side in PHYSICS_SIDES:
			var angle := float(side)/PHYSICS_SIDES*TAU
			hull_points.append(Vector3(cos(angle)*radius,float(ring)/PHYSICS_RINGS*3.7,sin(angle)*radius))
	var egg_hull := ConvexPolygonShape3D.new()
	egg_hull.points = hull_points
	egg_collision.shape = egg_hull
	egg_body.add_child(egg_collision)
	egg.add_child(egg_body)
	for body in egg.get_children():
		if body is StaticBody3D:
			body.collision_layer = 2
			body.collision_mask = 0
			body.add_to_group("scenery_obstacle")
	var link := TorusMesh.new()
	link.inner_radius = 0.105
	link.outer_radius = 0.16
	link.rings = 12
	link.ring_segments = 8
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.18,0.17,0.15)
	steel.metallic = 0.94
	steel.roughness = 0.28
	link.material = steel
	var transforms: Array[Transform3D] = []
	for axis in [Vector3(1,0,0),Vector3(0,0,1)]:
		for i in 52:
			var t := float(i) / 51.0
			var p: Vector3 = axis * lerpf(-4.1,4.1,t)
			p.y = 0.35 + pow(sin(t * PI),1.6) * 3.5
			var next_t := minf(t+0.015,1.0)
			var next: Vector3 = axis * lerpf(-4.1,4.1,next_t)
			next.y = 0.35 + pow(sin(next_t * PI),1.6) * 3.5
			var tangent: Vector3 = (next-p).normalized() if t < 0.99 else (axis-Vector3.UP).normalized()
			var orient := Basis(Quaternion(Vector3.RIGHT,tangent))
			if i % 2:
				orient = Basis(tangent,PI*0.5) * orient
			transforms.append(Transform3D(orient.scaled(Vector3(1.35,1.0,1.0)),p))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = link
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i,transforms[i])
	_chains = MultiMeshInstance3D.new()
	_chains.name = "CaptiveIronChains"
	_chains.multimesh = mm
	_chains.position = rescue_point
	add_child(_chains)

func liberate_nest() -> void:
	if _nest_freed:
		return
	_nest_freed = true
	_egg_material.set_shader_parameter("freed",1.0)
	# The physical objective stays in its stone cradle; the visibly removed chains
	# and awakened shell show that the captives have been freed.
	_chains.visible = false

func reset_nest() -> void:
	_nest_freed = false
	if _chains:
		_chains.visible = true
	if _egg_material:
		_egg_material.set_shader_parameter("freed",0.0)


func _build_sentinels_and_relics() -> void:
	var c := arena_center
	var sentinel_path := "res://assets/siege/environment/armor/armor_sentinel.glb"
	if ResourceLoader.exists(sentinel_path):
		var sentinel_scene := load(sentinel_path) as PackedScene
		# 1. Royal Sentinel Monuments flanking the inner Sanctum Gate
		# 2. Outer breach sentinels guarding entrance
		# 3. High walkway sentinels looking over the courtyard
		var sentinel_posts := [
			{"pos": c + Vector3(-5.4, 0.0, -32.0), "yaw": 0.28, "scale": 1.15},
			{"pos": c + Vector3(5.4, 0.0, -32.0), "yaw": -0.28, "scale": 1.15},
			{"pos": c + Vector3(-16.0, 0.0, 52.0), "yaw": PI - 0.25, "scale": 1.10},
			{"pos": c + Vector3(16.0, 0.0, 52.0), "yaw": PI + 0.25, "scale": 1.10},
			{"pos": c + Vector3(-35.0, 0.0, 10.0), "yaw": PI * 0.5, "scale": 1.05},
			{"pos": c + Vector3(35.0, 0.0, 10.0), "yaw": -PI * 0.5, "scale": 1.05}
		]
		for i in sentinel_posts.size():
			var data = sentinel_posts[i]
			var sentinel := sentinel_scene.instantiate() as Node3D
			sentinel.name = "RoyalArmorSentinel_%d" % i
			sentinel.position = data.pos
			sentinel.rotation.y = data.yaw
			sentinel.scale = Vector3.ONE * data.scale
			add_child(sentinel)
			for child: MeshInstance3D in sentinel.find_children("*", "MeshInstance3D", true, false):
				child.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
				child.visibility_range_end = 220.0
			_add_mesh_collisions(sentinel)
	
	# Standalone Greatswords embedded near the sacred dais and stone walkway plinths
	var sword_path := "res://assets/siege/weapons/greatsword.glb"
	if ResourceLoader.exists(sword_path):
		var sword_scene := load(sword_path) as PackedScene
		var relic_posts := [
			# Embedded in stone near the captive nest
			{"pos": c + Vector3(3.2, 0.2, -36.0), "rot": Vector3(0.12, 0.65, -0.08), "scale": 1.10},
			# Displayed at sanctum approach portal
			{"pos": c + Vector3(-3.2, 0.2, -36.0), "rot": Vector3(-0.10, -0.65, 0.08), "scale": 1.10}
		]
		for i in relic_posts.size():
			var data = relic_posts[i]
			var sword_inst := sword_scene.instantiate() as Node3D
			sword_inst.name = "FortressRelicGreatsword_%d" % i
			sword_inst.position = data.pos
			sword_inst.rotation = data.rot
			sword_inst.scale = Vector3.ONE * data.scale
			add_child(sword_inst)
			for child: MeshInstance3D in sword_inst.find_children("*", "MeshInstance3D", true, false):
				child.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
				child.visibility_range_end = 180.0
			_add_mesh_collisions(sword_inst)

func _build_ground_catapults() -> void:
	# CATAPULTAS ABAJO EN EL SUELO Y PATIO DE ARMAS (Foto de catapulta con municiones de piedra)
	var cat_path := "res://assets/siege/weapons/catapult.glb"
	if ResourceLoader.exists(cat_path):
		var cat_scene := load(cat_path) as PackedScene
		var ground_posts := [
			{"pos": arena_center + Vector3(-26.0, 0.0, 56.0), "yaw": 0.15, "scale": 1.25},
			{"pos": arena_center + Vector3(26.0, 0.0, 56.0), "yaw": -0.15, "scale": 1.25},
			{"pos": arena_center + Vector3(0.0, 0.0, -12.0), "yaw": PI, "scale": 1.30}
		]
		for i in ground_posts.size():
			var p = ground_posts[i]
			var cat := cat_scene.instantiate() as Node3D
			cat.name = "GroundSiegeCatapult_%d" % i
			cat.position = p.pos
			cat.rotation.y = p.yaw
			cat.scale = Vector3.ONE * p.scale
			add_child(cat)
			for child: MeshInstance3D in cat.find_children("*", "MeshInstance3D", true, false):
				child.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
				child.visibility_range_end = 260.0
			_add_mesh_collisions(cat)

func _build_leaning_wall_props() -> void:
	# BARRILES, LANZAS, HACHAS Y ESPADAS APOYADAS/TIRADAS JUNTO A LA PARED (Foto de armas y barriles)
	var props_path := "res://assets/siege/environment/props/citadel_wall_props.glb"
	if ResourceLoader.exists(props_path):
		var props_scene := load(props_path) as PackedScene
		var wall_spots := [
			{"pos": arena_center + Vector3(-34.0, 0.0, 22.0), "yaw": PI * 0.5},
			{"pos": arena_center + Vector3(34.0, 0.0, 22.0), "yaw": -PI * 0.5},
			{"pos": arena_center + Vector3(-32.0, 0.0, -8.0), "yaw": PI * 0.45},
			{"pos": arena_center + Vector3(32.0, 0.0, -8.0), "yaw": -PI * 0.45},
			{"pos": arena_center + Vector3(-12.0, 0.0, 48.0), "yaw": 0.0},
			{"pos": arena_center + Vector3(12.0, 0.0, 48.0), "yaw": 0.0}
		]
		for i in wall_spots.size():
			var s = wall_spots[i]
			var prop := props_scene.instantiate() as Node3D
			prop.name = "CitadelWallProps_%d" % i
			prop.position = s.pos
			prop.rotation.y = s.yaw
			prop.scale = Vector3.ONE * 1.05
			add_child(prop)
			for child: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
				child.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
				child.visibility_range_end = 160.0
			_add_mesh_collisions(prop)
