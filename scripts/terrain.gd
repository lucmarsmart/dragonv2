extends Node3D

## One triangulated surface drives both rendering and ground queries. Scanned props
## are separate layer-2 obstacles; the courtyard and riverbed are part of layer 1.
const MAP_EDGE := 1000.0
const ORIGINAL_STEP := 2000.0 / 120.0
const GRID_COUNT := 320
const GRID_STEP := 2000.0 / GRID_COUNT
const ARENA_CENTER := Vector3(300.0, 24.0, 120.0)
const WATER_LEVEL := 0.7
var _source_heights: Dictionary = {}
var _heights := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _ridge_noise := FastNoiseLite.new()
var _erosion_noise := FastNoiseLite.new()
var _terrain_material: ShaderMaterial
var _tree_transforms: Array[Transform3D] = []
var _tree_lods: Array[Mesh] = []
var _forest_nodes: Array[MultiMeshInstance3D] = []
var _lod_timer := 0.0

func _ready() -> void:
	add_to_group("landscape")
	_rng.seed = 1042026
	_noise.seed = 731084
	_noise.frequency = 0.010
	_noise.fractal_octaves = 5
	_ridge_noise.seed = 87242
	_ridge_noise.frequency = 0.0009
	_ridge_noise.fractal_octaves = 3
	_erosion_noise.seed = 913527
	_erosion_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_erosion_noise.frequency = 0.0045
	_erosion_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_erosion_noise.fractal_octaves = 4
	_erosion_noise.fractal_gain = 0.42
	_erosion_noise.domain_warp_enabled = true
	_erosion_noise.domain_warp_amplitude = 75.0
	_erosion_noise.domain_warp_frequency = 0.0028
	_erosion_noise.domain_warp_fractal_octaves = 3
	_erosion_noise.domain_warp_fractal_lacunarity = 2.0
	_collect_source(self)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_terrain_material = ShaderMaterial.new()
	_terrain_material.shader = load("res://shaders/terrain.gdshader")
	for pair in [["rock_albedo", "rock_face_diff_2k"], ["rock_normal", "rock_face_nor_gl_2k"], ["rock_rough", "rock_face_rough_2k"], ["earth_albedo", "forest_ground_04_diffuse"], ["earth_normal", "forest_ground_04_nor_gl"], ["earth_rough", "forest_ground_04_rough"]]:
		_terrain_material.set_shader_parameter(pair[0], load("res://assets/environment/" + pair[1] + ".jpg"))
	for pair in [["grass_albedo", "diff"], ["grass_normal", "normal"], ["grass_rough", "rough"]]:
		_terrain_material.set_shader_parameter(pair[0], load("res://assets/environment/aerial_grass_" + pair[1] + ".jpg"))
	_build_ground()
	_build_distant_ridges()
	_build_water()
	_build_forest()
	_setup_atmosphere()
	var reflection := ReflectionProbe.new()
	reflection.name = "RiverCatchmentReflection"
	reflection.position = Vector3(20, 45, 0)
	reflection.size = Vector3(1000, 450, 2100)
	reflection.max_distance = 3000.0
	reflection.intensity = 0.85
	reflection.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(reflection)

