extends Node3D

## One triangulated surface drives both rendering and ground queries. Scanned props
## are separate layer-2 obstacles; the courtyard and riverbed are part of layer 1.
const MAP_EDGE := 1000.0
const ORIGINAL_STEP := 2000.0 / 120.0
const GRID_COUNT := 320
const GRID_STEP := 2000.0 / GRID_COUNT
const ARENA_CENTER := Vector3(300.0, 24.0, 120.0)
const WATER_LEVEL := 0.7
const LAKE_CENTER := Vector2(-520.0, -280.0)
const LAKE_RADIUS := 90.0
const LAKE_CLEARING_RADIUS := 135.0
var _source_heights: Dictionary = {}
var _heights := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _ridge_noise := FastNoiseLite.new()
var _erosion_noise := FastNoiseLite.new()
var _hill_noise := FastNoiseLite.new()
var _terrain_material: ShaderMaterial
const GrassGen = preload("res://scripts/grass_generator.gd")
var _tree_transforms: Array[Transform3D] = []
# Especie y variante de cada árbol (paralelos a _tree_transforms) para medir su malla real.
var _tree_species: Array[String] = []
var _tree_variants: Array[int] = []
var _mature_fir_transforms: Array[Transform3D] = []
var boulder_transforms: Array[Transform3D] = []
var river_boulder_transforms: Array[Transform3D] = []
var log_transforms: Array[Transform3D] = []
var _tree_lods: Array = []
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
	_hill_noise.seed = 445219
	_hill_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hill_noise.frequency = 0.0034
	_hill_noise.fractal_octaves = 3
	_hill_noise.fractal_gain = 0.48
	_hill_noise.fractal_lacunarity = 2.1
	_collect_source(self)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_terrain_material = ShaderMaterial.new()
	_terrain_material.shader = load("res://shaders/terrain.gdshader")
	_terrain_material.set_shader_parameter("rock_albedo", load("res://assets/environment/rock_face_diff_2k.jpg"))
	_terrain_material.set_shader_parameter("earth_albedo", load("res://assets/environment/forest_ground_04_diffuse.jpg"))
	_terrain_material.set_shader_parameter("grass_albedo", load("res://assets/environment/aerial_grass_diff.jpg"))
	_terrain_material.set_shader_parameter("pebbles_albedo", load("res://assets/environment/pebbles/river_pebbles_diff_2k.jpg"))
	_terrain_material.set_shader_parameter("pebbles_normal", load("res://assets/environment/pebbles/river_pebbles_nor_gl_2k.jpg"))
	_terrain_material.set_shader_parameter("pebbles_roughness", load("res://assets/environment/pebbles/river_pebbles_rough_2k.jpg"))
	_build_ground()
	_build_distant_ridges()
	_build_water()
	_build_forest()
	_setup_atmosphere()

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

func stream_west_center(z: float) -> float:
	return -530.0 + sin((z + 180.0) * 0.0075) * 65.0 + sin(z * 0.019) * 18.0

func stream_east_center(z: float) -> float:
	return 570.0 + sin((z + 90.0) * 0.008) * 55.0 + cos(z * 0.02) * 16.0

func _is_in_stream(x: float, z: float) -> bool:
	if z >= -240.0 and z <= 330.0 and absf(x - stream_west_center(z)) < 15.0:
		return true
	if z >= -350.0 and z <= 190.0 and absf(x - stream_east_center(z)) < 14.0:
		return true
	return false

func _landform_height(x: float, z: float) -> float:
	var distance_to_river := absf(x - river_center(z))
	var width := river_width(z)
	var detail := _noise.get_noise_2d(x, z)
	var court_distance := maxf(absf(x - ARENA_CENTER.x) / 88.0, absf(z - ARENA_CENTER.z) / 78.0)

	# 1. Natural base elevation from original terrain contours, preserved with authentic relief
	var raw_orig := _original_height(x, z)
	var base_h := maxf(raw_orig * 0.52 + 5.5, 7.5)

	# 2. Domain-warped organic geological folds (eliminates geometric bubbles)
	var warp_x := _erosion_noise.get_noise_2d(x * 0.0022 + 230.0, z * 0.0022 - 310.0) * 95.0
	var warp_z := _erosion_noise.get_noise_2d(x * 0.0022 - 410.0, z * 0.0022 + 190.0) * 95.0
	var wx := x + warp_x
	var wz := z + warp_z

	# 3. Multi-scale rolling hill ridges, shoulders and saddles (Foto de referencia)
	# Primary broad rolling hill chains (~450m scale)
	var h1 := _hill_noise.get_noise_2d(wx * 0.0022, wz * 0.0022)
	# Secondary undulating ridgelines and shoulders (~180m scale)
	var h2 := 1.0 - absf(_ridge_noise.get_noise_2d(wx * 0.0048 + 140.0, wz * 0.0048 - 290.0))
	# Subtle drainage erosion creases (~65m scale)
	var h3 := _erosion_noise.get_noise_2d(x * 0.010, z * 0.010)

	var hill_relief := smoothstep(-0.25, 0.65, h1) * (26.0 + h2 * 32.0) + pow(maxf(h2, 0.0), 1.35) * 16.0 - absf(h3) * 5.5

	# Natural mountain foothill transition toward map margins (smoothly ramps up toward distant cordilleras)
	var edge_dist := maxf(absf(x), absf(z)) / MAP_EDGE
	var margin_rise := smoothstep(0.45, 0.98, edge_dist) * (25.0 + h2 * 45.0)

	var h := base_h + hill_relief + margin_rise + detail * 2.8

	# Mask out hill deformation near protected gameplay areas:
	var court_protection := 1.0 - smoothstep(1.0, 1.45, court_distance)
	var gate_road_protection := 0.0
	if z > 160.0 and z < 410.0:
		gate_road_protection = (1.0 - smoothstep(16.0, 38.0, absf(x - 300.0))) * (1.0 - smoothstep(330.0, 410.0, z))

	# Distance to forest lake basin (Foto 4)
	var lake_dist := (Vector2(x, z) - LAKE_CENTER).length()
	var noisy_lake_dist := lake_dist + _noise.get_noise_2d(x * 0.08, z * 0.08) * 14.0

	# Carve forest lake in a wide, gentle clearing (Foto 4)
	var clearing_t := (1.0 - smoothstep(LAKE_RADIUS + 8.0, LAKE_CLEARING_RADIUS + 75.0, noisy_lake_dist))
	if clearing_t > 0.0:
		h = lerpf(h, 3.2 + detail * 0.35, clearing_t)
	var lake_t := 1.0 - smoothstep(LAKE_RADIUS - 12.0, LAKE_RADIUS + 12.0, noisy_lake_dist)
	if lake_t > 0.0:
		h = lerpf(h, -2.8 + detail * 0.30, lake_t)

	# Carve forest streams / riachuelos in deep woods (Fotos 2 & 3 y Video)
	var dist_w := absf(x - stream_west_center(z))
	var in_west_stream_z := z >= -260.0 and z <= 350.0
	var blend_z_w := smoothstep(-260.0, -220.0, z) * smoothstep(350.0, 310.0, z) if in_west_stream_z else 0.0
	if blend_z_w > 0.0:
		var valley_t := (1.0 - smoothstep(14.0, 85.0, dist_w)) * blend_z_w
		if valley_t > 0.0:
			h = lerpf(h, 2.8 + detail * 0.35, valley_t)
		var st_t := (1.0 - smoothstep(5.0, 15.0, dist_w)) * blend_z_w
		if st_t > 0.0:
			h = lerpf(h, -1.25 + detail * 0.25, st_t)

	var dist_e := absf(x - stream_east_center(z))
	var in_east_stream_z := z >= -370.0 and z <= 210.0
	var blend_z_e := smoothstep(-370.0, -330.0, z) * smoothstep(210.0, 170.0, z) if in_east_stream_z else 0.0
	if blend_z_e > 0.0:
		var valley_e := (1.0 - smoothstep(13.0, 80.0, dist_e)) * blend_z_e
		if valley_e > 0.0:
			h = lerpf(h, 2.8 + detail * 0.35, valley_e)
		var st_t_e := (1.0 - smoothstep(5.0, 14.5, dist_e)) * blend_z_e
		if st_t_e > 0.0:
			h = lerpf(h, -1.20 + detail * 0.25, st_t_e)

	# River carving: incised gravel riverbed -> exposed banks -> terrace
	var bank := smoothstep(width - 8.0, width + 55.0, distance_to_river)
	h = lerpf(-3.0 + detail * 0.35, h, bank)

	# Level courtyard inside castle fortress walls
	h = lerpf(h, ARENA_CENTER.y, court_protection)

	# Grade approach road to the gate
	if gate_road_protection > 0.0:
		h = lerpf(h, 24.0, gate_road_protection)

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
	if absf(p.z) > MAP_EDGE or absf(p.x) > MAP_EDGE:
		return false
	if ground_height(p.x, p.z) >= WATER_LEVEL:
		return false
	if absf(p.x - river_center(p.z)) < river_width(p.z) + 32.0:
		return true
	if (Vector2(p.x, p.z) - LAKE_CENTER).length() < LAKE_RADIUS + 15.0:
		return true
	if _is_in_stream(p.x, p.z):
		return true
	return false

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
	var t := clampf((radius - MAP_EDGE) / 1400.0, 0.0, 1.0)
	
	# Domain warping for organic, natural geological curvature
	var wx := x + _erosion_noise.get_noise_2d(x * 0.0018 + 520.0, z * 0.0018 - 380.0) * 180.0
	var wz := z + _erosion_noise.get_noise_2d(x * 0.0018 - 290.0, z * 0.0018 + 610.0) * 180.0

	# 1. Primary folded cordillera chain (continuous undulating mountain spine)
	var n1 := _ridge_noise.get_noise_2d(wx * 0.75, wz * 0.75)
	var ridge1 := 1.0 - absf(n1)
	var spine := smoothstep(0.18, 0.82, ridge1) * 320.0

	# 2. Secondary branching ridges / spurs and mountain shoulders
	var n2 := _ridge_noise.get_noise_2d(wx * 1.55 + 173.0, wz * 1.55 - 289.0)
	var ridge2 := 1.0 - absf(n2)
	var spurs := pow(maxf(ridge2, 0.0), 1.5) * 160.0

	# 3. Broad geological massif foundation (rolling high plateaus and foothills)
	var massif := (1.0 + _hill_noise.get_noise_2d(wx * 0.65, wz * 0.65)) * 0.5 * 140.0

	# 4. Drainage valleys and erosion incisions between mountain folds
	var erosion := absf(_erosion_noise.get_noise_2d(wx * 2.2, wz * 2.2)) * 45.0

	# 5. Fine surface rock relief
	var detail := _noise.get_noise_2d(x * 0.8, z * 0.8) * 16.0

	var mountain_mass := massif + spine + spurs - erosion + detail
	var final_h := edge_h + mountain_mass * smoothstep(0.0, 1.0, t)
	return maxf(final_h, edge_h)

