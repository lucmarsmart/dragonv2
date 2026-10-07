class_name GrassGenerator
extends RefCounted

## Procedural Realistic Grass Blade Generator
## Generates true 3D grass blade meshes with sharp pointed tips, natural gravity curves,
## V-crease midribs, and rich length distribution (tall, mid, and short blades).

static func generate_tuft_mesh(variant: int = 0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 84129 + variant * 19283
	
	# Rich blade count for a full, natural, bushy tuft
	var blade_count := 34 if variant == 0 else 30
	
	for b in blade_count:
		var blade_type: int # 0 = short, 1 = mid, 2 = tall
		var r := rng.randf()
		if variant == 0: # Lush meadow tuft
			if r < 0.30:
				blade_type = 0 # short base blades
			elif r < 0.68:
				blade_type = 1 # mid meadow blades
			else:
				blade_type = 2 # tall arching blades
		else: # Wild pasture tuft (more tall briznas)
			if r < 0.24:
				blade_type = 0
			elif r < 0.52:
				blade_type = 1
			else:
				blade_type = 2
		
		var blade_height: float
		var curve_strength: float
		var base_width: float
		var root_radius: float
		
		match blade_type:
			0: # Short briznas (spreading out low to fill the base)
				blade_height = rng.randf_range(0.22, 0.42)
				curve_strength = rng.randf_range(0.12, 0.24)
				base_width = rng.randf_range(0.016, 0.024)
				root_radius = rng.randf_range(0.04, 0.14)
			1: # Mid briznas (classic meadow blades)
				blade_height = rng.randf_range(0.48, 0.78)
				curve_strength = rng.randf_range(0.22, 0.40)
				base_width = rng.randf_range(0.018, 0.026)
				root_radius = rng.randf_range(0.02, 0.10)
			2: # Tall briznas (más largas, arching outward gracefully)
				blade_height = rng.randf_range(0.82, 1.28)
				curve_strength = rng.randf_range(0.32, 0.58)
				base_width = rng.randf_range(0.020, 0.028)
				root_radius = rng.randf_range(0.01, 0.07)
		
		# Radial orientation around clump center with organic jitter
		var base_angle := (float(b) / float(blade_count)) * TAU + rng.randf_range(-0.35, 0.35)
		var root_pos := Vector3(cos(base_angle) * root_radius, 0.0, sin(base_angle) * root_radius)
		
		# Outward arching direction fanning away from center
		var arch_angle := base_angle + rng.randf_range(-0.28, 0.28)
		var arch_dir := Vector3(cos(arch_angle), 0.0, sin(arch_angle))
		var perp_dir := Vector3(-sin(arch_angle), 0.0, cos(arch_angle))
		var fold_dir := arch_dir
		
		var blade_color_tone := rng.randf_range(0.90, 1.10)
		var blade_flutter_phase := rng.randf()
		
		_build_blade(
			st, root_pos, arch_dir, perp_dir, fold_dir,
			blade_height, curve_strength, base_width,
			blade_color_tone, blade_flutter_phase
		)
	
	st.generate_normals()
	return st.commit()

static func _build_blade(
	st: SurfaceTool,
	root_pos: Vector3,
	arch_dir: Vector3,
	perp_dir: Vector3,
	fold_dir: Vector3,
	height: float,
	curve_strength: float,
	base_width: float,
	color_tone: float,
	flutter_phase: float
) -> void:
	# 5 height levels tapering smoothly from base to needle-pointed tip
	var t_levels := [0.0, 0.22, 0.48, 0.72, 0.90]
	var width_factors := [1.0, 0.92, 0.78, 0.50, 0.22]
	
	var ring_vertices: Array[Array] = []
	var ring_uvs: Array[Array] = []
	var ring_colors: Array[Array] = []
	
	for i in t_levels.size():
		var t: float = t_levels[i]
		var w: float = base_width * width_factors[i]
		
		# Natural parabolic gravity curve arching outward
		var spine_offset := arch_dir * (curve_strength * pow(t, 1.7))
		var y := height * t - (curve_strength * 0.22 * pow(t, 2.0))
		var center_pt := root_pos + spine_offset + Vector3.UP * y
		
		# V-crease midrib along the blade center
		var crease_offset := fold_dir * (w * 0.22)
		var v_center := center_pt + crease_offset
		var v_left := center_pt - perp_dir * (w * 0.5)
		var v_right := center_pt + perp_dir * (w * 0.5)
		
		var uv_y := t
		var c_left := Color(t, color_tone, flutter_phase)
		var c_center := Color(t, color_tone * 1.02, flutter_phase)
		var c_right := Color(t, color_tone, flutter_phase)
		
		ring_vertices.append([v_left, v_center, v_right])
		ring_uvs.append([Vector2(-0.5, uv_y), Vector2(0.0, uv_y), Vector2(0.5, uv_y)])
		ring_colors.append([c_left, c_center, c_right])
	
	# Apex tip (t = 1.0, single pointed needle vertex, never a square!)
	var tip_offset := arch_dir * curve_strength
	var tip_y := height - curve_strength * 0.22
	var tip_pos := root_pos + tip_offset + Vector3.UP * tip_y
	var tip_uv := Vector2(0.0, 1.0)
	var tip_col := Color(1.0, color_tone * 1.05, flutter_phase)
	
	# Connect quad segments between rings
	for i in t_levels.size() - 1:
		var r0_v: Array = ring_vertices[i]
		var r0_uv: Array = ring_uvs[i]
		var r0_c: Array = ring_colors[i]
		
		var r1_v: Array = ring_vertices[i + 1]
		var r1_uv: Array = ring_uvs[i + 1]
		var r1_c: Array = ring_colors[i + 1]
		
		# Left quad
		_add_quad(
			st,
			r0_v[0], r0_uv[0], r0_c[0],
			r1_v[0], r1_uv[0], r1_c[0],
			r1_v[1], r1_uv[1], r1_c[1],
			r0_v[1], r0_uv[1], r0_c[1]
		)
		# Right quad
		_add_quad(
			st,
			r0_v[1], r0_uv[1], r0_c[1],
			r1_v[1], r1_uv[1], r1_c[1],
			r1_v[2], r1_uv[2], r1_c[2],
			r0_v[2], r0_uv[2], r0_c[2]
		)
	
	# Connect last ring to apex needle tip
	var last_v: Array = ring_vertices[t_levels.size() - 1]
	var last_uv: Array = ring_uvs[t_levels.size() - 1]
	var last_c: Array = ring_colors[t_levels.size() - 1]
	
	# Left tip triangle
	_add_tri(
		st,
		last_v[0], last_uv[0], last_c[0],
		tip_pos, tip_uv, tip_col,
		last_v[1], last_uv[1], last_c[1]
	)
	# Right tip triangle
	_add_tri(
		st,
		last_v[1], last_uv[1], last_c[1],
		tip_pos, tip_uv, tip_col,
		last_v[2], last_uv[2], last_c[2]
	)

static func _add_tri(
	st: SurfaceTool,
	v0: Vector3, uv0: Vector2, c0: Color,
	v1: Vector3, uv1: Vector2, c1: Color,
	v2: Vector3, uv2: Vector2, c2: Color
) -> void:
	st.set_color(c0)
	st.set_uv(uv0)
	st.add_vertex(v0)
	
	st.set_color(c1)
	st.set_uv(uv1)
	st.add_vertex(v1)
	
	st.set_color(c2)
	st.set_uv(uv2)
	st.add_vertex(v2)

static func _add_quad(
	st: SurfaceTool,
	v0: Vector3, uv0: Vector2, c0: Color,
	v1: Vector3, uv1: Vector2, c1: Color,
	v2: Vector3, uv2: Vector2, c2: Color,
	v3: Vector3, uv3: Vector2, c3: Color
) -> void:
	_add_tri(st, v0, uv0, c0, v1, uv1, c1, v2, uv2, c2)
	_add_tri(st, v0, uv0, c0, v2, uv2, c2, v3, uv3, c3)