func _collect_source(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var vertices: PackedVector3Array = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for v in vertices:
				_source_heights[Vector2i(roundi((v.x + MAP_EDGE) / ORIGINAL_STEP), roundi((v.z + MAP_EDGE) / ORIGINAL_STEP))] = v.y
	for child in node.get_children():
		_collect_source(child)

func _original_height(x: float, z: float) -> float:
	var gx := clampf((x + MAP_EDGE) / ORIGINAL_STEP, 0.0, 119.999)
	var gz := clampf((z + MAP_EDGE) / ORIGINAL_STEP, 0.0, 119.999)
	var ix := floori(gx)
	var iz := floori(gz)
	return lerpf(lerpf(_source_heights.get(Vector2i(ix, iz), 0.0), _source_heights.get(Vector2i(ix + 1, iz), 0.0), gx - ix), lerpf(_source_heights.get(Vector2i(ix, iz + 1), 0.0), _source_heights.get(Vector2i(ix + 1, iz + 1), 0.0), gx - ix), gz - iz)

func river_center(z: float) -> float:
	return sin(z * 0.0041) * 62.0 + sin(z * 0.0103 + 0.6) * 18.0

func river_width(z: float) -> float:
	return 31.0 + sin(z * 0.006 + 1.5) * 9.0 + sin(z * 0.019) * 2.4

func _landform_height(x: float, z: float) -> float:
	var distance_to_river := absf(x - river_center(z))
	var width := river_width(z)
	var detail := _noise.get_noise_2d(x, z)
	var h := maxf(_original_height(x, z), 9.0) + detail * 9.0
	var court_distance := maxf(absf(x - ARENA_CENTER.x) / 96.0, absf(z - ARENA_CENTER.z) / 90.0)
	# Functional surfaces retain their exact previous samples; deformation fades in
	# beyond their margins. This is procedural ridge/gully relief, not hydraulic erosion.
	var protection := (1.0 - smoothstep(48.0, 100.0, absf(x - 300.0))) * smoothstep(100.0, 150.0, z) * (1.0 - smoothstep(430.0, 480.0, z))
	var deformation := smoothstep(1.55, 2.1, court_distance) * smoothstep(width + 64.0, width + 125.0, distance_to_river) * (1.0 - protection)
	if deformation > 0.0:
		var warp := Vector2(_ridge_noise.get_noise_2d(x * 2.7 + 711.0, z * 2.7 - 319.0), _ridge_noise.get_noise_2d(x * 2.7 - 517.0, z * 2.7 + 823.0)) * 145.0
		var warped_height := maxf(_original_height(x + warp.x, z + warp.y), 9.0)
		var elevation_strength := smoothstep(12.0, 150.0, warped_height)
		var shoulders := _ridge_noise.get_noise_2d(x * 3.1 - 930.0, z * 3.1 + 471.0) * 42.0
		var gullies := _erosion_noise.get_noise_2d(x, z) * 34.0
		var broken_height := warped_height + (shoulders + gullies) * lerpf(0.30, 1.0, elevation_strength) + detail * 9.0
		h = lerpf(h, broken_height, deformation)
	# A continuous incised river: underwater gravel -> exposed shore -> grassy terrace.
	var bank := smoothstep(width - 8.0, width + 64.0, distance_to_river)
	h = lerpf(-3.0 + detail * 0.35, h, bank)
	h = lerpf(ARENA_CENTER.y, h, smoothstep(1.0, 1.55, court_distance))
	# A gently graded, 32m-wide approach reaches the open gate.
	if z > 180.0 and z < 390.0:
		var access := (1.0 - smoothstep(18.0, 42.0, absf(x - 300.0))) * (1.0 - smoothstep(325.0, 390.0, z))
		h = lerpf(h, 24.0, access)
	return h

func _build_ground() -> void:
	_heights.resize((GRID_COUNT + 1) * (GRID_COUNT + 1))
	for z in GRID_COUNT + 1:
		for x in GRID_COUNT + 1:
			_heights[z * (GRID_COUNT + 1) + x] = _landform_height(-MAP_EDGE + x * GRID_STEP, -MAP_EDGE + z * GRID_STEP)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in GRID_COUNT:
		for x in GRID_COUNT:
			var a := _grid_vertex(x, z)
			var b := _grid_vertex(x, z + 1)
			var c := _grid_vertex(x + 1, z)
			var d := _grid_vertex(x + 1, z + 1)
			_triangle(st, a, b, c)
			_triangle(st, c, b, d)
	st.index()
	st.generate_normals()
	var ground := MeshInstance3D.new()
	ground.name = "ErodedValleyGround"
	ground.mesh = st.commit()
	ground.material_override = _terrain_material
	add_child(ground)
	ground.create_trimesh_collision()

func _grid_vertex(x: int, z: int) -> Vector3:
	return Vector3(-MAP_EDGE + x * GRID_STEP, _heights[z * (GRID_COUNT + 1) + x], -MAP_EDGE + z * GRID_STEP)

func terrain_height(x: float, z: float) -> float:
	return ground_height(x, z)

func ground_height(x: float, z: float) -> float:
	if maxf(absf(x), absf(z)) > MAP_EDGE:
		return _ridge_height(x, z)
	if _heights.is_empty():
		return _landform_height(x, z)
	var gx := clampf((x + MAP_EDGE) / GRID_STEP, 0.0, GRID_COUNT - 0.0001)
	var gz := clampf((z + MAP_EDGE) / GRID_STEP, 0.0, GRID_COUNT - 0.0001)
	var ix := floori(gx)
	var iz := floori(gz)
	var fx := gx - ix
	var fz := gz - iz
	var a := _heights[iz * (GRID_COUNT + 1) + ix]
	var b := _heights[(iz + 1) * (GRID_COUNT + 1) + ix]
	var c := _heights[iz * (GRID_COUNT + 1) + ix + 1]
	var d := _heights[(iz + 1) * (GRID_COUNT + 1) + ix + 1]
	# Exact barycentric height on the same a-b-c / c-b-d triangle as the collider.
	return a + (c - a) * fx + (b - a) * fz if fx + fz <= 1.0 else d + (b - d) * (1.0 - fx) + (c - d) * (1.0 - fz)

func is_water_at(world_position: Vector3) -> bool:
	var p := to_local(world_position)
	return absf(p.z) < MAP_EDGE and absf(p.x - river_center(p.z)) < river_width(p.z) + 32.0 and ground_height(p.x, p.z) < WATER_LEVEL

func get_water_level() -> float:
	return WATER_LEVEL

func ground_surface(world_position: Vector3) -> Dictionary:
	var p := world_position
	var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1000.0, p - Vector3.UP * 1500.0, 1)
	var player := get_parent().get_node_or_null("Dragon") as CollisionObject3D
	if player:
		query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func find_landing_site(origin: Vector3) -> Vector3:
	var local := to_local(origin)
	var footprint := BoxShape3D.new()
	# Folded wings span 6.289m; the long body needs fore/aft clearance, rather
	# than a thirty-metre square that rejected every usable forest opening.
	footprint.size = Vector3(8,12,28)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = footprint
	query.collision_mask = 2
	query.margin = 0.0
	var space := get_world_3d().direct_space_state
	for ring in 20:
		var radius := ring * 12.0
		var steps := 1 if ring == 0 else maxi(20,ceili(TAU*radius/12.0))
		for step in steps:
			var angle := step * TAU / steps
			var x := local.x + cos(angle) * radius
			var z := local.z + sin(angle) * radius
			if maxf(absf(x), absf(z)) > 930.0:
				continue
			var candidate := to_global(Vector3(x, ground_height(x, z), z))
			var approach:=candidate-origin
			approach.y=0.0
			var heading:=Basis(Vector3.UP,atan2(-approach.x,-approach.z)) if approach.length_squared()>.01 else Basis.IDENTITY
			var slope := Vector2(ground_height(x + 5.0, z) - ground_height(x - 5.0, z), ground_height(x, z + 5.0) - ground_height(x, z - 5.0)).length() / 10.0
			if is_water_at(candidate) or slope>=0.4:continue
			var walkable := true
			# A point under the belly does not represent the dragon's four feet,
			# neck and tail. Reject abrupt terrain changes across its landing patch.
			for dx in [-4.0,0.0,4.0]:
				for dz in [-14.0,0.0,14.0]:
					var offset:Vector3=heading*Vector3(dx,0,dz)
					var px:float=x+offset.x
					var pz:float=z+offset.z
					var height:=ground_height(px,pz)
					var gradient:=Vector2(ground_height(px+3,pz)-ground_height(px-3,pz),ground_height(px,pz+3)-ground_height(px,pz-3)).length()/6.0
					if gradient>=0.4 or absf(height-candidate.y)>5.0 or is_water_at(to_global(Vector3(px,height,pz))):walkable=false
			if not walkable:continue
			query.transform=Transform3D(heading,candidate+Vector3.UP*6)
			if not space.intersect_shape(query,1).is_empty():continue
			return candidate
	return to_global(ARENA_CENTER)

