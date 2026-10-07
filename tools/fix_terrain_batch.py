with open("scripts/terrain.gd", "r", encoding="utf-8") as f:
    text = f.read()

bad = """\t\t\tif species_transforms[sp][v].size() > 0:
\t\t\t\t# Optimize for Intel HD 620 GPU: shadows off on bulk instances to avoid TDR
\t\t\t\tnode.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
\t\t\t\tnode.visibility_range_end = 420.0
\t\t\t\tnode.visibility_range_end_margin = 50.0"""

good = """\t\t\tif species_transforms[sp][v].size() > 0:
\t\t\t\tvar node := _batch(species_meshes[sp][v], species_transforms[sp][v], "BotanicalTree_%s_%d" % [sp, v])
\t\t\t\tnode.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
\t\t\t\tnode.visibility_range_end = 450.0
\t\t\t\tnode.visibility_range_end_margin = 50.0"""

if bad in text:
    text = text.replace(bad, good)
    with open("scripts/terrain.gd", "w", encoding="utf-8") as f:
        f.write(text)
    print("Fixed batch line in terrain.gd successfully!")
else:
    print("Error: bad snippet not found in terrain.gd")
