"""The boot splash: the k'in sun glyph from the title wordmark, alone and
centred on a transparent 1024 px canvas (the plum around it is the boot
splash's bg_color). The game takes this same image over when it starts and
flies it up into the wordmark (GameUI.Splash), so its proportions follow
UiKit.Wordmark: disc radius r, count marks from r + 8 to r + 22, and ink
widths scaled from the wordmark's r = 58.

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


def main():
    s = SS
    img = Image.new("RGBA", (N * s, N * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = (N * s / 2, N * s / 2)
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
    img = img.resize((N, N), Image.LANCZOS)
    img.save("assets/icon/splash.png")
    print("wrote assets/icon/splash.png")


if __name__ == "__main__":
    main()