func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)

func _ridge_height(x: float, z: float) -> float:
	var radius := maxf(absf(x), absf(z))
	var p := Vector2(x, z) * MAP_EDGE / maxf(radius, MAP_EDGE)
	var edge_h := _landform_height(p.x, p.y)
	var t := clampf((radius - MAP_EDGE) / 1200.0, 0.0, 1.0)
	var n := _ridge_noise.get_noise_2d(x, z)
	var ridge := 1.0 - sqrt(n * n + 0.035)
	var valley := absf(_ridge_noise.get_noise_2d(x * 1.6 + 143, z * 1.6))
	var mass := pow(ridge, 2.1) * (520.0 + valley * 580.0) + _noise.get_noise_2d(x, z) * 18.0
	return lerpf(edge_h, 100.0 + mass, smoothstep(0.0, 1.0, t))

func _build_distant_ridges() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 640
	const RINGS := 120
	for ring in RINGS:
		for i in SEGMENTS:
			var quad: Array[Vector3] = []
			for offset in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1)]:
				var angle := float(i + offset.y) / SEGMENTS * TAU
				var radial := float(ring + offset.x) / RINGS
				var direction := Vector2(cos(angle), sin(angle))
				var radius := (MAP_EDGE + radial * 2400.0) / maxf(absf(direction.x), absf(direction.y))
				var p := direction * radius
				quad.append(Vector3(p.x, _ridge_height(p.x, p.y), p.y))
			_triangle(st, quad[0], quad[1], quad[2])
			_triangle(st, quad[1], quad[3], quad[2])
	st.index()
	st.generate_normals()
	var ridge := MeshInstance3D.new()
	ridge.name = "ErodedMountainCatchment"
	ridge.mesh = st.commit()
	ridge.material_override = _terrain_material
	add_child(ridge)
	ridge.create_trimesh_collision()

