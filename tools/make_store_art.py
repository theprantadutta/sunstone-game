"""Builds the Play Store art from raw device screenshots, in the Codex style.

    python tools/make_store_art.py [store/raw]

Reads <raw>/phone/*.png (a 1080-wide phone) and <raw>/tablet/*.png (the Tab A9,
800 wide), taken with `adb exec-out screencap -p`, and writes:
  store/screenshots/phone/NN.png   1080x2160 (Play's 2:1 limit)
  store/screenshots/tablet/NN.png  1080x1728 (fits Play's 7- and 10-inch slots;
                                   the tablet screen stays at native size)
  store/feature-graphic.png        1024x500
Raw shots live in store/raw/ (gitignored).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "store")
DELA = os.path.join(ROOT, "assets", "fonts", "DelaGothicOne-Regular.ttf")
NUNITO = os.path.join(ROOT, "assets", "fonts", "Nunito-Variable.ttf")
PAPER = os.path.join(ROOT, "assets", "ui", "paper.png")

INK = (27, 20, 16)
CINNABAR = (184, 50, 42)
OCHRE = (227, 168, 47)
DUSK_TOP = (42, 27, 61)
DUSK_LOW = (240, 154, 94)

# (raw file, caption, small line) — in store order (Play shows up to 8).
SHOTS = [
    ("02_sunset.png", "Run into the night", "The sun sets on every run."),
    ("03b_chase.png", "Outrun the jaguars", "Stone guardians that move in the dark."),
    ("03d_flare.png", "Tap to flare", "Turn the jaguars back to stone."),
    ("03_night.png", "Keep the Sunstone lit", "Your only light on the causeway."),
    ("01_title.png", "Steal the Sunstone", "A painted Maya temple at dusk."),
    ("05_ranks.png", "Race the world", "Ranks for the daily dusk, the week, all time."),
    ("06_glyphs.png", "Earn twenty glyphs", "Every one drawn like a scribe's sign."),
    ("07_market_garbs.png", "Dress your explorer", "Charms, garbs and hues for sun-drops."),
]
SIZES = {"phone": (1080, 2160, 330), "tablet": (1080, 1728, 300)} # width, height, caption band


def paper(w, h):
    tile = Image.open(PAPER).convert("RGB")
    img = Image.new("RGB", (w, h))
    for y in range(0, h, tile.height):
        for x in range(0, w, tile.width):
            img.paste(tile, (x, y))
    return img


def gradient(w, h):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / (h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(DUSK_TOP[i] + (DUSK_LOW[i] - DUSK_TOP[i]) * t) for i in range(3)))
    return img


def rule(d, x0, x1, y, width=6):
    d.line([(x0, y), (x1, y)], fill=CINNABAR, width=width)


def fitted(path, text, size, width, weight=None):
    """The font at [size], shrunk until [text] fits in [width]."""
    while True:
        f = ImageFont.truetype(path, size)
        if weight:
            f.set_variation_by_axes([weight])
        if ImageDraw.Draw(Image.new("RGB", (1, 1))).textlength(text, font=f) <= width or size <= 20:
            return f
        size -= 2


def centered(d, text, font, cx, y, fill):
    w = d.textlength(text, font=font)
    d.text((cx - w / 2, y), text, font=font, fill=fill)


def screenshot(raw, caption, line, kind="phone"):
    W, H, band_h = SIZES[kind]
    canvas = gradient(W, H)
    band = paper(W, band_h)
    bd = ImageDraw.Draw(band)
    rule(bd, 60, W - 60, 36)
    rule(bd, 60, W - 60, band_h - 36)
    centered(bd, caption, fitted(DELA, caption, 78, W - 140), W / 2, band_h * 0.236, INK)
    centered(bd, line, fitted(NUNITO, line, 40, W - 140, 900), W / 2, band_h * 0.594, CINNABAR)
    canvas.paste(band, (0, 0))
    shot = Image.open(raw).convert("RGB")
    # Fit the phone screen below the band, with an ink frame.
    avail_h = H - band_h - 70
    scale = avail_h / shot.height
    sw, sh = int(shot.width * scale), int(shot.height * scale)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    x, y = (W - sw) // 2, band_h + 36
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle([x - 12, y - 12, x + sw + 12, y + sh + 12], radius=28, fill=INK)
    canvas.paste(shot, (x, y))
    return canvas


def feature(raw_sunset):
    W, H = 1024, 500
    img = gradient(W, H)
    shot = Image.open(raw_sunset).convert("RGB")
    # A slice of the sunset run on the right.
    # Scale so the 470 px slot is filled edge to edge, then take the runner's band.
    scale = 470 / (shot.width * 0.62)
    s = shot.resize((int(shot.width * scale), int(shot.height * scale)), Image.LANCZOS)
    left = (s.width - 470) // 2
    top = min(int(s.height * 0.32), s.height - H)
    crop = s.crop((left, top, left + 470, top + H))
    img.paste(crop, (W - 470, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([W - 476, 0, W - 470, H], fill=INK)
    # The title on a strip of codex paper.
    strip = paper(520, 250)
    sd = ImageDraw.Draw(strip)
    rule(sd, 20, 500, 18, 5)
    rule(sd, 20, 500, 232, 5)
    centered(sd, "Sunstone", ImageFont.truetype(DELA, 74), 264, 44, CINNABAR)
    centered(sd, "Sunstone", ImageFont.truetype(DELA, 74), 260, 40, INK)
    sub = ImageFont.truetype(NUNITO, 40)
    sub.set_variation_by_axes([900])
    centered(sd, "Dusk Run", sub, 260, 160, CINNABAR)
    img.paste(strip, (34, 160))
    # The k'in sun above it.
    cx, cy, r = 294, 92, 52
    for k in range(20):
        import math
        a = 2 * math.pi * k / 20
        d.line([(cx + math.cos(a) * (r + 8), cy + math.sin(a) * (r + 8)),
                (cx + math.cos(a) * (r + 22), cy + math.sin(a) * (r + 22))], fill=OCHRE, width=5)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(239, 227, 200), outline=INK, width=4)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        px, py = cx + math.cos(a) * r * 0.4, cy + math.sin(a) * r * 0.4
        d.ellipse([px - 16, py - 16, px + 16, py + 16], fill=OCHRE, outline=INK, width=3)
    d.ellipse([cx - 9, cy - 9, cx + 9, cy + 9], fill=(255, 227, 160), outline=INK, width=3)
    return img


def main():
    raw_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(OUT, "raw")
    for kind in SIZES:
        src = os.path.join(raw_dir, kind)
        if not os.path.isdir(src):
            continue
        dst = os.path.join(OUT, "screenshots", kind)
        os.makedirs(dst, exist_ok=True)
        for i, (name, caption, line) in enumerate(SHOTS, 1):
            screenshot(os.path.join(src, name), caption, line, kind).save(os.path.join(dst, "%02d.png" % i))
    feature(os.path.join(raw_dir, "phone", "02_sunset.png")).save(os.path.join(OUT, "feature-graphic.png"))
    print("store art written to", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
