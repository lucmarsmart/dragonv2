@tool
extends SceneTree

# AAA Botanical Procedural Tree Generator:
# 5 Radically Distinct Tree Species with Unique 3D Silhouettes & Foliage Atlases:
# 1. Ancient Oak (Roble Centenario): Sprawling 16m umbrella/dome crown, massive gnarled boughs, deep furrowed ribs (Foto 3)
# 2. Eucalyptus (Eucalipto Blanco): Sinuous leaning trunk, 3D peeling bark ribbons, weeping cascading sickle leaves (Foto 1)
# 3. Silver Birch (Abedul Plateado): Slender chalk-white trunk, almond eye scars with broken stubs, fluttering lime leaves (Foto 2)
# 4. Stone Pine (Pino Piñonero / Parasol): Polygonal armor plates, bare lower trunk with stumps, flat horizontal parasol crown (Foto 4)
# 5. Mountain Fir (Abeto de Montaña): Towering straight fluted trunk, 14 layered pagoda tiers, sharp conical spire (Foto 5)

const OUT_DIR := "res://assets/environment/trees"

func _init() -> void:
	print("Starting AAA Multi-Species Botanical Tree Generation...")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	
	var foliage_shader = load("res://shaders/foliage.gdshader") as Shader
	
	var tex_oak = load("res://assets/environment/foliage/foliage_oak.png") as Texture2D
	var tex_birch = load("res://assets/environment/foliage/foliage_birch.png") as Texture2D
	var tex_eucalyptus = load("res://assets/environment/foliage/foliage_eucalyptus.png") as Texture2D
	var tex_pine = load("res://assets/environment/foliage/foliage_pine.png") as Texture2D
	var tex_fir = load("res://assets/environment/foliage/foliage_fir.png") as Texture2D
	
	# Species foliage materials
	var mat_oak_leaves = ShaderMaterial.new()
	mat_oak_leaves.shader = foliage_shader
	mat_oak_leaves.set_shader_parameter("needles", tex_oak)
	mat_oak_leaves.set_shader_parameter("alpha_cutoff", 0.35)
	mat_oak_leaves.set_shader_parameter("wind_strength", 0.16)
	
	var mat_birch_leaves = ShaderMaterial.new()
	mat_birch_leaves.shader = foliage_shader
	mat_birch_leaves.set_shader_parameter("needles", tex_birch)
	mat_birch_leaves.set_shader_parameter("alpha_cutoff", 0.30)
	mat_birch_leaves.set_shader_parameter("wind_strength", 0.22)
	
	var mat_eucalyptus_leaves = ShaderMaterial.new()
	mat_eucalyptus_leaves.shader = foliage_shader
	mat_eucalyptus_leaves.set_shader_parameter("needles", tex_eucalyptus)
	mat_eucalyptus_leaves.set_shader_parameter("alpha_cutoff", 0.30)
	mat_eucalyptus_leaves.set_shader_parameter("wind_strength", 0.18)
	
	var mat_pine_leaves = ShaderMaterial.new()
	mat_pine_leaves.shader = foliage_shader
	mat_pine_leaves.set_shader_parameter("needles", tex_pine)
	mat_pine_leaves.set_shader_parameter("alpha_cutoff", 0.32)
	mat_pine_leaves.set_shader_parameter("wind_strength", 0.12)
	
	var mat_fir_leaves = ShaderMaterial.new()
	mat_fir_leaves.shader = foliage_shader
	mat_fir_leaves.set_shader_parameter("needles", tex_fir)
	mat_fir_leaves.set_shader_parameter("alpha_cutoff", 0.32)
	mat_fir_leaves.set_shader_parameter("wind_strength", 0.14)
	
	var species_defs = [
		{
			"type": "oak",
			"bark_mat": load("res://assets/environment/bark/mat_bark_oak.tres"),
			"foliage_mat": mat_oak_leaves,
			"leaf_tint": Color(1.0, 1.0, 1.0),
			"count": 3
		},
		{
			"type": "eucalyptus",
			"bark_mat": load("res://assets/environment/bark/mat_bark_eucalyptus.tres"),
			"foliage_mat": mat_eucalyptus_leaves,
			"leaf_tint": Color(1.0, 1.0, 1.0),
			"count": 3
		},
		{
			"type": "birch",
			"bark_mat": load("res://assets/environment/bark/mat_bark_birch.tres"),
			"foliage_mat": mat_birch_leaves,
			"leaf_tint": Color(1.0, 1.0, 1.0),
			"count": 3
		},
		{
			"type": "pine",
			"bark_mat": load("res://assets/environment/bark/mat_bark_pine_plates.tres"),
			"foliage_mat": mat_pine_leaves,
			"leaf_tint": Color(1.0, 1.0, 1.0),
			"count": 3
		},
		{
			"type": "fir",
			"bark_mat": load("res://assets/environment/bark/mat_bark_corrugated.tres"),
			"foliage_mat": mat_fir_leaves,
			"leaf_tint": Color(1.0, 1.0, 1.0),
			"count": 3
		}
	]
	
	for s in species_defs:
		for var_idx in range(s["count"]):
			var mesh = _build_tree_mesh(s["type"], var_idx, s["bark_mat"], s["foliage_mat"], s["leaf_tint"])
			var filename = "%s/tree_%s_var%d.res" % [OUT_DIR, s["type"], var_idx + 1]
			var err = ResourceSaver.save(mesh, filename)
			print("Saved %s (err=%d)" % [filename, err])
			
	print("All 15 AAA botanical tree meshes generated successfully!")
	quit(0)