func _build_water() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const W_SEGS := 16
	for i in 400:
		var z0 := -MAP_EDGE + float(i) * 5.0
		var z1 := z0 + 5.0
		var rc0 := river_center(z0)
		var rw0 := river_width(z0) + 32.0
		var rc1 := river_center(z1)
		var rw1 := river_width(z1) + 32.0
		for w in W_SEGS:
			var ky0 := lerpf(-1.0, 1.0, float(w) / float(W_SEGS))
			var ky1 := lerpf(-1.0, 1.0, float(w + 1) / float(W_SEGS))
			var p0 := Vector3(rc0 + ky0 * rw0, WATER_LEVEL, z0)
			var p1 := Vector3(rc1 + ky0 * rw1, WATER_LEVEL, z1)
			var p2 := Vector3(rc0 + ky1 * rw0, WATER_LEVEL, z0)
			var p3 := Vector3(rc1 + ky1 * rw1, WATER_LEVEL, z1)
			_triangle(st, p0, p1, p2)
			_triangle(st, p2, p1, p3)
	st.index()
	st.generate_normals()
	var water := MeshInstance3D.new()
	water.name = "SinuousRiverSurface"
	water.mesh = st.commit()
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/landscape_water.gdshader")
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

func _asset_mesh(path: String) -> Mesh:
	var scene := (load(path) as PackedScene).instantiate()
	var st := SurfaceTool.new()
	var merged := ArrayMesh.new()
	_merge_asset(scene, Transform3D.IDENTITY, st, merged)
	scene.free()
	return merged

func _merge_asset(node: Node, transform: Transform3D, st: SurfaceTool, merged: ArrayMesh) -> void:
	var t := transform
	if node is Node3D:
		t = transform * node.transform
	if node is MeshInstance3D:
		if String(node.name).begins_with("grass_medium_01") and String(node.name) != "grass_medium_01_small_a_LOD0":
			return
		for surface in node.mesh.get_surface_count():
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.append_from(node.mesh, surface, t)
			var mat: Material = node.mesh.surface_get_material(surface)
			if mat is StandardMaterial3D:
				mat = mat.duplicate()
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			st.set_material(mat)
			st.commit(merged)
	for child in node.get_children():
		_merge_asset(child, t, st, merged)

func _batch(mesh: Mesh, transforms: Array[Transform3D], tag: String, material: Material = null) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.name = tag
	node.multimesh = mm
	if material:
		node.material_override = material
	add_child(node)
	return node

