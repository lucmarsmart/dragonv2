import os
import shutil
from PIL import Image, ImageFilter

# Backup originals first if not already backed up
img2_path = "assets/models/dragon_Image_2.png"
img2_bak = "assets/models/dragon_Image_2_backup.png"
if not os.path.exists(img2_bak):
    shutil.copy2(img2_path, img2_bak)
    print("Backed up dragon_Image_2.png")

img3_path = "assets/models/dragon_Image_3.png"
img3_bak = "assets/models/dragon_Image_3_backup.png"
if not os.path.exists(img3_bak):
    shutil.copy2(img3_path, img3_bak)
    print("Backed up dragon_Image_3.png")

im2 = Image.open(img2_path).convert("RGB")
im3 = Image.open(img3_path).convert("RGB")

pix2 = im2.load()
pix3 = im3.load()

# In dragon_Image_2.png (1024x1024):
# Left side of head has:
# - Main eye at roughly x: 685..735, y: 865..910
# - Secondary outer eye at x: 615..665, y: 865..910
# Right side of head has:
# - Main eye at roughly x: 800..850, y: 865..910
# - Secondary outer eye at x: 870..920, y: 865..910

# 1. REMOVE SECONDARY OUTER EYE ON LEFT SIDE:
# Source skin texture from nearby temple/cheek scales (x: 580..610, y: 840..870)
# We sample surrounding scales and blend across the secondary eye
for y in range(855, 915):
    for x in range(612, 668):
        # Calculate blend factor based on distance from center of secondary eye
        dx = (x - 640) / 25.0
        dy = (y - 885) / 25.0
        dist_sq = dx*dx + dy*dy
        if dist_sq < 1.0:
            weight = (1.0 - dist_sq)**1.5
            # Sample scale color from above the eye (y - 35) or to the left (x - 35)
            src_x = min(max(x - 30, 560), 610)
            src_y = min(max(y - 25, 830), 865)
            orig_r, orig_g, orig_b = pix2[x, y]
            src_r, src_g, src_b = pix2[src_x, src_y]
            
            # Blend to skin scales
            new_r = int(orig_r * (1.0 - weight) + src_r * weight)
            new_g = int(orig_g * (1.0 - weight) + src_g * weight)
            new_b = int(orig_b * (1.0 - weight) + src_b * weight)
            pix2[x, y] = (new_r, new_g, new_b)
            
            # Normal map: flatten the eye slit bump to match surrounding scale normal
            norm_src_r, norm_src_g, norm_src_b = pix3[src_x, src_y]
            orig_nr, orig_ng, orig_nb = pix3[x, y]
            pix3[x, y] = (
                int(orig_nr * (1.0 - weight) + norm_src_r * weight),
                int(orig_ng * (1.0 - weight) + norm_src_g * weight),
                int(orig_nb * (1.0 - weight) + norm_src_b * weight),
            )

# 2. REMOVE SECONDARY OUTER EYE ON RIGHT SIDE:
# Source skin texture from nearby temple/cheek scales (x: 925..955, y: 840..870)
for y in range(855, 915):
    for x in range(868, 924):
        dx = (x - 896) / 25.0
        dy = (y - 885) / 25.0
        dist_sq = dx*dx + dy*dy
        if dist_sq < 1.0:
            weight = (1.0 - dist_sq)**1.5
            src_x = min(max(x + 30, 925), 960)
            src_y = min(max(y - 25, 830), 865)
            orig_r, orig_g, orig_b = pix2[x, y]
            src_r, src_g, src_b = pix2[src_x, src_y]
            
            new_r = int(orig_r * (1.0 - weight) + src_r * weight)
            new_g = int(orig_g * (1.0 - weight) + src_g * weight)
            new_b = int(orig_b * (1.0 - weight) + src_b * weight)
            pix2[x, y] = (new_r, new_g, new_b)
            
            norm_src_r, norm_src_g, norm_src_b = pix3[src_x, src_y]
            orig_nr, orig_ng, orig_nb = pix3[x, y]
            pix3[x, y] = (
                int(orig_nr * (1.0 - weight) + norm_src_r * weight),
                int(orig_ng * (1.0 - weight) + norm_src_g * weight),
                int(orig_nb * (1.0 - weight) + norm_src_b * weight),
            )

# 3. ENHANCE THE PRIMARY EYE ON LEFT AND RIGHT:
# Golden-amber reptilian eye with vertical slit pupil (Lámina 1)
def enhance_primary_eye(center_x, center_y, radius_x, radius_y):
    for y in range(center_y - radius_y - 2, center_y + radius_y + 3):
        for x in range(center_x - radius_x - 2, center_x + radius_x + 3):
            nx = (x - center_x) / float(radius_x)
            ny = (y - center_y) / float(radius_y)
            d = nx*nx + ny*ny
            if d < 1.0:
                # Inside eye socket
                # Vertical slit pupil: narrow in x (|nx| < 0.22)
                slit_dist = abs(nx) / 0.24
                if slit_dist < 1.0 and abs(ny) < 0.85:
                    # Dark pupil
                    pupil_weight = 1.0 - slit_dist**2
                    gold_r, gold_g, gold_b = 20, 16, 14
                else:
                    # Fiery amber / golden reptile iris
                    iris_grad = 1.0 - d * 0.4
                    gold_r = int(min(255, 235 * iris_grad))
                    gold_g = int(min(255, 155 * iris_grad))
                    gold_b = int(min(255, 35 * iris_grad))
                
                # Smooth edge to eyelid
                edge_weight = smoothstep = 1.0 if d < 0.75 else (1.0 - d) / 0.25
                r, g, b = pix2[x, y]
                pix2[x, y] = (
                    int(r * (1.0 - edge_weight) + gold_r * edge_weight),
                    int(g * (1.0 - edge_weight) + gold_g * edge_weight),
                    int(b * (1.0 - edge_weight) + gold_b * edge_weight),
                )

enhance_primary_eye(707, 887, 18, 12) # Left primary eye
enhance_primary_eye(829, 887, 18, 12) # Right primary eye

im2.save(img2_path)
im3.save(img3_path)
print("dragon_Image_2.png and dragon_Image_3.png updated with single eye per side!")
