import re

TERRAIN_FILE = "scripts/terrain.gd"

with open(TERRAIN_FILE, "r", encoding="utf-8") as f:
    content = f.read()

start_marker = "\t# AAA Botanical Species / Races of trees:"
end_marker = "\t# Batch the 15 botanical tree species variants"

pos_start = content.find(start_marker)
pos_end = content.find(end_marker)

if pos_start == -1 or pos_end == -1:
    print(f"ERROR: Could not find markers: pos_start={pos_start}, pos_end={pos_end}")
    exit(1)

new_block = """\t# AAA Botanical Species / Races of trees:
\t# 1. Robles / Oaks: broadleaf ancient hardwoods with massive spreading crowns
\t# 2. Abedules / Birches: slender pale-bark trees with dark eye scars
\t# 3. Pinos / Pines: Scots/stone pines with armor-plated bark and umbrella canopy (3D Scanned GLB)
\t# 4. Eucaliptos / Eucalyptus: tall upright trees with peeling bark ribbons
\t# 5. Abetos / Firs: layered evergreen conifers with corrugated trunks (3D Scanned GLB)
\tvar species_types := ["oak", "eucalyptus", "birch", "pine", "fir"]
\tvar species_meshes: Dictionary = {}
\tvar species_transforms: Dictionary = {}
\tfor sp in species_types:
\t\tspecies_transforms[sp] = [[], [], []]

\t# Photogrammetric 3D Scans for Conifers:
\t# Fir: 3 LODs of mature mountain fir
\tspecies_meshes["fir"] = [_tree_lods[0], _tree_lods[1], _tree_lods[2]]

\t# Pine: 3 LODs of Scots pine
\tvar pine_lods := [
\t\t_asset_mesh("res://assets/environment/pine/pine_lod0.glb"),
\t\t_asset_mesh("res://assets/environment/pine/pine_lod1.glb"),
\t\t_asset_mesh("res://assets/environment/pine/pine_lod2.glb")
\t]
\tfor p_lod in pine_lods:
\t\tvar p_mesh := p_lod as ArrayMesh
\t\tfor surface in p_mesh.get_surface_count():
\t\t\tvar mat := p_mesh.surface_get_material(surface) as StandardMaterial3D
\t\t\tif mat:
\t\t\t\tif mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
\t\t\t\t\tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
\t\t\t\t\tmat.alpha_scissor_threshold = 0.25
\t\t\t\tmat.roughness = 0.92
\t\t\t\tmat.metallic = 0.0
\tspecies_meshes["pine"] = [pine_lods[0], pine_lods[1], pine_lods[2]]

\t# Deciduous broadleaf species with smooth botanical meshes:
\tfor sp in ["oak", "birch", "eucalyptus"]:
\t\tspecies_meshes[sp] = []
\t\tfor v in range(1, 4):
\t\t\tvar p := "res://assets/environment/trees/tree_%s_var%d.res" % [sp, v]
\t\t\tspecies_meshes[sp].append(load(p))

\tvar rocks: Array[Transform3D] = []
\tvar grasses_0: Array[Transform3D] = []
\tvar grasses_1: Array[Transform3D] = []
\tvar grasses_hill: Array[Transform3D] = []
\tvar grasses_valley: Array[Transform3D] = []

\t# Spatial Hash Grid: Guarantees strict distance separation between all trees
\t# ("También deben estar mas separados, para notar que son distintos")
\tvar tree_grid: Dictionary = {}
\tvar grid_cell_size: float = 16.0

\tvar can_place_tree := func(pos_x: float, pos_z: float, min_d: float) -> bool:
\t\tvar gx := int(floor(pos_x / grid_cell_size))
\t\tvar gz := int(floor(pos_z / grid_cell_size))
\t\tvar min_d_sq := min_d * min_d
\t\tvar pt := Vector2(pos_x, pos_z)
\t\tfor dx in range(-1, 2):
\t\t\tfor dz in range(-1, 2):
\t\t\t\tvar key = Vector2i(gx + dx, gz + dz)
\t\t\t\tif tree_grid.has(key):
\t\t\t\t\tvar cell_pts: Array = tree_grid[key]
\t\t\t\t\tfor other_pt in cell_pts:
\t\t\t\t\t\tif pt.distance_squared_to(other_pt) < min_d_sq:
\t\t\t\t\t\t\treturn false
\t\treturn true

\tvar register_tree := func(pos_x: float, pos_z: float):
\t\tvar gx := int(floor(pos_x / grid_cell_size))
\t\tvar gz := int(floor(pos_z / grid_cell_size))
\t\tvar key = Vector2i(gx, gz)
\t\tif not tree_grid.has(key):
\t\t\ttree_grid[key] = []
\t\ttree_grid[key].append(Vector2(pos_x, pos_z))

\t# Helper to instantiate a botanically distinct tree with 100% unique scaling, yaw, and tilt
\tvar add_tree := func(sp: String, x: float, z: float, h: float, var_idx: int = -1):
\t\tvar base_size := 1.0
\t\tmatch sp:
\t\t\t"oak":
\t\t\t\tbase_size = _rng.randf_range(0.55, 0.85)
\t\t\t"birch":
\t\t\t\tbase_size = _rng.randf_range(0.72, 1.05)
\t\t\t"pine":
\t\t\t\tbase_size = _rng.randf_range(7.5, 11.0)
\t\t\t"eucalyptus":
\t\t\t\tbase_size = _rng.randf_range(0.65, 0.95)
\t\t\t"fir":
\t\t\t\tbase_size = _rng.randf_range(0.85, 1.25)
\t\tvar sx := base_size * _rng.randf_range(0.90, 1.12)
\t\tvar sy := base_size * _rng.randf_range(0.88, 1.15)
\t\tvar sz := base_size * _rng.randf_range(0.90, 1.12)
\t\tvar yaw := _rng.randf() * TAU
\t\tvar tilt_angle := _rng.randf_range(0.015, 0.050)
\t\tvar tilt_dir := _rng.randf() * TAU
\t\tvar tilt_rot := Basis(Vector3(cos(tilt_dir), 0.0, sin(tilt_dir)).normalized(), tilt_angle)
\t\tvar basis := (Basis(Vector3.UP, yaw) * tilt_rot).scaled(Vector3(sx, sy, sz))
\t\tvar tree_xform := Transform3D(basis, Vector3(x, h - 0.06, z))
\t\t_tree_transforms.append(tree_xform)
\t\tvar v_idx := var_idx if (var_idx >= 0 and var_idx < 3) else _rng.randi_range(0, 2)
\t\tspecies_transforms[sp][v_idx].append(tree_xform)
\t\tregister_tree.call(x, z)

\t# 1. Spawn Valley in front of the nest ("antes habían arboles ahí reponlos")
\t# Stately, well-separated trees framing the view across the valley
\tfor i in 250:
\t\tvar x := _rng.randf_range(110.0, 235.0)
\t\tvar z := _rng.randf_range(45.0, 200.0)
\t\t# Clear zone for player spawn and direct camera vista to nest
\t\tif (x > 195.0 and x < 225.0 and z > 105.0 and z < 135.0):
\t\t\tcontinue
\t\tvar h := ground_height(x, z)
\t\tif h < WATER_LEVEL + 0.6:
\t\t\tcontinue
\t\tif can_place_tree.call(x, z, 18.0):
\t\t\tvar r_sp := _rng.randf()
\t\t\tvar sp_v: String
\t\t\tif r_sp < 0.38:
\t\t\t\tsp_v = "birch"
\t\t\telif r_sp < 0.65:
\t\t\t\tsp_v = "pine"
\t\t\telif r_sp < 0.85:
\t\t\t\tsp_v = "oak"
\t\t\telse:
\t\t\t\tsp_v = "fir"
\t\t\tadd_tree.call(sp_v, x, z, h)

\t# 2. Gate Approach: Framed avenue with wide central walking corridor clear
\tfor i in 120:
\t\tvar x := _rng.randf_range(230.0, 370.0)
\t\tvar z := _rng.randf_range(200.0, 380.0)
\t\tif absf(x - 300.0) < 15.0:
\t\t\tcontinue
\t\tvar h := ground_height(x, z)
\t\tif h < 2.0:
\t\t\tcontinue
\t\tif can_place_tree.call(x, z, 18.0):
\t\t\tvar sp_g := "oak" if _rng.randf() < 0.55 else "pine"
\t\t\tadd_tree.call(sp_g, x, z, h)

\t# 3. Riparian Conifers and River Birches along stream banks (Fotos 2 & 3)
\tfor i in 200:
\t\tvar z_s := _rng.randf_range(-230.0, 310.0)
\t\tvar side := -1.0 if i % 2 == 0 else 1.0
\t\tvar x_s := stream_west_center(z_s) + side * _rng.randf_range(16.0, 38.0)
\t\tvar h_s := ground_height(x_s, z_s)
\t\tif h_s > 1.2 and can_place_tree.call(x_s, z_s, 16.0):
\t\t\tvar sp_s := "birch" if _rng.randf() < 0.55 else "fir"
\t\t\tadd_tree.call(sp_s, x_s, z_s, h_s)

\tfor i in 180:
\t\tvar z_se := _rng.randf_range(-340.0, 170.0)
\t\tvar side_e := -1.0 if i % 2 == 0 else 1.0
\t\tvar x_se := stream_east_center(z_se) + side_e * _rng.randf_range(15.0, 36.0)
\t\tvar h_se := ground_height(x_se, z_se)
\t\tif h_se > 1.2 and can_place_tree.call(x_se, z_se, 16.0):
\t\t\tvar sp_se := "pine" if _rng.randf() < 0.5 else "birch"
\t\t\tadd_tree.call(sp_se, x_se, z_se, h_se)

\t# 4. Global World Forest Sampling across the island:
\t# Respects:
\t# - Fortress and Nest clear zone (radius 36m around nest)
\t# - Castle Gate approach road (15m width)
\t# - Lake clearing & shore glade (Foto 4)
\t# - Sinuous Rivers & stream channels
\t# - Rolling hills ("pocas y mucho mas chicas", "no deben estar infestadas de arboles deben tener hierba y ser verdes"):
\t#   Trees on hills are widely spaced (min_d >= 22m, 28% density)
\tfor i in 55000:
\t\tvar x := _rng.randf_range(-965.0, 965.0)
\t\tvar z := _rng.randf_range(-965.0, 965.0)

\t\tvar h := ground_height(x, z)
\t\tif h < WATER_LEVEL + 0.5:
\t\t\tcontinue

\t\t# Fortress & Nest protected space
\t\tvar dist_to_nest := Vector2(x - 300.0, z - 120.0).length()
\t\tif dist_to_nest < 36.0 or (absf(x - 300.0) < 62.0 and absf(z - 120.0) < 52.0):
\t\t\tcontinue
\t\tif absf(x - 300.0) < 14.0 and z > 180.0 and z < 360.0:
\t\t\tcontinue

\t\t# Lake clearing: open water and grassy glade (Foto 4)
\t\tvar lake_dist := (Vector2(x, z) - LAKE_CENTER).length()
\t\tif lake_dist < LAKE_CLEARING_RADIUS:
\t\t\tvar h_cl := ground_height(x, z)
\t\t\tif h_cl > WATER_LEVEL + 0.3 and (grasses_0.size() + grasses_1.size()) < 6500:
\t\t\t\tvar basis_cl := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.70, 1.35))
\t\t\t\tvar t_cl := Transform3D(basis_cl, Vector3(x, h_cl, z))
\t\t\t\tif grasses_0.size() <= grasses_1.size():
\t\t\t\t\tgrasses_0.append(t_cl)
\t\t\t\telse:
\t\t\t\t\tgrasses_1.append(t_cl)
\t\t\tcontinue

\t\t# Water channels
\t\tif is_water_at(Vector3(x, 0, z)) or _is_in_stream(x, z):
\t\t\tcontinue

\t\t# Natural valley clearings
\t\tvar glade_val := _noise.get_noise_2d(x * 0.005 + 520.0, z * 0.005 - 280.0)
\t\tif glade_val > 0.42 and h < 7.5:
\t\t\tif (grasses_0.size() + grasses_1.size()) < 18000:
\t\t\t\tvar t_gl := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.70, 1.35)), Vector3(x, h, z))
\t\t\t\tif grasses_0.size() <= grasses_1.size():
\t\t\t\t\tgrasses_0.append(t_gl)
\t\t\t\telse:
\t\t\t\t\tgrasses_1.append(t_gl)
\t\t\tcontinue

\t\tvar slope := Vector2(ground_height(x + 5, z) - ground_height(x - 5, z), ground_height(x, z + 5) - ground_height(x, z - 5)).length() / 10.0
\t\tif slope > 0.88:
\t\t\tcontinue

\t\t# Rolling hills rule ("las colinas no deben estar infestadas de árboles deben tener hierba y ser verdes"):
\t\t# On hills (h > 12.0), low density and wide spacing
\t\tvar req_dist: float = 16.0
\t\tif h > 12.0:
\t\t\tif _rng.randf() > 0.28:
\t\t\t\tcontinue
\t\t\treq_dist = 22.0

\t\tif not can_place_tree.call(x, z, req_dist):
\t\t\tcontinue

\t\t# Ecological biome determination
\t\tvar dist_to_west := absf(x - stream_west_center(z)) if (z >= -260.0 and z <= 350.0) else 999.0
\t\tvar dist_to_east := absf(x - stream_east_center(z)) if (z >= -370.0 and z <= 210.0) else 999.0
\t\tvar dist_to_stream := minf(dist_to_west, dist_to_east)
\t\tvar dist_to_river := absf(x - river_center(z))
\t\tvar biome_zone := _noise.get_noise_2d(x * 0.003 - 350.0, z * 0.003 + 450.0)

\t\tvar chosen_sp := "fir"
\t\tif dist_to_stream < 42.0 or dist_to_river < 52.0:
\t\t\tvar r_pick := _rng.randf()
\t\t\tif r_pick < 0.55:
\t\t\t\tchosen_sp = "birch"
\t\t\telif r_pick < 0.80:
\t\t\t\tchosen_sp = "fir"
\t\t\telse:
\t\t\t\tchosen_sp = "oak"
\t\telif h > 42.0 or slope > 0.38:
\t\t\tvar r_pick := _rng.randf()
\t\t\tif r_pick < 0.65:
\t\t\t\tchosen_sp = "pine"
\t\t\telif r_pick < 0.88:
\t\t\t\tchosen_sp = "fir"
\t\t\telse:
\t\t\t\tchosen_sp = "birch"
\t\telif biome_zone < -0.15:
\t\t\tvar r_pick := _rng.randf()
\t\t\tif r_pick < 0.68:
\t\t\t\tchosen_sp = "oak"
\t\t\telif r_pick < 0.86:
\t\t\t\tchosen_sp = "birch"
\t\t\telse:
\t\t\t\tchosen_sp = "pine"
\t\telif biome_zone > 0.15:
\t\t\tvar r_pick := _rng.randf()
\t\t\tif r_pick < 0.65:
\t\t\t\tchosen_sp = "eucalyptus"
\t\t\telif r_pick < 0.85:
\t\t\t\tchosen_sp = "pine"
\t\t\telse:
\t\t\t\tchosen_sp = "oak"
\t\telse:
\t\t\tvar r_pick := _rng.randf()
\t\t\tif r_pick < 0.25:
\t\t\t\tchosen_sp = "oak"
\t\t\telif r_pick < 0.50:
\t\t\t\tchosen_sp = "pine"
\t\t\telif r_pick < 0.70:
\t\t\t\tchosen_sp = "eucalyptus"
\t\t\telif r_pick < 0.85:
\t\t\t\tchosen_sp = "birch"
\t\t\telse:
\t\t\t\tchosen_sp = "fir"

\t\tadd_tree.call(chosen_sp, x, z, h)

\t\tif i % 85 == 0 and h > 0.5 and rocks.size() < 300:
\t\t\tvar r_scale := Vector3(_rng.randf_range(0.9, 2.7), _rng.randf_range(0.6, 2.4), _rng.randf_range(0.9, 2.7))
\t\t\tvar r_rot := Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU))
\t\t\trocks.append(Transform3D(r_rot.scaled(r_scale), Vector3(x, h - 0.12, z)))

"""

updated = content[:pos_start] + new_block + content[pos_end:]

with open(TERRAIN_FILE, "w", encoding="utf-8") as f:
    f.write(updated)

print("Successfully replaced forest tree generation with spatial hash grid and scanned glbs!")
