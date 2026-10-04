# Sunstone — design system

**Carry the sun through Xibalba.** In Maya myth the sun descends into the
underworld each night and must cross it to rise again. The explorer carries
the Sunstone — that sun — down a winding causeway through the Houses of
Xibalba: Gloom, Knives, Cold, Jaguars, Bats, Fire. A run is a chain of nights;
each night ends at dawn. One thumb decides how bright to be: hold and the stone
blazes (colour, steering, frozen jaguars — but it burns light and draws bats),
let go and it dims to embers.

The UI has three jobs: get you running instantly, keep the light and the way to
dawn readable at a glance, and make the end of a run land.

## The world — the codex comes alive where there is light

The 3D world is drawn as a codex page, not as a lit 3D scene:

- **Light paints, darkness is bare paper.** Inside a circle of light (the
  Sunstone, a brazier, the dusk and dawn floods) the world is in full codex
  colour. Outside it, it is bare indigo night paper with pale chalk lines.
  The light circle has a freehand cinnabar rim where it meets the dark.
- **Ink outlines on everything** — black in the light, pale in the dark. Even
  line weight on screen.
- **Flat shading:** three hard bands from one fixed sun. No real-time lights,
  no shadows, no bloom, no realistic sky.
- **Things that are light always show:** flames, the Sunstone, sun-drops,
  jaguar and bat eyes, lava. That's how you read the dark.
- **Every House has its own world:** earth colour, paving, road marks, curb
  colour, scenery set and floating motes (fireflies, ash, snow, embers).
- **Paper grain** over the whole view.

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
- **HUD:** "Night N" top-left, the House under it, then sun-drops and metres;
  the **sun meter** top centre — the k'in glyph ringed by twenty count marks
  that go dark as the light drains, a cinnabar ring beating when it's failing,
  and a jaguar's eyes opening beneath it as one wakes nearby. Pause top-right.
  Under them, the **way to dawn**: a dotted road with a tick at each House and
  the runner's little sun on it. Entering a House, a codex slip names it.
- **Results:** a page unfolds: the night and House it ended in, what ended the
  run, the distance in both numeral systems, sun-drops gathered, best, then Run
  again / Home.

## Motion

Two orchestrated moments: the title strip unrolling as the sun glyph rises, and
the results page unfolding before the distance is counted out. Everything else
answers touch: buttons stamp down, pages unfold, a flare bursts warm white.

## Copy

Death causes are specific: "Ran into a fallen stela", "Fell into a pit",
"Stepped off the road into Xibalba", "Caught by a jaguar in the dark", "The
Sunstone went out". Hints name the move at the moment it's needed: "Touch and
hold: the Sunstone blazes and you can steer", "Bats hunt bright light: let go
and they lose you".
