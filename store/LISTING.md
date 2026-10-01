# Play Store listing — Sunstone: Dusk Run

Everything to paste into Play Console. Art is in this folder:
`feature-graphic.png` (1024×500) and `screenshots/01–06.png` (1080×2160, phone).
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

```
Run a Maya causeway at dusk. Keep the Sunstone lit. Outrun the stone jaguars.
```

## Full description

```
The sun is setting over the temple, and you have just stolen the Sunstone.

Every run starts at sunset and runs into the night. As the light fades, the glowing stone in your hand becomes the only light on the causeway — and the stone jaguars that guard the temple only move in the dark. Gather sun-drops to keep the Sunstone lit. When the jaguars close in, tap to flare it and turn them back to stone.

Swipe to change lanes and turn the corners, jump fallen logs, slide under the arches, and see how far into the night you can run.

• A run that changes as you go: sunset, twilight, moonrise, deep night
• The Daily dusk: one causeway for everyone each day, named by the Maya calendar
• Twenty glyphs to earn, each drawn like a scribe's sign
• Daily offerings from the temple that wait for you if you miss a day
• Charms, explorer garbs and stone hues to spend your sun-drops on
• Ranks for the daily dusk, today, this week and all time
• Your progress follows you: sign in with Google to keep it on any phone
• Plays offline; the ranks catch up when you're back

A painted Maya world at dusk, and a codex-styled interface you won't find in any other runner.
```

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

Data **collected** (all encrypted in transit; users can request deletion — in-app
Settings → Account → Delete account):

| Data type | Collected | Shared | Why |
|---|---|---|---|
| Email address | Yes, optional (only if the player links Google) | No | Account management |
| User IDs (Firebase uid, our player id) | Yes | No | Account management, app functionality |
| Name (runner display name) | Yes, optional to change | No (shown on ranks in-app) | App functionality |
| Purchase history | Yes | No | App functionality (granting purchases) |
| App interactions (gameplay events) | Yes | No | Analytics |
| Other in-app content (runs, save) | Yes | No | App functionality |
| Device or other IDs (advertising ID) | Yes — by AdMob | Yes, with Google (AdMob) | Advertising |
| Approximate location from IP | Yes — by AdMob | Yes, with Google (AdMob) | Advertising |
| Crash logs / diagnostics | No | — | — |

- Is data encrypted in transit? **Yes** (HTTPS) — once the API is hosted on https.
- Can users request deletion? **Yes** — in the app and by email.
- Account deletion URL (Play requires a web link too): *(host a page explaining:
  open Settings → Account → Delete account, or email prantadutta1997@gmail.com)*

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
2. Host `legal/privacy.md` and the account-deletion page; paste the URLs above.
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