func _build_tree_mesh(species: String, seed_offset: int, bark_mat: Material, foliage_mat: Material, leaf_tint: Color) -> ArrayMesh:
	var rng = RandomNumberGenerator.new()
	rng.seed = 8000 + hash(species) * 73 + seed_offset * 2111
	
	var st_bark = SurfaceTool.new()
	st_bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var st_leaves = SurfaceTool.new()
	st_leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	match species:
		"oak":
			_generate_oak(st_bark, st_leaves, rng, leaf_tint)
		"eucalyptus":
			_generate_eucalyptus(st_bark, st_leaves, rng, leaf_tint)
		"birch":
			_generate_birch(st_bark, st_leaves, rng, leaf_tint)
		"pine":
			_generate_pine(st_bark, st_leaves, rng, leaf_tint)
		"fir":
			_generate_fir(st_bark, st_leaves, rng, leaf_tint)
			
	st_bark.generate_normals()
	st_bark.generate_tangents()
	st_bark.set_material(bark_mat)
	
	st_leaves.generate_normals()
	st_leaves.generate_tangents()
	st_leaves.set_material(foliage_mat)
	
	var final_mesh = ArrayMesh.new()
	st_bark.commit(final_mesh)
	st_leaves.commit(final_mesh)
	return final_mesh

