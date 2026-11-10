# iOS — handoff for the Mac

Everything that could be done on Windows is done. What's left needs a Mac with
Xcode. This is written for a coding agent (or a person) on that Mac. Read
`CLAUDE.md` first: the house rules there still apply. Never commit config or
key files. Ask the owner before touching any external account (App Store
Connect, Firebase, AdMob). Commit messages carry no co-author or AI lines.

## Before anything else: three files from the owner

A fresh clone on the Mac is missing three gitignored files that only live on
the owner's Windows PC. **At the start of a Mac session, check for them and, if
any is missing, ask the owner to copy them over** (AirDrop or USB, never chat
or email). Everything else the Mac needs is already on the Mac.

| File (repo-relative) | What it holds | Without it |
|---|---|---|
| `ads_config.json` | Live AdMob ad unit ids (`android` and `ios` blocks) | Release builds show no ads |
| `override.cfg` | Live AdMob App IDs (`[admob]` `general/android/app_id`, `general/ios/app_id`) | Release builds keep Google's test App ID |
| `.godot/export_credentials.cfg` | The export presets' saved passwords (keystore and signing) | Release exports can't sign |

Copy `.godot/export_credentials.cfg` as that one file only, not the rest of
`.godot/` (a cache Godot rebuilds). All three stay gitignored: never commit them.

```bash
for f in ads_config.json override.cfg .godot/export_credentials.cfg; do [ -f "$f" ] || echo "MISSING: $f"; done
```

## What already exists

| Piece | Where | State |
|---|---|---|
| iOS export preset | `export_presets.cfg` → `[preset.2]` "iOS" | bundle `com.pranta.sunstone`, iOS 17.0, iPhone & iPad, Sign in with Apple entitlement, ATT text, LAN dev-API exceptions. **Team ID empty.** |
| Ads | `scripts/ads.gd` + `addons/admob` (Poing v5.1.0) | Same code as Android: UMP consent → init → rewarded / interstitial / **rewarded interstitial**. iOS units in `ads_config.json` (`"ios"` block). Debug builds use Google's iOS test units. The AdMob iOS lib adds the SKAdNetwork ids and pulls the Google Mobile Ads SDK through Swift Package Manager. |
| Live AdMob App ID | `override.cfg` → `general/ios/app_id` | Applied to **release** exports only, by `addons/sunstone_overrides` (the editor ignores override.cfg). Debug = Google's test App ID. |
| Purchases | `scripts/store.gd` → `scripts/apple_store.gd` | StoreKit 2 through **GodotApplePlugins** (not installed yet, see step 3). Every transaction's JWS goes to `POST /api/v1/purchases/verify` with `store: "apple"`, and is finished only after the server grants it. |
| Server check | `sunstone-api` `Purchases/AppleVerifier.cs` | Verifies the JWS offline: chain to Apple Root CA G3, marker OIDs, bundle id, product. Accepts Sandbox, because App Review buys in Sandbox. Tested (`AppleVerifierTests`). |
| Sign in with Apple | `scripts/online.gd` `link_apple()`, Account page | On iOS the Account page offers **Sign in with Apple** instead of Google (rule 4.8), next to **Use email** (email/password works on iOS as is, with nothing native). Uses GodotApplePlugins' `ASAuthorizationController` → Firebase `signInWithIdp` with `providerId=apple.com`. |
| Firebase on iOS | `scripts/online.gd` | Reads the API key from `res://GoogleService-Info.plist` (gitignored; falls back to `google-services.json`) and sends `X-Ios-Bundle-Identifier`. |
| Rating prompt | `scripts/game.gd` → `store.request_review()` | StoreKit's `request_review`, same pacing as Android. |
| Safe area | `scripts/game_ui.gd` `_safe_top()` | Top inset (notch / Dynamic Island) applied on iOS. |

All Apple-plugin code is **untyped** and found through `ClassDB`
(`ClassDB.class_exists("StoreKitManager")`), because those classes don't exist
on Android. Keep it that way. Naming `StoreKitManager`, `StoreTransaction` or
`ASAuthorizationController` as a type anywhere breaks the Android build.

## Ask the owner for these first

