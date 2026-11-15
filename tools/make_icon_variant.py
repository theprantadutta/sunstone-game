"""Icon variant B for a Play store listing experiment (the shipped icon is A,
drawn by make_icon.py; this script never touches assets/).

    python tools/make_icon_variant.py

B: the k'in sun glyph, big and in thick ink, burning in its painted light
circle (with the freehand cinnabar rim from the game) on the night of
Xibalba. One shape, high contrast, readable at 48 px. Drawn at 2x and
downsampled. Writes store/experiments/icon-b-512.png (full-bleed square;
Play rounds the corners itself).
"""
import math
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "store", "experiments", "icon-b-512.png")

INK = (27, 20, 16)
STUCCO = (239, 227, 200)
CINNABAR = (184, 50, 42)
OCHRE = (227, 168, 47)
OCHRE_LIGHT = (255, 214, 110)
NIGHT = (11, 14, 36)
NIGHT_BLUE = (24, 34, 92)
MAYA_BLUE = (63, 167, 181)

S = 1024  # drawn at 2x
C = S / 2


def lerp(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def night():
    """Deep blue night, a little lighter toward the middle."""
    img = Image.new("RGB", (S, S))
    px = img.load()
    for y in range(S):
        for x in range(S):
            r = math.hypot(x - C, y - C) / (S * 0.72)
            px[x, y] = lerp(NIGHT_BLUE, NIGHT, r)
    return img


def wobbly_circle(cx, cy, r, amp, seed, n=180):
    rnd = random.Random(seed)
    phases = [rnd.uniform(0, math.tau) for _ in range(3)]
    pts = []
    for i in range(n):
        a = math.tau * i / n
        w = (math.sin(a * 5 + phases[0]) * 0.5 + math.sin(a * 9 + phases[1]) * 0.3
             + math.sin(a * 14 + phases[2]) * 0.2)
        rr = r + w * amp
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return pts


def main():
    img = night().convert("RGBA")

    # The painted light circle: warm stucco glow, freehand cinnabar rim.
    light = Image.new("RGB", (S, S))
    lp = light.load()
    for y in range(S):
        for x in range(S):
            lp[x, y] = lerp(OCHRE_LIGHT, STUCCO, math.hypot(x - C, y - C) / (S * 0.43))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).polygon(wobbly_circle(C, C, S * 0.43, S * 0.012, 7), fill=255)
    img.paste(light.convert("RGBA"), (0, 0), mask)
    d = ImageDraw.Draw(img)
    rim = wobbly_circle(C, C, S * 0.43, S * 0.012, 7)
    d.line(rim + [rim[0]], fill=CINNABAR, width=int(S * 0.028), joint="curve")

    # Rays: 8 cinnabar blades with ink outlines, between the disc and the rim.
    ri, ro = S * 0.25, S * 0.405
    for k in range(8):
        a = math.tau * k / 8 - math.pi / 2
        hw = 0.2
        p = [(C + math.cos(a - hw) * ri, C + math.sin(a - hw) * ri),
             (C + math.cos(a) * ro, C + math.sin(a) * ro),
             (C + math.cos(a + hw) * ri, C + math.sin(a + hw) * ri)]
        d.polygon(p, fill=CINNABAR, outline=INK, width=int(S * 0.018))

    # The k'in glyph: ochre disc, four petals, a stucco eye; thick ink.
    r = S * 0.265
    lw = int(S * 0.03)
    d.ellipse((C - r, C - r, C + r, C + r), fill=OCHRE, outline=INK, width=lw)
    pr = r * 0.36
    off = r * 0.42
    for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0)):
        x, y = C + dx * off, C + dy * off
        d.ellipse((x - pr, y - pr, x + pr, y + pr), fill=STUCCO, outline=INK, width=int(lw * 0.75))
    e = r * 0.2
    d.ellipse((C - e, C - e, C + e, C + e), fill=CINNABAR, outline=INK, width=int(lw * 0.75))

    out = img.convert("RGBA").resize((512, 512), Image.LANCZOS)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
