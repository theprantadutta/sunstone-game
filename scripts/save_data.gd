class_name SaveData
extends RefCounted
## Everything the game remembers between launches: user://save.json, versioned.
## Unknown or missing keys fall back to defaults, so new fields never break an
## older save.

const PATH := "user://save.json"
const VERSION := 2

# --- progress ---
var best := 0 ## best distance, metres
## Sun-drops are kept as two running totals that only ever grow; the balance
## is their difference. Merging two phones takes the larger of each, so
## spending on one can never be undone (or duplicated) by the other.
var earned := 0
var spent := 0
var bank: int: ## sun-drops to spend; assigning records an earning or a spend
	get:
		return earned - spent
	set(v):
		if v >= earned - spent:
			earned += v - (earned - spent)
		else:
			spent += (earned - spent) - v
var runs := 0
var tutorial_runs := 0 ## move hints show for the first two runs
var taught := {} ## hint id → true once the player has learned it (each shows until then)

# --- lifetime records ---
var total_distance := 0 ## metres
var total_drops := 0
var best_drops := 0 ## most sun-drops in a single run
var flares := 0
var deepest_dusk := 0.0 ## 0 = sunset … 1 = deep night
var play_seconds := 0.0
var deaths := {} ## cause → count

# --- daily dusk ---
var daily := {} ## "yyyy-mm-dd" → best metres that day
var daily_streak := 0 ## consecutive days with a daily run
var daily_last := "" ## the last day a daily run was finished

# --- glyphs and offerings ---
var glyphs := {} ## glyph id → "earned" | "claimed"
var offering_day := 0 ## which of the seven offerings is next (0..6)
var offering_last := "" ## the local day the last offering was taken

const OFFERINGS := [25, 40, 60, 80, 110, 150, 300]

# --- market ---
var charms := {} ## charm id → tier bought (1..3)
var owned: Array = ["explorer", "sun"] ## garbs and hues you own
var garb := "explorer"
var hue := "sun"
var character := "explorer" ## who runs (Themes.CHARACTERS)
var hat := "own" ## headwear (Shop.HATS); "own" keeps the runner's
## Boosts as two totals that only grow, like sun-drops, so cloud merges can't
## duplicate or undo them: held = bought - used.
var boosts_bought := {}
var boosts_used := {}
var entitlements: Array = [] ## bought for good: "no_ads", "patron", and looks sold for money
var review_asks := 0 ## times we've asked Google to show the rating sheet
var review_last := "" ## local day of the last ask

# --- settings ---
var music := true
var sound := true
var vibration := true

const BACKUP := "user://save.json.bak"

## Loads the save; if it's missing or unreadable (a phone died mid-write),
## falls back to the previous good copy rather than starting from nothing.
func load_from_disk() -> void:
	var d := _read(PATH)
	if d.is_empty():
		d = _read(BACKUP)
	if not d.is_empty():
		_apply(d)

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges().is_empty():
		return {}
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {}
	return json.data

func _apply(d: Dictionary) -> void:
	best = int(d.get("best", 0))
	earned = int(d.get("earned", d.get("bank", 0)))
	spent = int(d.get("spent", 0))
	runs = int(d.get("runs", 0))
	tutorial_runs = int(d.get("tutorial_runs", 0))
	var tg: Variant = d.get("taught", {})
	taught = tg if tg is Dictionary else {}
	total_distance = int(d.get("total_distance", 0))
	total_drops = int(d.get("total_drops", 0))
	best_drops = int(d.get("best_drops", 0))
	flares = int(d.get("flares", 0))
	deepest_dusk = float(d.get("deepest_dusk", 0.0))
	play_seconds = float(d.get("play_seconds", 0.0))
	var dd: Variant = d.get("deaths", {})
	deaths = dd if dd is Dictionary else {}
	var dl: Variant = d.get("daily", {})
	daily = dl if dl is Dictionary else {}
	daily_streak = int(d.get("daily_streak", 0))
	daily_last = str(d.get("daily_last", ""))
	var gl: Variant = d.get("glyphs", {})
	glyphs = gl if gl is Dictionary else {}
	offering_day = clampi(int(d.get("offering_day", 0)), 0, OFFERINGS.size() - 1)
	offering_last = str(d.get("offering_last", ""))
	var ch: Variant = d.get("charms", {})
	charms = ch if ch is Dictionary else {}
	var ow: Variant = d.get("owned", ["explorer", "sun"])
	owned = ow if ow is Array else ["explorer", "sun"]
	var en: Variant = d.get("entitlements", [])
	entitlements = en if en is Array else []
	review_asks = int(d.get("review_asks", 0))
	review_last = str(d.get("review_last", ""))
	garb = str(d.get("garb", "explorer"))
	hue = str(d.get("hue", "sun"))
	character = str(d.get("character", "explorer"))
	hat = str(d.get("hat", "own"))
	var bb: Variant = d.get("boosts_bought", {})
	boosts_bought = bb if bb is Dictionary else {}
	var bu: Variant = d.get("boosts_used", {})
	boosts_used = bu if bu is Dictionary else {}
	music = bool(d.get("music", true))
	sound = bool(d.get("sound", true))
	vibration = bool(d.get("vibration", true))