1. **Apple Team ID**: it goes in the preset (`application/app_store_team_id`).
2. **App Store Connect app**: bundle id `com.pranta.sunstone`, name "Sunstone: Dusk Run".
   On the App ID, enable **Sign in with Apple** and **In-App Purchase**.
3. **In-app purchases** in App Store Connect, using the same ids as Play (see `store/LISTING.md`):
   - `sunstone_remove_ads`, `sunstone_patron`: non-consumable
   - `sunstone_drops_small`, `sunstone_drops_medium`, `sunstone_drops_large`: consumable
4. **Firebase** (project `sunstone-95fce`):
   - Add an **iOS app** with bundle `com.pranta.sunstone`. Put its `GoogleService-Info.plist` in this repo's root. It is gitignored: never commit it.
   - Enable the **Apple** sign-in provider. Native iOS sign-in needs only the bundle id. The Services ID and key fields are for web/Android and can stay empty.
5. **AdMob → Privacy & messaging**:
   - an iOS **GDPR** message;
   - an **IDFA explainer** message. The UMP flow in `ads.gd` then shows Apple's tracking prompt (ATT) at the right moment. Without it, iOS ads are non-personalised.
6. The **Android rewarded interstitial unit id**, if `ads_config.json` still has `""` there. This is not needed for iOS.

## Steps on the Mac

1. **Tools.**
   - Xcode (current).
   - Godot **4.7.2-stable** for macOS, plus its export templates (Editor → Manage Export Templates; they include `ios.zip`).
   - Run Godot headless as described in CLAUDE.md, and don't leave windows open on the owner's screen.
2. **Get the project.** Clone both repos side by side into a `Sunstone/` folder:
   - `https://github.com/theprantadutta/sunstone-game` (public)
   - `https://github.com/theprantadutta/sunstone-api` (private)

   On the owner's own Mac everything below is already in place except the three
   files at the top of this doc. On a different Mac, ask the owner for these
   gitignored files too (they never go to GitHub):
   - `google-services.json`, `ads_config.json`, `override.cfg`;
   - `addons/admob/ios/bin/` (AdMob iOS libs). If it is missing, unzip `ios-template-v4.7.2.zip` into it, keeping at least `ads/` and `package.gd`. The zip is at https://github.com/poingstudios/godot-admob-plugin/releases/download/v5.1.0/ios-template-v4.7.2.zip.
   - `GoogleService-Info.plist`, from step 4 above.
3. **Install GodotApplePlugins** (MIT, by Miguel de Icaza).
   - Release used when this was written: https://github.com/migueldeicaza/GodotApplePlugins/releases/download/build-a6d667dda4d4f7b008009d3704f679b06f81424f/GodotApplePlugins-addons-a6d667dda4d4f7b008009d3704f679b06f81424f.zip (51 MB zip, about 294 MB unpacked).
   - The zip extracts to `dist/addons/…`. Copy **only** these into `addons/`:
     - `GodotApplePluginsRuntime` (required by the others)
     - `GodotApplePluginsStoreKit`
     - `GodotApplePluginsAuthenticationServices`
   - Add those three folders to `.gitignore`; they are huge.
   - Run `godot --headless --path . --import` once.
   - Then **re-run the Android debug export** to confirm Android still builds. These GDExtensions have no Android library, so Godot should only warn. If the warning ever becomes an error, add `addons/GodotApplePlugins*` to the Android presets' `exclude_filter`.
4. **Team ID** → `application/app_store_team_id` in `[preset.2.options]`. This value is fine to commit.
5. **Export.** Set `application/export_project_only=true` and run `godot --headless --path . --export-debug "iOS" build/ios/Sunstone.xcodeproj`. Then in Xcode:
   - Open the project and turn on automatic signing with the team. Xcode resolves the Google Mobile Ads Swift package; it needs network access.
   - Check that the **Sign in with Apple** and **In-App Purchase** capabilities show in Signing & Capabilities. Add them there if the entitlement didn't carry.
   - Run on a real iPhone.
