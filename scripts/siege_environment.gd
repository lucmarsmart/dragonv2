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
var _modules: Dictionary = {}
var _chains: MultiMeshInstance3D
var _egg_material: ShaderMaterial
var _nest_freed := false
var _fort_template: Node3D

func _ready() -> void:
	add_to_group("siege_environment")
	_landscape = get_tree().get_first_node_in_group("landscape")
	if not _landscape:
		push_error("Fortress requires landscape before SiegeEnvironment")
		return
	arena_center = _landscape.to_global(Vector3(300.0, _landscape.ground_height(300.0, 120.0), 120.0))
	_fort_template = (load("res://assets/siege/environment/fort/modular_fort_01.gltf") as PackedScene).instantiate()
	_collect_modules(_fort_template)
	_build_fortress()
	_build_positions()
	_build_captive_egg()
	_fort_template.free()
	print("SIEGE ENVIRONMENT arena=", arena_center, " gate clear=24m court=144x124m; CC0 fort modules ", _modules.size())

func _collect_modules(node: Node) -> void:
	if node is MeshInstance3D:
		_modules[String(node.name).replace("modular_fort_01_", "")] = node
	for child in node.get_children():
		_collect_modules(child)

func _place_module(key: String, p: Vector3, yaw: float = 0.0, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var template: MeshInstance3D = _modules[key]
	var module := MeshInstance3D.new()
	module.name = key
	module.mesh = template.mesh
	var bounds := module.mesh.get_aabb()
	var pivot := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var basis := Basis(Vector3.UP, yaw).scaled(scale_value)
	module.transform = Transform3D(basis, p - basis * pivot)
	add_child(module)
	module.create_trimesh_collision()
	for body in module.get_children():
		if body is StaticBody3D:
			body.collision_layer = 2
			body.collision_mask = 0
			body.add_to_group("scenery_obstacle")
	return module

func _wall_run(start: Vector3, end: Vector3, key: String = "wall_thick_straight_01") -> void:
	var direction := (end - start).normalized()
	var length := start.distance_to(end)
	var count := ceili(length / 14.56)
	var spacing := length / count
	var yaw := atan2(direction.x, direction.z)
	for i in count:
		_place_module(key, start + direction * spacing * (i + 0.5), yaw, Vector3(1.0, 1.0, spacing / 14.56278))

func _build_fortress() -> void:
	var c := arena_center
	_wall_run(c + Vector3(-76, 0, -67), c + Vector3(76, 0, -67))
	_wall_run(c + Vector3(-76, 0, -67), c + Vector3(-76, 0, 70))
	_wall_run(c + Vector3(76, 0, -67), c + Vector3(76, 0, 70), "wall_thick_straight_02")
	# Wide, roofless breach lets the folded dragon enter on foot and launch safely.
	_wall_run(c + Vector3(-76, 0, 70), c + Vector3(-12, 0, 70))
	_wall_run(c + Vector3(12, 0, 70), c + Vector3(76, 0, 70))
	for corner in [Vector3(-76, 0, -67), Vector3(76, 0, -67), Vector3(-76, 0, 70), Vector3(76, 0, 70)]:
		_place_module("tower_round", c + corner)
	# Imported stone stairs and walkways, with concave collision on actual steps.
	for x in [-69.0, 69.0]:
		_place_module("wall_stairs_straight_01", c + Vector3(x, 0, -37), 0.0 if x < 0 else PI)
		_place_module("wall_walkway_straight_01", c + Vector3(x, 0, -55), 0.0 if x < 0 else PI)
	# Small PBR gate embedded in the northern sanctum facade, away from walking lanes.
	_place_module("wall_thin_gate_01", c + Vector3(0, 0, -63), PI * 0.5, Vector3(1.0, 1.0, 1.6))
	var door := (load("res://assets/siege/environment/gate/large_castle_door.gltf") as PackedScene).instantiate() as Node3D
	door.name = "WeatheredSanctumDoor"
	add_child(door)
	door.position = c + Vector3(0, 0, -61.5)
	door.scale = Vector3.ONE * 2.0
	for offset in [Vector3(-15, 0, 68), Vector3(15, 0, 68), Vector3(-8, 0, -53), Vector3(8, 0, -53)]:
		var lantern := (load("res://assets/siege/environment/lantern.glb") as PackedScene).instantiate() as Node3D
		lantern.name = "GitHubCC0WoodenLantern"
		add_child(lantern)
		lantern.position = c + offset
		lantern.scale = Vector3.ONE * 0.15
		_add_mesh_collisions(lantern)
	# Defensive artillery positions remain low enough to be attacked from the court.
	for offset in [Vector3(-49, 0, -30), Vector3(49, 0, -30), Vector3(50, 0, 42)]:
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
	for offset in [Vector3(-32, 0, 7), Vector3(31, 0, 12), Vector3(-22, 0, -16), Vector3(23, 0, -17), Vector3(-24, 0, 44), Vector3(24, 0, 48), Vector3(-56, 0, 16), Vector3(58, 0, 4)]:
		knight_spawn_points.append(arena_center + offset)
	for offset in [Vector3(-49, 4.5, -30), Vector3(49, 4.5, -30), Vector3(50, 4.5, 42)]:
		turret_spawn_points.append(arena_center + offset)
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
