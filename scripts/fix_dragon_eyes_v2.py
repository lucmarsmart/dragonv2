import shutil
from PIL import Image

# Restore clean backup first
shutil.copy2("assets/models/dragon_Image_2_backup.png", "assets/models/dragon_Image_2.png")
shutil.copy2("assets/models/dragon_Image_3_backup.png", "assets/models/dragon_Image_3.png")

im2 = Image.open("assets/models/dragon_Image_2.png").convert("RGB")
im3 = Image.open("assets/models/dragon_Image_3.png").convert("RGB")
pix2 = im2.load()
pix3 = im3.load()

# 1. BLEND OUT THE SECONDARY OUTER EYE (LEFT: 610..660, y: 865..915)
# Sample scales from nearby temple skin (x: 580..610, y: 850..870)
for y in range(860, 920):
    for x in range(610, 665):
        # Sample patch of surrounding dark skin
        src_x = min(max(x - 35, 570), 605)
        src_y = min(max(y - 30, 840), 865)
        sr, sg, sb = pix2[src_x, src_y]
        
        # Inpaint over red/purple socket
        pix2[x, y] = (sr, sg, sb)
        
        # Flatten normal map bump of the second eye
        snr, sng, snb = pix3[src_x, src_y]
        pix3[x, y] = (snr, sng, snb)

# 2. BLEND OUT THE SECONDARY OUTER EYE (RIGHT: 865..920, y: 865..915)
# Sample scales from nearby temple skin (x: 925..955, y: 850..870)
for y in range(860, 920):
    for x in range(865, 920):
        src_x = min(max(x + 35, 925), 960)
        src_y = min(max(y - 30, 840), 865)
        sr, sg, sb = pix2[src_x, src_y]
        
        pix2[x, y] = (sr, sg, sb)
        
        snr, sng, snb = pix3[src_x, src_y]
        pix3[x, y] = (snr, sng, snb)

# 3. ENHANCE THE SINGLE MAIN EYE IN ITS NATURAL SOCKET:
# Left socket is centered at (692, 888), width ~24, height ~16
# Right socket is centered at (838, 888), width ~24, height ~16
# Transform the reddish eye fill into a fiery amber-golden reptilian eye with slit pupil
for y in range(872, 905):
    for x in range(676, 708):
        dx = (x - 692) / 12.0
        dy = (y - 888) / 8.0
        d = dx*dx + dy*dy
        if d < 1.0:
            # Inside the natural eye slit
            r, g, b = pix2[x, y]
            # If it's the eye pupil / slit:
            if abs(dx) < 0.28:
                # Vertical slit pupil
                pix2[x, y] = (25, 20, 18)
            else:
                # Fiery amber gold iris
                weight = 1.0 - d * 0.3
                pix2[x, y] = (int(215 * weight), int(140 * weight), int(30 * weight))

for y in range(872, 905):
    for x in range(822, 854):
        dx = (x - 838) / 12.0
        dy = (y - 888) / 8.0
        d = dx*dx + dy*dy
        if d < 1.0:
            r, g, b = pix2[x, y]
            if abs(dx) < 0.28:
                pix2[x, y] = (25, 20, 18)
            else:
                weight = 1.0 - d * 0.3
                pix2[x, y] = (int(215 * weight), int(140 * weight), int(30 * weight))

im2.save("assets/models/dragon_Image_2.png")
im3.save("assets/models/dragon_Image_3.png")

# Save a crop to verify
im2.crop((550, 820, 980, 940)).save("eyes_strip_verified.png")
print("Verified single eye per side generated.")
