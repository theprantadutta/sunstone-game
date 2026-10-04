# Sunstone — the game (Godot 4.7)

**Carry the sun through Xibalba.** In Maya myth the sun goes down into the
underworld every night and must cross it to rise at dawn. The explorer carries
the Sunstone — that sun — along a winding causeway through the Houses of
Xibalba (the Popol Vuh's trials). One run is a chain of nights; each night is
three Houses, then dawn.

One thumb, one decision: **how bright to be.** Holding blazes the Sunstone —
colour floods back into the world (outside the light it is bare ink on night
paper), the stone jaguars freeze, and the thumb steers. It burns light fast and
draws the bats of Camazotz. Letting go dims it to embers: the road leads you
back to its middle, light lasts, the dark closes in. The UI is the **Codex**
(Maya codex pages, glyph-block buttons). Store title **Sunstone: Dusk Run**
(launcher label "Sunstone"), package `com.pranta.sunstone`. Visual identity:
**`DESIGN.md`** — read it before touching UI or 3D art. Roadmap: **`PLAN.md`**.
The earlier lane runner (swipes, corners) is gone; its code is in git history
on `master` before the `xibalba` branch.

This repo is `sunstone-game`; its backend is the sibling repo `../sunstone-api`
(`G:\Personal\MyProjects\Sunstone\`). The game is a clean break from any
earlier project: no names, ids or assets carry over.

## Layout

```
project.godot / export_presets.cfg   portrait, Android uses Compatibility renderer
scenes/main.tscn        one node; everything is built in code by game.gd
scripts/
  game.gd               state machine (title → running → dying → results), the
                        run (blaze/steer, light, jaguars, bats, hazards, dawn),
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
  glyphs.gd             the 20 glyphs (achievements), earned by nights/blazes
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
- **The thumb.** Touch = blaze (light radius ember → 8.4 m) and steer: the
  runner keeps his place across the road and the drag moves him over
  (`STEER_SPAN` m per screen width). Let go = embers; he drifts back to the
  road's middle. Dodging always needs a touch.
- **Light** drains 0.014/s at embers, +0.075/s blazing (× House drain × Ember
  heart); sun-drops +0.055 (× Sun-drinker); a full trail of five = a
  "Sun-string" bonus (+3 drops); dawn gives back 0.35. Zero = "The Sunstone went
  out".
- **Jaguars** are frozen wherever any light reaches them (stone, braziers, the
  dusk/dawn flood); in the dark they come — at a creep from ahead, faster than
  you from behind. Stay dim > 2.2 s and one may pick up your trail.
  Jaguar's patience = they stay stone a moment after the light leaves.
- **Bats** come when you blaze for long (attraction builds while blazing, House
  "bat" factor) and steal 0.2 light on a hit; let go and they lose you. They
  move in the runner's frame.
- **Dangers**: off the road ("Stepped off the road into Xibalba"), pits (missing
  road cells), fallen stelae, obsidian blades. Death causes ≤ 60 chars.
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
  consumables. Boosts (Ember shield, Jaguar ward) are bought/used totals in the
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
  release checklist: **`store/LISTING.md`**. Art: `store/screenshots/{phone,tablet}/`
  and `store/feature-graphic.png`. Regenerate with `python tools/make_store_art.py`
  from raw shots in `store/raw/{phone,tablet}/` (gitignored, same file names as
  `SHOTS` in the tool).
- Privacy policy, terms and refund policy: `legal/{privacy,terms,refund}.md` (shown in-game
  under Settings → Privacy & terms; host the same files for the stores).

## Assets

All generated: models in code, audio by `tools/make_audio.py`, icon by
`tools/make_icon.py`. Fonts: Dela Gothic One + Nunito (OFL, `assets/fonts/`).
The music loop is set in `assets/audio/music.wav.import` (`edit/loop_mode=2`).
