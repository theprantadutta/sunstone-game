"""YouTube thumbnail (1280x720) from the feature graphic, which stays as it is.

The 1024x500 art is scaled to 1280 wide and laid over a blurred copy of itself
that fills the 16:9 frame, its top and bottom edges feathered in.
    python store/video/tools/thumb.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

STORE = Path(__file__).resolve().parents[2]
SRC = STORE / "feature-graphic.png"
OUT = STORE / "video" / "youtube-thumbnail-1280x720.png"
W, H, FEATHER = 1280, 720, 60

src = Image.open(SRC).convert("RGB")
art = src.resize((W, round(src.height * W / src.width)), Image.LANCZOS)  # 1280x625
top = (H - art.height) // 2
base = art.resize((W, H), Image.LANCZOS).filter(ImageFilter.GaussianBlur(60))
mask = Image.new("L", art.size, 255)
md = ImageDraw.Draw(mask)
for i in range(FEATHER):
    a = round(255 * (i / FEATHER) ** 1.4)
    md.line([(0, i), (W, i)], fill=a)
    md.line([(0, art.height - 1 - i), (W, art.height - 1 - i)], fill=a)
base.paste(art, (0, top), mask)
base.save(OUT, optimize=True)
print(OUT, base.size)
