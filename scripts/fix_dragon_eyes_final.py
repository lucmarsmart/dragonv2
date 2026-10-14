import shutil
from PIL import Image

# Start from clean original backup
shutil.copy2("assets/models/dragon_Image_2_backup.png", "assets/models/dragon_Image_2.png")
shutil.copy2("assets/models/dragon_Image_3_backup.png", "assets/models/dragon_Image_3.png")

im2 = Image.open("assets/models/dragon_Image_2.png").convert("RGB")
im3 = Image.open("assets/models/dragon_Image_3.png").convert("RGB")
pix2 = im2.load()
pix3 = im3.load()

# 1. REMOVE LEFT OUTER SECONDARY EYE (global x: 585..625, y: 865..905):
# Blend with surrounding grey slate scale texture from above (y - 30) and left (x - 30)
for y in range(860, 910):
    for x in range(585, 630):
        # Sample patch of surrounding dark skin
        src_x = x - 25
        src_y = y - 25
        sr, sg, sb = pix2[src_x, src_y]
        pix2[x, y] = (sr, sg, sb)
        
        # Flatten normal map bump of the secondary eye
        snr, sng, snb = pix3[src_x, src_y]
        pix3[x, y] = (snr, sng, snb)

# 2. REMOVE RIGHT OUTER SECONDARY EYE (global x: 900..945, y: 865..905):
# Blend with surrounding grey slate scale texture from above (y - 30) and right (x + 30)
for y in range(860, 910):
    for x in range(900, 945):
        src_x = x + 25
        src_y = y - 25
        sr, sg, sb = pix2[src_x, src_y]
        pix2[x, y] = (sr, sg, sb)
        
        snr, sng, snb = pix3[src_x, src_y]
        pix3[x, y] = (snr, sng, snb)

# 3. ENHANCE THE REMAINING SINGLE PRIMARY EYE ON EACH SIDE:
# Left primary eye center is at (655, 893)
# Right primary eye center is at (870, 892)
# Slit pupil: narrow vertically, fiery amber/gold iris matching Lámina 1
def paint_reptile_eye(center_x, center_y, rad_x, rad_y):
    for y in range(center_y - rad_y - 2, center_y + rad_y + 3):
        for x in range(center_x - rad_x - 2, center_x + rad_x + 3):
            nx = (x - center_x) / float(rad_x)
            ny = (y - center_y) / float(rad_y)
            d = nx*nx + ny*ny
            if d < 1.0:
                # Vertical slit pupil
                if abs(nx) < 0.28:
                    pix2[x, y] = (22, 18, 16)
                else:
                    # Amber-gold fiery iris
                    falloff = 1.0 - d * 0.35
                    ir = int(220 * falloff)
                    ig = int(145 * falloff)
                    ib = int(30 * falloff)
                    pix2[x, y] = (ir, ig, ib)

paint_reptile_eye(655, 893, 11, 8)
paint_reptile_eye(870, 892, 11, 8)

im2.save("assets/models/dragon_Image_2.png")
im3.save("assets/models/dragon_Image_3.png")

# Save strip
im2.crop((550, 820, 980, 940)).save("eyes_strip_single.png")
print("Single eye per side successfully painted and saved!")
