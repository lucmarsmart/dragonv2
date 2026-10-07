with open("scripts/terrain.gd", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Main forest loop species distribution
old_block = """\t\tvar chosen_sp := "fir"
\t\tvar is_mature_fir := false

\t\tif dist_to_stream < 48.0 or dist_to_river < 55.0:
\t\t\t# Riparian stream and river banks: towering firs and pines
\t\t\tvar r_pick := _rng.randf()
\t\t\tif r_pick < 0.42:
\t\t\t\tis_mature_fir = true
\t\t\telif r_pick < 0.72:
\t\t\t\tchosen_sp = "fir"
\t\t\telse:
\t\t\t\tchosen_sp = "pine"
\t\telif biome_zone < -0.16:
\t\t\t# Deciduous broadleaf woods (Robles y Abedules)
\t\t\tvar r_pick := _rng.randf()
\t\t\tif r_pick < 0.52:
\t\t\t\tchosen_sp = "oak"
\t\t\telif r_pick < 0.85:
\t\t\t\tchosen_sp = "birch"
\t\t\telse:
\t\t\t\tchosen_sp = "pine"
\t\telif biome_zone > 0.18:
\t\t\t# Conifer mountain knolls (Pinos y Abetos)
\t\t\tvar r_pick := _rng.randf()
\t\t\tif r_pick < 0.38:
\t\t\t\tis_mature_fir = true
\t\t\telif r_pick < 0.74:
\t\t\t\tchosen_sp = "pine"
\t\t\telse:
\t\t\t\tchosen_sp = "fir"
\t\telse:
\t\t\t# Rich mixed temperate forest (Robles, Abedules, Eucaliptos, Pinos, Abetos)
\t\t\tvar r_pick := _rng.randf()
\t\t\tif r_pick < 0.22:
\t\t\t\tis_mature_fir = true
\t\t\telif r_pick < 0.42:
\t\t\t\tchosen_sp = "oak"
\t\t\telif r_pick < 0.60:
\t\t\t\tchosen_sp = "birch"
\t\t\telif r_pick < 0.76:
\t\t\t\tchosen_sp = "pine"
\t\t\telif r_pick < 0.88:
\t\t\t\tchosen_sp = "fir"
\t\t\telse:
\t\t\t\tchosen_sp = "eucalyptus"

\t\t# Fully procedural unique transform for every single tree (100% unique scales, yaw, tilts)
\t\tvar size := _rng.randf_range(0.85, 1.70)
\t\tvar sx := size * _rng.randf_range(0.86, 1.15)
\t\tvar sy := size * _rng.randf_range(0.82, 1.25)
\t\tvar sz := size * _rng.randf_range(0.86, 1.15)
\t\tvar yaw := _rng.randf() * TAU
\t\tvar tilt_angle := _rng.randf_range(0.015, 0.055)
\t\tvar tilt_dir := _rng.randf() * TAU
\t\tvar tilt_rot := Basis(Vector3(cos(tilt_dir), 0.0, sin(tilt_dir)), tilt_angle)
\t\tvar basis := (Basis(Vector3.UP, yaw) * tilt_rot).scaled(Vector3(sx, sy, sz))
\t\tvar tree_xform := Transform3D(basis, Vector3(x, h - 0.06, z))
\t\t_tree_transforms.append(tree_xform)

\t\tif is_mature_fir:
\t\t\t_mature_fir_transforms.append(tree_xform)
\t\telse:
\t\t\tvar var_idx := _rng.randi_range(0, 2)
\t\t\tspecies_transforms[chosen_sp][var_idx].append(tree_xform)"""

new_block = """\t\tvar chosen_sp := "fir"

\t\tif dist_to_stream < 42.0 or dist_to_river < 52.0:
\t\t\t# Riparian wetland & riverbank: Luminous Silver Birch and riparian trees
\t\t\tvar r_pick := _rng.randf()
\t\t\tif r_pick < 0.55:
\t\t\t\tchosen_sp = "birch"
\t\t\telif r_pick < 0.80:
\t\t\t\tchosen_sp = "fir"
\t\t\telse:
\t\t\t\tchosen_sp = "oak"
\t\telif h > 42.0 or slope > 0.38:
\t\t\t# Sunlit ridges & rocky crests: Mediterranean Stone Pine and mountain Firs
\t\t\tvar r_pick := _rng.randf()
\t\t\tif r_pick < 0.65:
\t\t\t\tchosen_sp = "pine"
\t\t\telif r_pick < 0.88:
\t\t\t\tchosen_sp = "fir"
\t\t\telse:
\t\t\t\tchosen_sp = "birch"
\t\telif biome_zone < -0.15:
\t\t\t# Ancient Oak Forest (Robledal): Giant mushroom/dome crowns and thick gnarled boughs
\t\t\tvar r_pick := _rng.randf()
\t\t\tif r_pick < 0.68:
\t\t\t\tchosen_sp = "oak"
\t\t\telif r_pick < 0.86:
\t\t\t\tchosen_sp = "birch"
\t\t\telse:
\t\t\t\tchosen_sp = "pine"
\t\telif biome_zone > 0.15:
\t\t\t# Eucalyptus Glades (Eucaliptal): Sinuous weeping tall trees with peeling ribbons
\t\t\tvar r_pick := _rng.randf()
\t\t\tif r_pick < 0.65:
\t\t\t\tchosen_sp = "eucalyptus"
\t\t\telif r_pick < 0.85:
\t\t\t\tchosen_sp = "pine"
\t\t\telse:
\t\t\t\tchosen_sp = "oak"
\t\telse:
\t\t\t# Balanced mixed temperate woodland (Oaks, Pines, Eucalyptus, Birches, Firs)
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

\t\t# Fully procedural unique transform for every single tree (100% unique scales, yaw, tilts)
\t\tvar size := _rng.randf_range(0.85, 1.70)
\t\tvar sx := size * _rng.randf_range(0.86, 1.15)
\t\tvar sy := size * _rng.randf_range(0.82, 1.25)
\t\tvar sz := size * _rng.randf_range(0.86, 1.15)
\t\tvar yaw := _rng.randf() * TAU
\t\tvar tilt_angle := _rng.randf_range(0.015, 0.055)
\t\tvar tilt_dir := _rng.randf() * TAU
\t\tvar tilt_rot := Basis(Vector3(cos(tilt_dir), 0.0, sin(tilt_dir)), tilt_angle)
\t\tvar basis := (Basis(Vector3.UP, yaw) * tilt_rot).scaled(Vector3(sx, sy, sz))
\t\tvar tree_xform := Transform3D(basis, Vector3(x, h - 0.06, z))
\t\t_tree_transforms.append(tree_xform)

\t\tvar var_idx := _rng.randi_range(0, 2)
\t\tspecies_transforms[chosen_sp][var_idx].append(tree_xform)"""

if old_block in content:
    content = content.replace(old_block, new_block)
    print("Replaced main tree block!")
else:
    print("Warning: old_block not found in content!")

# 2. Gate trees
old_gate = """\t\t\t_tree_transforms.append(gate_tree)
\t\t\t_mature_fir_transforms.append(gate_tree)"""
new_gate = """\t\t\t_tree_transforms.append(gate_tree)
\t\t\tvar gate_sp = "oak" if _rng.randf() < 0.6 else "pine"
\t\t\tspecies_transforms[gate_sp][_rng.randi_range(0, 2)].append(gate_tree)"""
if old_gate in content:
    content = content.replace(old_gate, new_gate)
    print("Replaced gate trees!")

# 3. Stream west trees
old_sw = """\t\t\t_tree_transforms.append(str_tree)
\t\t\tif _rng.randf() < 0.5:
\t\t\t\t_mature_fir_transforms.append(str_tree)
\t\t\telse:
\t\t\t\tspecies_transforms["fir"][_rng.randi_range(0, 2)].append(str_tree)"""
new_sw = """\t\t\t_tree_transforms.append(str_tree)
\t\t\tvar sw_sp = "birch" if _rng.randf() < 0.55 else "fir"
\t\t\tspecies_transforms[sw_sp][_rng.randi_range(0, 2)].append(str_tree)"""
if old_sw in content:
    content = content.replace(old_sw, new_sw)
    print("Replaced stream west trees!")

# 4. Stream east trees
old_se = """\t\t\t_tree_transforms.append(str_tree_e)
\t\t\tif _rng.randf() < 0.5:
\t\t\t\t_mature_fir_transforms.append(str_tree_e)
\t\t\telse:
\t\t\t\tspecies_transforms["pine"][_rng.randi_range(0, 2)].append(str_tree_e)"""
new_se = """\t\t\t_tree_transforms.append(str_tree_e)
\t\t\tvar se_sp = "pine" if _rng.randf() < 0.5 else "birch"
\t\t\tspecies_transforms[se_sp][_rng.randi_range(0, 2)].append(str_tree_e)"""
if old_se in content:
    content = content.replace(old_se, new_se)
    print("Replaced stream east trees!")

# 5. Visibility range for botanical trees
old_vis = """\t\t\t\tnode.visibility_range_end = 340.0
\t\t\t\tnode.visibility_range_end_margin = 40.0"""
new_vis = """\t\t\t\tnode.visibility_range_end = 950.0
\t\t\t\tnode.visibility_range_end_margin = 80.0"""
if old_vis in content:
    content = content.replace(old_vis, new_vis)
    print("Replaced visibility range!")

with open("scripts/terrain.gd", "w", encoding="utf-8") as f:
    f.write(content)

print("Finished processing scripts/terrain.gd!")
