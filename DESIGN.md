# Sunstone — design system

A 3D endless runner. An explorer takes the glowing Sunstone from a jungle temple at
dusk; stone jaguar guardians wake and chase him along the painted temple causeway.
"Sunstone" is a working title.

The UI has three jobs: get you running instantly, stay readable over the 3D world
without covering it, and make the end of a run land.

## Palette — Maya temple pigments

| Name | Hex | Role |
|---|---|---|
| Maya blue | `#3FA7B5` | panel trim, painted temple bands, secondary accents |
| Cinnabar | `#B8322A` | danger, being caught, painted pillar accents |
| Deep jade | `#0E3B33` | panel faces — the "dark" of the app (never black) |
| Idol gold | `#F4B732` | coins, the primary action |
| Dusk violet | `#2A1B3D` | overlay tint behind modals |
| Limestone | `#EDE6D6` | text on dark surfaces |

## Type

- **Dela Gothic One** — wordmark, headlines, big numbers. Heavy, blocky, carved.
- **Nunito** (variable, 700–900) — buttons and all other text. Soft and rounded.
- Sentence case. Plain verbs: "Run again", "Resume", "Home".

## Shape

Stepped corners on every panel and button — temple steps. No plain rounded cards,
no neon glow. Primary buttons are gold slabs with a darker lip that presses down.

## Layout

The live 3D world is always the background; UI sits on it as carved slabs.

- **Title:** wordmark in the upper third, the explorer on the temple steps, a single
  "Run" slab low on the screen with the best distance under it, settings top-right.
- **HUD:** distance top-left, coins under it, pause top-right. Nothing else.
- **Results:** a slab rises from the bottom; headline says exactly what ended the run.

## Motion

Two orchestrated moments only: the wordmark settling on the title, and the results
slab rising while the distance counts up. Everything else responds to touch.

## Copy

Death causes are specific: "Hit a fallen log", "Fell into the jungle", "Caught by the
jaguars". Errors and empty states give direction, never mood.