func _build_forest() -> void:
	_tree_lods = [_asset_mesh("res://assets/environment/fir/fir_lod0.glb"), _asset_mesh("res://assets/environment/fir/fir_lod1.glb"), _asset_mesh("res://assets/environment/fir/fir_lod2.glb"), _asset_mesh("res://assets/environment/fir/fir_lod3.glb")]
	# At distance, the photographed color/alpha carries foliage detail; tiny normal
	# and roughness maps add bandwidth without visible detail.
	for lod in range(4):
		var mesh := _tree_lods[lod] as ArrayMesh
		for surface in mesh.get_surface_count():
			var mat := mesh.surface_get_material(surface) as StandardMaterial3D
			if mat:
				if mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					mat.alpha_scissor_threshold = 0.25
				if lod == 0:
					continue
				mat.normal_enabled = false
				mat.normal_texture = null
				mat.roughness_texture = null
				mat.roughness = 0.94
				mat.metallic_texture = null
				mat.metallic = 0.0
				mat.metallic_specular = 0.15
	var rock_mesh := _asset_mesh("res://assets/environment/rock/rock_lod1.glb")
	var grass_mesh := _asset_mesh("res://assets/environment/grass/grass_medium_01.gltf")
	var rocks: Array[Transform3D] = []
	var grasses: Array[Transform3D] = []
	for i in 28000:
		var x := _rng.randf_range(-965.0, 965.0)
		var z := _rng.randf_range(-965.0, 965.0)
		if absf(x - 300.0) < 115.0 and absf(z - 120.0) < 110.0:
			continue
		if absf(x - 300.0) < 35.0 and z > 120.0 and z < 430.0:
			continue
		var h := ground_height(x, z)
		var slope := Vector2(ground_height(x + 5, z) - ground_height(x - 5, z), ground_height(x, z + 5) - ground_height(x, z - 5)).length() / 10.0
		var pos := Vector3(x, h - 0.06, z)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU)
		var forest := _noise.get_noise_2d(x * 0.28, z * 0.28)
		if h > 5.0 and h < 180.0 and slope < 0.65 and forest > -0.19 and _tree_transforms.size() < 2600:
			var size := _rng.randf_range(0.85, 1.6)
			_tree_transforms.append(Transform3D(basis.scaled(Vector3(size, size * _rng.randf_range(0.88, 1.18), size)), pos))
		elif h > 1.0 and h < 100.0 and slope < 0.65 and grasses.size() < 1800:
			grasses.append(Transform3D(basis.scaled(Vector3.ONE * _rng.randf_range(0.55, 1.2)), pos))
		if i % 47 == 0 and h > 0.5 and rocks.size() < 190:
			rocks.append(Transform3D(basis.scaled(Vector3(_rng.randf_range(1.0, 2.5), _rng.randf_range(1.0, 2.6), _rng.randf_range(1.0, 2.4))), pos - Vector3.UP * 0.12))
	# Coherent mixed-age stands frame the approach, with broad walking lanes clear.
	for z_index in 14:
		for x_index in 22:
			var x := 95.0 + x_index * 18.0 + _rng.randf_range(-6.0, 6.0)
			var z := 255.0 + z_index * 19.0 + _rng.randf_range(-7.0, 7.0)
			if absf(x - 300.0) < 39.0:
				continue
			var h := ground_height(x, z)
			var slope := Vector2(ground_height(x + 5, z) - ground_height(x - 5, z), ground_height(x, z + 5) - ground_height(x, z - 5)).length() / 10.0
			if h < 3.0 or h > 175.0 or slope > 0.60:
				continue
			if _tree_transforms.size() >= 2771:
				continue
			var size := _rng.randf_range(1.05, 1.65)
			_tree_transforms.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(x, h - 0.06, z)))
	for i in 650:
		var z := _rng.randf_range(-400.0, 500.0)
		var side := -1.0 if i % 2 else 1.0
		var x := river_center(z) + side * (river_width(z) + _rng.randf_range(27.0, 65.0))
		var h := ground_height(x, z)
		if h > 1.0:
			grasses.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.8, 1.4)), Vector3(x, h, z)))
	# River stones and boulders along the river channel and shorelines (matching alpine river reference)
	for i in 320:
		var z := _rng.randf_range(-950.0, 950.0)
		var offset := _rng.randf_range(-1.0, 1.0) * (river_width(z) + _rng.randf_range(-6.0, 18.0))
		var x := river_center(z) + offset
		var h := ground_height(x, z)
		if h >= -2.2 and h <= 2.2:
			var s_xz := _rng.randf_range(1.1, 3.6)
			var s_y := _rng.randf_range(0.55, 2.0)
			var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s_xz, s_y, s_xz))
			rocks.append(Transform3D(b, Vector3(x, h - _rng.randf_range(0.06, 0.30), z)))
	for lod in 4:
		for cz in 4:
			for cx in 4:
				var node := _batch(_tree_lods[lod], [], "Forest_LOD%s_%s_%s" % [lod, cx, cz])
				if lod >= 2:
					node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_forest_nodes.append(node)
	_update_forest_lods()
	_batch(rock_mesh, rocks, "ScatteredBoulders")
	var grass := _batch(grass_mesh, grasses, "PhotographicMeadowTufts")
	grass.visibility_range_end = 210.0
	grass.visibility_range_end_margin = 35.0
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Scanned eroded formations visibly anchor the river and mountain feet.
	var scan := _asset_mesh("res://assets/environment/rock/rock_lod0.glb")
	for data in [Vector4(138, -160, 17, 0.6), Vector4(-138, 220, 13, 1.5), Vector4(550, -100, 20, 2.3), Vector4(-590, -420, 27, 0.2), Vector4(790, 300, 34, 1.1)]:
		var outcrop := MeshInstance3D.new()
		outcrop.name = "ScannedLimestoneOutcrop"
		outcrop.mesh = scan
		var footing := ground_height(data.x, data.y)
		for dx in [-1.0, 0.0, 1.0]:
			for dz in [-1.0, 0.0, 1.0]:
				footing = minf(footing, ground_height(data.x + dx * data.z * 1.5, data.y + dz * data.z * 1.5))
		outcrop.position = Vector3(data.x, footing - 3.0, data.y)
		outcrop.rotation.y = data.w
		outcrop.scale = Vector3(data.z, data.z * 1.25, data.z)
		add_child(outcrop)
		outcrop.create_trimesh_collision()
		for body in outcrop.get_children():
			if body is StaticBody3D:
				body.collision_layer = 2
				body.add_to_group("scenery_obstacle")
	var cliff := MeshInstance3D.new()
	cliff.name = "GithubNamaqualandCliffScan"
	cliff.mesh = _asset_mesh("res://assets/environment/github_cliff.glb")
	cliff.position = Vector3(462, ground_height(462, 145) - 1.4, 145)
	cliff.rotation.y = -PI * 0.5
	cliff.scale = Vector3.ONE * 4.0
	add_child(cliff)
	cliff.create_trimesh_collision()
	for body in cliff.get_children():
		if body is StaticBody3D:
			body.collision_layer = 2
			body.collision_mask = 0
			body.add_to_group("scenery_obstacle")
	print("LANDSCAPE mature fir, grass, limestone; ", _tree_transforms.size(), " trees. Courtyard ", ARENA_CENTER)

