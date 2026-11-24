"""Builds the Play Store art from raw device screenshots, in the Codex style.

    python tools/make_store_art.py [store/raw]

Reads <raw>/phone/*.png (a 1080-wide phone) and <raw>/tablet/*.png (the Tab A9,
800 wide), taken with `adb exec-out screencap -p`, and writes:
  store/screenshots/phone/NN.png   1080x2160 (Play's 2:1 limit)
  store/screenshots/tablet-7in/NN.png   1080x1920 (9:16, as Play's 7-inch and
  store/screenshots/tablet-10in/NN.png  10-inch tablet slots both require)
  store/feature-graphic.png        1024x500
Raw shots live in store/raw/ (committed, so any machine can rebuild the art).
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
    # Action first: the store feed shows only the first two or three.
    # Nov 2026: 6% of visitors installed, so the chase and the flare (the two
    # things no other temple runner has) lead.
    ("04_pack.png", "Outrun the jaguars", "Let your light die and the pack catches you."),
    ("03_flare.png", "Freeze them to stone", "Tap to flare: your light stops every jaguar."),
    ("02_leap.png", "Swipe. Leap. Slide.", "Three lanes through the Maya temple."),
    ("05_fire.png", "Six deadly Houses", "Gloom, Knives, Cold, Jaguars, Bats and Fire."),
    ("06_dawn.png", "Make it to dawn", "Then the next night runs faster."),
    ("01_title.png", "Carry the sun", "An endless runner, one night at a time."),
    ("07_shop.png", "Choose your runner", "Runners, outfits, hats and stone hues."),
    ("08_glyphs.png", "24 glyphs to earn", "Daily dusk, ranks and gifts every day."),
]
SIZES = {"phone": (1080, 2160, 360), "tablet": (1080, 1920, 340)} # width, height, caption band
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
    centered(bd, caption, fitted(DELA, caption, 104, W - 120), W / 2, band_h * 0.19, INK)
    centered(bd, line, fitted(NUNITO, line, 44, W - 120, 900), W / 2, band_h * 0.62, CINNABAR)
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
    """Play's Explore cards show this small, so: the chase full-bleed, the name big.
    Text stays in the left half and clear of the edges (Play crops and may lay a
    play button over the middle when a video is set)."""
    import math
    W, H = 1024, 500
    shot = Image.open(raw_run).convert("RGB")
    # The run fills the card: the band with the runner and the frozen jaguars,
    # mirrored so they sit on the right, away from the name.
    band_h = int(shot.width * H / W)
    top = int(shot.height * 0.43)
    img = shot.crop((0, top, shot.width, top + band_h)).transpose(Image.FLIP_LEFT_RIGHT)
    img = img.resize((W, H), Image.LANCZOS)
    # Night falls over the left, where the name goes.
    shade = Image.new("L", (W, H))
    sd = ImageDraw.Draw(shade)
    for x in range(W):
        t = max(0.0, min(1.0, (x - 300) / 360))
        sd.line([(x, 0), (x, H)], fill=int(235 * (1 - t * t * (3 - 2 * t))))
    night = Image.new("RGB", (W, H), (14, 12, 34))
    img = Image.composite(night, img, shade)
    d = ImageDraw.Draw(img)
    # The k'in sun, then the name.
    cx, cy, r = 112, 128, 40
    for k in range(20):
        a = 2 * math.pi * k / 20
        d.line([(cx + math.cos(a) * (r + 7), cy + math.sin(a) * (r + 7)),
                (cx + math.cos(a) * (r + 19), cy + math.sin(a) * (r + 19))], fill=OCHRE, width=5)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(239, 227, 200), outline=INK, width=4)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        px, py = cx + math.cos(a) * r * 0.4, cy + math.sin(a) * r * 0.4
        d.ellipse([px - 12, py - 12, px + 12, py + 12], fill=OCHRE, outline=INK, width=3)
    d.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], fill=(255, 227, 160), outline=INK, width=2)
    title = fitted(DELA, "Sunstone", 104, 470)
    d.text((66, 200), "Sunstone", font=title, fill=CINNABAR)
    d.text((60, 194), "Sunstone", font=title, fill=(250, 240, 220))
    sub = fitted(NUNITO, "MAYA TEMPLE RUNNER", 44, 460, 900)
    d.text((64, 330), "MAYA TEMPLE RUNNER", font=sub, fill=OCHRE)
    rule(d, 64, 300, 400, 6)
    tag = fitted(NUNITO, "Outrun the jaguars till dawn", 30, 440, 800)
    d.text((64, 418), "Outrun the jaguars till dawn", font=tag, fill=(239, 227, 200))
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
