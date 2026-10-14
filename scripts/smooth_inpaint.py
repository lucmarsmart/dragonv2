import shutil
from PIL import Image, ImageFilter

im2 = Image.open("assets/models/dragon_Image_2.png").convert("RGB")
im3 = Image.open("assets/models/dragon_Image_3.png").convert("RGB")

# Apply slight blur only on the boundary of the inpainted regions to make them 100% seamless
def smooth_patch(im, x0, y0, x1, y1):
    crop = im.crop((x0, y0, x1, y1))
    blurred = crop.filter(ImageFilter.GaussianBlur(radius=1.5))
    im.paste(blurred, (x0, y0))

smooth_patch(im2, 580, 855, 635, 915)
smooth_patch(im2, 895, 855, 950, 915)
smooth_patch(im3, 580, 855, 635, 915)
smooth_patch(im3, 895, 855, 950, 915)

im2.save("assets/models/dragon_Image_2.png")
im3.save("assets/models/dragon_Image_3.png")

im2.crop((550, 820, 980, 940)).save("eyes_strip_feathered.png")
print("Seamless blend applied.")
