# Sunstone — 3D endless runner (Godot 4.7)

An explorer takes the glowing Sunstone from a painted Maya temple at dusk; stone
jaguar guardians chase him along an endless causeway. Temple-Run-style controls:
swipe left/right to change lanes (or to turn at corners), up to jump, down to
slide — plus our own twist, the **dusk run**: the sun sets over each run, the
Sunstone is the only light (drains; sun-drops refill it), the jaguars move only
in the dark, and a tap flares the stone to freeze and push them back. The UI is
the **Codex** (Maya codex pages, glyph-block buttons). Keep both original.
"Sunstone" is a working title. Visual identity and rules: **`DESIGN.md`** — read it
before touching any UI. Nothing from the old Deadbounce app is reused here.

## Layout

```
project.godot / export_presets.cfg   portrait, Mobile renderer, Android arm64,
                                     package com.pranta.sunstone
scenes/main.tscn        one node; everything is built in code by game.gd
scripts/
  game.gd               state machine (title → running → dying → results),
                        path-space movement, input, collisions, jaguars, camera,
                        environment (sky, fog, sun, glow), dev autopilot
  world.gd              endless causeway: segments + 90° corners, obstacles,
                        coins, scenery; each segment is ONE batched mesh
  mesher.gd             batches low-poly primitives into one mesh (vertex colours,
                        flat normals, lit + glowing surfaces) — the perf backbone
  models.gd             every 3D asset, written into a Mesher (no imported models)
  runner_model.gd       the explorer, jointed, procedural run/jump/slide/fall/idle
  jaguar_model.gd       the chasers
  ui_kit.gd             the Codex design system: palette, fonts, paper, glyph
                        blocks, pages, k'in sun glyph, sun meter, Maya numerals
  game_ui.gd            screens (title, HUD, pause, settings, results), anchored
  sfx.gd / save_data.gd audio + vibration / ConfigFile at user://save.cfg
tools/make_audio.py     synthesizes every sound + the music loop (pure Python)
tools/make_icon.py      draws the app icon, adaptive layers and boot splash
tools/make_paper.py     draws the tileable codex bark-paper texture
```

## Rules of the world (path space)

A segment has `origin`, `dir`, `right`, `length`; a point is (s along, x across,
y up). The straight run is `s ∈ [0, length]`, the corner square `[length,
length + PATH_WIDTH]`. Turns alternate so heading stays within ±90° of the start —
the causeway zig-zags forward and can never cross itself. Lanes are x = −1.6/0/+1.6.

- Nothing floats: the road is a raised sacbe on a stepped embankment
  (`Models.embankment`) standing on the jungle floor at `Models.GROUND_Y`.
  Pillars stand on buttresses, torches on the parapet, trees and bushes are
  rooted on the floor or tier ledges. Gaps break the embankment too (rubble
  below). The ground plane and skyline ride along under the camera.
- Head-on hit = run over (specific cause shown). Clipping a statue mid lane-change
  = stumble (jaguars close in); a second stumble within 8 s = caught.
- Missing the corner = "Ran off the causeway". Gaps = "Fell into the jungle".
- Turning: a swipe inside the window queues the turn; each lane pivots where it
  meets the same lane of the next stretch (`_pivot_s`), so only the heading
  changes. Camera and runner yaw are exp-damped; lanes ride a critically
  damped spring.
- Speed 12.5 → 27 u/s over ~1800 m; difficulty (density, gaps, double statues)
  ramps over ~2600 m. Swipe hints show during the first two runs.

## Building and testing — never open windows on the user's PC

The user works on this PC; Godot windows (`--write-movie` renders) block them.
**Test on the Android devices**, export headless:

```bash
G="/c/Users/pranta/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"
"$G" --headless --path . --import                      # after adding assets
"$G" --headless --path . --check-only --script scripts/x.gd   # parse check
"$G" --headless --path . --export-debug "Android" build/sunstone.apk
adb -s R83X309RLNR install -r build/sunstone.apk        # Galaxy Tab A9 (preferred)
adb -s R83X309RLNR shell monkey -p com.pranta.sunstone -c android.intent.category.LAUNCHER 1
```

- **Autopilot** (the game plays itself, for screenshots): `adb shell run-as
  com.pranta.sunstone touch files/autopilot`; remove the file to turn it off.
- **Renderer:** Android uses the Compatibility renderer (`rendering_method.mobile`).
  On the Tab A9 (Mali-G57) the Mobile renderer's fixed post-process cost alone
  is ~9 ms; Compatibility holds a locked 60. Verify pacing with
  `dumpsys SurfaceFlinger --latency '<SurfaceView layer>'` — every interval
  should be one vsync.
- **Dusk dev switches:** `files/dev_dusk` (e.g. `1.0`) starts runs at that much
  night; `files/dev_light` (e.g. `0.3`) sets the starting light.
- **Perf switches** (dev): with autopilot on, logcat prints fps / frame-time /
  draw calls every 2 s. Flag files in `files/` toggle features without a rebuild:
  `perf_noglow`, `perf_noshadow`, `perf_nomsaa`, `perf_nosky`, `perf_noui`,
  `perf_noworld`, `perf_nocoins`, `perf_novsync`, `perf_scale` (contents = 3D scale).
- Segment geometry is baked on a WorkerThreadPool task (`World._bake`) and
  attached on the main thread (`_attach`) — keep `_bake` free of scene-tree and
  shared-RNG access, or turns will hitch again.
- Keep devices **silent** while testing (the user is in an office): media volume 0.
- Typed GDScript: values read from Dictionaries need explicit types
  (`var x: float = d.value`), not `:=`.

## Assets

All generated: models in code, audio by `tools/make_audio.py`, icon by
`tools/make_icon.py`. Fonts: Dela Gothic One + Nunito (OFL, `assets/fonts/`).
The music loop is set in `assets/audio/music.wav.import` (`edit/loop_mode=2`).