# Extrusion using Parallel-Transport Frame (Bishop frame) with radial profile displacement
func _extrude_branch(st: SurfaceTool, points: Array[Vector3], radii: Array[float], radial_segments: int, uv_v_scale: float, profile_type: int = 0, cap_ends: bool = true) -> void:
	var count = points.size()
	if count < 2: return
	
	var tangents: Array[Vector3] = []
	for i in count:
		var t: Vector3
		if i == 0:
			t = (points[1] - points[0]).normalized()
		elif i == count - 1:
			t = (points[count - 1] - points[count - 2]).normalized()
		else:
			t = (points[i + 1] - points[i - 1]).normalized()
		if t.length_squared() < 0.001:
			t = Vector3.UP
		tangents.append(t)
		
	var normals: Array[Vector3] = []
	var binormals: Array[Vector3] = []
	
	var t0 = tangents[0]
	var initial_ref = Vector3.RIGHT if absf(t0.dot(Vector3.UP)) > 0.9 else Vector3.UP
	var n0 = t0.cross(initial_ref).normalized()
	var b0 = t0.cross(n0).normalized()
	normals.append(n0)
	binormals.append(b0)
	
	for i in range(1, count):
		var prev_t = tangents[i - 1]
		var cur_t = tangents[i]
		var prev_n = normals[i - 1]
		
		var rot_axis = prev_t.cross(cur_t)
		var cur_n: Vector3
		if rot_axis.length_squared() > 1e-6:
			rot_axis = rot_axis.normalized()
			var dot = clampf(prev_t.dot(cur_t), -1.0, 1.0)
			var angle = acos(dot)
			var basis = Basis(rot_axis, angle)
			cur_n = (basis * prev_n).normalized()
		else:
			cur_n = prev_n
			
		var cur_b = cur_t.cross(cur_n).normalized()
		normals.append(cur_n)
		binormals.append(cur_b)
		
	var rings: Array = []
	var uv_v = 0.0
	
	for i in count:
		var p = points[i]
		var r = radii[i]
		var n = normals[i]
		var b = binormals[i]
		
		if i > 0:
			uv_v += points[i].distance_to(points[i - 1]) * uv_v_scale
			
		var ring_verts: Array[Vector3] = []
		var ring_uvs: Array[Vector2] = []
		
		for s in radial_segments + 1:
			var angle = (float(s) / float(radial_segments)) * TAU
			var cur_r = r
			
			if profile_type == 1:
				# OAK (Foto 3): 8 undulating deep longitudinal ridges
				var f1 = sin(angle * 8.0) * 0.16
				var f2 = sin(angle * 16.0 + float(i) * 0.3) * 0.05
				cur_r *= (1.0 + f1 + f2)
			elif profile_type == 2:
				# PINE (Foto 4): Polygonal armor plates
				var plate = sin(angle * 7.0) * 0.14 + cos(angle * 5.0 + float(i) * 0.5) * 0.07
				cur_r *= (1.0 + plate)
			elif profile_type == 3:
				# FIR (Foto 5): Vertical fluting
				var fluting = sin(angle * 18.0) * 0.08
				cur_r *= (1.0 + fluting)
				
			var offset = (n * cos(angle) + b * sin(angle)) * cur_r
			ring_verts.append(p + offset)
			ring_uvs.append(Vector2(float(s) / float(radial_segments), uv_v))
			
		rings.append({"verts": ring_verts, "uvs": ring_uvs})
		
	for i in count - 1:
		var r0 = rings[i]
		var r1 = rings[i + 1]
		for s in radial_segments:
			var v00: Vector3 = r0["verts"][s]
			var v01: Vector3 = r0["verts"][s + 1]
			var v10: Vector3 = r1["verts"][s]
			var v11: Vector3 = r1["verts"][s + 1]
			
			var uv00: Vector2 = r0["uvs"][s]
			var uv01: Vector2 = r0["uvs"][s + 1]
			var uv10: Vector2 = r1["uvs"][s]
			var uv11: Vector2 = r1["uvs"][s + 1]
			
			st.set_uv(uv00); st.add_vertex(v00)
			st.set_uv(uv10); st.add_vertex(v10)
			st.set_uv(uv01); st.add_vertex(v01)
			
			st.set_uv(uv01); st.add_vertex(v01)
			st.set_uv(uv10); st.add_vertex(v10)
			st.set_uv(uv11); st.add_vertex(v11)
			
	if cap_ends:
		var b_center = points[0]
		var b_verts = rings[0]["verts"]
		for s in radial_segments:
			st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(b_center)
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(b_verts[s + 1])
			st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(b_verts[s])
			
		var t_center = points[count - 1]
		var t_verts = rings[count - 1]["verts"]
		for s in radial_segments:
			st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(t_center)
			st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(t_verts[s])
			st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(t_verts[s + 1])