func _build_distant_ridges() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 160
	const RINGS := 32
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
	ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ridge)
	ridge.create_trimesh_collision()
	_build_distant_ridge_forest()

func _create_distant_canopy_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.38, 0.16)
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	var foliage_tex = load("res://assets/environment/foliage/foliage_pine.png") as Texture2D
	if foliage_tex:
		mat.albedo_texture = foliage_tex
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.28
	st.set_material(mat)
	
	var angles := [0.0, PI / 3.0, 2.0 * PI / 3.0]
	var w := 10.0
	var h := 16.0
	for a in angles:
		var dir := Vector3(cos(a), 0, sin(a)) * w * 0.5
		var p0 := -dir
		var p1 := dir
		var p2 := dir + Vector3(0, h, 0)
		var p3 := -dir + Vector3(0, h, 0)
		st.set_uv(Vector2(0, 1)); st.add_vertex(p0)
		st.set_uv(Vector2(1, 1)); st.add_vertex(p1)
		st.set_uv(Vector2(1, 0)); st.add_vertex(p2)
		st.set_uv(Vector2(0, 1)); st.add_vertex(p0)
		st.set_uv(Vector2(1, 0)); st.add_vertex(p2)
		st.set_uv(Vector2(0, 0)); st.add_vertex(p3)
	st.index()
	st.generate_normals()
	return st.commit()

func _build_distant_ridge_forest() -> void:
	var ridge_tree_transforms: Array[Transform3D] = []
	var canopy_mesh := _create_distant_canopy_mesh()
	const RIDGE_SAMPLES := 48000
	for i in RIDGE_SAMPLES:
		var angle := _rng.randf() * TAU
		var radial := _rng.randf()
		var r_dist := lerpf(1015.0, 2600.0, pow(radial, 0.75))
		var dir := Vector2(cos(angle), sin(angle))
		var norm_box := maxf(absf(dir.x), absf(dir.y))
		var p := dir * (r_dist / norm_box)
		var h := _ridge_height(p.x, p.y)
		if h > 720.0:
			continue
		var sl := Vector2(
			_ridge_height(p.x + 12.0, p.y) - _ridge_height(p.x - 12.0, p.y),
			_ridge_height(p.x, p.y + 12.0) - _ridge_height(p.x, p.y - 12.0)
		).length() / 24.0
		if sl > 0.98:
			continue
		var dist_factor := clampf((r_dist - 1000.0) / 1600.0, 0.0, 1.0)
		var size := _rng.randf_range(1.8, 3.6) * lerpf(1.0, 1.7, dist_factor)
		var yaw := _rng.randf() * TAU
		if i % 4 == 0:
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * (size * 1.35))
			ridge_tree_transforms.append(Transform3D(basis, Vector3(p.x, h - 0.4, p.y)))
	
	if ridge_tree_transforms.size() > 0:
		var node := _batch(canopy_mesh, ridge_tree_transforms, "DistantRidgeForestCanopy")
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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

	# Alpine Forest Lake (Foto 4)
	var st_lake := SurfaceTool.new()
	st_lake.begin(Mesh.PRIMITIVE_TRIANGLES)
	const LAKE_RINGS := 14
	const LAKE_SECS := 48
	for r in LAKE_RINGS:
		var r0 := float(r) / float(LAKE_RINGS) * (LAKE_RADIUS + 12.0)
		var r1 := float(r + 1) / float(LAKE_RINGS) * (LAKE_RADIUS + 12.0)
		for s in LAKE_SECS:
			var a0 := float(s) / float(LAKE_SECS) * TAU
			var a1 := float(s + 1) / float(LAKE_SECS) * TAU
			var lp0 := Vector3(LAKE_CENTER.x + cos(a0) * r0, WATER_LEVEL, LAKE_CENTER.y + sin(a0) * r0)
			var lp1 := Vector3(LAKE_CENTER.x + cos(a0) * r1, WATER_LEVEL, LAKE_CENTER.y + sin(a0) * r1)
			var lp2 := Vector3(LAKE_CENTER.x + cos(a1) * r0, WATER_LEVEL, LAKE_CENTER.y + sin(a1) * r0)
			var lp3 := Vector3(LAKE_CENTER.x + cos(a1) * r1, WATER_LEVEL, LAKE_CENTER.y + sin(a1) * r1)
			_triangle(st_lake, lp0, lp1, lp2)
			_triangle(st_lake, lp2, lp1, lp3)
	st_lake.index()
	st_lake.generate_normals()
	var lake_water := MeshInstance3D.new()
	lake_water.name = "AlpineForestLakeSurface"
	lake_water.mesh = st_lake.commit()
	lake_water.material_override = material
	lake_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lake_water)

	# West Forest Stream / Riachuelo (Fotos 2 & 3)
	var st_west := SurfaceTool.new()
	st_west.begin(Mesh.PRIMITIVE_TRIANGLES)
	const W_STREAM_STEPS := 120
	for i in W_STREAM_STEPS:
		var z0 := -240.0 + float(i) * (570.0 / float(W_STREAM_STEPS))
		var z1 := -240.0 + float(i + 1) * (570.0 / float(W_STREAM_STEPS))
		var cx0 := stream_west_center(z0)
		var cx1 := stream_west_center(z1)
		var sw0 := 12.0
		var sw1 := 12.0
		var wp0 := Vector3(cx0 - sw0, WATER_LEVEL, z0)
		var wp1 := Vector3(cx1 - sw0, WATER_LEVEL, z1)
		var wp2 := Vector3(cx0 + sw0, WATER_LEVEL, z0)
		var wp3 := Vector3(cx1 + sw0, WATER_LEVEL, z1)
		_triangle(st_west, wp0, wp1, wp2)
		_triangle(st_west, wp2, wp1, wp3)
	st_west.index()
	st_west.generate_normals()
	var west_stream := MeshInstance3D.new()
	west_stream.name = "WestForestStreamSurface"
	west_stream.mesh = st_west.commit()
	west_stream.material_override = material
	west_stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(west_stream)

	# East Forest Stream / Riachuelo
	var st_east := SurfaceTool.new()
	st_east.begin(Mesh.PRIMITIVE_TRIANGLES)
	const E_STREAM_STEPS := 110
	for i in E_STREAM_STEPS:
		var z0 := -350.0 + float(i) * (530.0 / float(E_STREAM_STEPS))
		var z1 := -350.0 + float(i + 1) * (530.0 / float(E_STREAM_STEPS))
		var cx0 := stream_east_center(z0)
		var cx1 := stream_east_center(z1)
		var sw0 := 11.5
		var sw1 := 11.5
		var ep0 := Vector3(cx0 - sw0, WATER_LEVEL, z0)
		var ep1 := Vector3(cx1 - sw0, WATER_LEVEL, z1)
		var ep2 := Vector3(cx0 + sw0, WATER_LEVEL, z0)
		var ep3 := Vector3(cx1 + sw0, WATER_LEVEL, z1)
		_triangle(st_east, ep0, ep1, ep2)
		_triangle(st_east, ep2, ep1, ep3)
	st_east.index()
	st_east.generate_normals()
	var east_stream := MeshInstance3D.new()
	east_stream.name = "EastForestStreamSurface"
	east_stream.mesh = st_east.commit()
	east_stream.material_override = material
	east_stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(east_stream)

