import os
import numpy as np
from PIL import Image, ImageFilter, ImageOps

BASE_DIR = r"c:\Proyectos\Dragon v2"
OUT_DIR = os.path.join(BASE_DIR, "assets", "environment", "bark")
os.makedirs(OUT_DIR, exist_ok=True)

USER_DIR = r"C:\Users\Lucas Marsiglia\.gemini\antigravity\brain\a53d2dc3-e34f-480b-b77b-efaadb2bef9c\.user_uploaded"

# Definitions of crops for each reference photo to capture optimal bark sections:
BARK_CONFIGS = [
    {
        "name": "eucalyptus",
        "file": "media_1791317855197.png",
        # Trunk area is in x: [250, 545], y: [100, 550]
        "crop_box": (255, 60, 545, 545),
        "target_size": (1024, 1024),
        "description": "Eucalyptus peeling ribbons with smooth cream under-bark",
        "normal_strength": 3.2,
        "roughness_base": 0.88,
        "roughness_invert": False
    },
    {
        "name": "birch",
        "file": "media_1791317862970.png",
        # Birch trunk is in x: [55, 320], y: [10, 475]
        "crop_box": (55, 20, 320, 470),
        "target_size": (1024, 1024),
        "description": "White birch bark with eye-shaped scars and horizontal lenticels",
        "normal_strength": 2.4,
        "roughness_base": 0.72,
        "roughness_invert": False
    },
    {
        "name": "oak",
        "file": "media_1791317882485.png",
        # Center trunk with deep furrowed bark
        "crop_box": (110, 10, 480, 380),
        "target_size": (1024, 1024),
        "description": "Deep furrowed ancient oak bark with heavy ridges",
        "normal_strength": 4.0,
        "roughness_base": 0.94,
        "roughness_invert": False
    },
    {
        "name": "pine_plates",
        "file": "media_1791317895832.png",
        # Armored pine plates and orange terracotta cracks
        "crop_box": (15, 10, 725, 390),
        "target_size": (1024, 1024),
        "description": "Armored pine plates with terracotta under-cracks",
        "normal_strength": 3.8,
        "roughness_base": 0.90,
        "roughness_invert": False
    },
    {
        "name": "corrugated",
        "file": "media_1791317911850.png",
        # Vertical dense corrugated bark
        "crop_box": (10, 10, 615, 410),
        "target_size": (1024, 1024),
        "description": "Dense vertical corrugated fibrous bark",
        "normal_strength": 3.0,
        "roughness_base": 0.92,
        "roughness_invert": False
    }
]

def make_seamless(img, overlap_ratio=0.18):
    """Blends edges to make texture seamless vertically and horizontally."""
    arr = np.array(img, dtype=np.float32)
    h, w = arr.shape[:2]
    
    # Horizontal blend
    ow = int(w * overlap_ratio)
    for x in range(ow):
        t = x / float(ow)
        # smoothstep blend
        t = t * t * (3.0 - 2.0 * t)
        left = arr[:, x].copy()
        right = arr[:, w - ow + x].copy()
        blended = left * t + right * (1.0 - t)
        arr[:, x] = blended
        arr[:, w - ow + x] = blended

    # Vertical blend
    oh = int(h * overlap_ratio)
    for y in range(oh):
        t = y / float(oh)
        t = t * t * (3.0 - 2.0 * t)
        top = arr[y, :].copy()
        bottom = arr[h - oh + y, :].copy()
        blended = top * t + bottom * (1.0 - t)
        arr[y, :] = blended
        arr[h - oh + y, :] = blended

    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))

