# Store listing experiments

## Icon A vs B

- **A (current, shipped):** `store/icon-512.png`, drawn by `tools/make_icon.py`. It shows the gold Sunstone rising behind a stepped jade pyramid, with cinnabar rays, on a dusk gradient.
- **B (variant):** `store/experiments/icon-b-512.png`, drawn by `tools/make_icon_variant.py`. It shows the k'in sun glyph, big and in thick ink. The glyph burns inside the game's painted light circle, which has a freehand cinnabar rim, on the deep blue night of Xibalba.

**Hypothesis:** Play shows Sunstone about 250 to 300 times a day, but under 1% of those people open the listing. At search and browse sizes (48 to 96 px), A's pyramid, rays and soft dusk gradient blur into a busy shape that resembles many other temple runners. B is one round shape with a near-black background around a bright cream and ochre centre. It should read at a glance and stand out in a grid of runner icons, which should raise the share of impressions that become store visits and installs.

**How to run it:**
1. Go to Play Console > Store listing experiments > Default graphics.
2. Set the attribute to App icon and upload B.
3. Use a 50/50 split, with first-time installers retained as the metric.
4. Run it until Play reports a result, and apply B only if it wins.

**Regenerate:**

```
python tools/make_icon_variant.py
```

This never touches `assets/`. If B wins, port its drawing into `tools/make_icon.py` so that the adaptive layers, the iOS icons and the splash all match.
