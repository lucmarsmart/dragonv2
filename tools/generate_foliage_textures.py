import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT_DIR = "assets/environment/foliage"
os.makedirs(OUT_DIR, exist_ok=True)
SIZE = 1024

def generate_oak_texture():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Twig branches
    branches = [
        ((512, 980), (512, 500), 16),
        ((512, 700), (320, 450), 12),
        ((512, 600), (700, 380), 12),
        ((512, 450), (420, 220), 10),
        ((512, 400), (620, 180), 10),
        ((512, 300), (512, 100), 9),
    ]
    for p0, p1, w in branches:
        draw.line([p0, p1], fill=(75, 52, 35, 255), width=w)

    # Function to draw a single lobed oak leaf
    def draw_oak_leaf(cx, cy, length, angle_deg, leaf_col):
        rad = math.radians(angle_deg)
        cos_a = math.cos(rad)
        sin_a = math.sin(rad)
        
        # Base parametric shape for lobed oak leaf (Quercus robur)
        pts = []
        n_steps = 48
        for i in range(n_steps):
            t = i / (n_steps - 1) # 0 to 1 along length
            y = t * length
            # Lobes modulation along length
            width_envelope = math.sin(t * math.pi) * (length * 0.42)
            lobes = math.sin(t * math.pi * 5.0) * (length * 0.12)
            w = max(0.0, width_envelope + lobes)
            
            # Right side
            rx = w
            ry = y
            gx = cx + (rx * cos_a - ry * sin_a)
            gy = cy + (rx * sin_a + ry * cos_a)
            pts.append((gx, gy))
            
        for i in range(n_steps - 1, -1, -1):
            t = i / (n_steps - 1)
            y = t * length
            width_envelope = math.sin(t * math.pi) * (length * 0.42)
            lobes = math.sin(t * math.pi * 5.0) * (length * 0.12)
            w = max(0.0, width_envelope + lobes)
            
            # Left side
            lx = -w
            ly = y
            gx = cx + (lx * cos_a - ly * sin_a)
            gy = cy + (lx * sin_a + ly * cos_a)
            pts.append((gx, gy))
            
        leaf_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        ldraw = ImageDraw.Draw(leaf_img)
        ldraw.polygon(pts, fill=leaf_col)
        
        # Central midrib
        tip_x = cx - length * sin_a
        tip_y = cy + length * cos_a
        ldraw.line([(cx, cy), (tip_x, tip_y)], fill=(min(255, leaf_col[0] + 30), min(255, leaf_col[1] + 35), leaf_col[2] + 10, 255), width=3)
        
        return leaf_img

    # Composite multiple overlapping oak leaves in natural branch cluster
    np.random.seed(42)
    clusters = [
        (320, 450, 220, -135), (380, 400, 240, -110), (260, 480, 200, -160),
        (700, 380, 230, 130), (640, 340, 250, 105), (760, 420, 210, 155),
        (420, 220, 240, -80), (360, 180, 210, -60), (460, 160, 220, -40),
        (620, 180, 240, 75), (680, 150, 220, 60), (580, 130, 210, 35),
        (512, 120, 250, 0), (480, 80, 230, -20), (544, 75, 230, 20),
        (512, 500, 260, -90), (512, 460, 260, 90), (480, 350, 240, -45), (544, 340, 240, 45)
    ]
    
    for cx, cy, l, ang in clusters:
        # Organic green tone variations
        r = int(np.random.uniform(50, 75))
        g = int(np.random.uniform(105, 145))
        b = int(np.random.uniform(25, 45))
        leaf = draw_oak_leaf(cx, cy, l, ang + np.random.uniform(-12, 12), (r, g, b, 255))
        img = Image.alpha_composite(img, leaf)
        
    img.save(os.path.join(OUT_DIR, "foliage_oak.png"), "PNG")
    print("Saved foliage_oak.png")

