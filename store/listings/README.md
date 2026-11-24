# Localized Play Store listings

`listings.json` holds the translated Google Play store listing (title, short
description, full description) for 11 languages, keyed by Play Console
language code:

```json
{ "<code>": { "title": "...", "short": "...", "full": "..." } }
```

| Code | Language |
|---|---|
| `hi-IN` | Hindi |
| `bn-BD` | Bengali |
| `ar` | Arabic (Modern Standard) |
| `pt-BR` | Portuguese (Brazil) |
| `id` | Indonesian |
| `es-419` | Spanish (Latin America) |
| `tr-TR` | Turkish |
| `ru-RU` | Russian |
| `de-DE` | German |
| `it-IT` | Italian |
| `vi` | Vietnamese |

The English source is `../LISTING.md` (App name, Short description, Full
description). Play limits, in Unicode characters: title 30, short description
80, full description 4000. All entries are within them.

These were machine-translated in Nov 2026 as marketing copy (not literal).
Have a native speaker review a language before any big marketing push in it.