func _asset_mesh(path: String) -> Mesh:
	var scene := (load(path) as PackedScene).instantiate()
	var st := SurfaceTool.new()
	var merged := ArrayMesh.new()
	_merge_asset(scene, Transform3D.IDENTITY, st, merged)
	scene.free()
	return merged

func _load_glb_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var sc := load(path) as PackedScene
	if not sc:
		return null
	var inst := sc.instantiate()
	var mi := inst.find_child("*", true, false) as MeshInstance3D
	var m: Mesh = mi.mesh if mi else null
	inst.free()
	return m

func _merge_asset(node: Node, transform: Transform3D, st: SurfaceTool, merged: ArrayMesh) -> void:
	var t := transform
	if node is Node3D:
		t = transform * node.transform
	if node is MeshInstance3D:
		var n_name := String(node.name)
		if n_name.begins_with("searsia_burchellii_") and not n_name.ends_with("_LOD0"):
			return
		if n_name.begins_with("grass_medium_01") and n_name != "grass_medium_01_small_a_LOD0":
			return
		for surface in node.mesh.get_surface_count():
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.append_from(node.mesh, surface, t)
			var mat: Material = node.mesh.surface_get_material(surface)
			if mat is StandardMaterial3D:
				mat = mat.duplicate()
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				var m_name := mat.resource_name.to_lower()
				if "001" in m_name or "006" in m_name or "bark" in m_name:
					mat.albedo_color = Color(0.28, 0.20, 0.14)
				elif "002" in m_name or "007" in m_name or "leave" in m_name:
					mat.albedo_color = Color(0.18, 0.38, 0.12)
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					mat.alpha_scissor_threshold = 0.25
			st.set_material(mat)
			st.commit(merged)
	for child in node.get_children():
		_merge_asset(child, t, st, merged)

func _batch(mesh: Mesh, transforms: Array, tag: String, material: Material = null) -> MultiMeshInstance3D:
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

func _batch_spatial(mesh: Mesh, transforms: Array, tag: String, grid_div: int, map_half: float, vis_end: float, vis_margin: float, material: Material = null) -> void:
	if transforms.is_empty():
		return
	var buckets: Dictionary = {}
	var cell_span := (map_half * 2.0) / float(grid_div)
	for xform in transforms:
		var t: Transform3D = xform
		var cx := clampi(int((t.origin.x + map_half) / cell_span), 0, grid_div - 1)
		var cz := clampi(int((t.origin.z + map_half) / cell_span), 0, grid_div - 1)
		var key := cz * grid_div + cx
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(t)
	var first := true
	for key in buckets.keys():
		var cell_name := tag if first else "%s_cell_%d" % [tag, key]
		first = false
		var node := _batch(mesh, buckets[key], cell_name, material)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if vis_end > 0.0:
			node.visibility_range_end = vis_end
			node.visibility_range_end_margin = vis_margin

func _decimate_rock_mesh(src_mesh: ArrayMesh, stride: int) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in src_mesh.get_surface_count():
		var mat := src_mesh.surface_get_material(s) as StandardMaterial3D
		if mat:
			mat = mat.duplicate() as StandardMaterial3D
			_simplify_material(mat)
		var arr: Array = src_mesh.surface_get_arrays(s)
		var vtx: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var step := 3 * maxi(1, stride)
		for i in range(0, idx.size() - 2, step):
			for k in 3:
				var vi := idx[i + k]
				if uvs.size() > 0: st.set_uv(uvs[vi])
				if nrm.size() > 0: st.set_normal(nrm[vi])
				st.add_vertex(vtx[vi])
		st.set_material(mat)
		st.commit(out)
	out.set_custom_aabb(src_mesh.get_aabb())
	return out

func _simplify_material(mat: StandardMaterial3D) -> void:
	if not mat:
		return
	if mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.25
	mat.normal_enabled = false
	mat.normal_texture = null
	mat.roughness_texture = null
	mat.roughness = 0.92
	mat.metallic_texture = null
	mat.metallic = 0.0
	mat.metallic_specular = 0.12

func _decimate_pine_mesh(src_mesh: ArrayMesh, stride: int, card_scale: float, target_aabb: AABB) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in src_mesh.get_surface_count():
		var mat := src_mesh.surface_get_material(s) as StandardMaterial3D
		if mat:
			mat = mat.duplicate() as StandardMaterial3D
			_simplify_material(mat)
		if s == 0:
			var st0 := SurfaceTool.new()
			st0.begin(Mesh.PRIMITIVE_TRIANGLES)
			st0.append_from(src_mesh, 0, Transform3D.IDENTITY)
			st0.set_material(mat)
			st0.commit(out)
		else:
			var arr: Array = src_mesh.surface_get_arrays(s)
			var vtx: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var st1 := SurfaceTool.new()
			st1.begin(Mesh.PRIMITIVE_TRIANGLES)
			var step := 3 * maxi(1, stride)
			for i in range(0, idx.size() - 2, step):
				var i0 := idx[i]
				var i1 := idx[i + 1]
				var i2 := idx[i + 2]
				var v0 := vtx[i0]
				var v1 := vtx[i1]
				var v2 := vtx[i2]
				var c := (v0 + v1 + v2) / 3.0
				v0 = c + (v0 - c) * card_scale
				v1 = c + (v1 - c) * card_scale
				v2 = c + (v2 - c) * card_scale
				if uvs.size() > 0: st1.set_uv(uvs[i0])
				if nrm.size() > 0: st1.set_normal(nrm[i0])
				st1.add_vertex(v0)
				if uvs.size() > 0: st1.set_uv(uvs[i1])
				if nrm.size() > 0: st1.set_normal(nrm[i1])
				st1.add_vertex(v1)
				if uvs.size() > 0: st1.set_uv(uvs[i2])
				if nrm.size() > 0: st1.set_normal(nrm[i2])
				st1.add_vertex(v2)
			st1.set_material(mat)
			st1.commit(out)
	out.set_custom_aabb(target_aabb)
	return out

