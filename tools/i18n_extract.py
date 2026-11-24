"""Collects every translatable string into i18n/strings.csv, keeping existing translations.

    python tools/i18n_extract.py

Sources: tr("...") and TranslationServer.translate("...") literals in scripts/*.gd,
plus i18n/data_strings.txt (data shown through tr() at the display site: glyph
names, shop items, House names, ...; one string per line, '#' lines are comments).
English is the key. Columns follow LOCALES; empty cells fall back to English in game.
Godot imports the CSV into one .translation per locale (project.godot lists them).
"""
import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV = ROOT / "i18n" / "strings.csv"
DATA = ROOT / "i18n" / "data_strings.txt"
LOCALES = ["hi", "bn", "ar", "pt", "id", "es", "tr", "ru", "de", "it", "vi"]
CALL = re.compile(r'(?:\btr|TranslationServer\.translate)\(\s*"((?:[^"\\]|\\.)*)"')


def unescape(s):
    return s.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")


def collect():
    keys = []
    for gd in sorted((ROOT / "scripts").glob("*.gd")):
        for m in CALL.finditer(gd.read_text(encoding="utf-8")):
            keys.append(unescape(m.group(1)))
    if DATA.exists():
        for line in DATA.read_text(encoding="utf-8").splitlines():
            if line.strip() and not line.lstrip().startswith("#"):
                keys.append(line.rstrip("\n"))
    seen, out = set(), []
    for k in keys:
        if k and k not in seen:
            seen.add(k)
            out.append(k)
    return out


def main():
    old = {}
    if CSV.exists():
        with CSV.open(encoding="utf-8", newline="") as f:
            for row in csv.DictReader(f):
                old[row["keys"]] = row
    keys = collect()
    CSV.parent.mkdir(exist_ok=True)
    with CSV.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["keys"] + LOCALES)
        for k in keys:
            row = old.get(k, {})
            w.writerow([k] + [row.get(l, "") for l in LOCALES])
    missing = {l: sum(1 for k in keys if not old.get(k, {}).get(l)) for l in LOCALES}
    print(len(keys), "strings;", "untranslated per locale:", missing)


if __name__ == "__main__":
    main()