func _process(delta: float) -> void:
	_lod_timer += delta
	if _lod_timer > 0.2:
		_lod_timer = 0.0
		_update_forest_lods()

func _update_forest_lods() -> void:
	if _forest_nodes.is_empty():
		return
	var camera := get_viewport().get_camera_3d()
	var viewer := to_local(camera.global_position) if camera else Vector3(300, 100, 350)
	var buckets: Array = []
	for i in 64:
		buckets.append([])
	var frustum: Array = camera.get_frustum() if camera else []
	for transform in _tree_transforms:
		var size := transform.basis.get_scale().y
		var crown_center := transform.origin + Vector3.UP * 9.4 * size
		var distance := viewer.distance_to(crown_center)
		# Individual sphere culling avoids drawing an entire 500m MultiMesh cell.
		# Nearby casters remain even outside the view so their ground shadows persist.
		if distance > 80.0 and camera:
			var culled := false
			var world_center := to_global(crown_center)
			for plane in frustum:
				if plane.distance_to(world_center) > 11.0 * size + distance * 0.20:
					culled = true
					break
			if culled:
				continue
		var lod := 0 if distance < 32.0 else (1 if distance < 75.0 else (2 if distance < 230.0 else 3))
		var cx := clampi(int((transform.origin.x + 1000) / 500), 0, 3)
		var cz := clampi(int((transform.origin.z + 1000) / 500), 0, 3)
		buckets[lod * 16 + cz * 4 + cx].append(transform)
	for i in 64:
		var mm := _forest_nodes[i].multimesh
		if mm.instance_count != buckets[i].size():
			mm.instance_count = buckets[i].size()
		for j in buckets[i].size():
			mm.set_instance_transform(j, buckets[i][j])

func _setup_atmosphere() -> void:
	var world := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun := get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun:
		sun.rotation_degrees = Vector3(-39.0, -38.0, 0)
		sun.light_color = Color(1.0, 0.95, 0.85)
		sun.light_energy = 1.25
		sun.light_angular_distance = 0.55
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 360.0
		sun.directional_shadow_fade_start = 0.85
	if world and world.environment:
		var env := world.environment
		var sky_material := ShaderMaterial.new()
		sky_material.shader = load("res://shaders/landscape_sky.gdshader")
		if sun:
			sky_material.set_shader_parameter("sun_direction", sun.global_basis.z)
		var sky := Sky.new()
		sky.sky_material = sky_material
		sky.radiance_size = Sky.RADIANCE_SIZE_256
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.5
		env.fog_enabled = true
		env.fog_density = 0.00028
		env.fog_sky_affect = 0.16
		env.fog_light_color = Color(0.69, 0.76, 0.77)
		env.fog_sun_scatter = 0.3
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.ssao_enabled = true
		env.ssao_radius = 1.6
		env.ssao_intensity = 1.2
		env.ssil_enabled = true
		env.ssil_radius = 3.0
		env.ssil_intensity = 0.35