def generate_birch_texture():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Fine reddish slender weeping twigs
    twigs = [
        ((512, 980), (512, 600), 10),
        ((512, 750), (280, 520), 7),
        ((280, 520), (180, 380), 5),
        ((180, 380), (140, 220), 4),
        ((512, 650), (740, 480), 7),
        ((740, 480), (840, 340), 5),
        ((840, 340), (880, 180), 4),
        ((512, 550), (420, 320), 6),
        ((420, 320), (360, 140), 4),
        ((512, 450), (600, 280), 6),
        ((600, 280), (660, 110), 4),
        ((512, 350), (512, 80), 5)
    ]
    for p0, p1, w in twigs:
        draw.line([p0, p1], fill=(110, 60, 45, 255), width=w)
        
    def draw_birch_leaf(cx, cy, length, angle_deg, leaf_col):
        rad = math.radians(angle_deg)
        cos_a = math.cos(rad)
        sin_a = math.sin(rad)
        
        pts = []
        n_steps = 36
        for i in range(n_steps):
            t = i / (n_steps - 1)
            y = t * length
            # Triangular deltoid birch leaf with serrated edge
            base_w = (1.0 - math.pow(t, 1.4)) * math.sin(math.pow(t, 0.45) * math.pi) * (length * 0.65)
            serration = math.sin(t * math.pi * 12.0) * (length * 0.05)
            w = max(0.0, base_w + serration)
            
            rx, ry = w, y
            gx = cx + (rx * cos_a - ry * sin_a)
            gy = cy + (rx * sin_a + ry * cos_a)
            pts.append((gx, gy))
            
        for i in range(n_steps - 1, -1, -1):
            t = i / (n_steps - 1)
            y = t * length
            base_w = (1.0 - math.pow(t, 1.4)) * math.sin(math.pow(t, 0.45) * math.pi) * (length * 0.65)
            serration = math.sin(t * math.pi * 12.0) * (length * 0.05)
            w = max(0.0, base_w + serration)
            
            lx, ly = -w, y
            gx = cx + (lx * cos_a - ly * sin_a)
            gy = cy + (lx * sin_a + ry * cos_a)
            pts.append((gx, gy))
            
        leaf_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        ldraw = ImageDraw.Draw(leaf_img)
        ldraw.polygon(pts, fill=leaf_col)
        
        # Pale yellow-green vein
        tip_x = cx - length * sin_a
        tip_y = cy + length * cos_a
        ldraw.line([(cx, cy), (tip_x, tip_y)], fill=(min(255, leaf_col[0] + 45), min(255, leaf_col[1] + 35), leaf_col[2] + 20, 255), width=2)
        return leaf_img

    np.random.seed(123)
    # Abundant shimmering small fluttering leaves
    for _ in range(45):
        # Pick point along twig system
        idx = np.random.randint(len(twigs))
        p0, p1, _ = twigs[idx]
        t = np.random.uniform(0.1, 1.0)
        cx = p0[0] + (p1[0] - p0[0]) * t + np.random.uniform(-30, 30)
        cy = p0[1] + (p1[1] - p0[1]) * t + np.random.uniform(-30, 30)
        l = np.random.uniform(110, 160)
        ang = np.random.uniform(-180, 180)
        
        # Bright fluttering golden/lime green tones (Betula pendula)
        r = int(np.random.uniform(95, 135))
        g = int(np.random.uniform(175, 220))
        b = int(np.random.uniform(35, 60))
        leaf = draw_birch_leaf(cx, cy, l, ang, (r, g, b, 255))
        img = Image.alpha_composite(img, leaf)
        
    img.save(os.path.join(OUT_DIR, "foliage_birch.png"), "PNG")
    print("Saved foliage_birch.png")

def generate_eucalyptus_texture():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Central branch leaning with hanging dangling twigs
    twigs = [
        ((512, 100), (512, 380), 10),
        ((512, 300), (320, 520), 8),
        ((320, 520), (220, 780), 5),
        ((512, 340), (700, 540), 8),
        ((700, 540), (800, 800), 5),
        ((512, 380), (450, 680), 6),
        ((450, 680), (410, 920), 4),
        ((512, 380), (580, 690), 6),
        ((580, 690), (620, 930), 4),
    ]
    for p0, p1, w in twigs:
        draw.line([p0, p1], fill=(130, 115, 85, 255), width=w)
        
    def draw_eucalyptus_leaf(cx, cy, length, angle_deg, leaf_col):
        rad = math.radians(angle_deg)
        cos_a = math.cos(rad)
        sin_a = math.sin(rad)
        
        pts = []
        n_steps = 40
        # Long, drooping sickle-shaped lanceolate leaf
        for i in range(n_steps):
            t = i / (n_steps - 1)
            y = t * length
            # Sickle curvature
            curve = math.sin(t * math.pi) * (length * 0.18)
            w = math.sin(t * math.pi) * (length * 0.16)
            
            rx, ry = curve + w, y
            gx = cx + (rx * cos_a - ry * sin_a)
            gy = cy + (rx * sin_a + ry * cos_a)
            pts.append((gx, gy))
            
        for i in range(n_steps - 1, -1, -1):
            t = i / (n_steps - 1)
            y = t * length
            curve = math.sin(t * math.pi) * (length * 0.18)
            w = math.sin(t * math.pi) * (length * 0.16)
            
            lx, ly = curve - w, y
            gx = cx + (lx * cos_a - ly * sin_a)
            gy = cy + (lx * sin_a + ry * cos_a)
            pts.append((gx, gy))
            
        leaf_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        ldraw = ImageDraw.Draw(leaf_img)
        ldraw.polygon(pts, fill=leaf_col)
        
        # Central pale midrib
        mid_pts = []
        for i in range(0, n_steps, 3):
            t = i / (n_steps - 1)
            y = t * length
            curve = math.sin(t * math.pi) * (length * 0.18)
            gx = cx + (curve * cos_a - y * sin_a)
            gy = cy + (curve * sin_a + y * cos_a)
            mid_pts.append((gx, gy))
        ldraw.line(mid_pts, fill=(min(255, leaf_col[0] + 35), min(255, leaf_col[1] + 35), min(255, leaf_col[2] + 30), 255), width=2)
        return leaf_img

    np.random.seed(789)
    # Elegant drooping leaves hanging downwards
    for _ in range(36):
        idx = np.random.randint(len(twigs))
        p0, p1, _ = twigs[idx]
        t = np.random.uniform(0.15, 1.0)
        cx = p0[0] + (p1[0] - p0[0]) * t + np.random.uniform(-25, 25)
        cy = p0[1] + (p1[1] - p0[1]) * t + np.random.uniform(-25, 25)
        l = np.random.uniform(200, 320)
        # Drooping downwards (pointing down with slight sway)
        ang = np.random.uniform(160, 200)
        
        # Glaucous blue-green / olive eucalyptus tones
        r = int(np.random.uniform(70, 95))
        g = int(np.random.uniform(120, 150))
        b = int(np.random.uniform(90, 115))
        leaf = draw_eucalyptus_leaf(cx, cy, l, ang, (r, g, b, 255))
        img = Image.alpha_composite(img, leaf)
        
    img.save(os.path.join(OUT_DIR, "foliage_eucalyptus.png"), "PNG")
    print("Saved foliage_eucalyptus.png")

