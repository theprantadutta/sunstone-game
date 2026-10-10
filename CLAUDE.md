# Sunstone — the game (Godot 4.7)

**Carry the sun through Xibalba.** In Maya myth the sun goes down into the
underworld every night and must cross it to rise at dawn. The explorer carries
the Sunstone — that sun — along a winding causeway through the Houses of
Xibalba (the Popol Vuh's trials). One run is a chain of nights; each night is
three Houses, then dawn.

**Three lanes, one thumb that rests between moves** (since 1.1.0, ruleset 2;
see `PLAN-LANES.md`). Swipe left/right to change lane, up to jump low walls
and pits, down to slide under lintels and diving bats; a tap **flares** the
Sunstone — its light thrown far down the road, the jaguars frozen to stone —
at the cost of a lump of light. Light is sight (outside it the world is bare
ink on night paper, and past the stone's reach not even that), and light is
life: when it fails, the jaguar pack behind you catches up. Head-on hits end
the run. The UI is the **Codex**
(Maya codex pages, glyph-block buttons). Store title **Sunstone: Dusk Run**
(launcher label "Sunstone"), package `com.pranta.sunstone`. Visual identity:
**`DESIGN.md`** — read it before touching UI or 3D art. Roadmap: **`PLAN.md`**.
The hold-to-blaze version (1.0.x, ruleset 1) is in git history before the
`lanes` branch.

This repo is `sunstone-game`; its backend is the sibling repo `../sunstone-api`
(`G:\Personal\MyProjects\Sunstone\`). The game is a clean break from any
earlier project: no names, ids or assets carry over.

## Layout

```
project.godot / export_presets.cfg   portrait, Android uses Compatibility renderer
scenes/main.tscn        one node; everything is built in code by game.gd
scripts/
  game.gd               state machine (title → running → dying → results), the
                        run (lanes/swipes/flare, light, pack, jaguars, bats, hazards, dawn),
                        camera, halo, motes, title sky, dev autopilot
  nights.gd             THE shape of a run: nights, Houses (their numbers and
                        looks), speeds, widths, dawn — pure functions of distance
  world.gd              the winding causeway in 12 m chunks: road cells, walls,
                        pits, dangers, drops, braziers, gates, scenery per House;
                        baked on a worker thread, one mesh + one drop MultiMesh
  codex.gd              the look: the three shared materials (world, glow, ink
                        outline) and the light uniforms (stone, braziers, dawn)
  mesher.gd             batches low-poly primitives into one mesh: lit, glow and
                        flat (no outline) surfaces; stores outline directions
  models.gd             every 3D asset (road marks, all House scenery, gates,
                        temple, sky, sun-drop) — no imported models
  runner_model.gd       the explorer, jointed; `raise` lifts the Sunstone high
  jaguar_model.gd       the stone jaguars        bat_model.gd   the bats
  ui_kit.gd             the Codex design system: palette, fonts, paper, glyph
                        blocks, pages, k'in sun glyph, sun meter, Maya numerals
  game_ui.gd            screens (title + menu, HUD with night/House/dawn track
                        and banners, pause, settings, results, Daily dusk,
                        Offerings, Glyphs, Market, Records, Second wind)
  save_data.gd          versioned JSON save (+ .bak fallback)
  maya_calendar.gd      tzolk'in day names, UTC/local day keys, daily seeds
  glyphs.gd             the 24 glyphs (achievements), earned by nights/moves
  market.gd             charms, stone hues, Second wind cost
  shop.gd               the shop catalog: outfits, hats, boosts, treasury,
                        prices (sun-drops or a store product); Shop.dress()
                        builds a runner from character + outfit + hat + hue
  themes.gd             characters (look + outfit + price) and seasonal events
                        that restyle Houses, scenery, motes, fire, sky, runner
  online.gd             Firebase Auth (REST, silent guest) → our JWT; run outbox;
                        leaderboards; account; cloud save merge; analytics
  sfx.gd                audio + vibration
tools/make_audio.py     synthesizes every sound + the night music (pure Python)
tools/make_icon.py      app icon, adaptive layers, boot splash
tools/make_paper.py     the tileable codex bark-paper texture (UI)
```

## Rules of the run

- **Road space.** A point on the road is (s, u): metres along, metres across
  (+ right). `world.point(s, u)` gives the world position; the road runs toward
  −Z and its centre wanders (`world.center(s)`, two sines, seeded phases). Width
  belongs to the House (`Nights.width`, blended at House changes).
- **Nights** (`nights.gd`): night n lasts min(90, 58 + 8(n−1)) s at its own speed
  (6.6 → 11 m/s); its length in metres follows. Three Houses per night, a 36 m
  sunrise road (no danger) between nights. Night 1 is always dusk causeway →
  Jaguars → Bats; later nights draw three from Gloom, Knives, Cold, Jaguars,
  Bats, Fire (seeded). Everything is a function of distance and seed, so the
  daily dusk is identical for everyone and the score stays in metres.
- **The thumb.** A swipe (≥ 4.5% of the short screen side, one per touch) is a
  move: left/right = lane (−1, 0, 1; `LANE_W` 2.5 m, eased), up = jump (1.2 m,
  0.6 s), down = slide (0.65 s; in the air it dives and slides on landing). A
  touch < 0.3 s that didn't swipe = **flare**: 2.2 s, light circle grows to
  11 m centred 8 m ahead; costs 0.15 light, 0.45 s cooldown, fizzles below the
  cost (the sun meter marks it). Keys: arrows/WASD + space.
- **Speed** 10 → 20 m/s (`Nights.speed`). Rows of road come about a second
  apart at the speed you'll have there (`world.gd _deal_until/_row`): stela or
  blades (1–2 lanes), low wall (jump), lintel (whole road, slide), pits over
  1–3 lanes (jump), sun-drop lines/arcs, jaguars, braziers. Every row leaves a
  way through. Each House weighs them by its `mix`.
- **Hits**: meeting a danger's front face in its lane = death; clipping it
  from the side mid-lane-change = **stumble** (thrown back, −0.12 light, pack
  at your heels); a second stumble within 6 s = caught.
- **Light** drains 0.02/s (× House drain × Ember heart); a sun-drop +0.014
  (× Sun-drinker), a whole line +3 drops and 3× that light; close calls +0.01;
  dawn +0.35. **Sight** = light radius + (8 + 14 × light) m: past it the
  night swallows the ink (`Codex` `sight`); glowing things still show.
- **The pack** (`_step_pack`): three stone jaguars behind, out of view while the
  light is high, closer as it dims, at the heels after a stumble; a flare turns
  them to stone and they fall back; at zero light they catch you. They run the
  same road (round stelae, over walls/pits, under lintels: `World.occupant`).
- **Jaguars ahead** crouch at the curb; in the dark, as you near, one leaps into
  your lane (only where it can land clear) and comes at you; light freezes it
  where it stands — a stone jaguar is an obstacle. Patience charm = linger.
- **Bats** come when you flare a lot (attraction while blazing, House "bat"),
  dive at head height for 3.5 s and steal 0.2 light; a slide ducks them.
- **Close calls**: a danger passed within 0.45 s of the move that dodged it
  pays sun-drops (more in a row). **Teaching**: the first time each danger meets
  you, time slows (0.3×) and a hint names the swipe until you make it
  (`save.taught`). **Head start** boost: the sun carries you 300 m at 2.6× over
  everything, landing on clear road (not on the daily dusk).
- **Second wind**: once per run — rise past what ended it, nearby jaguars gone,
  light ≥ 0.6, 1.5 s shield.
- **The look** (`codex.gd`): no real lights or shadows. Flat three-band shading
  from a fixed sun; painted colour only inside light circles (stone, up to 8
  braziers, dawn flood), bare night paper elsewhere; ink outline (inverted hull)
  black in light, pale in the dark; distance fades to the background colour.
  Glow geometry (flames, eyes, drops, lava) always shows. Paper grain is a
  multiplied texture over the 3D view (under the UI).

## Shop and themes

- Everything visual is data. Characters: `Themes.CHARACTERS`. Outfits, hats,
  boosts, treasury: `Shop`. Events: `Themes.EVENTS` (winter is the example),
  switched by the server's `/config` `event` (`GAME_EVENT` in sunstone-api
  .env; "none" = off), by the event's date window, or `files/dev_event`.
- Looks bought for sun-drops go in `save.owned`; looks sold for real money are
  non-consumable store products whose server grant is an entitlement equal to
  the item's id (`save.owns()` checks both). Product ids must match
  `sunstone-api` Purchases/Products.cs and Play Console. Sun-drop packs are the
  consumables. Boosts (Ember shield, Jaguar ward, Head start) are bought/used totals in the
  save, used automatically in a run.
- The shop's 3D preview is a SubViewport with its own world; it is painted
  because the title's daylight flood covers it — only open the shop on the title.

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
- **`files/dev_start`** (metres) starts every run that far along — to look at a
  given House (night 1 Houses begin at 0 / 138 / 276 m; night 2 at ~450).
  `files/dev_noflare` stops the autopilot blazing for jaguars.
- The Godot console wrapper can hang after an export finishes: wait for the APK
  timestamp to change, then stop the wrapper. Gradle sometimes takes ~10 min.
- **Renderer:** Android uses the Compatibility renderer (`rendering_method.mobile`).
  On the Tab A9 (Mali-G57) the Mobile renderer's fixed post-process cost alone
  is ~9 ms; Compatibility holds a locked 60. Verify pacing with
  `dumpsys SurfaceFlinger --latency '<SurfaceView layer>'` — every interval
  should be one vsync.
- **Dev switches:** `files/dev_light` (e.g. `0.3`) sets the starting light.
- **Perf switches** (dev): with autopilot on, logcat prints fps / frame-time /
  draw calls every 2 s. Flag files in `files/` toggle features without a rebuild:
  `perf_nomsaa`, `perf_noui`, `perf_noworld`, `perf_nograin`, `perf_novsync`,
  `perf_scale` (contents = 3D scale). Budget on the Tab A9: a locked 60 at
  ~250–320 draws and ~90k primitives.
- Chunk geometry is baked on a WorkerThreadPool task (`World._bake`) and
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
- Firebase project **`sunstone-95fce`** (Auth: anonymous, Google, email/password;
  Apple for iOS once the Mac work is done). The game talks
  to Firebase Auth over its REST API; the web API key comes from the Android app's
  `google-services.json` in this repo's root — **gitignored, never commit it**.
- Google sign-in web client id (public):
  `865615140000-9jk5kbkrjg2ip2lmckib1oohokvaiten.apps.googleusercontent.com`
- Debug keystore SHA-1 (register in Firebase for Google sign-in on test builds):
  `DB:66:45:43:4B:46:84:35:E8:50:2E:B7:81:C0:15:1D:DE:98:A6:3C`
- The server exchanges the Firebase ID token for its own JWT (`POST /api/v1/auth/firebase`).
- Dev API base URL (LAN, the dev PC): `http://192.168.0.141:8395`. Hosted later at
  `https://sunstone.pranta.dev`.
- **Accounts** (`online.gd`, Account page in `game_ui.gd`): everyone starts as a
  guest. Settings → Account offers Google (Apple on iOS) and **Use email**:
  - sign in to an email account (the phone switches to it, and the save merges);
  - create one (`accounts:signUp` *with the guest's idToken*, which links the
    email to the same uid; `accounts:update` is refused under email
    enumeration protection);
  - a reset link (`sendOobCode`).

  **Sign out** syncs first, then the phone starts fresh as a new guest.
  `online.links()` (from `accounts:lookup`) says which methods the account has.
- **Test accounts** for store review: FREE `test.user@sunstone.pranta.dev` and
  PREMIUM `test.user.premium@sunstone.pranta.dev` (Patron). The password is in
  the private `../sunstone-api/CLAUDE.md`, never in this public repo. They're made
  by `../sunstone-api/manage-test-users.cs` (`create` resets them).
- Testing on the tablet: back up `files/` (save.json, online.json, outbox.json)
  first and restore it after, or the demo accounts pick up local runs.

## Android plugins

- `android-plugins/google-signin/` — Kotlin source of the Google sign-in plugin
  (Credential Manager → Google ID token). Build: from that folder,
  `JAVA_HOME="C:/Program Files/Java/jdk-17.0.2" ./gradlew --no-daemon copyAar`
  (needs a `local.properties` with `sdk.dir=C:/Users/pranta/AppData/Local/Android/Sdk`).
  The AAR lands in `addons/sunstone_google_signin/bin/` (committed so exports work
  without rebuilding it); the editor plugin there adds it and its Maven deps to
  the Gradle export.
- Exports use the Gradle build (`android/build`, regenerated, gitignored).
- `addons/admob` (Poing Studios v5.1.0, only the core `ads` lib under
  `android/bin`) and `addons/GodotGooglePlayBilling` (3.3.0). Debug builds use
  Google's TEST ad units and test app id — never use live ad ids in development.
  `scripts/ads.gd` (consent → init → rewarded/interstitial, paced),
  `scripts/store.gd` (Play Billing; every purchase verified by the server).
  The server's `/config` switches ads and the store on/off.
- **Live ad ids (never committed):** `ads_config.json` in the repo root
  (`{"android": {"rewarded", "interstitial", "rewarded_interstitial"}, "ios": {…}}`,
  shipped with exports) and the AdMob App IDs in `override.cfg` (`[admob]` /
  `general/android/app_id`, `general/ios/app_id`). Both gitignored. Without them,
  release builds show no ads. The editor ignores `override.cfg`, so
  `addons/sunstone_overrides` applies it during **release** exports only (never
  saved to project.godot); debug exports keep Google's test app id.
- Between runs (paced) the game offers a **rewarded interstitial** behind an intro
  page with the reward, a countdown and "No thanks" (AdMob policy), or falls back
  to a plain interstitial. `files/dev_ads_eager` skips the pacing for testing.

## iOS

Prepared on Windows and finished on a Mac: **`IOS.md`** is the handoff (what's
done, what to ask the owner, the steps). iOS uses StoreKit 2 and Sign in with
Apple through GodotApplePlugins (installed on the Mac, gitignored). Its classes
don't exist on Android, so `apple_store.gd` and `online.gd` `link_apple()` use
them **untyped via ClassDB**; never name them as types.

## Release

- `--export-release "Android Play" build/sunstone.aab` → signed AAB. Upload key:
  `C:\android-keys\sunstone\` (outside the repo; password in
  `.godot/export_credentials.cfg`, gitignored). Upload SHA-1
  `61:D9:FE:78:02:71:C8:1E:9C:4E:3A:1B:12:0C:A1:A0:2C:6D:32:96`.
- Release builds call `https://sunstone.pranta.dev` (debug: the LAN dev API).
- Store copy, Data safety / content rating answers, IAP product table and the
  release checklist: **`store/LISTING.md`**. Art: `store/screenshots/{phone,tablet-7in,tablet-10in}/`
  and `store/feature-graphic.png`. Regenerate with `python tools/make_store_art.py`
  from raw shots in `store/raw/{phone,tablet}/` (gitignored, same file names as
  `SHOTS` in the tool).
- Privacy policy, terms and refund policy: `legal/{privacy,terms,refund}.md` (shown in-game
  under Settings → Privacy & terms; host the same files for the stores).

## Assets

All generated: models in code, audio by `tools/make_audio.py`, icon by
`tools/make_icon.py`. Fonts: Dela Gothic One + Nunito (OFL, `assets/fonts/`).
The music loop is set in `assets/audio/music.wav.import` (`edit/loop_mode=2`).
