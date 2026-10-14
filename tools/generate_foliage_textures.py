import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT_DIR = "assets/environment/foliage"
os.makedirs(OUT_DIR, exist_ok=True)
SIZE = 1024

def smooth_leaf_edges(img):
    # Smooth antialiasing pass
    alpha = img.split()[3]
    alpha = alpha.filter(ImageFilter.GaussianBlur(1.8))
    # Threshold slightly to sharpen silhouette while keeping antialiased gradient
    alpha = alpha.point(lambda p: int(min(255, p * 1.35)))
    img.putalpha(alpha)
    return img

def generate_oak_texture():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Twig branch skeleton
    branches = [
        ((512, 980), (512, 520), 16),
        ((512, 760), (320, 580), 12),
        ((320, 580), (180, 460), 9),
        ((512, 680), (720, 520), 12),
        ((720, 520), (840, 400), 9),
        ((512, 520), (400, 320), 11),
        ((400, 320), (280, 200), 8),
        ((512, 480), (640, 300), 11),
        ((640, 300), (760, 180), 8),
        ((512, 420), (512, 140), 9),
        ((512, 280), (420, 160), 7),
        ((512, 260), (600, 150), 7),
    ]
    for p0, p1, w in branches:
        draw.line([p0, p1], fill=(58, 42, 28, 255), width=w)
    
    np.random.seed(42)
    # Draw organic rounded oak clusters (combinations of overlapping rounded lobes)
    for _ in range(160):
        b_idx = np.random.randint(len(branches))
        bp0, bp1, _ = branches[b_idx]
        bt = np.random.uniform(0.15, 1.15)
        cx = bp0[0] + (bp1[0] - bp0[0]) * bt + np.random.uniform(-75, 75)
        cy = bp0[1] + (bp1[1] - bp0[1]) * bt + np.random.uniform(-75, 75)
        length = np.random.uniform(70, 120)
        angle_deg = np.random.uniform(-180, 180)
        rad = math.radians(angle_deg)
        cos_a = math.cos(rad)
        sin_a = math.sin(rad)
        
        # Color variation
        r = int(np.random.uniform(38, 64))
        g = int(np.random.uniform(88, 134))
        b = int(np.random.uniform(24, 42))
        
        # Draw soft rounded lobes along leaf axis
        n_lobes = 4
        for li in range(n_lobes):
            t = float(li) / float(n_lobes - 1)
            dist = t * length
            lobe_r = math.sin(t * math.pi) * (length * 0.28) + (length * 0.12)
            # Center of lobe pair
            lx = cx + (-dist * sin_a)
            ly = cy + (dist * cos_a)
            # Left and right lobe disks
            draw.ellipse([lx - lobe_r, ly - lobe_r, lx + lobe_r, ly + lobe_r], fill=(r, g, b, 255))
            
            # Wing lobes
            wing_dist = lobe_r * 0.85
            wx1 = lx + wing_dist * cos_a
            wy1 = ly + wing_dist * sin_a
            draw.ellipse([wx1 - lobe_r*0.75, wy1 - lobe_r*0.75, wx1 + lobe_r*0.75, wy1 + lobe_r*0.75], fill=(r+4, g+6, b+2, 255))
            wx2 = lx - wing_dist * cos_a
            wy2 = ly - wing_dist * sin_a
            draw.ellipse([wx2 - lobe_r*0.75, wy2 - lobe_r*0.75, wx2 + lobe_r*0.75, wy2 + lobe_r*0.75], fill=(r-3, g-4, b-2, 255))

    img = smooth_leaf_edges(img)
    img.save(os.path.join(OUT_DIR, "foliage_oak.png"), "PNG")
    print("Saved organic smooth foliage_oak.png")

def generate_birch_texture():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    twigs = [
        ((512, 980), (512, 580), 9),
        ((512, 780), (260, 600), 6),
        ((260, 600), (140, 440), 4),
        ((512, 700), (760, 560), 6),
        ((760, 560), (880, 400), 4),
        ((512, 560), (360, 360), 5),
        ((360, 360), (220, 200), 4),
        ((512, 480), (660, 320), 5),
        ((660, 320), (800, 180), 4),
        ((512, 380), (512, 100), 4),
        ((512, 240), (380, 90), 3),
        ((512, 220), (640, 80), 3),
    ]
    for p0, p1, w in twigs:
        draw.line([p0, p1], fill=(88, 50, 36, 255), width=w)
        
    np.random.seed(123)
    # 200 small, delicate fluttering birch leaf droplets
    for _ in range(200):
        t_idx = np.random.randint(len(twigs))
        tp0, tp1, _ = twigs[t_idx]
        t = np.random.uniform(0.12, 1.15)
        cx = tp0[0] + (tp1[0] - tp0[0]) * t + np.random.uniform(-65, 65)
        cy = tp0[1] + (tp1[1] - tp0[1]) * t + np.random.uniform(-65, 65)
        r_x = np.random.uniform(16, 26)
        r_y = np.random.uniform(22, 36)
        
        r = int(np.random.uniform(65, 105))
        g = int(np.random.uniform(140, 185))
        b = int(np.random.uniform(30, 55))
        draw.ellipse([cx - r_x, cy - r_y, cx + r_x, cy + r_y], fill=(r, g, b, 255))
        
    img = smooth_leaf_edges(img)
    img.save(os.path.join(OUT_DIR, "foliage_birch.png"), "PNG")
    print("Saved organic smooth foliage_birch.png")

def generate_eucalyptus_texture():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    twigs = [
        ((512, 120), (512, 420), 10),
        ((512, 320), (300, 580), 8),
        ((300, 580), (180, 860), 5),
        ((512, 360), (720, 600), 8),
        ((720, 600), (840, 880), 5),
        ((512, 420), (440, 750), 6),
        ((440, 750), (400, 960), 4),
        ((512, 420), (580, 760), 6),
        ((580, 760), (620, 960), 4),
    ]
    for p0, p1, w in twigs:
        draw.line([p0, p1], fill=(110, 95, 70, 255), width=w)
        
    np.random.seed(789)
    # Weeping drooping sickle leaves made of smooth bezier chains
    for _ in range(140):
        t_idx = np.random.randint(len(twigs))
        tp0, tp1, _ = twigs[t_idx]
        t = np.random.uniform(0.15, 1.1)
        cx = tp0[0] + (tp1[0] - tp0[0]) * t + np.random.uniform(-40, 40)
        cy = tp0[1] + (tp1[1] - tp0[1]) * t + np.random.uniform(-40, 40)
        length = np.random.uniform(90, 160)
        
        r = int(np.random.uniform(55, 85))
        g = int(np.random.uniform(120, 160))
        b = int(np.random.uniform(45, 75))
        
        # Smooth drooping chain of discs
        n_discs = 16
        curve_amt = np.random.uniform(12, 28)
        for di in range(n_discs):
            dt = float(di) / float(n_discs - 1)
            dy = dt * length
            dx = math.sin(dt * math.pi) * curve_amt
            disc_r = math.sin(dt * math.pi) * 14.0 + 3.0
            draw.ellipse([cx + dx - disc_r, cy + dy - disc_r, cx + dx + disc_r, cy + dy + disc_r], fill=(r, g, b, 255))
            
    img = smooth_leaf_edges(img)
    img.save(os.path.join(OUT_DIR, "foliage_eucalyptus.png"), "PNG")
    print("Saved organic smooth foliage_eucalyptus.png")

if __name__ == "__main__":
    generate_oak_texture()
    generate_birch_texture()
    generate_eucalyptus_texture()