6. **Test on the device** (debug build = Google test ads, **production API**):
   - On iOS every build calls `https://sunstone.pranta.dev` (`online.gd`: the LAN dev API is used only by Android debug builds), so test runs and guests land in the production database. To use a local API instead, put its URL in a `files/api_base` file in the app's user dir. iOS asks for **local network** access the first time; allow it. The preset sets `NSAllowsLocalNetworking` for this.
   - Sign-in: a guest account appears and runs and the cloud save sync. Watch the Xcode console for `[online]` lines.
   - **Ads**:
     - the consent form, then the ATT prompt (if the IDFA message is set up);
     - "Watch: double" on results;
     - Second wind "Watch to rise";
     - the **rewarded interstitial** between runs: the intro page "The temple's gift" with a countdown and "No thanks", then the ad, then +50 sun-drops. A `files/dev_ads_eager` file skips the pacing.
   - **Purchases**: use a Sandbox tester, or a StoreKit configuration file in Xcode with the five product ids.
     - Buy a drops pack: the server log shows the verify, the drops land, and the transaction finishes, so it doesn't come back on relaunch.
     - Buy Remove ads, then Restore.
     - A StoreKit configuration file signs with Xcode's local certificate, **not** Apple's. The server will refuse those (400) by design. Use Sandbox to test the full server path.
   - **Sign in with Apple**: Account page → the black Apple button. It must show the Apple logo; that is the `U+F8FF` glyph from the system font. If the logo is missing, use Apple's official button artwork; App Review rejects off-spec buttons.
     - Known gap: the plugin sets **no nonce**. Firebase should accept a token without one, but if `signInWithIdp` answers `MISSING_OR_INVALID_NONCE`, fork the plugin's `ASAuthorizationController.swift`: set `request.nonce = sha256(raw)` and expose `raw`. Then add `&nonce=<raw>` to the postBody in `online.gd` `link_apple()`.
   - **Layout**: check the top inset on a notch or Dynamic Island phone. Also check the **bottom** home-indicator area; only the top inset is handled today. Check an iPad too: the UI is portrait and scales.
   - **Rating prompt**: it shows in debug builds every time it is called, so a 500 m+ best after 5 runs triggers it.
7. **Release.**
   - Run `--export-release "iOS"`. The release build calls `https://sunstone.pranta.dev` and gets the live AdMob App ID.
   - Archive in Xcode and upload to TestFlight.
   - App Store privacy labels: match the Data safety table in `store/LISTING.md`. Tracking is "Yes" only if ATT is on. The AdMob SDK ships its own privacy manifest.
   - Age rating: the same answers as the IARC section.

## If the game won't run on the Mac (notes from the Windows side)

Written by the session that built the game, for whoever picks it up on a Mac.
The Simulator was never tried from Windows, so treat this as a map, not a log.

**Simulator or device?** The Simulator should work on an Apple Silicon Mac:
Godot 4.7.2's iOS templates carry simulator slices, and the game uses the
Compatibility renderer on mobile (`project.godot`
`renderer/rendering_method.mobile="gl_compatibility"`); keep it that way, since
the Mobile/Vulkan renderer is the one that struggles in the Simulator and was
too slow on the Android test tablet anyway. The Simulator needs no Team ID or
signing; a real iPhone does. Use the Simulator for UI, menus, sign-in with
email, runs, ranks and test ads; a real iPhone for swipe feel, frame rate and
real sandbox purchases. Simulator frame rates mean nothing.

