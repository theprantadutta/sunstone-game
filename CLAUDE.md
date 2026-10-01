# Sunstone: Dusk Run — the game (Godot 4.7)

An explorer takes the glowing Sunstone from a painted Maya temple at dusk; stone
jaguar guardians chase him along an endless causeway. Temple-Run-style controls:
swipe left/right to change lanes (or to turn at corners), up to jump, down to
slide — plus our own twist, the **dusk run**: the sun sets over each run, the
Sunstone is the only light (drains; sun-drops refill it), the jaguars move only
in the dark, and a tap flares the stone to freeze and push them back. The UI is
the **Codex** (Maya codex pages, glyph-block buttons). Keep both original.
Store title **Sunstone: Dusk Run** (launcher label "Sunstone"), package
`com.pranta.sunstone`. Visual identity and rules: **`DESIGN.md`** — read it before
touching any UI. The roadmap to release is **`PLAN.md`**.

This repo is `sunstone-game`; its backend is the sibling repo `../sunstone-api`
(`G:\Personal\MyProjects\Sunstone\`). The game is a clean break from any
earlier project: no names, ids or assets carry over.

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
  game_ui.gd            screens (title + menu, HUD, pause, settings, results, Daily
                        dusk, Offerings, Glyphs, Market, Records, Second wind)
  save_data.gd          versioned JSON save (+ .bak fallback): progress, records,
                        daily, glyphs, offerings, charms, owned looks
  maya_calendar.gd      tzolk'in day names, UTC/local day keys, daily seeds
  glyphs.gd             the 20 glyphs (achievements) and when they're earned
  market.gd             charms, garbs, hues, Second wind cost — effects mirrored
                        in sunstone-api Runs/RunRules.cs
  online.gd             Firebase Auth (REST, silent guest) → our JWT; run outbox;
                        leaderboards; rename/delete account; cloud save merge;
                        batched analytics. Never blocks play when offline.
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
- Second wind: once per run, for sun-drops (Market.SECOND_WIND_COST): rise just
  past what ended the run, jaguars driven off, 1.5 s shield.
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
- Wrapping labels: use `UiKit.wrapped(...)`. Setting a Label's position before
  enabling autowrap locks it to the unwrapped width.
- After adding a new `class_name` script, run `--import` once so the class
  registers, or other scripts fail to parse.
- Sun-drops are `earned - spent` (two totals that only grow) so cloud merges can't
  duplicate or undo spending: `dev/check_save_merge.gd` proves it.
- `dev/check_calendar.gd` checks the tzolk'in math: `"$G" --headless --path . -s dev/check_calendar.gd`
  (2012-12-21 must be 4 Ajaw).

## Online (Firebase + sunstone-api)

No Flutter anywhere — the game is pure Godot, so FlutterFire doesn't apply.
- Firebase project **`sunstone-95fce`** (Auth: anonymous + Google). The game talks
  to Firebase Auth over its REST API; the web API key comes from the Android app's
  `google-services.json` in this repo's root — **gitignored, never commit it**.
- Google sign-in web client id (public):
  `865615140000-9jk5kbkrjg2ip2lmckib1oohokvaiten.apps.googleusercontent.com`
- Debug keystore SHA-1 (register in Firebase for Google sign-in on test builds):
  `DB:66:45:43:4B:46:84:35:E8:50:2E:B7:81:C0:15:1D:DE:98:A6:3C`
- The server exchanges the Firebase ID token for its own JWT (`POST /api/v1/auth/firebase`).
- Dev API base URL (LAN, the dev PC): `http://192.168.0.141:8395`. Hosted later at
  `https://sunstone.pranta.dev`. Anonymous + Google sign-in are enabled and verified.

## Android plugins

- `android-plugins/google-signin/` — Kotlin source of the Google sign-in plugin
  (Credential Manager → Google ID token). Build: from that folder,
  `JAVA_HOME="C:/Program Files/Java/jdk-17.0.2" ./gradlew --no-daemon copyAar`
  (needs a `local.properties` with `sdk.dir=C:/Users/pranta/AppData/Local/Android/Sdk`).
  The AAR lands in `addons/sunstone_google_signin/bin/` (committed so exports work
  without rebuilding it); the editor plugin there adds it and its Maven deps to
  the Gradle export.
- Exports use the Gradle build (`android/build`, regenerated, gitignored).

## Assets

All generated: models in code, audio by `tools/make_audio.py`, icon by
`tools/make_icon.py`. Fonts: Dela Gothic One + Nunito (OFL, `assets/fonts/`).
The music loop is set in `assets/audio/music.wav.import` (`edit/loop_mode=2`).
