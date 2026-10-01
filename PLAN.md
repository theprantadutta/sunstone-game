# Sunstone: Dusk Run — plan to a full release

Store title **Sunstone: Dusk Run**, package `com.pranta.sunstone`, a brand-new Play
listing. Two repos under `G:\Personal\MyProjects\Sunstone\`: **`sunstone-game`**
(this one, Godot) and **`sunstone-api`** (.NET). Everything a finished mobile game
needs — accounts, leaderboards, a currency and shop, achievements, daily rewards, a
daily challenge, ads, purchases, cloud save, crash reporting, analytics, legal — is
built new for this game and its Codex identity. Nothing ships that looks like any
other mobile game.

Work goes one phase at a time, each tested on the tablet and committed.

## Architecture decisions

| Concern | Choice | Why |
|---|---|---|
| Engine | Godot 4.7, Android first | already built; iOS later |
| Identity | **Google Play Games Services** (silent sign-in), guest fallback | no sign-in button; official Godot plugin |
| Server | **.NET 10 API, repo `sunstone-api`**, written fresh (proven patterns: JWT, Play purchase verification, ad SSV) | clean names, clean schema, no history |
| Leaderboards | own server, shown as codex pages | Google's UI would break the identity; server-side validation |
| Purchases | official Godot Play Billing plugin + server verification | grants only after Google confirms the token |
| Ads | AdMob (Poing Studios plugin) + UMP consent + server-side reward verification | |
| Crashes | Sentry (official Godot SDK) | Firebase has no Godot SDK |
| Analytics | a small batched events endpoint on our server | no Firebase; we own the funnel |
| Kill switches | server `/config`: ads on/off, interstitial pacing, store open | change behaviour without a release |

Firebase is dropped entirely.

## Phases

### 1. The game, complete offline
- [x] 1a. Save v2 (versioned; sun-drop bank, stats, unlocks, glyphs, offerings), a title menu
      in codex style (Run · Daily dusk · Market · Glyphs · Records), Records page (stats)
- [x] 1b. **Daily dusk**: one seeded causeway per UTC day, the same for everyone; its own best
- [ ] 1c. **Glyphs** (achievements, ~20, paying sun-drops) and **Offerings** (7-day login calendar)
- [ ] 1d. **Market**: charms (permanent perks: slower drain, longer freeze, brighter drops — 3 tiers
      each), explorer garbs and stone hues (cosmetics); **Second wind** (one continue per run)

### 2. Android platform layer
- [ ] Gradle build template; Sentry; Play Games sign-in (silent) with guest fallback
- [ ] Release signing (new upload keystore), AAB export, version scheme

### 3. Server (`sunstone-api`)
- [ ] Auth: Play Games server auth code → JWT; guest device accounts that upgrade in place
- [ ] Runs + validation (distance vs time vs speed curve, drop and seed checks)
- [ ] Leaderboards: daily, weekly, all-time, daily dusk — top N + your rank
- [ ] Cloud save (snapshot/sync), events (analytics), `/config` (kill switches)
- [ ] Account deletion (Play policy), purchases verify, ad reward verification (SSV)
- [ ] Docker + compose deploy at `sunstone.pranta.dev`

### 4. Online in the game
- [ ] Leaderboard pages, cloud restore on a new device, account page (link / delete)

### 5. Monetization
- [ ] Rewarded: second wind, double sun-drops on results, bigger offering
- [ ] Interstitial between runs, paced (never in the first runs, never twice close together)
- [ ] Purchases: remove ads, supporter pack, sun-drop packs; restore purchases

### 6. Release
- [ ] Privacy policy + terms (hosted), Data safety form answers, content rating answers
- [ ] Store listing: icon, feature graphic, screenshots (from the tablet), copy
- [ ] In-app review prompt, in-app update
- [ ] Closed test → production

## Needs from you (when we reach them)
- Play Console: create the app; check whether the closed-test rule applies to your account
- Play Games Services: enable for the app (I'll give exact steps)
- Sentry: a project DSN · AdMob: app + ad units · server: deploy access + DNS for
  `sunstone.pranta.dev`
