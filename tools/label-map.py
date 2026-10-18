# Labels a map rendered by render-continent.luau (step 4, no overlay).
# Usage: python3 tools/label-map.py base.ppm continent-map.png
import sys
from PIL import Image, ImageDraw, ImageFont
img = Image.open(sys.argv[1]).convert("RGB")
img = img.resize((img.width*2, img.height*2), Image.LANCZOS)
d = ImageDraw.Draw(img)
B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
big, small, tiny = ImageFont.truetype(B, 30), ImageFont.truetype(B, 20), ImageFont.truetype(B, 15)
def px(x, z): return ((x + 1680) / 4 * 2, (z + 2120) / 4 * 2)
def text(xy, s, f, fill=(255,255,255)):
    d.text(xy, s, font=f, fill=fill, anchor="mm", stroke_width=4, stroke_fill=(16,22,48))
# name, centre in pixels of the 800x760 map, level colour
regions = [
 ("Dragon's End", "Lv 91-100", (275,100), (255,120,90)),
 ("Starfall Highlands", "Lv 81-90", (175,265), (200,170,255)),
 ("Ashenreach", "Lv 71-80", (370,262), (255,140,60)),
 ("Glacial Expanse", "Lv 61-70", (545,232), (170,225,255)),
 ("Frostpeak Mountains", "Lv 41-50", (590,410), (200,220,240)),
 ("Mirehollow Swamps", "Lv 31-40", (330,372), (150,210,120)),
 ("Sunscar Desert", "Lv 21-30", (205,440), (255,200,110)),
 ("Whisperwood Forest", "Lv 11-20", (175,590), (120,220,140)),
 ("Greenhaven Grasslands", "Lv 1-10", (420,662), (190,255,140)),
 ("Verdantwild Jungle", "Lv 51-60", (640,600), (110,240,160)),
]
# plot outline
x0, z0 = px(-128, -128); x1, z1 = px(128, 128)
d.rectangle([x0, z0, x1, z1], outline=(255,80,60), width=4)
text(((x0+x1)/2, z0-16), "Your build plot", tiny, (255,230,200))
for name, lv, (cx, cy), col in regions:
    text((cx*2, cy*2), name, big)
    text((cx*2, cy*2+30), lv, small, col)
# title + legend
text((img.width/2, 40), "MMO TYCOON  ·  THE CONTINENT", big, (255,215,120))
text((img.width/2, img.height-30), "Levels 1-100 · start in Greenhaven, follow the roads north", small, (220,230,255))
img.save(sys.argv[2])
print(img.size)
