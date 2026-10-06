"""Original deterministic foliage alpha masks. Requires Pillow; runtime ships PNGs."""
from pathlib import Path
import math
import random
from PIL import Image, ImageDraw

OUTPUT = Path(__file__).resolve().parent.parent / 'assets' / 'environment'
OUTPUT.mkdir(parents=True, exist_ok=True)
random.seed(55122)
image = Image.new('RGBA', (512, 512), (0, 0, 0, 0))
draw = ImageDraw.Draw(image)
for stem in range(11):
    sx, sy = 256, 490
    ex = 256 + (stem - 5) * 37 + random.uniform(-14, 14)
    ey = 28 + abs(stem - 5) * 39 + random.uniform(-14, 15)
    draw.line((sx, sy, ex, ey), fill=(59, 74, 37, 255), width=3)
    dx, dy = ex - sx, ey - sy
    length = math.hypot(dx, dy)
    nx, ny = -dy / length, dx / length
    for j in range(8, 70):
        t = j / 72
        px, py = sx + dx * t, sy + dy * t
        for side in [-1, 1]:
            needle = random.uniform(12, 27) * (1 - t * .45)
            qx = px + nx * needle * side + dx / length * needle * .45
            qy = py + ny * needle * side + dy / length * needle * .45
            color = (random.randint(41, 80), random.randint(77, 131), random.randint(35, 68), 255)
            draw.line((px, py, qx, qy), fill=color, width=random.choice([1, 2, 2, 3]))
image.save(OUTPUT / 'pine_needles.png')
random.seed(2207)
image = Image.new('RGBA', (512, 512), (0, 0, 0, 0))
draw = ImageDraw.Draw(image)
for i in range(45):
    sx, sy = random.uniform(130, 380), 510
    ex, ey = sx + random.uniform(-180, 180), random.uniform(35, 330)
    mid = (sx * .7 + ex * .3, sy * .5 + ey * .5)
    width = random.uniform(2, 6)
    polygon = []
    for direction in [-1, 1]:
        steps = range(16) if direction == -1 else range(15, -1, -1)
        for j in steps:
            t = j / 15
            px = (1-t)**2 * sx + 2 * (1-t) * t * mid[0] + t*t*ex
            py = (1-t)**2 * sy + 2 * (1-t) * t * mid[1] + t*t*ey
            polygon.append((px + direction * width * (1-t), py))
    draw.polygon(polygon, fill=(random.randint(65, 105), random.randint(90, 130), random.randint(24, 49), 255))
image.save(OUTPUT / 'meadow_blades.png')