func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"best": best, "earned": earned, "spent": spent, "bank": bank, "runs": runs, "tutorial_runs": tutorial_runs, "taught": taught,
		"total_distance": total_distance, "total_drops": total_drops, "best_drops": best_drops,
		"flares": flares, "deepest_dusk": deepest_dusk, "play_seconds": play_seconds,
		"deaths": deaths,
		"daily": daily, "daily_streak": daily_streak, "daily_last": daily_last,
		"glyphs": glyphs, "offering_day": offering_day, "offering_last": offering_last,
		"charms": charms, "owned": owned, "garb": garb, "hue": hue, "character": character, "hat": hat,
		"boosts_bought": boosts_bought, "boosts_used": boosts_used, "entitlements": entitlements,
		"review_asks": review_asks, "review_last": review_last,
		"music": music, "sound": sound, "vibration": vibration,
	}

## Folds another copy of the save (the cloud's) into this one, so progress
## from two phones adds up instead of one overwriting the other. Records take
## the larger value, collections the union, claims the furthest state.
## Returns true when anything changed. Settings stay as this phone has them.
func merge_from(other: Variant) -> bool:
	if not other is Dictionary or other.is_empty():
		return false
	var o: Dictionary = other
	var before := JSON.stringify(to_dict())
	best = maxi(best, int(o.get("best", 0)))
	earned = maxi(earned, int(o.get("earned", o.get("bank", 0))))
	spent = maxi(spent, int(o.get("spent", 0)))
	runs = maxi(runs, int(o.get("runs", 0)))
	tutorial_runs = maxi(tutorial_runs, int(o.get("tutorial_runs", 0)))
	var ot: Variant = o.get("taught", {})
	if ot is Dictionary:
		for k in ot:
			taught[k] = true
	total_distance = maxi(total_distance, int(o.get("total_distance", 0)))
	total_drops = maxi(total_drops, int(o.get("total_drops", 0)))
	best_drops = maxi(best_drops, int(o.get("best_drops", 0)))
	flares = maxi(flares, int(o.get("flares", 0)))
	deepest_dusk = maxf(deepest_dusk, float(o.get("deepest_dusk", 0.0)))
	play_seconds = maxf(play_seconds, float(o.get("play_seconds", 0.0)))
	var od: Variant = o.get("deaths", {})
	if od is Dictionary:
		for k in od:
			deaths[k] = maxi(int(deaths.get(k, 0)), int(od[k]))
	var odl: Variant = o.get("daily", {})
	if odl is Dictionary:
		for k in odl:
			daily[k] = maxi(int(daily.get(k, -1)), int(odl[k]))
	if str(o.get("daily_last", "")) > daily_last:
		daily_last = str(o.get("daily_last", ""))
		daily_streak = int(o.get("daily_streak", daily_streak))
	var og: Variant = o.get("glyphs", {})
	if og is Dictionary:
		for k in og:
			if og[k] == "claimed" or not glyphs.has(k):
				glyphs[k] = og[k]
	if str(o.get("offering_last", "")) > offering_last:
		offering_last = str(o.get("offering_last", ""))
		offering_day = clampi(int(o.get("offering_day", 0)), 0, OFFERINGS.size() - 1)
	var oc: Variant = o.get("charms", {})
	if oc is Dictionary:
		for k in oc:
			charms[k] = maxi(charm_tier(k), clampi(int(oc[k]), 0, 3))
	var oe: Variant = o.get("entitlements", [])
	if oe is Array:
		set_entitlements(entitlements + oe)
	var ow: Variant = o.get("owned", [])
	if ow is Array:
		for id in ow:
			if not owned.has(id):
				owned.append(id)
	for pair in [["boosts_bought", boosts_bought], ["boosts_used", boosts_used]]:
		var ob: Variant = o.get(pair[0], {})
		if ob is Dictionary:
			for k in ob:
				pair[1][k] = maxi(int(pair[1].get(k, 0)), int(ob[k]))
	return JSON.stringify(to_dict()) != before

func save_to_disk() -> void:
	var d := to_dict()
	# Write beside, keep the last good save as a backup, then swap in — a crash
	# at any point leaves at least one whole save on disk.
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	if not _read(PATH).is_empty():
		DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(BACKUP))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(PATH))