**Command-line path** (no Godot window on the owner's screen):

```bash
godot --headless --path . --import
godot --headless --path . --export-debug "iOS" build/ios/Sunstone.xcodeproj
xcodebuild -project build/ios/Sunstone.xcodeproj -scheme Sunstone   -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16'   -derivedDataPath build/ios/dd build
xcrun simctl boot "iPhone 16" 2>/dev/null; open -a Simulator
xcrun simctl install booted "$(find build/ios/dd -name '*.app' -path '*iphonesimulator*' | head -1)"
xcrun simctl launch --console booted com.pranta.sunstone   # game prints show here
```

(The scheme and device names may differ: `xcodebuild -list` and
`xcrun simctl list devices` tell you.)

**When it fails, in the order I'd suspect:**

1. **Export fails before Xcode.** The export templates must be exactly
   4.7.2-stable (Godot refuses others), and the iOS preset needs
   `export_project_only=true` from the headless command line. If GDScript parse
   errors appear, run `--import` once: new `class_name` scripts need it.
2. **Linking fails for the Simulator** ("building for iOS Simulator, but linking
   in object file built for iOS"). A native plugin has no simulator slice:
   the AdMob iOS libs (`addons/admob/ios/bin`) or GodotApplePlugins. For a
   Simulator-only build, leave that plugin out of the export (its plugin
   checkbox in the iOS preset, or `exclude_filter`) and build again. Without GodotApplePlugins
   the game is fine: `apple_store.gd` checks `ClassDB.class_exists("StoreKitManager")`
   and the store just says it's closed. Without the AdMob libs it's
   **unverified**: `ads.gd` calls the addon's `MobileAds` wrapper
   (`MobileAds.initialize`), which should only warn when its native singleton is
   missing; if it errors instead, guard that call with `Engine.has_singleton(...)`
   for Simulator builds. Put both back for device builds.
3. **Google Mobile Ads package won't resolve.** Xcode pulls it through Swift
   Package Manager on the first build; it needs network access. File → Packages
   → Reset Package Caches, then build again.
4. **Black or empty screen.** Check the console for renderer errors first. The
   boot splash is the k'in glyph on plum (`#2a1b3d`); a plum screen that never
   reaches the title means the main scene stalled, usually a script error at
   startup: read the console. Apple-plugin classes must stay untyped and found
   through `ClassDB` (see above); a typed reference to one breaks the build.
5. **Starts, but nothing online works.** Expected offline: the game is fully
   playable as a guest without the server, and runs queue in an outbox. Online
   needs `GoogleService-Info.plist` (Firebase Auth over REST) and the production
   API at `https://sunstone.pranta.dev`; `GET /health` there should answer
   `{"status":"ok"}`.
6. **Taps act twice, or toggles flip back.** That's the touch-then-emulated-click
   behaviour described in CLAUDE.md; custom controls handle it. If something new
   misbehaves on iOS only, look there first.

**Android-only on purpose (don't chase these on iOS):** the
`SunstoneGoogleSignIn` plugin, so Google sign-in (iOS uses Sign in with Apple
and email), notifications (`push.gd`), Firebase Analytics and Crashlytics
(`firebase.gd`, release Android only), Play in-app updates, run-card sharing
and the refresh-rate lock. All are guarded by `Engine.has_singleton(...)`, so
they're silent no-ops on iOS. The **Sunstone Pass** subscription is Play only
too; on iOS its shop tab says it opens soon.

**Dev switches** are files in the app's user dir (Godot's `user://`). In the
Simulator: `xcrun simctl get_app_container booted com.pranta.sunstone data`,
then the files go where Godot's user dir lives inside it (on iOS that's
`Documents/`). The useful ones: `autopilot` (plays itself), `dev_start`
(start metres), `dev_untaught` (every hint again), `dev_ads_eager` (no ad
pacing), `api_base` (another server). The full list is in CLAUDE.md.

**Checks that run anywhere** (headless, no device): parse a script with
`godot --headless --path . --check-only --script scripts/<x>.gd`, the save
merge with `godot --headless --path . -s dev/check_save_merge.gd`, the calendar
with `-s dev/check_calendar.gd`.

## Not done yet (decide with the owner)

- **Cross-platform progress.**
  - A player who linked Google on Android and later signs in with Apple on iOS gets two separate accounts.
  - Fix option 1: offer Google sign-in on iOS too, through Google's iOS SDK. Apple still has to be offered alongside it.
  - Fix option 2: let a signed-in player link a second provider (Firebase account linking). Either way needs a small native piece or plugin.
- **App Store Server Notifications** (refunds) are not wired. A refunded purchase stays granted. It is cheap to add later as `POST /api/v1/purchases/apple-notify`, verifying the signed payload with the same `AppleVerifier` chain check.
- No CI. A GitHub Actions macOS runner could build and upload to TestFlight. The repos are on GitHub now; it would need the signing secrets.
