"""Sunstone Play Store promo video, landscape 1920x1080 (light, codex paper).

Captions on the left, the phone recording on the right in an ink frame, on
the game's bark paper. Adapted from snake-classic's render_landscape.py.
    python render.py <ffmpeg.exe> <scenes.json> <out.mp4>
scenes.json: {"music_start": s, "segments": [{src, a, b, chip, title, sub}]},
src relative to this folder (raw recordings are not committed).
"""
import json
import math
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

D = Path(__file__).parent
GAME = D.parents[2]
FF, SCENES, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
W, H = 1920, 1080
INK = (27, 20, 16)
CINNABAR = (184, 50, 42)
OCHRE = (227, 168, 47)
MUTED = (110, 84, 64)
CREAM = (250, 240, 220)
DELA = GAME / "assets" / "fonts" / "DelaGothicOne-Regular.ttf"
NUNITO = GAME / "assets" / "fonts" / "Nunito-Variable.ttf"
PAPER = GAME / "assets" / "ui" / "paper.png"
MUSIC = D / "music.mp3"  # Pixabay: "Tribal Drums Epic Action" by Stereo_Color

INTRO, OUTRO, FADE = 3.0, 4.5, 0.3
PH = 980
PW = round(PH * 1080 / 2340 / 2) * 2
PX, PY = 1250, (H - PH) // 2
RADIUS = 34
CAP_X, CAP_W = 150, 960


def dela(size):
    return ImageFont.truetype(str(DELA), size)


def nunito(size, weight=800):
    f = ImageFont.truetype(str(NUNITO), size)
    f.set_variation_by_axes([weight])
    return f


def wrap(d, text, f, width):
    lines, cur = [], ""
    for word in text.split():
        trial = f"{cur} {word}".strip()
        if d.textlength(trial, font=f) <= width:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    return lines + [cur]


def paper():
    tile = Image.open(PAPER).convert("RGB")
    img = Image.new("RGB", (W, H))
    for y in range(0, H, tile.height):
        for x in range(0, W, tile.width):
            img.paste(tile, (x, y))
    return img


