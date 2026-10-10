"""Builds the Play Store art from raw device screenshots, in the Codex style.

    python tools/make_store_art.py [store/raw]

Reads <raw>/phone/*.png (a 1080-wide phone) and <raw>/tablet/*.png (the Tab A9,
800 wide), taken with `adb exec-out screencap -p`, and writes:
  store/screenshots/phone/NN.png   1080x2160 (Play's 2:1 limit)
  store/screenshots/tablet-7in/NN.png   1080x1920 (9:16, as Play's 7-inch and
  store/screenshots/tablet-10in/NN.png  10-inch tablet slots both require)
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
    ("01_title.png", "Carry the sun", "Through the Maya underworld, one night at a time."),
    ("02_leap.png", "Swipe, leap, slide", "Three lanes. One wrong move ends the night."),
    ("03_flare.png", "Tap to flare", "Light the road ahead. Jaguars turn to stone."),
    ("04_pack.png", "The pack is behind you", "Let your light die and they catch you."),
    ("05_fire.png", "Six Houses of Xibalba", "Gloom, Knives, Cold, Jaguars, Bats and Fire."),
    ("06_dawn.png", "Make it to dawn", "Then the next night begins."),
    ("07_shop.png", "Choose your runner", "Runners, outfits, hats and stones."),
    ("08_glyphs.png", "Earn twenty-four glyphs", "Every one drawn like a scribe's sign."),
]
SIZES = {"phone": (1080, 2160, 330), "tablet": (1080, 1920, 320)} # width, height, caption band
# Where each set goes: Play wants tablet shots in two slots (7- and 10-inch),
# both 9:16; one 1080x1920 set meets both rules.
DESTS = {"phone": ["phone"], "tablet": ["tablet-7in", "tablet-10in"]}


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


def feature(raw_run):
    W, H = 1024, 500
    img = gradient(W, H)
    shot = Image.open(raw_run).convert("RGB")
    # A slice of a run on the right: the Sunstone's painted circle in the night.
    # Scale so the 470 px slot is filled edge to edge, then take the runner's band.
    scale = 470 / (shot.width * 0.62)
    s = shot.resize((int(shot.width * scale), int(shot.height * scale)), Image.LANCZOS)
    left = (s.width - 470) // 2
    top = min(int(s.height * 0.36), s.height - H)
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
        for i, (name, caption, line) in enumerate(SHOTS, 1):
            img = screenshot(os.path.join(src, name), caption, line, kind)
            for folder in DESTS[kind]:
                dst = os.path.join(OUT, "screenshots", folder)
                os.makedirs(dst, exist_ok=True)
                img.save(os.path.join(dst, "%02d.png" % i))
    feature(os.path.join(raw_dir, "phone", "03_flare.png")).save(os.path.join(OUT, "feature-graphic.png"))
    print("store art written to", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
