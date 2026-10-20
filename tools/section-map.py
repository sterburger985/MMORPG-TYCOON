"""Draw the labelled section map.

Usage:
  lune run tools/render-continent.luau <world.rbxl> base.ppm 4 none sections.json
  python3 tools/section-map.py base.ppm sections.json out.png
"""
import json, sys
from PIL import Image, ImageDraw, ImageFont

base, data, out = sys.argv[1], json.load(open(sys.argv[2])), sys.argv[3]
SCALE = 2  # output pixels per base pixel (base is 4 studs per pixel)
img = Image.open(base).convert("RGB")
img = img.resize((img.width * SCALE, img.height * SCALE), Image.LANCZOS)
W, H, G = data["W"], data["H"], data["G"]
ids = data["ids"]
studs_per_px = 4 / SCALE
minX, minZ = data["minX"], data["minZ"]

def px(x, z):
    return ((x - minX) / studs_per_px, (z - minZ) / studs_per_px)

def is_sea(c):
    return c[2] > c[0] + 50 and c[2] > c[1] + 10

pix = img.load()
# subtle alternating tint so neighbouring sections read as separate pieces
tint = Image.new("RGBA", img.size, (0, 0, 0, 0))
tp = tint.load()
cell = G / studs_per_px
for k in range(H):
    for i in range(W):
        sid = ids[k * W + i]
        if sid == 0:
            continue
        shade = 22 if (sid * 7919) % 3 == 0 else (0 if (sid * 7919) % 3 == 1 else -18)
        x0, y0 = int(i * cell), int(k * cell)
        for yy in range(y0, min(y0 + int(cell), img.height)):
            for xx in range(x0, min(x0 + int(cell), img.width)):
                if not is_sea(pix[xx, yy]):
                    a = abs(shade)
                    tp[xx, yy] = (255, 255, 255, a) if shade > 0 else (0, 0, 0, a)
img = Image.alpha_composite(img.convert("RGBA"), tint).convert("RGB")
pix = img.load()
d = ImageDraw.Draw(img)
# borders
for k in range(H - 1):
    for i in range(W - 1):
        a = ids[k * W + i]
        for (di, dk) in ((1, 0), (0, 1)):
            b = ids[(k + dk) * W + i + di]
            if a and b and a != b:
                x, y = (i + di * 0.5) * cell + cell / 2, (k + dk * 0.5) * cell + cell / 2
                if 0 <= x < img.width and 0 <= y < img.height and not is_sea(pix[int(x), int(y)]):
                    d.ellipse([x - 1.6, y - 1.6, x + 1.6, y + 1.6], fill=(255, 238, 190))
B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
f_sec, f_reg, f_title = ImageFont.truetype(B, 13), ImageFont.truetype(B, 22), ImageFont.truetype(B, 30)
def text(xy, s, f, fill=(255, 255, 255), stroke=3):
    d.text(xy, s, font=f, fill=fill, anchor="mm", stroke_width=stroke, stroke_fill=(16, 22, 48))
for g in data["gates"]:
    x, y = px(*g)
    d.ellipse([x - 5, y - 5, x + 5, y + 5], fill=(255, 196, 60), outline=(60, 30, 0), width=2)
for t in data["trails"]:
    x, y = px(*t)
    d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(120, 230, 255), outline=(0, 40, 70), width=2)
x0, z0 = px(-128, -128); x1, z1 = px(128, 128)
d.rectangle([x0, z0, x1, z1], outline=(255, 80, 60), width=3)
for s in data["sections"]:
    x, y = px(s["x"], s["z"])
    text((x, y), s["name"], f_sec)
text((img.width / 2, 36), "MMO TYCOON  ·  BUILDABLE SECTIONS", f_title, (255, 215, 120))
text((img.width / 2, img.height - 46), "%d sections  ·  gold dots: road gateways  ·  blue dots: trail entrances  ·  red box: your build plot" % len(data["sections"]), f_reg, (220, 230, 255))
img.save(out)
print(img.size)
