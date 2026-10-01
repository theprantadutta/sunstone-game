"""Synthesizes every sound in Sunstone from scratch (pure Python, no samples).

    python tools/make_audio.py

Writes 16-bit mono WAVs to assets/audio/. Deterministic: same output each run.
"""
import math
import os
import random
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = random.Random(7)


def silence(seconds):
    return [0.0] * int(SR * seconds)


def env_exp(i, decay):
    return math.exp(-i / (SR * decay))


def lowpass(x, cutoff):
    a = 1 - math.exp(-2 * math.pi * cutoff / SR)
    y, out = 0.0, []
    for v in x:
        y += a * (v - y)
        out.append(y)
    return out


def highpass(x, cutoff):
    lp = lowpass(x, cutoff)
    return [a - b for a, b in zip(x, lp)]


def noise(n):
    return [rng.uniform(-1, 1) for _ in range(n)]


def mix_into(buf, clip, at, gain=1.0, wrap=False):
    for i, v in enumerate(clip):
        j = at + i
        if wrap:
            j %= len(buf)
        elif j >= len(buf):
            break
        buf[j] += v * gain


def normalize(x, peak=0.9):
    m = max(1e-9, max(abs(v) for v in x))
    return [v * peak / m for v in x]


def fade(x, fin=0.004, fout=0.02):
    n = len(x)
    a, b = int(SR * fin), int(SR * fout)
    for i in range(min(a, n)):
        x[i] *= i / a
    for i in range(min(b, n)):
        x[n - 1 - i] *= i / b
    return x


def write(name, x, peak=0.9):
    x = normalize(x, peak)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in x))
    print(f"{name}.wav  {len(x) / SR:.2f}s")


# ------------------------------------------------------------- voices ---

def sweep(f0, f1, seconds, decay=None, shape="sine"):
    n = int(SR * seconds)
    out, ph = [], 0.0
    for i in range(n):
        t = i / n
        f = f0 * (f1 / f0) ** t
        ph += 2 * math.pi * f / SR
        v = math.sin(ph) if shape == "sine" else (2 / math.pi) * math.asin(math.sin(ph))
        out.append(v * (env_exp(i, decay) if decay else (1 - t)))
    return out


def bell(freq, seconds=0.4):
    n = int(SR * seconds)
    return [
        (math.sin(2 * math.pi * freq * i / SR) * env_exp(i, 0.16)
         + 0.45 * math.sin(2 * math.pi * freq * 2.0 * i / SR) * env_exp(i, 0.07)
         + 0.2 * math.sin(2 * math.pi * freq * 3.93 * i / SR) * env_exp(i, 0.03))
        for i in range(n)
    ]


def marimba(freq, seconds=0.5, decay=0.18):
    n = int(SR * seconds)
    return [
        (math.sin(2 * math.pi * freq * i / SR)
         + 0.35 * math.sin(2 * math.pi * freq * 4.0 * i / SR) * env_exp(i, 0.02))
        * env_exp(i, decay) * min(1.0, i / 60)
        for i in range(n)
    ]


def drum(f0, f1, seconds, decay, click=0.3):
    body = sweep(f0, f1, seconds, decay)
    hit = noise(int(SR * 0.012))
    for i, v in enumerate(hit):
        body[i] += v * click * (1 - i / len(hit))
    return body


def whoosh(seconds, lo, hi, rising=True):
    n = int(SR * seconds)
    raw = noise(n)
    out, y = [], 0.0
    for i, v in enumerate(raw):
        t = i / n
        f = lo + (hi - lo) * (t if rising else 1 - t)
        a = 1 - math.exp(-2 * math.pi * f / SR)
        y += a * (v - y)
        out.append(y * math.sin(math.pi * t))
    return out


# --------------------------------------------------------------- sfx ---