def kin(d, cx, cy, r):
    """The k'in sun glyph: rays, a cream disc, four ochre petals."""
    for k in range(20):
        a = 2 * math.pi * k / 20
        d.line([(cx + math.cos(a) * r * 1.16, cy + math.sin(a) * r * 1.16),
                (cx + math.cos(a) * r * 1.45, cy + math.sin(a) * r * 1.45)], fill=OCHRE, width=max(3, r // 9))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=CREAM, outline=INK, width=max(2, r // 14))
    p = r * 0.34
    for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0)):
        x, y = cx + dx * p * 1.05, cy + dy * p * 1.05
        d.ellipse((x - p, y - p, x + p, y + p), fill=OCHRE, outline=INK, width=max(1, r // 22))
    q = p * 0.45
    d.ellipse((cx - q, cy - q, cx + q, cy + q), fill=CREAM, outline=INK, width=max(1, r // 40))


def chip(d, x, y, label):
    f = nunito(32, 900)
    tw = d.textlength(label, font=f)
    h = 60
    d.rounded_rectangle((x, y, x + tw + 48, y + h), radius=10, fill=CINNABAR)
    d.text((x + 24, y + h / 2), label, font=f, fill=CREAM, anchor="lm")
    return y + h


def caption_png(i, label, title, sub):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ft, fs = dela(84), nunito(46, 800)
    tl = wrap(d, title, ft, CAP_W)
    sl = wrap(d, sub, fs, CAP_W - 60)[:3]
    block = 60 + 44 + len(tl) * 112 + 34 + len(sl) * 62
    y = (H - block) // 2
    y = chip(d, CAP_X, y, label) + 44
    for line in tl:
        d.text((CAP_X - 4, y), line, font=ft, fill=INK)
        y += 112
    y += 34
    for line in sl:
        d.text((CAP_X, y), line, font=fs, fill=CINNABAR)
        y += 62
    p = D / f"cap{i}.png"
    img.save(p)
    return p


def stage():
    bg = paper()
    d = ImageDraw.Draw(bg)
    d.line([(90, 40), (W - 90, 40)], fill=CINNABAR, width=6)
    d.line([(90, H - 40), (W - 90, H - 40)], fill=CINNABAR, width=6)
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (PX - 6, PY + 4, PX + PW + 18, PY + PH + 22), radius=RADIUS + 12, fill=(60, 40, 20, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    bg.paste(shadow, (0, 0), shadow)
    ImageDraw.Draw(bg).rounded_rectangle(
        (PX - 12, PY - 12, PX + PW + 11, PY + PH + 11), radius=RADIUS + 12, fill=INK)
    bg.save(D / "stage.png")
    mask = Image.new("L", (PW, PH), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, PW - 1, PH - 1), radius=RADIUS, fill=255)
    mask.save(D / "mask.png")


def card(name, build):
    img = paper()
    build(img, ImageDraw.Draw(img))
    p = D / f"{name}.png"
    img.save(p)
    return p


def centered(d, cx, y, text, f, fill):
    d.text((cx - d.textlength(text, font=f) / 2, y), text, font=f, fill=fill)


def intro(img, d):
    kin(d, W // 2, 290, 120)
    f = dela(170)
    centered(d, W / 2 + 7, 497, "Sunstone", f, CINNABAR)
    centered(d, W / 2, 490, "Sunstone", f, INK)
    d.line([(560, 760), (W - 560, 760)], fill=CINNABAR, width=6)
    centered(d, W / 2, 790, "Maya Temple Runner", nunito(64, 900), CINNABAR)


def outro(img, d):
    kin(d, 290, 270, 90)
    d.text((446, 180), "Sunstone", font=dela(110), fill=INK)
    d.text((452, 330), "Maya Temple Runner", font=nunito(52, 900), fill=CINNABAR)
    items = ["Swipe, leap and slide", "Flare to freeze the jaguars", "Six Houses of Xibalba",
             "A new daily dusk every day"]
    fi = nunito(50, 800)
    y = 520
    for t in items:
        kin(d, 215, y + 22, 14)
        d.text((265, y + 22), t, font=fi, fill=INK, anchor="lm")
        y += 96
    bw, bh = 640, 150
    bx, by = 1130, 430
    d.rounded_rectangle((bx, by, bx + bw, by + bh), radius=24, fill=CINNABAR)
    centered(d, bx + bw / 2, by + 36, "FREE TO PLAY", nunito(66, 900), CREAM)
    centered(d, bx + bw / 2, by + bh + 36, "on Google Play", nunito(44, 800), MUTED)


def main():
    cfg = json.loads(Path(SCENES).read_text(encoding="utf-8"))
    scenes = cfg["segments"]
    stage()
    caps = [caption_png(i, s["chip"], s["title"], s["sub"]) for i, s in enumerate(scenes)]
    intro_p, outro_p = card("intro", intro), card("outro", outro)
    durs = [s["b"] - s["a"] for s in scenes]
    demo = sum(durs)
    total = INTRO + demo + OUTRO

    srcs = sorted({s["src"] for s in scenes})
    idx = {sp: i for i, sp in enumerate(srcs)}
    inputs = []
    for sp in srcs:
        inputs += ["-i", str(D / sp)]
    n = len(srcs)
    inputs += ["-loop", "1", "-i", str(D / "stage.png"), "-i", str(D / "mask.png")]
    inputs += ["-loop", "1", "-t", str(INTRO), "-i", str(intro_p)]
    inputs += ["-loop", "1", "-t", str(OUTRO), "-i", str(outro_p)]
    cap0 = n + 4
    for p, du in zip(caps, durs):
        inputs += ["-loop", "1", "-t", f"{du:.3f}", "-i", str(p)]
    music_i = cap0 + len(scenes)
    inputs += ["-ss", str(cfg.get("music_start", 0)), "-i", str(MUSIC)]

    fc = []
    for sp in srcs:
        ids = [i for i, s in enumerate(scenes) if s["src"] == sp]
        outs = "".join(f"[r{i}]" for i in ids)
        fc.append(f"[{idx[sp]}:v]fps=30,split={len(ids)}{outs}" if len(ids) > 1 else f"[{idx[sp]}:v]fps=30{outs}")
    for i, s in enumerate(scenes):
        fc.append(f"[r{i}]trim={s['a']}:{s['b']},setpts=PTS-STARTPTS[t{i}]")
    fc.append("".join(f"[t{i}]" for i in range(len(scenes))) + f"concat=n={len(scenes)}:v=1:a=0[rec]")
    fc.append(f"[rec]scale={PW}:{PH}:flags=lanczos,format=rgba[ph]")
    fc.append(f"[{n + 1}:v]format=gray[mk]")
    fc.append("[ph][mk]alphamerge[phr]")
    fc.append(f"[{n}:v]fps=30,trim=0:{demo:.3f},setpts=PTS-STARTPTS[stg]")
    fc.append(f"[stg][phr]overlay={PX}:{PY}:shortest=1[a0]")
    last, t = "a0", 0.0
    for i, du in enumerate(durs):
        fades = f"fade=in:st=0:d={FADE}:alpha=1,fade=out:st={du - FADE:.3f}:d={FADE}:alpha=1"
        fc.append(f"[{cap0 + i}:v]format=rgba,{fades},setpts=PTS-STARTPTS+{t:.3f}/TB[c{i}]")
        fc.append(f"[{last}][c{i}]overlay=0:0:eof_action=pass[b{i}]")
        last, t = f"b{i}", t + du
    fc.append(f"color=c=0xE3A82F:s={W}x10:r=30:d={demo:.3f}[bar]")
    fc.append(f"[{last}][bar]overlay=x='-{W}+{W}*t/{demo:.3f}':y={H - 10}:shortest=1,format=yuv420p,setsar=1[demo]")
    fc.append(f"[{n + 2}:v]fps=30,format=yuv420p,fade=in:st=0:d=0.35,fade=out:st={INTRO - 0.35}:d=0.35,setsar=1[in]")
    fc.append(f"[{n + 3}:v]fps=30,format=yuv420p,fade=in:st=0:d=0.35,fade=out:st={OUTRO - 0.6}:d=0.6,setsar=1[out]")
    fc.append("[in][demo][out]concat=n=3:v=1:a=0[v]")
    fc.append(f"[{music_i}:a]atrim=0:{total:.3f},asetpts=PTS-STARTPTS,volume=0.85,"
              f"afade=in:st=0:d=0.5,afade=out:st={total - 2.0:.3f}:d=2.0[aud]")
    cmd = [FF, "-hide_banner", "-loglevel", "error", "-y", *inputs, "-filter_complex", ";".join(fc),
           "-map", "[v]", "-map", "[aud]", "-t", f"{total:.2f}", "-c:v", "libx264", "-crf", "19",
           "-preset", "slow", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k",
           "-movflags", "+faststart", OUT]
    subprocess.run(cmd, check=True)
    print("done", round(total, 2))


if __name__ == "__main__":
    main()