# Generate realistic surface buttress roots spreading into the ground
func _generate_roots(st_bark: SurfaceTool, base_pos: Vector3, base_r: float, num_roots: int, rng: RandomNumberGenerator, profile: int = 0) -> void:
	for r_idx in num_roots:
		var angle = (float(r_idx) / float(num_roots)) * TAU + rng.randf_range(-0.25, 0.25)
		var root_dir = Vector3(cos(angle), 0, sin(angle)).normalized()
		var root_len = rng.randf_range(1.8, 3.2) * base_r
		
		var start_p = base_pos + Vector3(0, rng.randf_range(0.5, 1.1), 0) + root_dir * (base_r * 0.75)
		var mid_p = base_pos + Vector3(0, 0.05, 0) + root_dir * (base_r + root_len * 0.5)
		var end_p = base_pos + Vector3(0, -0.30, 0) + root_dir * (base_r + root_len)
		
		var pts: Array[Vector3] = [start_p, mid_p, end_p]
		var rads: Array[float] = [base_r * 0.32, base_r * 0.18, 0.04]
		_extrude_branch(st_bark, pts, rads, 8, 0.45, profile, true)

# Triple cross-quad foliage card for maximum 3D volume from all angles
func _add_leaf_card(st: SurfaceTool, center: Vector3, size: float, normal_dir: Vector3, tint: Color, pitch_tilt: float = 0.0) -> void:
	var fwd = normal_dir.normalized()
	var right = fwd.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	var up = right.cross(fwd).normalized()
	
	if absf(pitch_tilt) > 0.001:
		up = (up * cos(pitch_tilt) + fwd * sin(pitch_tilt)).normalized()
		fwd = right.cross(up).normalized()
		
	var hs = size * 0.5
	
	# Quad 1: Front
	var v0 = center - right * hs - up * hs
	var v1 = center + right * hs - up * hs
	var v2 = center + right * hs + up * hs
	var v3 = center - right * hs + up * hs
	
	st.set_color(tint)
	st.set_uv(Vector2(0, 1)); st.add_vertex(v0)
	st.set_uv(Vector2(1, 1)); st.add_vertex(v1)
	st.set_uv(Vector2(1, 0)); st.add_vertex(v2)
	st.set_uv(Vector2(0, 1)); st.add_vertex(v0)
	st.set_uv(Vector2(1, 0)); st.add_vertex(v2)
	st.set_uv(Vector2(0, 0)); st.add_vertex(v3)
	
	# Quad 2: Rotated 60 deg
	var cos60 = 0.5
	var sin60 = 0.866
	var r2 = right * cos60 + fwd * sin60
	var f2 = -right * sin60 + fwd * cos60
	var q2_0 = center - r2 * hs - up * hs
	var q2_1 = center + r2 * hs - up * hs
	var q2_2 = center + r2 * hs + up * hs
	var q2_3 = center - r2 * hs + up * hs
	
	st.set_color(tint)
	st.set_uv(Vector2(0, 1)); st.add_vertex(q2_0)
	st.set_uv(Vector2(1, 1)); st.add_vertex(q2_1)
	st.set_uv(Vector2(1, 0)); st.add_vertex(q2_2)
	st.set_uv(Vector2(0, 1)); st.add_vertex(q2_0)
	st.set_uv(Vector2(1, 0)); st.add_vertex(q2_2)
	st.set_uv(Vector2(0, 0)); st.add_vertex(q2_3)
	
	# Quad 3: Rotated 120 deg
	var cos120 = -0.5
	var sin120 = 0.866
	var r3 = right * cos120 + fwd * sin120
	var f3 = -right * sin120 + fwd * cos120
	var q3_0 = center - r3 * hs - up * hs
	var q3_1 = center + r3 * hs - up * hs
	var q3_2 = center + r3 * hs + up * hs
	var q3_3 = center - r3 * hs + up * hs
	
	st.set_color(tint)
	st.set_uv(Vector2(0, 1)); st.add_vertex(q3_0)
	st.set_uv(Vector2(1, 1)); st.add_vertex(q3_1)
	st.set_uv(Vector2(1, 0)); st.add_vertex(q3_2)
	st.set_uv(Vector2(0, 1)); st.add_vertex(q3_0)
	st.set_uv(Vector2(1, 0)); st.add_vertex(q3_2)
	st.set_uv(Vector2(0, 0)); st.add_vertex(q3_3)

