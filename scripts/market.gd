class_name Market
## What sun-drops buy. Charms are permanent upgrades in three tiers; garbs
## dress the explorer; hues colour the Sunstone's light. The effects here are
## mirrored by the server's run checks (sunstone-api Runs/RunRules.cs) where
## they change what a run can do — keep them in step.

const SECOND_WIND_COST := 150 ## one rise per run, after a fall or a crash

const CHARMS := [
	{"id": "ember_heart", "title": "Ember heart", "text": "The stone's light drains slower.",
		"costs": [300, 800, 1800], "effects": ["10% slower", "20% slower", "30% slower"]},
	{"id": "patience", "title": "Jaguar's patience", "text": "Jaguars stay stone a moment after your light leaves them.",
		"costs": [250, 700, 1500], "effects": ["+0.4 s", "+0.8 s", "+1.2 s"]},
	{"id": "sun_drinker", "title": "Sun-drinker", "text": "Each sun-drop restores more light.",
		"costs": [300, 800, 1800], "effects": ["+15% light", "+30% light", "+50% light"]},
]

const GARBS := [
	{"id": "explorer", "title": "Explorer", "cost": 0, "palette": {}},
	{"id": "scribe", "title": "Scribe", "cost": 600, "palette": {
		"shirt": Color("#EFE6D2"), "scarf": Color("#B8322A"), "trousers": Color("#3B2618"),
		"hat": Color("#6B4426"), "band": Color("#B8322A"), "pack": Color("#7A1D17")}},
	{"id": "night", "title": "Night runner", "cost": 900, "palette": {
		"shirt": Color("#2A2F5C"), "scarf": Color("#3FA7B5"), "trousers": Color("#1E2238"),
		"hat": Color("#2B2A3A"), "band": Color("#E3A82F"), "pack": Color("#3B3550")}},
	{"id": "ajaw", "title": "Ajaw", "cost": 2000, "palette": {
		"shirt": Color("#E3A82F"), "scarf": Color("#2F6B5A"), "trousers": Color("#EFE6D2"),
		"hat": Color("#7A1D17"), "band": Color("#3FA7B5"), "pack": Color("#7A1D17")}},
]

const HUES := [
	{"id": "sun", "title": "Sun gold", "cost": 0, "light": Color("#FFC46A"), "gem": Color("#F4B732")},
	{"id": "jade", "title": "Jade fire", "cost": 500, "light": Color("#8CFFB8"), "gem": Color("#4FD18B")},
	{"id": "moon", "title": "Moon pearl", "cost": 700, "light": Color("#D4E6FF"), "gem": Color("#BFD8FF")},
	{"id": "blood", "title": "Blood moon", "cost": 1500, "light": Color("#FF7A5A"), "gem": Color("#E2442A")},
	# Not sold for sun-drops: the patron's own hue.
	{"id": "obsidian", "title": "Obsidian", "cost": -1, "light": Color("#C9A6FF"), "gem": Color("#2B2238")},
]

static func find(list: Array, id: String) -> Dictionary:
	for d in list:
		if d.id == id:
			return d
	return list[0]

## Light drains this many times as fast.
static func drain_scale(save: SaveData) -> float:
	return 1.0 - 0.1 * save.charm_tier("ember_heart")

## Extra seconds a flare holds the jaguars.
static func freeze_bonus(save: SaveData) -> float:
	return 0.4 * save.charm_tier("patience")

## Each sun-drop's light, times this.
static func drop_scale(save: SaveData) -> float:
	return [1.0, 1.15, 1.3, 1.5][save.charm_tier("sun_drinker")]