## Back to a brand-new save (after deleting the account). Settings stay.
func reset_all() -> void:
	var keep := [music, sound, vibration]
	var knows := taught.duplicate()
	var fresh := SaveData.new()
	_apply(fresh.to_dict())
	taught = knows
	music = keep[0]
	sound = keep[1]
	vibration = keep[2]
	tutorial_runs = 2 # they already know how to play

## Folds one finished run into the records.
func record_run(metres: int, drops: int, run_flares: int, dusk: float, seconds: float, cause: String) -> void:
	runs += 1
	total_distance += metres
	total_drops += drops
	bank += drops
	best_drops = maxi(best_drops, drops)
	flares += run_flares
	deepest_dusk = maxf(deepest_dusk, dusk)
	play_seconds += seconds
	deaths[cause] = int(deaths.get(cause, 0)) + 1
	if tutorial_runs < 2:
		tutorial_runs += 1

## Records a daily dusk run; returns true when it beat that day's best.
func record_daily(date_key: String, metres: int) -> bool:
	if daily_last != date_key:
		daily_streak = daily_streak + 1 if daily_last == MayaCalendar.day_before(date_key) else 1
		daily_last = date_key
	var prev := int(daily.get(date_key, -1))
	if metres > prev:
		daily[date_key] = metres
	# Keep a few weeks of history; the server holds the rest.
	if daily.size() > 60:
		var keys := daily.keys()
		keys.sort()
		for k in keys.slice(0, keys.size() - 60):
			daily.erase(k)
	return metres > prev

func daily_best(date_key: String) -> int:
	return int(daily.get(date_key, -1))

## The streak as it stands today (broken if yesterday was missed).
func live_streak(today: String) -> int:
	if daily_last == today or daily_last == MayaCalendar.day_before(today):
		return daily_streak
	return 0

## Pays out a glyph's reward; returns the sun-drops added (0 if not claimable).
func claim_glyph(id: String) -> int:
	if glyphs.get(id, "") != "earned":
		return 0
	var reward: int = Glyphs.def(id).get("reward", 0)
	glyphs[id] = "claimed"
	bank += reward
	return reward

## True when today's offering hasn't been taken yet.
func offering_ready(today: String) -> bool:
	return offering_last != today

## Takes today's offering; returns the sun-drops added (0 if already taken).
## Missing days never resets the cycle — it simply waits for you.
func take_offering(today: String) -> int:
	if not offering_ready(today):
		return 0
	var reward: int = OFFERINGS[offering_day]
	bank += reward
	offering_last = today
	offering_day = (offering_day + 1) % OFFERINGS.size()
	return reward

func has_entitlement(key: String) -> bool:
	return entitlements.has(key)

## Adds what the server says this player owns (never removes); a patron also
## gets the Obsidian hue. Returns true when anything changed.
func set_entitlements(keys: Array) -> bool:
	var changed := false
	for k in keys:
		if not entitlements.has(str(k)):
			entitlements.append(str(k))
			changed = true
	if entitlements.has("patron") and not owned.has("obsidian"):
		owned.append("obsidian")
		changed = true
	return changed

func charm_tier(id: String) -> int:
	return clampi(int(charms.get(id, 0)), 0, 3)

## Buys the next tier of a charm; false if maxed out or too dear.
func buy_charm(id: String) -> bool:
	var tier := charm_tier(id)
	var costs: Array = Market.find(Market.CHARMS, id).costs
	if tier >= costs.size() or bank < int(costs[tier]):
		return false
	bank -= int(costs[tier])
	charms[id] = tier + 1
	return true

## Owns a look: bought with sun-drops, or with real money (an entitlement).
func owns(id: String) -> bool:
	return owned.has(id) or entitlements.has(id)

## How many of a boost are held.
func boosts(id: String) -> int:
	return maxi(0, int(boosts_bought.get(id, 0)) - int(boosts_used.get(id, 0)))

func buy_boost(id: String, cost: int) -> bool:
	if bank < cost:
		return false
	bank -= cost
	boosts_bought[id] = int(boosts_bought.get(id, 0)) + 1
	return true

## Uses one boost; false when none are held.
func use_boost(id: String) -> bool:
	if boosts(id) <= 0:
		return false
	boosts_used[id] = int(boosts_used.get(id, 0)) + 1
	return true

## Buys a garb or hue; false if already owned or too dear.
func buy_item(id: String, cost: int) -> bool:
	if owns(id) or bank < cost:
		return false
	bank -= cost
	owned.append(id)
	return true

## The cause that has ended the most runs, or "".
func most_common_death() -> String:
	var top := ""
	var n := 0
	for cause in deaths:
		if int(deaths[cause]) > n:
			n = int(deaths[cause])
			top = cause
	return top
