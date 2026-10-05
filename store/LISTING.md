# Play Store listing — Sunstone: Dusk Run

Everything to paste into Play Console. Art is in this folder:
- `feature-graphic.png` (1024×500);
- `screenshots/phone/01–08.png` (1080×2160) for the phone slot;
- `screenshots/tablet/01–08.png` (1080×1728), which works for both the 7-inch and 10-inch tablet slots.

Rebuild them with `python tools/make_store_art.py`, from the raw shots in `raw/`
(gitignored). For a lived-in look, the shots used a showcase save and
temporary ranks runners, deleted again afterwards.
App icon: `assets/icon/icon.png` (512×512 export of it for the listing).

## App details

- **App name** (30 max): `Sunstone: Dusk Run`
- **Package**: `com.pranta.sunstone`
- **Category**: Game → Arcade
- **Tags**: Runner, Arcade, Casual, Offline (playable offline)
- **Contact email**: prantadutta1997@gmail.com
- **Website**: https://pranta.dev
- **Privacy policy URL**: *(host `legal/privacy.md` — e.g. https://pranta.dev/sunstone/privacy)*

## Short description (80 max)

Carry the sun through the Maya underworld. Hold to blaze, let go to hide.

## Full description (4000 max)

Every night, the sun goes down into Xibalba, the Maya underworld, and must cross it to rise again at dawn. Tonight, you carry it.

Sunstone: Dusk Run is a one-thumb runner unlike any other. Your Sunstone is the only light on a winding causeway through the dark, and you decide how bright it burns.

HOLD TO BLAZE
Touch and hold and the Sunstone blazes. Colour floods back into the world, you can steer across the road, and the stone jaguars freeze where they stand. But a blaze burns your light fast.

LET GO TO HIDE
Let go and the stone dims to embers. Your light lasts, and the road leads you on. But in the dark, the jaguars wake, and you'll see their eyes coming.

A WORLD PAINTED BY YOUR LIGHT
Sunstone looks like a Maya codex come to life. Outside your light, the underworld is bare ink on night paper. Inside it, everything is painted in cinnabar, ochre and Maya blue. Every blaze paints the world back in.

THE HOUSES OF XIBALBA
Each night is three Houses from the Popol Vuh, each with its own rules and its own look:
- House of Jaguars: stone guardians that only move in the dark
- House of Bats: they hunt bright light, so blaze too long and they swoop in
- House of Gloom: even your embers barely glow
- House of Knives: obsidian blades in the road
- House of Cold: your light drains faster
- House of Fire: braziers, lava, and what waits between them

MAKE IT TO DAWN
Survive the three Houses and the sun rises. Then the next night begins, faster and harder, with new Houses. How many dawns can you reach?

SUN-DROPS AND SUN-STRINGS
Sun-drops feed your light. Most lie off the middle of the road, so taking them means steering, and steering means blazing. Take a whole trail for a Sun-string bonus.

MORE TO PLAY FOR
- Daily dusk: the same road for everyone, once a day, named for its day in the Maya calendar
- Ranks: race players everywhere on the daily dusk, the week and all time
- Twenty glyphs to earn, each drawn like a scribe's sign
- Offerings: a gift for every day you come back
- Records of your deepest night, longest run and more

YOUR RUNNER, YOUR WAY
Choose your runner, then dress them in outfits and hats, and pick the colour of your Sunstone's light. Try everything on in a live 3D preview before you buy. Charms make your light last longer, and boosts can save a run: an Ember shield relights your stone, a Jaguar ward turns a pouncing jaguar to stone.

SEASONS IN THE UNDERWORLD
Special nights arrive with the seasons, with new scenery, new looks and new surprises.

MADE FOR ONE THUMB
Simple to pick up, hard to master. Play in short bursts or chase one more dawn. Your progress is saved to your account, so sign in with Google to keep it on any phone.

Sunstone: Dusk Run is free to play. It contains ads and optional in-app purchases. You can remove ads with a one-time purchase.

Carry the sun. Make it to dawn.

## Content rating (IARC questionnaire)

- Category: **Game**
- Violence: **cartoon/fantasy, non-realistic** — the runner stumbles or falls; stone jaguars "catch" him (no blood, no gore, no injury shown). Answer *No* to realistic violence, blood, gore.
- Fear: mild (chased in the dark) — no horror imagery.
- Sexuality, language, drugs, alcohol, tobacco, gambling: **No**.
- User interaction: **Yes** — players choose a display name shown on public leaderboards (no chat, no user-generated content beyond the name).
- Shares location: **No**. Digital purchases: **Yes**.
- Expected rating: Everyone / PEGI 3–7.

## Target audience

**13 and over** (not designed for children; the game shows ads). Answer "No" to
"Could the app appeal to children?" only if the store listing/art stays as is.

## Data safety form

Overview: collects data **Yes**; all of it encrypted in transit **Yes** (HTTPS: the
API once hosted on https, Firebase, AdMob, Play); accounts: guest by default,
optional **username/password (email)** and **OAuth (Google)** sign-in; users can
delete their account **in the app** (Settings → Account → Delete account) and
**on the web** (the deletion URL below); partial deletion on request **No**.

"Shared" follows Play's meaning: service providers working for us (Firebase, the
server host) are not sharing. Data the AdMob SDK sends to Google for ads is.
Nothing is processed ephemerally only.