func _clone_mesh_with_aabb(src_mesh: ArrayMesh, target_aabb: AABB) -> ArrayMesh:
	var copy := src_mesh.duplicate() as ArrayMesh
	copy.set_custom_aabb(target_aabb)
	return copy

func _build_forest() -> void:
	var fir_lod1 := _asset_mesh("res://assets/environment/fir/fir_lod1.glb") as ArrayMesh
	var fir_lod2 := _asset_mesh("res://assets/environment/fir/fir_lod2.glb") as ArrayMesh
	var fir_lod3 := _asset_mesh("res://assets/environment/fir/fir_lod3.glb") as ArrayMesh
	for mesh in [fir_lod1, fir_lod2, fir_lod3]:
		for surface in mesh.get_surface_count():
			_simplify_material(mesh.surface_get_material(surface) as StandardMaterial3D)
	_tree_lods = [
		_clone_mesh_with_aabb(fir_lod2, AABB(Vector3(-3.241559, 0.128333, -3.559948), Vector3(6.583094, 18.7485, 6.467402))),
		fir_lod1,
		fir_lod2,
		fir_lod3
	]
	var rock_mesh := _asset_mesh("res://assets/environment/rock/rock_lod1.glb") as ArrayMesh
	for surface in rock_mesh.get_surface_count():
		_simplify_material(rock_mesh.surface_get_material(surface) as StandardMaterial3D)
	var boulder_mesh := _decimate_rock_mesh(rock_mesh, 6)
	var grass_mesh_0 := GrassGen.generate_tuft_mesh(0)
	var grass_mesh_1 := GrassGen.generate_tuft_mesh(1)
	var grass_material := ShaderMaterial.new()
	grass_material.shader = load("res://shaders/grass.gdshader")
	grass_material.set_shader_parameter("texture_albedo", load("res://assets/environment/grass/textures/grass_medium_01_diff_2k.jpg"))
	grass_material.set_shader_parameter("use_photographic_texture", true)
	grass_material.set_shader_parameter("alpha_scissor_threshold", 0.35)
	grass_material.set_shader_parameter("wind_speed", 2.4)
	grass_material.set_shader_parameter("wind_strength", 0.36)
	grass_material.set_shader_parameter("backlight_tint", Color(0.42, 0.58, 0.15))

	var grass_gltf := (load("res://assets/environment/grass/grass_medium_01.gltf") as PackedScene).instantiate()
	var g_mesh_tall: Mesh = null
	var mi_t := grass_gltf.find_child("grass_medium_01_tall_a_LOD0", true, false) as MeshInstance3D
	if mi_t: g_mesh_tall = mi_t.mesh
	grass_gltf.free()

	# AAA Botanical Species / Races of trees:
	var species_types := ["oak", "eucalyptus", "birch", "pine", "fir"]
	var species_meshes: Dictionary = {}
	var species_transforms: Dictionary = {}
	for sp in species_types:
		species_transforms[sp] = [[], [], []]

	# Photogrammetric 3D Scans for Conifers using lightweight LODs + exact original AABBs:
	species_meshes["fir"] = [
		_tree_lods[0],
		_clone_mesh_with_aabb(fir_lod2, fir_lod1.get_aabb()),
		_clone_mesh_with_aabb(fir_lod3, fir_lod2.get_aabb())
	]

	# Pine: Decimated from pine_lod2.glb (~820 tris vs 106,879 tris) while preserving exact AABBs
	var pine_base := _asset_mesh("res://assets/environment/pine/pine_lod2.glb") as ArrayMesh
	species_meshes["pine"] = [
		_decimate_pine_mesh(pine_base, 24, 1.55, AABB(Vector3(-0.360306, -0.015484, -0.371386), Vector3(0.787674, 1.298833, 0.727431))),
		_decimate_pine_mesh(pine_base, 28, 1.60, AABB(Vector3(-0.360468, -0.015808, -0.371449), Vector3(0.787866, 1.299347, 0.727495))),
		_decimate_pine_mesh(pine_base, 32, 1.65, AABB(Vector3(-0.360049, -0.015808, -0.371449), Vector3(0.787533, 1.295364, 0.727553)))
	]

	# NEW REALISTIC 3D SCANNED TREE ASSETS (Completely replaces all old procedural trees):
	var narnia_tree := _asset_mesh("res://assets/environment/narnia/narnia_tree_3d.glb") as ArrayMesh
	var searsia_tree := _asset_mesh("res://assets/environment/trees/searsia_tree.glb") as ArrayMesh
	if not narnia_tree: narnia_tree = fir_lod1
	if not searsia_tree: searsia_tree = fir_lod2
	for m in [narnia_tree, searsia_tree]:
		for s in m.get_surface_count():
			_simplify_material(m.surface_get_material(s) as StandardMaterial3D)

	species_meshes["oak"] = [narnia_tree, _clone_mesh_with_aabb(narnia_tree, narnia_tree.get_aabb()), _clone_mesh_with_aabb(searsia_tree, searsia_tree.get_aabb())]
	species_meshes["birch"] = [searsia_tree, _clone_mesh_with_aabb(searsia_tree, searsia_tree.get_aabb()), _clone_mesh_with_aabb(narnia_tree, narnia_tree.get_aabb())]
	species_meshes["eucalyptus"] = [narnia_tree, _clone_mesh_with_aabb(searsia_tree, searsia_tree.get_aabb()), _clone_mesh_with_aabb(fir_lod2, fir_lod2.get_aabb())]

	var rocks: Array[Transform3D] = []
	var scanned_boulders_01: Array[Transform3D] = []
	var namaqualand_boulders: Array[Transform3D] = []
	var fallen_logs: Array[Transform3D] = []
	var river_pebble_clusters: Array[Transform3D] = []
	var grasses_0: Array[Transform3D] = []
	var grasses_1: Array[Transform3D] = []
	var grasses_hill: Array[Transform3D] = []
	var grasses_valley: Array[Transform3D] = []

	# Spatial Hash Grid: Guarantees strict distance separation between all trees
	# ("También deben estar mas separados, para notar que son distintos")
	var tree_grid: Dictionary = {}
	var grid_cell_size: float = 16.0

	var can_place_tree := func(pos_x: float, pos_z: float, min_d: float) -> bool:
		var gx := int(floor(pos_x / grid_cell_size))
		var gz := int(floor(pos_z / grid_cell_size))
		var min_d_sq := min_d * min_d
		var pt := Vector2(pos_x, pos_z)
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var key = Vector2i(gx + dx, gz + dz)
				if tree_grid.has(key):
					var cell_pts: Array = tree_grid[key]
					for other_pt in cell_pts:
						if pt.distance_squared_to(other_pt) < min_d_sq:
							return false
		return true

	var register_tree := func(pos_x: float, pos_z: float):
		var gx := int(floor(pos_x / grid_cell_size))
		var gz := int(floor(pos_z / grid_cell_size))
		var key = Vector2i(gx, gz)
		if not tree_grid.has(key):
			tree_grid[key] = []
		tree_grid[key].append(Vector2(pos_x, pos_z))

	# Helper to instantiate a botanically distinct tree with 100% unique scaling, yaw, and tilt
	var add_tree := func(sp: String, x: float, z: float, h: float, var_idx: int = -1):
		var base_size := 1.0
		match sp:
			"oak":
				base_size = _rng.randf_range(0.55, 0.85)
			"birch":
				base_size = _rng.randf_range(0.72, 1.05)
			"pine":
				base_size = _rng.randf_range(7.5, 11.0)
			"eucalyptus":
				base_size = _rng.randf_range(0.65, 0.95)
			"fir":
				base_size = _rng.randf_range(0.85, 1.25)
		var sx := base_size * _rng.randf_range(0.90, 1.12)
		var sy := base_size * _rng.randf_range(0.88, 1.15)
		var sz := base_size * _rng.randf_range(0.90, 1.12)
		var yaw := _rng.randf() * TAU
		var tilt_angle := _rng.randf_range(0.015, 0.050)
		var tilt_dir := _rng.randf() * TAU
		var tilt_rot := Basis(Vector3(cos(tilt_dir), 0.0, sin(tilt_dir)).normalized(), tilt_angle)
		var basis := (Basis(Vector3.UP, yaw) * tilt_rot).scaled(Vector3(sx, sy, sz))
		var tree_xform := Transform3D(basis, Vector3(x, h - 0.06, z))
		_tree_transforms.append(tree_xform)
		var v_idx := var_idx if (var_idx >= 0 and var_idx < 3) else _rng.randi_range(0, 2)
		_tree_species.append(sp)
		_tree_variants.append(v_idx)
		species_transforms[sp][v_idx].append(tree_xform)
		register_tree.call(x, z)

	# 1. Spawn Valley in front of the nest ("antes habían arboles ahí reponlos")
	# Stately, well-separated trees framing the view across the valley
	for i in 250:
		var x := _rng.randf_range(110.0, 235.0)
		var z := _rng.randf_range(45.0, 200.0)
		# Clear zone for player spawn and direct camera vista to nest
		if (x > 195.0 and x < 225.0 and z > 105.0 and z < 135.0):
			continue
		var h := ground_height(x, z)
		if h < WATER_LEVEL + 0.6:
			continue
		if can_place_tree.call(x, z, 18.0):
			var r_sp := _rng.randf()
			var sp_v: String
			if r_sp < 0.38:
				sp_v = "birch"
			elif r_sp < 0.65:
				sp_v = "pine"
			elif r_sp < 0.85:
				sp_v = "oak"
			else:
				sp_v = "fir"
			add_tree.call(sp_v, x, z, h)

	# 2. Gate Approach: Framed avenue with wide central walking corridor clear
	for i in 120:
		var x := _rng.randf_range(230.0, 370.0)
		var z := _rng.randf_range(200.0, 380.0)
		if absf(x - 300.0) < 15.0:
			continue
		var h := ground_height(x, z)
		if h < 2.0:
			continue
		if can_place_tree.call(x, z, 18.0):
			var sp_g := "oak" if _rng.randf() < 0.55 else "pine"
			add_tree.call(sp_g, x, z, h)

	# 3. Riparian Conifers and River Birches along stream banks (Fotos 2 & 3)
	for i in 200:
		var z_s := _rng.randf_range(-230.0, 310.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var x_s := stream_west_center(z_s) + side * _rng.randf_range(16.0, 38.0)
		var h_s := ground_height(x_s, z_s)
		if h_s > 1.2 and can_place_tree.call(x_s, z_s, 16.0):
			var sp_s := "birch" if _rng.randf() < 0.55 else "fir"
			add_tree.call(sp_s, x_s, z_s, h_s)

	for i in 180:
		var z_se := _rng.randf_range(-340.0, 170.0)
		var side_e := -1.0 if i % 2 == 0 else 1.0
		var x_se := stream_east_center(z_se) + side_e * _rng.randf_range(15.0, 36.0)
		var h_se := ground_height(x_se, z_se)
		if h_se > 1.2 and can_place_tree.call(x_se, z_se, 16.0):
			var sp_se := "pine" if _rng.randf() < 0.5 else "birch"
			add_tree.call(sp_se, x_se, z_se, h_se)

	# 4. Global World Forest Sampling across the island:
	for i in 55000:
		var x := _rng.randf_range(-965.0, 965.0)
		var z := _rng.randf_range(-965.0, 965.0)

		var h := ground_height(x, z)
		if h < WATER_LEVEL + 0.5:
			continue

		# Fortress & Nest protected space
		var dist_to_nest := Vector2(x - 300.0, z - 120.0).length()
		if dist_to_nest < 36.0 or (absf(x - 300.0) < 62.0 and absf(z - 120.0) < 52.0):
			continue
		if absf(x - 300.0) < 14.0 and z > 180.0 and z < 360.0:
			continue

		# Lake clearing: open water and grassy glade (Foto 4)
		var lake_dist := (Vector2(x, z) - LAKE_CENTER).length()
		if lake_dist < LAKE_CLEARING_RADIUS:
			var h_cl := ground_height(x, z)
			if h_cl > WATER_LEVEL + 0.3 and (grasses_0.size() + grasses_1.size()) < 6500:
				var basis_cl := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.70, 1.35))
				var t_cl := Transform3D(basis_cl, Vector3(x, h_cl, z))
				if grasses_0.size() <= grasses_1.size():
					grasses_0.append(t_cl)
				else:
					grasses_1.append(t_cl)
			continue

		# Water channels
		if is_water_at(Vector3(x, 0, z)) or _is_in_stream(x, z):
			continue

		# Natural valley clearings
		var glade_val := _noise.get_noise_2d(x * 0.005 + 520.0, z * 0.005 - 280.0)
		if glade_val > 0.42 and h < 7.5:
			if (grasses_0.size() + grasses_1.size()) < 18000:
				var t_gl := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.70, 1.35)), Vector3(x, h, z))
				if grasses_0.size() <= grasses_1.size():
					grasses_0.append(t_gl)
				else:
					grasses_1.append(t_gl)
			continue

		var slope := Vector2(ground_height(x + 5, z) - ground_height(x - 5, z), ground_height(x, z + 5) - ground_height(x, z - 5)).length() / 10.0
		if slope > 0.88:
			continue

		# Rolling hills rule ("las colinas no deben estar infestadas de árboles deben tener hierba y ser verdes"):
		# On hills (h > 12.0), low density and wide spacing
		var req_dist: float = 16.0
		if h > 12.0:
			if _rng.randf() > 0.28:
				continue
			req_dist = 22.0

		if not can_place_tree.call(x, z, req_dist):
			continue

		# Ecological biome determination
		var dist_to_west := absf(x - stream_west_center(z)) if (z >= -260.0 and z <= 350.0) else 999.0
		var dist_to_east := absf(x - stream_east_center(z)) if (z >= -370.0 and z <= 210.0) else 999.0
		var dist_to_stream := minf(dist_to_west, dist_to_east)
		var dist_to_river := absf(x - river_center(z))
		var biome_zone := _noise.get_noise_2d(x * 0.003 - 350.0, z * 0.003 + 450.0)

		var chosen_sp := "fir"
		if dist_to_stream < 42.0 or dist_to_river < 52.0:
			var r_pick := _rng.randf()
			if r_pick < 0.55:
				chosen_sp = "birch"
			elif r_pick < 0.80:
				chosen_sp = "fir"
			else:
				chosen_sp = "oak"
		elif h > 42.0 or slope > 0.38:
			var r_pick := _rng.randf()
			if r_pick < 0.65:
				chosen_sp = "pine"
			elif r_pick < 0.88:
				chosen_sp = "fir"
			else:
				chosen_sp = "birch"
		elif biome_zone < -0.15:
			var r_pick := _rng.randf()
			if r_pick < 0.68:
				chosen_sp = "oak"
			elif r_pick < 0.86:
				chosen_sp = "birch"
			else:
				chosen_sp = "pine"
		elif biome_zone > 0.15:
			var r_pick := _rng.randf()
			if r_pick < 0.65:
				chosen_sp = "eucalyptus"
			elif r_pick < 0.85:
				chosen_sp = "pine"
			else:
				chosen_sp = "oak"
		else:
			var r_pick := _rng.randf()
			if r_pick < 0.25:
				chosen_sp = "oak"
			elif r_pick < 0.50:
				chosen_sp = "pine"
			elif r_pick < 0.70:
				chosen_sp = "eucalyptus"
			elif r_pick < 0.85:
				chosen_sp = "birch"
			else:
				chosen_sp = "fir"

		add_tree.call(chosen_sp, x, z, h)

		if i % 85 == 0 and h > 0.5 and rocks.size() < 300:
			var r_scale := Vector3(_rng.randf_range(0.9, 2.7), _rng.randf_range(0.6, 2.4), _rng.randf_range(0.9, 2.7))
			var r_rot := Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU))
			rocks.append(Transform3D(r_rot.scaled(r_scale), Vector3(x, h - 0.12, z)))

	# Batch the 15 botanical tree species variants in 6x6 spatial cells for frustum and distance culling
	for sp in species_types:
		for v in range(3):
			if species_transforms[sp][v].size() > 0:
				_batch_spatial(species_meshes[sp][v], species_transforms[sp][v], "Tree_%s_v%d" % [sp, v], 6, 1000.0, 580.0, 70.0)

	# 1. Modular Wooden Pier on Alpine Lake (Agua)
	var pier_mesh := _asset_mesh("res://assets/environment/water/modular_pier.glb") as ArrayMesh
	if pier_mesh:
		var pier_inst := MeshInstance3D.new()
		pier_inst.name = "LakeWoodenPier"
		pier_inst.mesh = pier_mesh
		pier_inst.position = Vector3(LAKE_CENTER.x + 35.0, WATER_LEVEL + 0.35, LAKE_CENTER.y - 12.0)
		pier_inst.rotation.y = 0.45
		add_child(pier_inst)
		pier_inst.create_trimesh_collision()

	# 2. Mountain Massif Cliffs & Peaks (Montañas)
	var cliff_mesh := _asset_mesh("res://assets/environment/rock/coastal_cliff.glb") as ArrayMesh
	if cliff_mesh:
		var cliff_xforms: Array[Transform3D] = []
		for m_pos in [Vector3(-720, 145, -640), Vector3(680, 160, -580), Vector3(-650, 150, 710), Vector3(740, 175, 680)]:
			var c_basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * 5.5)
			cliff_xforms.append(Transform3D(c_basis, m_pos))
		_batch(cliff_mesh, cliff_xforms, "MountainMassifCliffs")

	# 3. Riverbank Root Clusters (Agua y árboles)
	var root_mesh := _asset_mesh("res://assets/environment/trees/root_cluster.glb") as ArrayMesh
	if root_mesh:
		var root_xforms: Array[Transform3D] = []
		for i in 45:
			var rz := _rng.randf_range(-650.0, 650.0)
			var rx := river_center(rz) + (river_width(rz) + 3.5) * (1.0 if i % 2 == 0 else -1.0)
			var rh := ground_height(rx, rz)
			var r_basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(1.2, 2.2))
			root_xforms.append(Transform3D(r_basis, Vector3(rx, rh - 0.15, rz)))
		_batch(root_mesh, root_xforms, "RiverbankRootClusters")

	# Meadow tufts along river terraces and valley meadows
	for i in 1200:
		var z := _rng.randf_range(-700.0, 700.0)
		var side := -1.0 if i % 2 else 1.0
		var x := river_center(z) + side * (river_width(z) + _rng.randf_range(16.0, 85.0))
		var h := ground_height(x, z)
		if h > 1.0 and (grasses_0.size() + grasses_1.size()) < 18000:
			var t_r := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.75, 1.45)), Vector3(x, h, z))
			if grasses_0.size() <= grasses_1.size():
				grasses_0.append(t_r)
			else:
				grasses_1.append(t_r)

	# River stones, boulders and cobblestones along the main river channel and shores (matching video)
	for i in 480:
		var z := _rng.randf_range(-960.0, 960.0)
		var width_ratio := _rng.randf_range(-1.05, 1.05)
		var x := river_center(z) + width_ratio * river_width(z)
		var h := ground_height(x, z)
		if h >= -2.8 and h <= 2.5:
			var s_xz := _rng.randf_range(0.8, 3.4)
			var s_y := _rng.randf_range(0.4, 2.2)
			var b := Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)).scaled(Vector3(s_xz, s_y, s_xz))
			rocks.append(Transform3D(b, Vector3(x, h - _rng.randf_range(0.02, 0.25), z)))

	# Lake shore boulders in crystal clear water and grassy banks (Foto 4)
	for i in 90:
		var a := _rng.randf() * TAU
		var r := LAKE_RADIUS + _rng.randf_range(-8.0, 20.0)
		var rx := LAKE_CENTER.x + cos(a) * r
		var rz := LAKE_CENTER.y + sin(a) * r
		var rh := ground_height(rx, rz)
		var rs_xz := _rng.randf_range(1.1, 3.8)
		var rs_y := _rng.randf_range(0.5, 2.2)
		var rb := Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)).scaled(Vector3(rs_xz, rs_y, rs_xz))
		rocks.append(Transform3D(rb, Vector3(rx, rh - _rng.randf_range(0.06, 0.32), rz)))

	# Stream rocks and boulders along both riachuelos (Fotos 2 & 3 y Video)
	for i in 180:
		var z_w := _rng.randf_range(-235.0, 325.0)
		var x_w := stream_west_center(z_w) + _rng.randf_range(-12.0, 12.0)
		var h_w := ground_height(x_w, z_w)
		var b_w := Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)).scaled(Vector3(_rng.randf_range(0.85, 2.9), _rng.randf_range(0.45, 2.0), _rng.randf_range(0.85, 2.9)))
		rocks.append(Transform3D(b_w, Vector3(x_w, h_w - 0.12, z_w)))
	for i in 140:
		var z_e := _rng.randf_range(-345.0, 185.0)
		var x_e := stream_east_center(z_e) + _rng.randf_range(-11.0, 11.0)
		var h_e := ground_height(x_e, z_e)
		var b_e := Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)).scaled(Vector3(_rng.randf_range(0.85, 2.8), _rng.randf_range(0.45, 1.9), _rng.randf_range(0.85, 2.8)))
		rocks.append(Transform3D(b_e, Vector3(x_e, h_e - 0.12, z_e)))

	# Photogrammetric Scanned Boulders (boulder_01 & namaqualand) on fortress slopes and riverbed
	# 1. Fortress Slopes & Perimeter Rocky Outcrops
	for i in 60:
		var angle := _rng.randf() * TAU
		var dist := _rng.randf_range(68.0, 130.0)
		var bx := ARENA_CENTER.x + cos(angle) * dist
		var bz := ARENA_CENTER.z + sin(angle) * dist
		if bz > 140.0 and bz < 380.0 and absf(bx - 300.0) < 18.0:
			continue
		var bh := ground_height(bx, bz)
		if bh < 3.0:
			continue
		var s_xz := _rng.randf_range(1.1, 2.8)
		var s_y := _rng.randf_range(0.8, 2.2)
		var yaw := Basis(Vector3.UP, _rng.randf() * TAU)
		var tilt := Basis(Vector3.RIGHT, _rng.randf_range(-0.15, 0.15)) * Basis(Vector3.FORWARD, _rng.randf_range(-0.15, 0.15))
		var b_rot := (yaw * tilt).scaled(Vector3(s_xz, s_y, s_xz))
		var xf := Transform3D(b_rot, Vector3(bx, bh - _rng.randf_range(0.04, 0.16), bz))
		boulder_transforms.append(xf)
		if i % 2 == 0:
			scanned_boulders_01.append(xf)
		else:
			namaqualand_boulders.append(xf)

	# 2. Cauce del Río & Riparian Stream Beds
	for i in 180:
		var rz := _rng.randf_range(-950.0, 950.0)
		var rx := river_center(rz) + _rng.randf_range(-0.95, 0.95) * river_width(rz)
		var rh := ground_height(rx, rz)
		if rh >= -2.8 and rh <= 2.2:
			var s_xz := _rng.randf_range(1.0, 2.8)
			var s_y := _rng.randf_range(0.7, 2.0)
			var yaw := Basis(Vector3.UP, _rng.randf() * TAU)
			var tilt := Basis(Vector3.RIGHT, _rng.randf_range(-0.12, 0.12)) * Basis(Vector3.FORWARD, _rng.randf_range(-0.12, 0.12))
			var b_rot := (yaw * tilt).scaled(Vector3(s_xz, s_y, s_xz))
			var xf := Transform3D(b_rot, Vector3(rx, rh - _rng.randf_range(0.04, 0.15), rz))
			river_boulder_transforms.append(xf)
			if i % 3 == 0:
				namaqualand_boulders.append(xf)
			else:
				scanned_boulders_01.append(xf)

	for i in 45:
		var zw := _rng.randf_range(-230.0, 320.0)
		var xw := stream_west_center(zw) + _rng.randf_range(-10.0, 10.0)
		var hw := ground_height(xw, zw)
		var bw := Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)).scaled(Vector3.ONE * _rng.randf_range(0.9, 2.4))
		scanned_boulders_01.append(Transform3D(bw, Vector3(xw, hw - 0.10, zw)))

	for i in 40:
		var ze := _rng.randf_range(-340.0, 180.0)
		var xe := stream_east_center(ze) + _rng.randf_range(-9.0, 9.0)
		var he := ground_height(xe, ze)
		var be := Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)).scaled(Vector3.ONE * _rng.randf_range(0.9, 2.4))
		namaqualand_boulders.append(Transform3D(be, Vector3(xe, he - 0.10, ze)))

	# 4. Piedras de Rio y Bancos de Grava (river_pebbles_cluster)
	for i in 220:
		var rz := _rng.randf_range(-960.0, 960.0)
		var rx := river_center(rz) + _rng.randf_range(-1.25, 1.25) * river_width(rz)
		var rh := ground_height(rx, rz)
		if rh >= -2.6 and rh <= 2.8:
			var p_scale := Vector3(_rng.randf_range(0.85, 2.3), _rng.randf_range(0.55, 1.35), _rng.randf_range(0.85, 2.3))
			var p_rot := Basis(Vector3.UP, _rng.randf() * TAU).scaled(p_scale)
			river_pebble_clusters.append(Transform3D(p_rot, Vector3(rx, rh - 0.08, rz)))

	for i in 75:
		var a := _rng.randf() * TAU
		var r := LAKE_RADIUS + _rng.randf_range(-14.0, 18.0)
		var lx := LAKE_CENTER.x + cos(a) * r
		var lz := LAKE_CENTER.y + sin(a) * r
		var lh := ground_height(lx, lz)
		if lh >= -2.0 and lh <= 3.0:
			var p_scale := Vector3(_rng.randf_range(0.9, 2.5), _rng.randf_range(0.6, 1.4), _rng.randf_range(0.9, 2.5))
			var p_rot := Basis(Vector3.UP, _rng.randf() * TAU).scaled(p_scale)
			river_pebble_clusters.append(Transform3D(p_rot, Vector3(lx, lh - 0.07, lz)))

	for i in 60:
		var zw := _rng.randf_range(-230.0, 320.0)
		var xw := stream_west_center(zw) + _rng.randf_range(-12.0, 12.0)
		var hw := ground_height(xw, zw)
		if hw >= -1.5 and hw <= 3.2:
			var p_rot := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.8, 1.9))
			river_pebble_clusters.append(Transform3D(p_rot, Vector3(xw, hw - 0.08, zw)))

	for i in 50:
		var ze := _rng.randf_range(-340.0, 180.0)
		var xe := stream_east_center(ze) + _rng.randf_range(-11.0, 11.0)
		var he := ground_height(xe, ze)
		if he >= -1.5 and he <= 3.2:
			var p_rot := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.8, 1.9))
			river_pebble_clusters.append(Transform3D(p_rot, Vector3(xe, he - 0.08, ze)))

	# 3. Tronco de Bosque Caído (dead_tree_trunk_02) en claros del bosque y zonas abiertas de planeo bajo
	var add_log := func(lx: float, lz: float):
		var yaw := _rng.randf() * TAU
		var dir := Vector3(cos(yaw), 0.0, sin(yaw))
		var p1 := Vector3(lx - dir.x * 2.0, ground_height(lx - dir.x * 2.0, lz - dir.z * 2.0), lz - dir.z * 2.0)
		var p2 := Vector3(lx + dir.x * 2.0, ground_height(lx + dir.x * 2.0, lz + dir.z * 2.0), lz + dir.z * 2.0)
		var tangent := (p2 - p1).normalized()
		var side := tangent.cross(Vector3.UP).normalized()
		var up := side.cross(tangent).normalized()
		var scale_val := _rng.randf_range(0.92, 1.38)
		var b := Basis(tangent, up, side).scaled(Vector3.ONE * scale_val)
		var xf := Transform3D(b, Vector3(lx, (p1.y + p2.y) * 0.5 + 0.12 * scale_val, lz))
		fallen_logs.append(xf)
		log_transforms.append(xf)

	for i in 28:
		var lx := _rng.randf_range(115.0, 235.0)
		var lz := _rng.randf_range(48.0, 195.0)
		if ground_height(lx, lz) > WATER_LEVEL + 0.5:
			add_log.call(lx, lz)

	for i in 22:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(LAKE_RADIUS + 8.0, LAKE_CLEARING_RADIUS + 30.0)
		var lx := LAKE_CENTER.x + cos(a) * r
		var lz := LAKE_CENTER.y + sin(a) * r
		if ground_height(lx, lz) > WATER_LEVEL + 0.4:
			add_log.call(lx, lz)

	for i in 40:
		var lx := _rng.randf_range(-850.0, 850.0)
		var lz := _rng.randf_range(-850.0, 850.0)
		var h := ground_height(lx, lz)
		if h > 1.5 and h < 9.0 and not is_water_at(Vector3(lx, 0, lz)):
			var glade_val := _noise.get_noise_2d(lx * 0.005 + 520.0, lz * 0.005 - 280.0)
			if glade_val > 0.38:
				add_log.call(lx, lz)

	# Batch mature firs with 4 LOD levels in 4x4 spatial cells
	for lod in 4:
		for cz in 4:
			for cx in 4:
				var node := _batch(_tree_lods[lod], [], "Forest_LOD%s_%s_%s" % [lod, cx, cz])
				if lod >= 2:
					node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_forest_nodes.append(node)
	_update_forest_lods()
	var boulders := _batch(boulder_mesh, rocks, "ScatteredBoulders")
	boulders.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	boulders.visibility_range_end = 550.0
	boulders.visibility_range_end_margin = 60.0

	# Instanced GPU Scenery MultiMeshes (1 draw call each)
	var mesh_scanned_boulder_01 := _load_glb_mesh("res://assets/environment/rock/boulder_scanned_01.glb")
	if mesh_scanned_boulder_01 and scanned_boulders_01.size() > 0:
		var node_sb := _batch(mesh_scanned_boulder_01, scanned_boulders_01, "ScannedGraniteBoulders_01")
		node_sb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node_sb.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

	var mesh_boulder_namaqualand := _load_glb_mesh("res://assets/environment/rock/boulder_namaqualand.glb")
	if mesh_boulder_namaqualand and namaqualand_boulders.size() > 0:
		var node_nb := _batch(mesh_boulder_namaqualand, namaqualand_boulders, "NamaqualandMonolithBoulders")
		node_nb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node_nb.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

	var mesh_dead_trunk := _load_glb_mesh("res://assets/environment/trees/dead_tree_trunk_02.glb")
	if mesh_dead_trunk and fallen_logs.size() > 0:
		var node_dt := _batch(mesh_dead_trunk, fallen_logs, "FallenOldGrowthTrunks")
		node_dt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node_dt.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

	var mesh_pebbles := _load_glb_mesh("res://assets/environment/pebbles/river_pebbles_cluster.glb")
	if mesh_pebbles and river_pebble_clusters.size() > 0:
		var node_pebbles := _batch(mesh_pebbles, river_pebble_clusters, "RiverPebbleClusters")
		node_pebbles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node_pebbles.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Dense 3D grass blade covering on the hill behind the nest ("cubierta de brisnas de pasto que se muevan tengan forma y textura y parezcan reales")
	for i in 6500:
		var x := _rng.randf_range(370.0, 520.0)
		var z := _rng.randf_range(50.0, 190.0)
		var h := ground_height(x, z)
		if h >= 22.0:
			var s := _rng.randf_range(1.15, 2.25)
			var yaw := _rng.randf() * TAU
			var tilt_angle := _rng.randf_range(0.02, 0.08)
			var tilt_dir := _rng.randf() * TAU
			var tilt_rot := Basis(Vector3(cos(tilt_dir), 0.0, sin(tilt_dir)).normalized(), tilt_angle)
			var b := (Basis(Vector3.UP, yaw) * tilt_rot).scaled(Vector3.ONE * s)
			if i % 2 == 0:
				grasses_hill.append(Transform3D(b, Vector3(x, h - 0.03, z)))

	# Dense 3D grass blade covering in the valley in front of the nest
	for i in 5500:
		var x := _rng.randf_range(105.0, 245.0)
		var z := _rng.randf_range(40.0, 205.0)
		var h := ground_height(x, z)
		if h > WATER_LEVEL + 0.3:
			var s := _rng.randf_range(1.0, 2.1)
			var yaw := _rng.randf() * TAU
			var b := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s)
			if i % 2 == 0:
				grasses_valley.append(Transform3D(b, Vector3(x, h - 0.03, z)))

	_batch_spatial(grass_mesh_0, grasses_0, "PhotographicMeadowTufts", 6, 1000.0, 160.0, 30.0, grass_material)
	_batch_spatial(grass_mesh_1, grasses_1, "PhotographicMeadowTufts_Wild", 6, 1000.0, 160.0, 30.0, grass_material)

	var hill_mesh: Mesh = g_mesh_tall if g_mesh_tall else grass_mesh_1
	var grass_hill := _batch(hill_mesh, grasses_hill, "HillBehindNest_GrassBlades", grass_material)
	grass_hill.visibility_range_end = 180.0
	grass_hill.visibility_range_end_margin = 30.0
	grass_hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var valley_mesh: Mesh = g_mesh_tall if g_mesh_tall else grass_mesh_0
	var grass_valley := _batch(valley_mesh, grasses_valley, "ValleyNest_GrassBlades", grass_material)
	grass_valley.visibility_range_end = 180.0
	grass_valley.visibility_range_end_margin = 30.0
	grass_valley.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Scanned eroded formations visibly anchor the river and mountain feet.
	var scan := rock_mesh
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

	# Eliminada la pared atrás del nido ("elimina o achica esa pared que ahí atras del nido, debe ser una colina")
	# El terreno ahora es una suave colina ondulada y este nodo se conserva encogido al mínimo sin colisión para compatibilidad
	var cliff := MeshInstance3D.new()
	cliff.name = "GithubNamaqualandCliffScan"
	cliff.mesh = _asset_mesh("res://assets/environment/github_cliff.glb")
	cliff.position = Vector3(462, ground_height(462, 145) - 1.4, 145)
	cliff.rotation.y = -PI * 0.5
	cliff.scale = Vector3.ONE * 0.001
	cliff.visible = false
	add_child(cliff)
	print("LANDSCAPE mature fir, grass, limestone; ", _tree_transforms.size(), " trees. Courtyard ", ARENA_CENTER)