# ==============================================================================
# 1. ANCIENT OAK (Roble Centenario - Foto 3)
# Massive mushroom/dome crown (15m diameter), thick gnarled limbs, flared roots
# ==============================================================================
func _generate_oak(st_bark: SurfaceTool, st_leaves: SurfaceTool, rng: RandomNumberGenerator, tint: Color) -> void:
	var base_h = rng.randf_range(3.8, 4.8)
	var base_r = rng.randf_range(1.35, 1.65)
	var fork_r = base_r * 0.75
	
	# Trunk extrusion up to fork
	var trunk_pts: Array[Vector3] = []
	var trunk_rad: Array[float] = []
	var t_segs = 8
	for i in t_segs:
		var t = float(i) / float(t_segs - 1)
		var p = Vector3(sin(t * 1.5) * 0.25, t * base_h, cos(t * 1.2) * 0.2)
		var r = lerpf(base_r, fork_r, t) + pow(1.0 - t, 2.5) * base_r * 0.45
		trunk_pts.append(p)
		trunk_rad.append(r)
	_extrude_branch(st_bark, trunk_pts, trunk_rad, 16, 0.28, 1, true)
	
	# Massive buttress roots
	_generate_roots(st_bark, Vector3(0, 0, 0), base_r, rng.randi_range(5, 7), rng, 1)
	
	var fork_pt = trunk_pts[t_segs - 1]
	
	# 3 to 4 massive sprawling limbs spreading wide horizontally
	var num_limbs = rng.randi_range(3, 4)
	for limb_i in num_limbs:
		var angle = (float(limb_i) / float(num_limbs)) * TAU + rng.randf_range(-0.25, 0.25)
		var out_dir = Vector3(cos(angle), rng.randf_range(0.35, 0.65), sin(angle)).normalized()
		var limb_len = rng.randf_range(7.5, 10.5)
		
		var l_pts: Array[Vector3] = []
		var l_rad: Array[float] = []
		var l_segs = 8
		for j in l_segs:
			var lt = float(j) / float(l_segs - 1)
			# Gnarled bend
			var bend_y = sin(lt * PI) * 0.8
			var p = fork_pt + out_dir * (lt * limb_len) + Vector3(0, bend_y, 0)
			l_pts.append(p)
			l_rad.append(lerpf(fork_r * 0.65, 0.25, lt))
		_extrude_branch(st_bark, l_pts, l_rad, 12, 0.32, 1, true)
		
		# Secondary gnarled sub-branches
		var limb_tip = l_pts[l_segs - 1]
		var sub_count = rng.randi_range(3, 5)
		for sub_k in sub_count:
			var sub_ang = angle + rng.randf_range(-0.9, 0.9)
			var sub_dir = Vector3(cos(sub_ang), rng.randf_range(0.2, 0.7), sin(sub_ang)).normalized()
			var sub_len = rng.randf_range(3.5, 5.5)
			var sub_end = limb_tip + sub_dir * sub_len
			_extrude_branch(st_bark, [limb_tip, sub_end], [0.22, 0.08], 6, 0.45, 0, true)
			
			# Lush volumetric oak leaf clouds
			for leaf_p in rng.randi_range(8, 12):
				var offset = Vector3(
					rng.randf_range(-2.8, 2.8),
					rng.randf_range(-1.2, 2.2),
					rng.randf_range(-2.8, 2.8)
				)
				var l_pos = sub_end + offset
				_add_leaf_card(st_leaves, l_pos, rng.randf_range(4.2, 5.8), sub_dir, tint, rng.randf_range(-0.3, 0.3))
				
	# Central dome apex foliage filling the upper canopy
	for c in rng.randi_range(16, 24):
		var apex_pos = fork_pt + Vector3(
			rng.randf_range(-3.5, 3.5),
			rng.randf_range(4.0, 8.5),
			rng.randf_range(-3.5, 3.5)
		)
		_add_leaf_card(st_leaves, apex_pos, rng.randf_range(4.5, 6.2), Vector3.UP, tint)

