"""Draws the Sunstone app icon, Android adaptive-icon layers and the boot splash.

    python tools/make_icon.py

The mark: the gold Sunstone rising behind a stepped jade pyramid, cinnabar rays,
on a dusk sky. Drawn at 2x and downsampled for clean edges.
"""
import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")

DUSK_TOP = (70, 40, 92)
DUSK_MID = (200, 96, 122)
DUSK_LOW = (240, 154, 94)
GOLD = (244, 183, 50)
GOLD_DEEP = (185, 128, 26)
GOLD_LIGHT = (255, 230, 150)
CINNABAR = (184, 50, 42)
JADE = (14, 59, 51)
JADE_LIGHT = (28, 90, 78)
MAYA_BLUE = (63, 167, 181)
DUSK = (42, 27, 61)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def sky(size):
    img = Image.new("RGB", (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        c = lerp(DUSK_TOP, DUSK_MID, t / 0.55) if t < 0.55 else lerp(DUSK_MID, DUSK_LOW, (t - 0.55) / 0.45)
        d.line([(0, y), (size, y)], fill=c)
    return img


def mark(d, size, scale=1.0, cy_frac=0.5):
    """Sun + rays + stepped pyramid, centred; [scale] shrinks it into a safe zone."""
    s = size * scale
    cx = size / 2
    cy = size * cy_frac
    sun_y = cy - s * 0.07
    r = s * 0.2
    # Stepped rays.
    for k in range(8):
        a = 2 * math.pi * k / 8 + math.pi / 8
        dx, dy = math.cos(a), math.sin(a)
        px, py = -dy, dx
        def P(dist, side):
            return (cx + dx * dist + px * side, sun_y + dy * dist + py * side)
        w1, w2 = s * 0.05, s * 0.025
        d.polygon([P(r - 4, w1), P(r + s * 0.07, w1), P(r + s * 0.07, w2), P(r + s * 0.13, w2),
                   P(r + s * 0.13, -w2), P(r + s * 0.07, -w2), P(r + s * 0.07, -w1), P(r - 4, -w1)], fill=CINNABAR)
    d.ellipse([cx - r, sun_y - r, cx + r, sun_y + r], fill=GOLD_DEEP)
    ri = r * 0.82
    d.ellipse([cx - ri, sun_y - ri, cx + ri, sun_y + ri], fill=GOLD)
    rc = r * 0.35
    d.polygon([(cx, sun_y - rc), (cx + rc, sun_y), (cx, sun_y + rc), (cx - rc, sun_y)], fill=GOLD_LIGHT)
    # Stepped pyramid rising over the lower half of the sun.
    base_y = cy + s * 0.36
    tiers = 4
    tier_h = s * 0.085
    for i in range(tiers):
        w = s * (0.78 - i * 0.15)
        top = base_y - (i + 1) * tier_h
        d.rectangle([cx - w / 2, top, cx + w / 2, top + tier_h + 1], fill=JADE if i % 2 == 0 else JADE_LIGHT)
        if i == 1:
            d.rectangle([cx - w / 2, top + tier_h * 0.38, cx + w / 2, top + tier_h * 0.58], fill=MAYA_BLUE)
    # A glowing doorway — the Sunstone's resting place.
    dw = s * 0.1
    d.rectangle([cx - dw / 2, base_y - tier_h * 1.7, cx + dw / 2, base_y], fill=GOLD)


def render(size, background=True, scale=1.0, cy_frac=0.5):
    big = size * 2
    img = sky(big) if background else Image.new("RGBA", (big, big), (0, 0, 0, 0))
    mark(ImageDraw.Draw(img), big, scale, cy_frac)
    return img.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    render(1024).save(os.path.join(OUT, "icon.png"))
    render(192).save(os.path.join(OUT, "icon_192.png"))
    # The Play Store's own icon: 512x512, 32-bit PNG, full square (Play rounds it).
    render(1024).convert("RGBA").resize((512, 512), Image.LANCZOS).save(
        os.path.join(os.path.dirname(__file__), "..", "store", "icon-512.png"), optimize=True)
    # Adaptive icon: the mark inside the 66% safe zone, sky as its own layer.
    render(432, background=False, scale=0.62).save(os.path.join(OUT, "adaptive_foreground.png"))
    sky(432).save(os.path.join(OUT, "adaptive_background.png"))
    # Boot splash: the mark alone on dusk violet.
    splash = Image.new("RGB", (1024, 1024), DUSK)
    fg = render(1024, background=False, scale=0.7)
    splash.paste(fg, (0, 0), fg)
    splash.save(os.path.join(OUT, "splash.png"))
    print("icons written to", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
