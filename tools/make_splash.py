"""The boot splash: the k'in sun glyph from the title wordmark, alone and
centred on a transparent 1024 px canvas (the plum around it is the boot
splash's bg_color). The game takes this same image over when it starts and
flies it up into the wordmark (GameUI.Splash), so its proportions follow
UiKit.Wordmark: disc radius r, count marks from r + 8 to r + 22, and ink
widths scaled from the wordmark's r = 58.

It also writes the Android splash icon (android-res/, copied into the Gradle
build by addons/sunstone_google_signin at export): the same glyph, centred in
Android 12's 288 dp icon box (1152 px, 4 px per dp), drawn at the size the boot
splash will show it, so the handover from the system splash to Godot's doesn't
jump. The boot splash scales with the screen's width (stretch "keep"), Android's
icon with dp, so there's one icon per width class: the glyph's outer radius is
about 0.212 x the screen's width in dp (360-399 dp phones: 80 dp; 400-599: 91;
tablets: 94, the most Android's 96 dp icon circle allows).

Run from the repo root: python tools/make_splash.py
"""
import math
from PIL import Image, ImageDraw

INK = (27, 20, 16, 255)
STUCCO = (239, 227, 200, 255)
OCHRE = (227, 168, 47, 255)
OCHRE_LIGHT = (255, 227, 160, 255)

N = 1024
R = 150.0  # disc radius; GameUI.Splash.GLYPH_R must match R / N
K = R / 58.0  # scale from the wordmark's glyph
SS = 4  # supersampling


def ellipse_pts(cx, cy, rx, ry, ang, seg=64):
    pts = []
    for i in range(seg):
        t = math.tau * i / seg
        x, y = math.cos(t) * rx, math.sin(t) * ry
        pts.append((cx + x * math.cos(ang) - y * math.sin(ang), cy + x * math.sin(ang) + y * math.cos(ang)))
    return pts


def line(d, a, b, width, col):
    d.line([a, b], fill=col, width=int(round(width)))
    for p in (a, b):
        d.ellipse([p[0] - width / 2, p[1] - width / 2, p[0] + width / 2, p[1] + width / 2], fill=col)


def draw(n, R):
    K = R / 58.0
    s = SS
    img = Image.new("RGBA", (n * s, n * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = (n * s / 2, n * s / 2)
    r = R * s
    k = K * s
    # Twenty count marks: ink with an ochre core.
    for i in range(20):
        a = math.tau * i / 20 - math.pi / 2
        u = (math.cos(a), math.sin(a))
        line(d, (c[0] + u[0] * (r + 8 * k), c[1] + u[1] * (r + 8 * k)), (c[0] + u[0] * (r + 22 * k), c[1] + u[1] * (r + 22 * k)), 8 * k, INK)
        line(d, (c[0] + u[0] * (r + 9 * k), c[1] + u[1] * (r + 9 * k)), (c[0] + u[0] * (r + 21 * k), c[1] + u[1] * (r + 21 * k)), 4 * k, OCHRE)
    # The cartouche, its petals and hub.
    d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=STUCCO, outline=INK, width=int(4 * k))
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        pc = (c[0] + math.cos(a) * r * 0.38, c[1] + math.sin(a) * r * 0.38)
        pts = ellipse_pts(pc[0], pc[1], r * 0.36, r * 0.22, a)
        d.polygon(pts, fill=OCHRE, outline=INK, width=int(3 * k))
    hub = r * 0.17
    d.ellipse([c[0] - hub, c[1] - hub, c[0] + hub, c[1] + hub], fill=tuple(int(OCHRE_LIGHT[i] * 0.6 + OCHRE[i] * 0.4) for i in range(3)) + (255,), outline=INK, width=int(3 * k))
    return img.resize((n, n), Image.LANCZOS)


OUTER = 1.0 + 26.0 / 58.0  # outer edge of the count marks (with their round caps), in disc radii
ANDROID = {"drawable-nodpi": 80.0, "drawable-sw400dp-nodpi": 91.0, "drawable-sw600dp-nodpi": 94.0}


def main():
    import os
    draw(N, R).save("assets/icon/splash.png")
    print("wrote assets/icon/splash.png")
    for folder, outer_dp in ANDROID.items():
        os.makedirs(f"android-res/{folder}", exist_ok=True)
        draw(1152, outer_dp * 4.0 / OUTER).save(f"android-res/{folder}/sunstone_splash.png")
        print(f"wrote android-res/{folder}/sunstone_splash.png")


if __name__ == "__main__":
    main()
