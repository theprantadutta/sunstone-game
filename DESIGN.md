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

Polished stone: smooth, generous curves with chunky depth. Buttons are pills
standing on a darker lip they press into, with a soft sheen across the top; icon
buttons are round on the same lip. Panels are deep jade slabs with big soft
corners, a thin Maya-blue rim and a soft shadow. Toggles are pills with a round
knob; the coin is round. No hard notches or cut corners, no neon glow. All
curves are anti-aliased styleboxes (`UiKit.round_box`).

## Layout

The live 3D world is always the background; UI sits on it as polished slabs.

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
