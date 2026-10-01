# Sunstone: Dusk Run — plan to a full release

Store title **Sunstone: Dusk Run**, package `com.pranta.sunstone`, a brand-new Play
listing. Two repos under `G:\Personal\MyProjects\Sunstone\`: **`sunstone-game`**
(this one, Godot) and **`sunstone-api`** (.NET). Everything a finished mobile game
needs — accounts, leaderboards, a currency and shop, achievements, daily rewards, a
daily challenge, ads, purchases, cloud save, analytics, legal — is
built new for this game and its Codex identity. Nothing ships that looks like any
other mobile game.

Work goes one phase at a time, each tested on the tablet and committed.

## Architecture decisions

| Concern | Choice | Why |
|---|---|---|
| Engine | Godot 4.7, Android first | already built; iOS later |
| Identity | **Firebase Auth** over its REST API: anonymous guest first, Google later (same uid, progress kept) | the server verifies Firebase tokens against Google's keys — no Admin SDK |
| Server | **.NET 10 API, repo `sunstone-api`**, written fresh (proven patterns: JWT, Play purchase verification, ad SSV) | clean names, clean schema, no history |
| Leaderboards | own server, shown as codex pages | Google's UI would break the identity; server-side validation |
| Purchases | official Godot Play Billing plugin + server verification | grants only after Google confirms the token |
| Ads | AdMob (Poing Studios plugin) + UMP consent + server-side reward verification | |
| Crashes | none for now (user decision) — revisit before release | |
| Analytics | a small batched events endpoint on our server | no Firebase; we own the funnel |
| Kill switches | server `/config`: ads on/off, interstitial pacing, store open | change behaviour without a release |

Firebase is used for sign-in only (the user is creating the project); analytics and
analytics go through our own server.

## Phases

### 1. The game, complete offline
- [x] 1a. Save v2 (versioned; sun-drop bank, stats, unlocks, glyphs, offerings), a title menu
      in codex style (Run · Daily dusk · Market · Glyphs · Records), Records page (stats)
- [x] 1b. **Daily dusk**: one seeded causeway per UTC day, the same for everyone; its own best
- [x] 1c. **Glyphs** (achievements, ~20, paying sun-drops) and **Offerings** (7-day login calendar)
- [x] 1d. **Market**: charms (permanent perks: slower drain, longer freeze, brighter drops — 3 tiers
      each), explorer garbs and stone hues (cosmetics); **Second wind** (one continue per run)

### 2. Android platform layer
- [ ] Gradle build template; Firebase Auth sign-in (guest done; Google needs a native plugin)
- [x] Release signing (new upload keystore), AAB export (Android Play preset), version 1.0.0 (1)

### 3. Server (`sunstone-api`)
- [x] Database `sunstone` created on the production Postgres server; schema migrated
- [x] Auth: Firebase ID token → our JWT (answers 503 until the Firebase project exists)
- [x] Runs + validation (top speed, drop spacing, flare budget, daily-key window); idempotent
- [x] Leaderboards: daily dusk, day, week, all-time — top N + your place
- [x] Cloud save (optimistic revisions), events (analytics), `/config` (kill switches)
- [x] Account deletion (cascades everywhere), rename; 27 tests
- [ ] Deploy with Docker + compose at `sunstone.pranta.dev` (needs server access + DNS)
- [ ] Purchases verify, ad reward verification (SSV) — with phase 5

### 4. Online in the game
- [x] Silent guest sign-in (Firebase REST) → our JWT; run outbox (offline-safe)
- [x] Ranks page: daily dusk, today, week, all time — top 10 + your place
- [x] Cloud save merge (earned/spent totals, unions, max records); analytics events
- [x] Account page: rename, delete account (server + Firebase + fresh phone)
- [ ] Link Google to keep progress across reinstalls (needs phase 2's native sign-in)

### 5. Monetization
- [x] Rewarded: second wind, double sun-drops on results, double offering (test ads)
- [x] Interstitial between runs, paced (never in the first runs, never twice close together)
- [x] Purchases: remove ads, patron pack, sun-drop packs; restore — code + server verification (needs Play Console products)

### 6. Release
- [x] Privacy policy + terms (in game; hosting pending), Data safety + content rating answers (store/LISTING.md)
- [x] Store listing: feature graphic, 6 phone screenshots, copy (store/)
- [ ] In-app review prompt, in-app update
- [ ] Closed test → production

## Needs from you (when we reach them)
- **Firebase project** for Sunstone with Authentication (anonymous + Google) — you offered to
  set this up together; then `FIREBASE_PROJECT_ID` goes in `sunstone-api/.env`
- Play Console: create the app; check whether the closed-test rule applies to your account
- AdMob: app + ad units (ask before creating anything) · server hosting later (user)
