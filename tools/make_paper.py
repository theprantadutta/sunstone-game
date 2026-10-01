"""Draws the codex paper: lime-stucco over fig-bark (amate), tileable.

    python tools/make_paper.py

Writes assets/ui/paper.png (512x512, seamless). Deterministic.
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui")
N = 512
STUCCO = (239, 227, 200)
rng = random.Random(3)


def tile_noise(cells, amp):
    """Smooth value noise that wraps at the edges."""
    grid = [[rng.uniform(-1, 1) for _ in range(cells)] for _ in range(cells)]
    img = Image.new("L", (N, N))
    px = img.load()
    for y in range(N):
        fy = y / N * cells
        y0 = int(fy) % cells
        ty = fy - int(fy)
        ty = ty * ty * (3 - 2 * ty)
        for x in range(N):
            fx = x / N * cells
            x0 = int(fx) % cells
            tx = fx - int(fx)
            tx = tx * tx * (3 - 2 * tx)
            a = grid[y0][x0] + (grid[y0][(x0 + 1) % cells] - grid[y0][x0]) * tx
            b = grid[(y0 + 1) % cells][x0] + (grid[(y0 + 1) % cells][(x0 + 1) % cells] - grid[(y0 + 1) % cells][x0]) * tx
            px[x, y] = int(128 + (a + (b - a) * ty) * amp)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    base = Image.new("RGB", (N, N), STUCCO)
    # Broad blotches where the stucco is thicker or thinner.
    blot = tile_noise(6, 60).filter(ImageFilter.GaussianBlur(6))
    fine = tile_noise(48, 40)
    px = base.load()
    bp = blot.load()
    fp = fine.load()
    for y in range(N):
        for x in range(N):
            v = (bp[x, y] - 128) * 0.09 + (fp[x, y] - 128) * 0.05
            px[x, y] = tuple(max(0, min(255, int(c + v * (1.0 if i < 2 else 1.25)))) for i, c in enumerate(STUCCO))
    # Bark fibres: long faint strokes, mostly horizontal, wrapped at the edges.
    d = ImageDraw.Draw(base, "RGBA")
    for _ in range(260):
        x, y = rng.uniform(0, N), rng.uniform(0, N)
        length = rng.uniform(30, 140)
        ang = rng.gauss(0, 0.12)
        dark = rng.random() < 0.7
        col = (150, 120, 80, rng.randint(14, 34)) if dark else (255, 250, 235, rng.randint(20, 45))
        for ox in (-N, 0, N):
            for oy in (-N, 0, N):
                d.line([(x + ox, y + oy), (x + ox + math.cos(ang) * length, y + oy + math.sin(ang) * length)], fill=col, width=1)
    # Specks of bark showing through.
    for _ in range(500):
        x, y = rng.uniform(0, N), rng.uniform(0, N)
        r = rng.uniform(0.4, 1.4)
        col = (110, 85, 55, rng.randint(40, 110))
        for ox in (-N, 0, N):
            for oy in (-N, 0, N):
                d.ellipse([x + ox - r, y + oy - r, x + ox + r, y + oy + r], fill=col)
    base.save(os.path.join(OUT, "paper.png"))
    print("paper written to", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
