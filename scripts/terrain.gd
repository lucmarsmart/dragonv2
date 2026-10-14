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
var _mature_fir_transforms: Array[Transform3D] = []
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
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size)
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

func _build_forest() -> void:
	_tree_lods = [
		_asset_mesh("res://assets/environment/fir/fir_lod0.glb"),
		_asset_mesh("res://assets/environment/fir/fir_lod1.glb"),
		_asset_mesh("res://assets/environment/fir/fir_lod2.glb"),
		_asset_mesh("res://assets/environment/fir/fir_lod3.glb")
	]
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
	var grass_mesh_0 := GrassGen.generate_tuft_mesh(0)
	var grass_mesh_1 := GrassGen.generate_tuft_mesh(1)
	var grass_material := ShaderMaterial.new()
	grass_material.shader = load("res://shaders/grass.gdshader")
	grass_material.set_shader_parameter("texture_albedo", load("res://assets/environment/grass/textures/grass_medium_01_diff_2k.jpg"))
	grass_material.set_shader_parameter("texture_normal", load("res://assets/environment/grass/textures/grass_medium_01_nor_gl_2k.jpg"))
	grass_material.set_shader_parameter("texture_arm", load("res://assets/environment/grass/textures/grass_medium_01_arm_2k.jpg"))
	grass_material.set_shader_parameter("use_photographic_texture", true)
	grass_material.set_shader_parameter("alpha_scissor_threshold", 0.35)
	grass_material.set_shader_parameter("wind_speed", 2.4)
	grass_material.set_shader_parameter("wind_strength", 0.36)
	grass_material.set_shader_parameter("backlight_tint", Color(0.42, 0.58, 0.15))

	var grass_gltf := (load("res://assets/environment/grass/grass_medium_01.gltf") as PackedScene).instantiate()
	var g_mesh_small: Mesh = null
	var g_mesh_mid: Mesh = null
	var g_mesh_tall: Mesh = null
	var mi_s := grass_gltf.find_child("grass_medium_01_small_a_LOD0", true, false) as MeshInstance3D
	if mi_s: g_mesh_small = mi_s.mesh
	var mi_m := grass_gltf.find_child("grass_medium_01_mid_a_LOD0", true, false) as MeshInstance3D
	if mi_m: g_mesh_mid = mi_m.mesh
	var mi_t := grass_gltf.find_child("grass_medium_01_tall_a_LOD0", true, false) as MeshInstance3D
	if mi_t: g_mesh_tall = mi_t.mesh
	grass_gltf.free()

	# AAA Botanical Species / Races of trees:
	# 1. Robles / Oaks: broadleaf ancient hardwoods with massive spreading crowns
	# 2. Abedules / Birches: slender pale-bark trees with dark eye scars
	# 3. Pinos / Pines: Scots/stone pines with armor-plated bark and umbrella canopy (3D Scanned GLB)
	# 4. Eucaliptos / Eucalyptus: tall upright trees with peeling bark ribbons
	# 5. Abetos / Firs: layered evergreen conifers with corrugated trunks (3D Scanned GLB)
	var species_types := ["oak", "eucalyptus", "birch", "pine", "fir"]
	var species_meshes: Dictionary = {}
	var species_transforms: Dictionary = {}
	for sp in species_types:
		species_transforms[sp] = [[], [], []]

	# Photogrammetric 3D Scans for Conifers:
	# Fir: 3 LODs of mature mountain fir
	species_meshes["fir"] = [_tree_lods[0], _tree_lods[1], _tree_lods[2]]

	# Pine: 3 LODs of Scots pine
	var pine_lods := [
		_asset_mesh("res://assets/environment/pine/pine_lod0.glb"),
		_asset_mesh("res://assets/environment/pine/pine_lod1.glb"),
		_asset_mesh("res://assets/environment/pine/pine_lod2.glb")
	]
	for p_lod in pine_lods:
		var p_mesh := p_lod as ArrayMesh
		for surface in p_mesh.get_surface_count():
			var mat := p_mesh.surface_get_material(surface) as StandardMaterial3D
			if mat:
				if mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					mat.alpha_scissor_threshold = 0.25
				mat.roughness = 0.92
				mat.metallic = 0.0
	species_meshes["pine"] = [pine_lods[0], pine_lods[1], pine_lods[2]]

	# Deciduous broadleaf species with smooth botanical meshes:
	for sp in ["oak", "birch", "eucalyptus"]:
		species_meshes[sp] = []
		for v in range(1, 4):
			var p := "res://assets/environment/trees/tree_%s_var%d.res" % [sp, v]
			species_meshes[sp].append(load(p))

	var rocks: Array[Transform3D] = []
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
	# Respects:
	# - Fortress and Nest clear zone (radius 36m around nest)
	# - Castle Gate approach road (15m width)
	# - Lake clearing & shore glade (Foto 4)
	# - Sinuous Rivers & stream channels
	# - Rolling hills ("pocas y mucho mas chicas", "no deben estar infestadas de arboles deben tener hierba y ser verdes"):
	#   Trees on hills are widely spaced (min_d >= 22m, 28% density)
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

	# Batch the 15 botanical tree species variants
	for sp in species_types:
		for v in range(3):
			if species_transforms[sp][v].size() > 0:
				var node := _batch(species_meshes[sp][v], species_transforms[sp][v], "Tree_%s_v%d" % [sp, v])
				# Optimize for Intel HD 620 GPU: shadows off on bulk instances to avoid TDR
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.visibility_range_end = 1600.0
				node.visibility_range_end_margin = 150.0

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

	# Batch mature firs with 4 LOD levels in 4x4 spatial cells
	for lod in 4:
		for cz in 4:
			for cx in 4:
				var node := _batch(_tree_lods[lod], [], "Forest_LOD%s_%s_%s" % [lod, cx, cz])
				if lod >= 2:
					node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_forest_nodes.append(node)
	_update_forest_lods()
	_batch(rock_mesh, rocks, "ScatteredBoulders")
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
			grasses_valley.append(Transform3D(b, Vector3(x, h - 0.03, z)))

	var grass_0 := _batch(grass_mesh_0, grasses_0, "PhotographicMeadowTufts", grass_material)
	grass_0.visibility_range_end = 240.0
	grass_0.visibility_range_end_margin = 40.0
	grass_0.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var grass_1 := _batch(grass_mesh_1, grasses_1, "PhotographicMeadowTufts_Wild", grass_material)
	grass_1.visibility_range_end = 240.0
	grass_1.visibility_range_end_margin = 40.0
	grass_1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var hill_mesh: Mesh = g_mesh_tall if g_mesh_tall else grass_mesh_1
	var grass_hill := _batch(hill_mesh, grasses_hill, "HillBehindNest_GrassBlades", grass_material)
	grass_hill.visibility_range_end = 280.0
	grass_hill.visibility_range_end_margin = 40.0
	grass_hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var valley_mesh: Mesh = g_mesh_mid if g_mesh_mid else grass_mesh_0
	var grass_valley := _batch(valley_mesh, grasses_valley, "ValleyNest_GrassBlades", grass_material)
	grass_valley.visibility_range_end = 280.0
	grass_valley.visibility_range_end_margin = 40.0
	grass_valley.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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
	cliff.create_trimesh_collision()
	for body in cliff.get_children():
		if body is StaticBody3D:
			body.collision_layer = 0
			body.collision_mask = 0
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
		sun.light_color = Color(1.0, 0.96, 0.88)
		sun.light_energy = 1.32
		sun.light_angular_distance = 0.65
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 420.0
		sun.directional_shadow_fade_start = 0.85
	if world and world.environment:
		var env := world.environment
		var sky_material := ShaderMaterial.new()
		sky_material.shader = load("res://shaders/landscape_sky.gdshader")
		if sun:
			sky_material.set_shader_parameter("sun_direction", sun.global_basis.z)
		var sky := Sky.new()
		sky.sky_material = sky_material
		sky.radiance_size = Sky.RADIANCE_SIZE_1024
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.55
		env.fog_enabled = true
		env.fog_density = 0.00022
		env.fog_sky_affect = 0.18
		# Azul atmosferico de dispersion Rayleigh para cordilleras y colinas lejanas (Foto de referencia)
		env.fog_light_color = Color(0.70, 0.82, 0.94)
		env.fog_sun_scatter = 0.35
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.ssao_enabled = true
		env.ssao_radius = 1.8
		env.ssao_intensity = 1.35
		env.ssil_enabled = true
		env.ssil_radius = 3.2
		env.ssil_intensity = 0.40