# ==============================================================================
# 2. EUCALYPTUS (Eucalipto Blanco - Foto 1)
# Sinuous leaning trunk (17-21m), 3D peeling bark ribbons, weeping canopy
# ==============================================================================
func _generate_eucalyptus(st_bark: SurfaceTool, st_leaves: SurfaceTool, rng: RandomNumberGenerator, tint: Color) -> void:
	var total_h = rng.randf_range(17.0, 22.0)
	var base_r = rng.randf_range(0.85, 1.10)
	
	var pts: Array[Vector3] = []
	var radii: Array[float] = []
	var segs = 18
	var curve_dir = Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.0, 1.0)).normalized()
	
	for i in segs:
		var t = float(i) / float(segs - 1)
		var y = t * total_h
		var offset = sin(t * PI) * curve_dir * 2.2 + sin(t * TAU) * curve_dir.cross(Vector3.UP) * 0.65
		pts.append(Vector3(0, y, 0) + offset)
		var burl = sin(t * 9.0) * 0.05
		radii.append(lerpf(base_r, 0.22, t) + burl)
	_extrude_branch(st_bark, pts, radii, 14, 0.26, 0, true)
	
	# Roots
	_generate_roots(st_bark, pts[0], base_r, rng.randi_range(3, 5), rng, 0)
	
	# Tangential Peeling Bark Ribbons (tiras colgantes que se desprenden como en la Foto 1)
	for ribbon_idx in rng.randi_range(7, 11):
		var rib_h_t = rng.randf_range(0.18, 0.68)
		var pt_idx = clampi(int(rib_h_t * (segs - 1)), 2, segs - 3)
		var center_pt = pts[pt_idx]
		var cur_r = radii[pt_idx]
		var angle = rng.randf() * TAU
		var normal_out = Vector3(cos(angle), 0, sin(angle)).normalized()
		var tangent_side = Vector3(-sin(angle), 0, cos(angle)).normalized()
		
		var r_pts: Array[Vector3] = []
		var r_rad: Array[float] = []
		var r_len = rng.randf_range(2.0, 3.8)
		var r_segs = 6
		for ri in r_segs:
			var rt = float(ri) / float(r_segs - 1)
			var peel_dist = cur_r + pow(rt, 1.2) * rng.randf_range(0.18, 0.42)
			var drop_y = -rt * r_len
			var side_curl = sin(rt * PI) * rng.randf_range(-0.15, 0.15)
			r_pts.append(center_pt + normal_out * peel_dist + tangent_side * side_curl + Vector3(0, drop_y, 0))
			r_rad.append(lerpf(0.08, 0.02, rt))
		_extrude_branch(st_bark, r_pts, r_rad, 4, 0.8, 0, true)
		
	# High weeping canopy
	var top_start_idx = int(segs * 0.65)
	for bi in range(top_start_idx, segs):
		var b_origin = pts[bi]
		var b_num = rng.randi_range(2, 3)
		for b in b_num:
			var angle = rng.randf() * TAU
			var b_dir = (Vector3(cos(angle), rng.randf_range(0.2, 0.6), sin(angle)) + curve_dir * 0.3).normalized()
			var b_end = b_origin + b_dir * rng.randf_range(5.0, 8.5) + Vector3(0, -rng.randf_range(1.5, 3.5), 0)
			_extrude_branch(st_bark, [b_origin, b_end], [0.22, 0.06], 6, 0.45, 0, true)
			
			# Cascading weeping sickle leaves
			for lf in rng.randi_range(6, 10):
				var cascade_y = -float(lf) * 0.45
				var l_pos = b_end + Vector3(
					rng.randf_range(-1.8, 1.8),
					cascade_y + rng.randf_range(-0.5, 0.5),
					rng.randf_range(-1.8, 1.8)
				)
				_add_leaf_card(st_leaves, l_pos, rng.randf_range(3.8, 5.2), Vector3.DOWN, tint, 0.4)

