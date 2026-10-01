# Sunstone — design system

A 3D endless runner with one twist of its own: **the dusk run**. An explorer takes
the glowing Sunstone from a jungle temple as the sun goes down. Every run goes
sunset → twilight → moonlit night, and the Sunstone is his only light. It drains;
sun-drops feed it. The stone jaguars that guard the temple are statues that only
move in the dark — let the light fail and they close in. A tap flares the stone:
they freeze back into stone and fall away. Temple Run gave us the run, the swipes
and the chase; everything else is ours.

The UI has three jobs: get you running instantly, keep the light readable at a
glance, and make the end of a run land.

## Identity — the Codex

Every screen is a page from a Maya codex: the folding books Maya scribes painted
on lime-stucco-coated bark paper, in black ink and red, divided into registers by
red rules, their words written in squared glyph blocks. Nothing here is a stock
game UI element; if it could be in any other mobile game, it doesn't belong.

## Palette — codex pigments

| Name | Hex | Role |
|---|---|---|
| Stucco | `#EFE3C8` | the page (always with the bark-paper texture) |
| Ink | `#1B1410` | linework, text on paper, the stamp edge under buttons |
| Cinnabar | `#B8322A` | register rules, page frames, the primary action, danger |
| Ochre | `#E3A82F` | the sun: the k'in glyph, count marks, sun-drops |
| Maya blue | `#3FA7B5` | painted temple bands in the world |
| Night | `#0B0E24` | the dim behind an open page |

## Type

- **Dela Gothic One** — headings, button words, big numbers. Heavy, carved.
- **Nunito** (variable, 900) — notes and row labels on paper.
- Sentence case. Plain verbs: "Run again", "Resume", "Home".
- Distances are also written in **Maya bar-and-dot numerals** (base 20, highest
  place on top) beside our own — on the best-distance slip and the results page.

## Shapes

- **Page** — stucco paper with a hand-cut edge and a double cinnabar frame.
  Opens like the screenfold: three leaves unfolding from the middle, creases
  fading as it lies flat.
- **Glyph block** — the squared, puffy cartouche glyphs are written in: rounded
  corners, gently bulging sides, thick ink outline, inner rule, dotted affixes.
  Every button is one. It stands on its own ink edge and stamps down into it.
  Primary: cinnabar with stucco lettering. Secondary: paper with ink lettering.
- **Rule** — a freehand cinnabar line between registers of a page.
- **k'in** — the Maya sun/day sign, a four-petalled flower in a round cartouche.
  The brand mark, the light meter, the sun-drop, the settings "on" state.
- Lines waver like a scribe's hand, but steadily (seeded) — never boiling.

## Layout

The live 3D world is always the background.

- **Title:** the codex strip with the k'in sun and "Sunstone" in two-colour ink
  (red printed a hair off the black) up top; the explorer raising the stone on
  the temple steps; the Run glyph block low, with the best distance on a paper
  slip beneath it. Settings (bar-and-dot sliders) top-right.
- **HUD:** distance top-left with sun-drops under it; the **sun meter** top
  centre — the k'in glyph ringed by twenty count marks that go dark as the light
  drains, a cinnabar ring beating when it's failing, and a jaguar's eyes opening
  beneath it as the pack closes in. Pause top-right. The edges of the screen
  darken as the light fails at night.
- **Results:** a page unfolds: what ended the run, the distance in both numeral
  systems, sun-drops gathered, best, then Run again / Home.

## Motion

Two orchestrated moments: the title strip unrolling as the sun glyph rises, and
the results page unfolding before the distance is counted out. Everything else
answers touch: buttons stamp down, pages unfold, a flare bursts warm white.

## Copy

Death causes are specific: "Hit a fallen log", "Fell into the jungle", "Caught in
the dark", "Caught by the jaguars". Hints name the move at the moment it's needed:
"Tap to flare the Sunstone", "Sun-drops keep the stone lit".