| Category → type | Shared | Required? | Purposes |
|---|---|---|---|
| Personal info → Name (runner name, auto-made, changeable) | No | Required | App functionality, Account management |
| Personal info → Email address (Google / email sign-in) | No | Optional | App functionality, Account management |
| Personal info → User IDs (Firebase uid, player id) | No | Required | App functionality, Analytics, Fraud prevention/security, Account management |
| Financial info → Purchase history (product, order id, receipt) | No | Optional | App functionality, Fraud prevention/security |
| Location → Approximate location (from IP, by AdMob) | Yes | Required | Advertising or marketing, Analytics, Fraud prevention/security |
| App activity → App interactions (our gameplay events; AdMob ad interactions) | Yes | Required | Analytics, Advertising or marketing, Fraud prevention/security |
| App activity → Other actions (runs, scores, cloud save) | No | Required | App functionality, Fraud prevention/security |
| App info and performance → Diagnostics (by AdMob) | Yes | Required | Analytics, Fraud prevention/security |
| Device or other IDs (advertising ID, app set ID; by AdMob) | Yes | Required | Advertising or marketing, Analytics, Fraud prevention/security |

Not collected: phone, address, other personal info, payment info (Play handles
it), precise location, messages, photos/videos, audio, files, calendar,
contacts, health, web browsing, installed apps, search history, crash logs.

- Account deletion URL (Play requires a web link): host a page explaining
  Settings → Account → Delete account, or email prantadutta1997@gmail.com.

## App access (Play Console → App content → App access)

Everything can be played without an account, but give reviewers both test
accounts so they can check sign-in and the paid perks. Choose "All or some
functionality is restricted" and add two sets of instructions:

The password is in the private `sunstone-api/CLAUDE.md` (this repo is public).

```
Free account
Username: test.user@sunstone.pranta.dev
Password: <from sunstone-api/CLAUDE.md>
Settings (top right) → Account → Use email → enter the email and password → Sign in.
```

```
Premium account (owns "Patron of the temple": no ads between runs, the Obsidian hue, 2,500 sun-drops)
Username: test.user.premium@sunstone.pranta.dev
Password: <from sunstone-api/CLAUDE.md>
Settings (top right) → Account → Use email → enter the email and password → Sign in.
To switch accounts: Settings → Account → Sign out, then sign in with the other one.
```

Re-create or reset them any time with `dotnet run manage-test-users.cs` in
`sunstone-api` (they need the hosted API to work in release builds).

## Ads

- "Contains ads": **Yes**.
- AdMob app + units: *(user creates; IDs go in the gitignored config, see CLAUDE.md)*.

## In-app products (create in Play Console → Monetize → In-app products)

Must match `sunstone-api/src/Sunstone.Api/Purchases/Products.cs` and
`scripts/store.gd` exactly. All one-time products (not subscriptions).

| Product ID | Name | Description | Suggested price | Type in game |
|---|---|---|---|---|
| `sunstone_remove_ads` | Remove ads | No ads between runs. Offers you choose stay. | US$2.99 | non-consumable |
| `sunstone_patron` | Patron of the temple | No ads, 2,500 sun-drops and the Obsidian hue. | US$4.99 | non-consumable |
| `sunstone_drops_small` | A pouch of sun-drops | 1,000 sun-drops. | US$0.99 | consumable |
| `sunstone_drops_medium` | A jar of sun-drops | 5,500 sun-drops. | US$3.99 | consumable |
| `sunstone_drops_large` | A chest of sun-drops | 12,000 sun-drops. | US$7.99 | consumable |

## Release checklist

1. Host the API at `https://sunstone.pranta.dev` (release builds talk to it).
2. Host `legal/privacy.md`, `legal/terms.md`, `legal/refund.md` and the account-deletion
   page; paste the URLs above.
3. Create the app in Play Console (package `com.pranta.sunstone`), upload
   `build/sunstone.aab` (`--export-release "Android Play"`) to **closed testing**.
4. After the first upload: copy the **app signing key SHA-1** from Play Console →
   Setup → App signing into Firebase (Android app) so Google sign-in works in
   Play-installed builds. Also add the upload key SHA-1:
   `61:D9:FE:78:02:71:C8:1E:9C:4E:3A:1B:12:0C:A1:A0:2C:6D:32:96`.
5. Replace `sunstone-api/google-play-service-account.json` (currently a copy of the
   Firebase admin key) with a real Play service account, invited in Play Console
   with "View financial data" — then purchases verify.
6. Create the in-app products above; set `GAME_STORE_OPEN=true` on the server.
7. AdMob: app + rewarded + interstitial units → config; `GAME_ADS_ENABLED=true`.
8. Closed test (12 testers × 14 days if your account needs it) → production.