func _process(delta: float) -> void:
	_lod_timer += delta
	if _lod_timer > 0.2:
		_lod_timer = 0.0
		_update_forest_lods()

func _update_forest_lods() -> void:
	if _forest_nodes.is_empty() or _mature_fir_transforms.is_empty():
		return
	var camera := get_viewport().get_camera_3d()
	var viewer := to_local(camera.global_position) if camera else Vector3(300, 100, 350)
	var buckets: Array = []
	for i in 64:
		buckets.append([])
	var frustum: Array = camera.get_frustum() if camera else []
	for transform in _mature_fir_transforms:
		var size := transform.basis.get_scale().y
		var crown_center := transform.origin + Vector3.UP * 9.4 * size
		var distance := viewer.distance_to(crown_center)
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
		# Calibrated to exact solar center of Kloofendal Pure Sky HDR (Elevation 47.8°, Azimuth 34.1°)
		sun.rotation_degrees = Vector3(-47.8, -34.1, 0.0)
		sun.light_color = Color(1.0, 0.97, 0.92)
		sun.light_energy = 1.36
		sun.light_angular_distance = 0.72
		sun.shadow_enabled = true
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_blend_splits = false
		sun.directional_shadow_max_distance = 250.0
		sun.directional_shadow_fade_start = 0.85
	if world and world.environment:
		var env := world.environment
		var hdri_path := "res://materials/kloofendal_sky_2k.hdr"
		var fallback_hdri := "res://materials/citrus_sky_2k.hdr"
		var sky := Sky.new()
		if ResourceLoader.exists(hdri_path):
			var panorama_mat := PanoramaSkyMaterial.new()
			panorama_mat.panorama = load(hdri_path) as Texture2D
			panorama_mat.filter = true
			sky.sky_material = panorama_mat
			sky.radiance_size = Sky.RADIANCE_SIZE_512
			sky.process_mode = Sky.PROCESS_MODE_QUALITY
		elif ResourceLoader.exists(fallback_hdri):
			var panorama_mat := PanoramaSkyMaterial.new()
			panorama_mat.panorama = load(fallback_hdri) as Texture2D
			panorama_mat.filter = true
			sky.sky_material = panorama_mat
			sky.radiance_size = Sky.RADIANCE_SIZE_512
			sky.process_mode = Sky.PROCESS_MODE_QUALITY
		else:
			var sky_material := ShaderMaterial.new()
			sky_material.shader = load("res://shaders/landscape_sky.gdshader")
			if sun:
				sky_material.set_shader_parameter("sun_direction", sun.global_basis.z)
			sky.sky_material = sky_material
			sky.radiance_size = Sky.RADIANCE_SIZE_256
			sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.76
		env.ambient_light_sky_contribution = 0.85
		env.fog_enabled = true
		env.fog_density = 0.00020
		env.fog_sky_affect = 0.16
		env.fog_light_color = Color(0.72, 0.82, 0.94)
		env.fog_sun_scatter = 0.35
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.adjustment_enabled = true
		env.adjustment_contrast = 1.06
		env.adjustment_saturation = 1.04
		# Disabled heavy GPU passes for maximum 60 FPS stability
		env.ssao_enabled = false
		env.ssil_enabled = false
		env.sdfgi_enabled = false
		env.volumetric_fog_enabled = false

