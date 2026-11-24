"""Merges i18n/tr/<locale>.json ({english: translation}) into i18n/strings.csv.

    python tools/i18n_merge.py

Checks each translation keeps the English placeholders in order; bad ones are
reported and left out (the game shows English for them).
"""
import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV = ROOT / "i18n" / "strings.csv"
PH = re.compile(r"%(?:\.\d+)?[sdf%]")


def main():
    with CSV.open(encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    cols = list(rows[0].keys())
    bad = 0
    for path in sorted((ROOT / "i18n" / "tr").glob("*.json")):
        loc = path.stem
        if loc not in cols:
            print("skip unknown locale", loc)
            continue
        tr = json.loads(path.read_text(encoding="utf-8"))
        n = 0
        for r in rows:
            t = tr.get(r["keys"], "")
            if not t:
                continue
            if PH.findall(t) != PH.findall(r["keys"]):
                print(f"[{loc}] placeholder mismatch: {r['keys']!r} -> {t!r}")
                bad += 1
                continue
            r[loc] = t
            n += 1
        print(f"{loc}: {n}/{len(rows)}")
    with CSV.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(rows)
    print("placeholder problems:", bad)


if __name__ == "__main__":
    main()