# ==============================================================================
# 3. SILVER BIRCH (Abedul Plateado - Foto 2)
# Slender chalk-white trunk, eye scars with branch stubs, fluttering lime leaves
# ==============================================================================
func _generate_birch(st_bark: SurfaceTool, st_leaves: SurfaceTool, rng: RandomNumberGenerator, tint: Color) -> void:
	var total_h = rng.randf_range(15.0, 19.5)
	var base_r = rng.randf_range(0.44, 0.58)
	
	var pts: Array[Vector3] = []
	var radii: Array[float] = []
	var segs = 20
	var lean_dir = Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
	
	for i in segs:
		var t = float(i) / float(segs - 1)
		var y = t * total_h
		var curve = lean_dir * (t * t * 2.0)
		pts.append(Vector3(0, y, 0) + curve)
		radii.append(lerpf(base_r, 0.10, t))
	_extrude_branch(st_bark, pts, radii, 14, 0.24, 0, true)
	
	# Roots
	_generate_roots(st_bark, pts[0], base_r, rng.randi_range(3, 4), rng, 0)
	
	# Eye scars with dry branch stubs (Foto 2)
	for eye_idx in rng.randi_range(5, 9):
		var eye_t = rng.randf_range(0.12, 0.65)
		var pt_idx = clampi(int(eye_t * (segs - 1)), 1, segs - 4)
		var eye_center = pts[pt_idx]
		var eye_r = radii[pt_idx]
		var angle = rng.randf() * TAU
		var out_dir = Vector3(cos(angle), rng.randf_range(-0.1, 0.2), sin(angle)).normalized()
		
		var stub_len = rng.randf_range(0.20, 0.45)
		var stub_start = eye_center + out_dir * (eye_r - 0.02)
		var stub_end = stub_start + out_dir * stub_len
		_extrude_branch(st_bark, [stub_start, stub_end], [0.11, 0.05], 6, 1.2, 0, true)
		
	# Upper airy shimmering crown (starts at 50% height)
	var start_idx = int(segs * 0.48)
	for i in range(start_idx, segs, 2):
		var p = pts[i]
		var branches_count = rng.randi_range(2, 4)
		for b in branches_count:
			var angle = rng.randf() * TAU
			var dir = Vector3(cos(angle), rng.randf_range(0.4, 0.8), sin(angle)).normalized()
			var tip = p + dir * rng.randf_range(3.5, 5.5) + Vector3(0, -rng.randf_range(0.5, 1.5), 0)
			_extrude_branch(st_bark, [p, tip], [0.16, 0.05], 5, 0.5, 0, true)
			
			# Fluttering small golden/lime leaf clusters
			for lf in rng.randi_range(6, 10):
				var l_pos = tip + Vector3(
					rng.randf_range(-2.0, 2.0),
					rng.randf_range(-1.2, 1.6),
					rng.randf_range(-2.0, 2.0)
				)
				_add_leaf_card(st_leaves, l_pos, rng.randf_range(3.2, 4.4), dir, tint)

