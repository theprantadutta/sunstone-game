# Translating Sunstone

`strings.csv` holds the game's text: the `keys` column is the English source, and each other
column is one locale (hi, bn, ar, pt = Brazilian Portuguese, id, es = Latin American Spanish,
tr, ru, de, it, vi). Rebuild the key list with `python tools/i18n_extract.py`, which keeps
existing translations. An empty cell shows English in the game.

## Rules
- **Placeholders**: keep every `%s`, `%d`, `%.1f`, `%%` exactly, the same number of them **in the same
  order** (Godot formats positionally; it can't reorder). Rephrase the sentence around them if needed.
  Keep double spaces (`"%s  (you)"`, `"Close!  ×%d"`) and leading/trailing spaces as they are.
- **Short.** Most text sits in fixed-size buttons and one-line labels on a phone. Prefer the shortest
  natural wording; a button label should stay close to the English length. Imperatives for buttons.
- **Tone**: a friendly mobile game, informal "you" where a language has formal/informal
  (du, tu, tú, ты, kamu, sen, তুমি, तुम); Arabic: Modern Standard, simple.
- **Untranslated proper nouns**: Sunstone, Xibalba, Maya day names (Imix, Ik', Ajaw, …), runner names
  (Tomás, Ixchel, Kinich, Nina), Google, Apple, App Store, Google Play, UTC.
- **Glossary** (be consistent):
  - Night: one run's chapter ("Night 2")
  - dawn / Dawn: sunrise at the end of a night
  - House: one of six trials of Xibalba. Gloom, Knives, Cold, Jaguars, Bats, Fire are their names; translate them as names.
  - sun-drops: the currency, little suns
  - Sun-string: a whole line of sun-drops
  - flare: tapping to blaze the stone's light
  - the pack: the jaguars behind you
  - glyph: an achievement
  - Offerings: daily gifts
  - Daily dusk: the daily challenge road
  - Ranks: leaderboards
  - Records: personal stats
  - Second wind: revive once per run
  - the Pass / Sunstone Pass: subscription
  - charm: upgrade
  - Treasury: sun-drop packs for money
  - Head start: boost
  - Ember shield, Jaguar ward: boosts
  - stela, lintel: temple stones
  - "m" is metres, "km" kilometres; keep the unit symbols.