def generate_normal_map(gray_img, strength=3.0):
    """Computes Sobel derivative tangent space normal map (Godot OpenGL format)."""
    arr = np.array(gray_img, dtype=np.float32) / 255.0
    h, w = arr.shape
    
    # Sobel kernels
    dx = (np.roll(arr, -1, axis=1) - np.roll(arr, 1, axis=1)) * 0.5
    dy = (np.roll(arr, -1, axis=0) - np.roll(arr, 1, axis=0)) * 0.5
    
    # Invert Y for OpenGL coordinate standard (Godot expects Y+ up)
    nx = -dx * strength * 2.0
    ny = dy * strength * 2.0
    nz = np.ones_like(nx)
    
    norm = np.sqrt(nx**2 + ny**2 + nz**2)
    nx /= norm
    ny /= norm
    nz /= norm
    
    rgb = np.stack([
        (nx * 0.5 + 0.5) * 255.0,
        (ny * 0.5 + 0.5) * 255.0,
        (nz * 0.5 + 0.5) * 255.0
    ], axis=-1)
    
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))

def generate_roughness_map(gray_img, base=0.88, is_birch=False, is_eucalyptus=False):
    """Generates roughness map with variation in cracks and ridges."""
    arr = np.array(gray_img, dtype=np.float32) / 255.0
    
    if is_birch:
        # Birch: white outer surface is smoother/satin (~0.65), dark scars and lenticels are rougher (~0.95)
        roughness = np.clip(1.0 - (arr * 0.35) + 0.15, 0.45, 0.98)
    elif is_eucalyptus:
        # Eucalyptus: exposed cream wood is smoother (~0.62), peeling shreds are very rough (~0.96)
        roughness = np.clip(1.0 - (arr * 0.32) + 0.12, 0.50, 0.98)
    else:
        # General bark: deep fissures are rough and dark, ridge tops slightly more polished
        roughness = np.clip(base + (1.0 - arr) * 0.12 - (arr * 0.08), 0.55, 0.99)
        
    return Image.fromarray((roughness * 255.0).astype(np.uint8))

def generate_ao_map(gray_img):
    """Generates crevice Ambient Occlusion."""
    arr = np.array(gray_img, dtype=np.float32) / 255.0
    blurred = np.array(gray_img.filter(ImageFilter.GaussianBlur(radius=8)), dtype=np.float32) / 255.0
    # Valleys are darker in AO
    ao = np.clip((arr * 0.7 + blurred * 0.3) * 1.25, 0.15, 1.0)
    return Image.fromarray((ao * 255.0).astype(np.uint8))

def process():
    print("Processing bark textures from user reference photos...")
    for cfg in BARK_CONFIGS:
        in_path = os.path.join(USER_DIR, cfg["file"])
        if not os.path.exists(in_path):
            print(f"File not found: {in_path}")
            continue
            
        src = Image.open(in_path).convert("RGB")
        crop = src.crop(cfg["crop_box"])
        resized = crop.resize(cfg["target_size"], Image.Resampling.LANCZOS)
        seamless_albedo = make_seamless(resized)
        
        # Save Albedo
        albedo_path = os.path.join(OUT_DIR, f"bark_{cfg['name']}_diff_2k.png")
        seamless_albedo.save(albedo_path, "PNG", optimize=True)
        print(f"Saved: {albedo_path}")
        
        # Grayscale for height/normal
        gray = seamless_albedo.convert("L")
        
        # Normal map
        normal_map = generate_normal_map(gray, strength=cfg["normal_strength"])
        normal_path = os.path.join(OUT_DIR, f"bark_{cfg['name']}_nor_gl_2k.png")
        normal_map.save(normal_path, "PNG", optimize=True)
        print(f"Saved: {normal_path}")
        
        # Roughness map
        is_birch = (cfg["name"] == "birch")
        is_euc = (cfg["name"] == "eucalyptus")
        rough_map = generate_roughness_map(gray, base=cfg["roughness_base"], is_birch=is_birch, is_eucalyptus=is_euc)
        rough_path = os.path.join(OUT_DIR, f"bark_{cfg['name']}_rough_2k.png")
        rough_map.save(rough_path, "PNG", optimize=True)
        print(f"Saved: {rough_path}")
        
        # Ambient Occlusion map
        ao_map = generate_ao_map(gray)
        ao_path = os.path.join(OUT_DIR, f"bark_{cfg['name']}_ao_2k.png")
        ao_map.save(ao_path, "PNG", optimize=True)
        print(f"Saved: {ao_path}")

    print("All bark texture sets generated successfully!")

if __name__ == "__main__":
    process()