def generate_pine_texture():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Woody branch base
    draw.line([(512, 980), (512, 550)], fill=(85, 55, 38, 255), width=18)
    draw.line([(512, 700), (300, 520)], fill=(85, 55, 38, 255), width=12)
    draw.line([(512, 680), (720, 500)], fill=(85, 55, 38, 255), width=12)
    draw.line([(512, 550), (420, 380)], fill=(85, 55, 38, 255), width=10)
    draw.line([(512, 550), (600, 360)], fill=(85, 55, 38, 255), width=10)
    draw.line([(512, 450), (512, 280)], fill=(85, 55, 38, 255), width=9)
    
    # Draw tufts of long paired needles (Pinus pinea stone pine)
    centers = [
        (300, 520), (720, 500), (420, 380), (600, 360), (512, 280),
        (220, 420), (800, 410), (350, 260), (670, 240), (512, 160)
    ]
    
    np.random.seed(333)
    for cx, cy in centers:
        # Needle cluster radial spray
        n_needles = 55
        for _ in range(n_needles):
            ang = np.random.uniform(-170, -10) # Fanning upward and outward
            rad = math.radians(ang)
            n_len = np.random.uniform(160, 260)
            
            ex = cx + math.cos(rad) * n_len
            ey = cy + math.sin(rad) * n_len
            
            r = int(np.random.uniform(40, 65))
            g = int(np.random.uniform(85, 125))
            b = int(np.random.uniform(30, 50))
            
            draw.line([(cx, cy), (ex, ey)], fill=(r, g, b, 255), width=int(np.random.choice([3, 4])))
            
        # Basal sheath (fascicle)
        draw.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=(70, 45, 30, 255))
        
    img.save(os.path.join(OUT_DIR, "foliage_pine.png"), "PNG")
    print("Saved foliage_pine.png")

def generate_fir_texture():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Central and lateral woody twigs of evergreen fir spray
    twigs = [
        ((512, 980), (512, 200), 14),
        ((512, 750), (250, 520), 9),
        ((512, 700), (774, 480), 9),
        ((512, 550), (320, 350), 7),
        ((512, 500), (700, 320), 7),
        ((512, 380), (380, 220), 6),
        ((512, 340), (640, 200), 6),
        ((512, 250), (512, 80), 5)
    ]
    for p0, p1, w in twigs:
        draw.line([p0, p1], fill=(68, 48, 32, 255), width=w)
        
    np.random.seed(999)
    # Dense comb-like rows of flat fir needles along all twigs
    for p0, p1, _ in twigs:
        dx = p1[0] - p0[0]
        dy = p1[1] - p0[1]
        length = math.hypot(dx, dy)
        steps = int(length / 7.0)
        ux = dx / max(1.0, length)
        uy = dy / max(1.0, length)
        
        # Perpendicular normal
        nx = -uy
        ny = ux
        
        for s in range(steps):
            t = float(s) / max(1.0, float(steps))
            bx = p0[0] + dx * t
            by = p0[1] + dy * t
            
            # Needles on both sides (left and right comb)
            for side in [-1.0, 1.0]:
                n_len = np.random.uniform(45.0, 75.0)
                # Angle slightly forward
                fwd_skew = 0.35
                ex = bx + (nx * side + ux * fwd_skew) * n_len
                ey = by + (ny * side + uy * fwd_skew) * n_len
                
                # Dark rich forest green
                r = int(np.random.uniform(26, 45))
                g = int(np.random.uniform(65, 95))
                b = int(np.random.uniform(24, 42))
                draw.line([(bx, by), (ex, ey)], fill=(r, g, b, 255), width=int(np.random.choice([3, 4])))
                
    img.save(os.path.join(OUT_DIR, "foliage_fir.png"), "PNG")
    print("Saved foliage_fir.png")

if __name__ == "__main__":
    generate_oak_texture()
    generate_birch_texture()
    generate_eucalyptus_texture()
    generate_pine_texture()
    generate_fir_texture()
    print("All 5 botanical foliage textures generated successfully!")