def make_sfx():
    j = sweep(200, 620, 0.2, 0.09, "tri")
    mix_into(j, whoosh(0.2, 600, 3000), 0, 0.5)
    write("jump", fade(j))

    s = highpass(noise(int(SR * 0.42)), 500)
    s = [v * math.sin(math.pi * i / len(s)) * (0.6 + 0.4 * rng.random()) for i, v in enumerate(s)]
    write("slide", fade(lowpass(s, 2600)), 0.7)

    write("lane", fade(whoosh(0.13, 900, 4000)), 0.55)

    t = whoosh(0.26, 500, 2600)
    mix_into(t, drum(300, 200, 0.06, 0.02, 0.1), 0, 0.3)
    write("turn", fade(t), 0.75)

    write("coin", fade(bell(1318.5, 0.38)), 0.75)

    st = drum(110, 48, 0.25, 0.08, 0.6)
    mix_into(st, lowpass(noise(int(SR * 0.2)), 1200), 0, 0.5)
    write("stumble", fade(st))

    cr = drum(90, 36, 0.6, 0.18, 0.8)
    crumble = [0.0] * int(SR * 0.9)
    for _ in range(26):
        at = int(rng.uniform(0, 0.75) * SR)
        mix_into(crumble, [v * env_exp(i, 0.025) for i, v in enumerate(noise(int(SR * 0.08)))], at, rng.uniform(0.2, 0.6))
    mix_into(cr, lowpass(crumble, 1800), 0, 0.9)
    write("crash", fade(cr))

    f = sweep(900, 180, 0.9, None)
    mix_into(f, [v * 0.3 for v in whoosh(0.9, 300, 1200, False)], 0)
    write("fall", fade(f), 0.8)

    # Jaguar growl: a wobbling low saw, roughened with noise, then muffled.
    n = int(SR * 1.2)
    growl, ph = [], 0.0
    for i in range(n):
        t = i / n
        fq = 70 + 40 * math.sin(math.pi * t) + 6 * math.sin(2 * math.pi * 11 * t)
        ph += fq / SR
        saw = 2 * (ph % 1.0) - 1
        e = min(1.0, t / 0.08) * (1 - t) ** 1.4
        growl.append((saw * (0.7 + 0.6 * rng.random())) * e)
    write("roar", fade(lowpass(growl, 900)))

    r = [0.0] * int(SR * 1.1)
    for k, note in enumerate([440.0, 523.25, 659.25, 880.0]):
        mix_into(r, marimba(note, 0.7, 0.22), int(k * 0.11 * SR))
    write("results", fade(r), 0.8)

    write("tap", fade(marimba(880, 0.12, 0.03)), 0.6)


# ------------------------------------------------------------- music ---

def make_music():
    bpm = 100
    beat = 60.0 / bpm
    bars = 8
    total = int(SR * beat * 4 * bars)
    buf = [0.0] * total

    def at(bar, step16):  # sample index for a 16th-note step in a bar
        return int(SR * beat * (bar * 4 + step16 / 4.0))

    low = drum(120, 70, 0.4, 0.14, 0.25)
    high = drum(210, 160, 0.25, 0.08, 0.2)
    for bar in range(bars):
        for st in (0, 6, 10):
            mix_into(buf, low, at(bar, st), 0.55, True)
        for st in (4, 12, 14):
            mix_into(buf, high, at(bar, st), 0.35, True)
        for st in range(16):  # shaker
            sh = [v * env_exp(i, 0.012) for i, v in enumerate(highpass(noise(int(SR * 0.05)), 5000))]
            mix_into(buf, sh, at(bar, st), 0.12 if st % 4 else 0.2, True)

    # A minor pentatonic (A C D E G): bass roots per bar.
    roots = [55.0, 55.0, 65.41, 73.42, 55.0, 55.0, 49.0, 65.41]
    for bar, f in enumerate(roots):
        for st in (0, 8, 11):
            mix_into(buf, marimba(f, 0.6, 0.25), at(bar, st), 0.5, True)

    scale = [220.0, 261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33]
    phrase = [(0, 5), (3, 4), (6, 3), (8, 5), (10, 6), (12, 4), (14, 3)]
    answer = [(0, 4), (2, 3), (4, 2), (8, 1), (10, 2), (14, 0)]
    for bar in range(bars):
        notes = phrase if bar % 2 == 0 else answer
        lift = 1 if bar >= 4 else 0
        for st, deg in notes:
            mix_into(buf, marimba(scale[min(deg + lift, 7)], 0.45, 0.16), at(bar, st), 0.32, True)

    write("music", buf, 0.75)


def make_dusk():
    """The Sunstone's flare and its fizzle when there's no light left."""
    # Flare: a bright rising shimmer — stacked bells over a rising whoosh.
    f = whoosh(0.7, 400, 5000)
    for k, (note, at) in enumerate([(659.25, 0.0), (987.77, 0.05), (1318.5, 0.1), (1975.5, 0.16)]):
        mix_into(f, bell(note, 0.6), int(at * SR), 0.55 - k * 0.08)
    write("flare", fade(f, 0.004, 0.2), 0.85)
    # Fizzle: a dull, falling puff.
    z = sweep(420, 160, 0.22, 0.06, "tri")
    mix_into(z, lowpass(noise(int(SR * 0.2)), 900), 0, 0.4)
    write("fizzle", fade(z), 0.6)


if __name__ == "__main__":
    import sys
    if "--dusk" in sys.argv:
        make_dusk()
    else:
        make_sfx()
        make_music()
        make_dusk()
