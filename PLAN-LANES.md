# The lanes rework — swipe to move, tap to flare

Play-test feedback (2026-10-10): holding a finger on the screen the whole run is
tiring and hides the road, and nothing kills you suddenly, so there is no tension.
This rework keeps everything that makes Sunstone itself (carrying the sun, the
painted light, the Houses, nights and dawn, the codex art, the shop) and gives it
a real runner's controls and danger.

Branch `lanes` in both repos. Each phase is tested on the tablet (R83X309RLNR),
committed, and gets a play-test from the user before the next one starts.

## The design in one page

- **Three lanes.** The causeway still winds, and the lanes follow it. Swipe
  left/right to change lane (quick, ~0.13 s), **up to jump**, **down to slide**.
  Swiping down in the air drops you fast. Your thumb rests between moves.
  Arrow keys / WASD + space do the same on desktop.
- **Tap to flare.** A tap that isn't a swipe throws the Sunstone's light far down
  the road for ~2.5 s: the road ahead paints in, jaguars ahead freeze, and the
  pack behind falls back. It costs a fifth of your light and has a short cooldown.
  Sun-drops refill the light, and dawn gives some back.
- **Your light is your sight.** The circle of light shrinks as the stone drains.
  Hazards show as faint ink in the dark and only read clearly inside the light,
  so the lower you are, the later you see what's coming. The core decision is
  **when to flare**.
- **Sudden death.** Hitting a hazard head-on kills you. Hazards:
  - *Fallen stela* — tall, blocks a lane: change lane.
  - *Low wall* — knee height: jump it (or change lane).
  - *Lintel / beam* — head height across lanes: slide under it.
  - *Pit* — one, two or all three lanes: jump it (or change lane).
  - *Obsidian blades* (House of Knives) — a lane you can't jump.
  - Later Houses mix them into patterns: two lanes blocked and a wall in the
    third, a lintel over a pit...
- **Stumbles and the pack.** Clipping a hazard from the side (changing lane into
  it) is a stumble, not a death: the jaguar pack behind you closes in. A second
  stumble while they're close, or letting the stone go out, and they catch you.
  Flaring drives them back.
- **Faster.** About 10 m/s at the start up to about 20 m/s deep in a run. Nights
  still end at dawn, and every night is faster and denser than the last.
- **Jaguars ahead** crouch by the road. In the dark they leap into your lane; a
  flare turns them to stone, and a stone jaguar is just another obstacle.
- **Bats** come when you flare a lot and swoop low across the road at head height:
  slide under them.

## Phases

### Phase 1 — Lanes, swipes, sudden death (the core)
1. Input: a swipe/tap recogniser (distance + time thresholds, works on any
   screen size) and keys. Remove hold-to-blaze and free steering.
2. The runner: lane position (eased), jump arc, slide, fast-drop, and the run /
   jump / slide poses the model already has.
3. The road: width fits three lanes (`Nights.LANE_W`) plus margins; lanes follow
   the winding centre line.
4. Dealing the road in **rows**: each event is a lane pattern (stela, low wall,
   lintel, pits over 1–3 lanes, sun-drop lines in a lane or arcs over walls),
   always leaving at least one way through. Seeded as before (the daily dusk
   stays the same for everyone).
5. Hazard models: low wall and lintel (new), stela and blades re-sized to a lane.
6. Collision by lane and height: head-on = death, side clip = stumble.
7. Speed curve 10 → 20 m/s; camera lower and closer behind the runner.
8. Tap-to-flare in its simple form (light cost, cooldown, the burst), drain retuned.
9. Autopilot rewritten for lanes, so the profile tour and store shots still work.

### Phase 2 — The dark and the chase
1. Light as sight: radius from charge, flare reach far ahead, unlit hazards drawn
   as faint ink.
2. The jaguar pack behind: distance meter, stumble → closer, flare → further,
   caught → death. Second wind drives them off.
3. Jaguars ahead: crouch, leap into your lane in the dark, freeze into an obstacle
   in light.
4. Bats: low swoops across the road (slide), drawn by flaring.
5. Per-House hazard mixes: knives (blades), fire (lava pits, braziers that paint
   the way), cold (faster drain), gloom (tiny embers), and the event overrides.

### Phase 3 — Feel and onboarding
1. Near misses ("Close!") pay a sun-drop and build a combo; pops and a short shake.
2. Sounds: swipe whoosh, jump, land, slide, stumble, pack growl rising as they
   close, flare. Haptics on stumble/death.
3. HUD: light ring with the flare cost marked, the pack's distance, swipe hints.
4. First-run tutorial: a gentle opening stretch with a ghost swipe for each move.
5. Glyphs reworked for the new verbs (leaps, slides, close calls, few flares).
6. Store-shot staging and profile tour updated.

### Phase 4 — Backend (`sunstone-api`)
1. Run rules: top speed 20 m/s; flares bounded by the cooldown; new counts
   (`jumps`, `slides`, `stumbles`) sanity-checked.
2. `ruleset` on every run (1 = hold-to-blaze, 2 = lanes): leaderboards show only
   the current ruleset (configurable), so old scores don't mix with new ones.
   Database migration and tests.
3. The game sends `ruleset` and the new counts; `/config` can carry a tuning
   version for later.
4. Docs in both CLAUDE.md files; tests pass.

### Phase 5 — Shop, polish, release
1. Charms re-read for the new game (slower drain, longer freeze, brighter drops
   still fit); boosts: Ember shield (relight once), Jaguar ward (the pack misses
   once), and a new **Head start** (begin a run 300 m in).
2. Profile on the tablet and the A24: a locked 60 everywhere.
3. Store listing copy and screenshots for the new controls; DESIGN.md / CLAUDE.md.
4. Version 1.1.0 (3), AAB built and checked; merge to master and push both repos
   (after the user's OK).