# ==============================================================================
# 4. STONE PINE (Pino Piñonero / Parasol - Foto 4)
# Polygonal armored plates, bare lower trunk with stumps, flat-top umbrella crown
# ==============================================================================
func _generate_pine(st_bark: SurfaceTool, st_leaves: SurfaceTool, rng: RandomNumberGenerator, tint: Color) -> void:
	var total_h = rng.randf_range(13.0, 17.0)
	var base_r = rng.randf_range(0.95, 1.25)
	
	var pts: Array[Vector3] = []
	var radii: Array[float] = []
	var segs = 14
	var lean = Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
	
	for i in segs:
		var t = float(i) / float(segs - 1)
		var y = t * total_h
		pts.append(Vector3(0, y, 0) + lean * (t * 1.5))
		radii.append(lerpf(base_r, 0.42, t))
	_extrude_branch(st_bark, pts, radii, 16, 0.32, 2, true)
	
	# Massive roots
	_generate_roots(st_bark, pts[0], base_r, rng.randi_range(5, 7), rng, 2)
	
	# Lower broken weathered branch stumps (Foto 4)
	for s_idx in rng.randi_range(4, 7):
		var st_t = rng.randf_range(0.20, 0.62)
		var p_idx = clampi(int(st_t * (segs - 1)), 2, segs - 4)
		var st_p = pts[p_idx]
		var st_r = radii[p_idx]
		var st_ang = rng.randf() * TAU
		var st_dir = Vector3(cos(st_ang), -0.18, sin(st_ang)).normalized()
		_extrude_branch(st_bark, [st_p, st_p + st_dir * (st_r + rng.randf_range(0.35, 0.85))], [0.20, 0.12], 6, 0.8, 2, true)
		
	# Wide flat-topped umbrella / parasol crown
	var top_pt = pts[pts.size() - 1]
	var umbrella_arms = rng.randi_range(6, 9)
	for b in umbrella_arms:
		var angle = (float(b) / float(umbrella_arms)) * TAU + rng.randf_range(-0.15, 0.15)
		var arm_dir = Vector3(cos(angle), rng.randf_range(0.08, 0.28), sin(angle)).normalized()
		var arm_len = rng.randf_range(6.5, 9.5)
		var arm_end = top_pt + arm_dir * arm_len
		
		_extrude_branch(st_bark, [top_pt, arm_end], [0.38, 0.14], 6, 0.38, 0, true)
		
		# Dense horizontal needle pads sitting on the umbrella arms
		for pad in rng.randi_range(8, 14):
			var pad_pos = arm_end + Vector3(
				rng.randf_range(-2.8, 2.8),
				rng.randf_range(-0.4, 0.6),
				rng.randf_range(-2.8, 2.8)
			)
			_add_leaf_card(st_leaves, pad_pos, rng.randf_range(4.2, 5.8), Vector3.UP, tint)
			
	# Top flat parasol roof layer
	for t in rng.randi_range(12, 18):
		var roof_pos = top_pt + Vector3(
			rng.randf_range(-4.5, 4.5),
			rng.randf_range(0.5, 1.8),
			rng.randf_range(-4.5, 4.5)
		)
		_add_leaf_card(st_leaves, roof_pos, rng.randf_range(4.5, 6.2), Vector3.UP, tint)

# ==============================================================================
# 5. MOUNTAIN FIR (Abeto de Montaña - Foto 5)
# Towering columnar fluted trunk, 14 layered pagoda tiers, sharp conical spire
# ==============================================================================
func _generate_fir(st_bark: SurfaceTool, st_leaves: SurfaceTool, rng: RandomNumberGenerator, tint: Color) -> void:
	var total_h = rng.randf_range(20.0, 27.0)
	var base_r = rng.randf_range(1.05, 1.35)
	
	var pts: Array[Vector3] = []
	var radii: Array[float] = []
	var segs = 22
	
	for i in segs:
		var t = float(i) / float(segs - 1)
		var y = t * total_h
		pts.append(Vector3(0, y, 0))
		radii.append(lerpf(base_r, 0.08, t))
	_extrude_branch(st_bark, pts, radii, 16, 0.35, 3, true)
	
	_generate_roots(st_bark, pts[0], base_r, rng.randi_range(4, 6), rng, 3)
	
	var tiers = 14
	for tier in tiers:
		var t = lerpf(0.12, 0.96, float(tier) / float(tiers - 1))
		var tier_y = t * total_h
		var tier_r = (1.0 - t) * rng.randf_range(5.2, 7.8)
		var branches_in_tier = 6
		for b in branches_in_tier:
			var angle = (float(b) / float(branches_in_tier)) * TAU + (tier * 0.55)
			var b_dir = Vector3(cos(angle), -0.15, sin(angle)).normalized()
			var b_pos = Vector3(0, tier_y, 0) + b_dir * tier_r
			_add_leaf_card(st_leaves, b_pos, rng.randf_range(3.8, 5.2), Vector3.UP, tint)
			# Mid branch card for lushness
			_add_leaf_card(st_leaves, Vector3(0, tier_y, 0) + b_dir * (tier_r * 0.55), rng.randf_range(3.4, 4.6), Vector3.UP, tint)
