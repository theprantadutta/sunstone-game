class_name SaveData
extends RefCounted
## Everything the game remembers between launches: user://save.json, versioned.
## Unknown or missing keys fall back to defaults, so new fields never break an
## older save.

const PATH := "user://save.json"
const VERSION := 2

# --- progress ---
var best := 0 ## best distance, metres
var bank := 0 ## sun-drops to spend
var runs := 0
var tutorial_runs := 0 ## move hints show for the first two runs

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
	bank = int(d.get("bank", 0))
	runs = int(d.get("runs", 0))
	tutorial_runs = int(d.get("tutorial_runs", 0))
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
	garb = str(d.get("garb", "explorer"))
	hue = str(d.get("hue", "sun"))
	music = bool(d.get("music", true))
	sound = bool(d.get("sound", true))
	vibration = bool(d.get("vibration", true))

func save_to_disk() -> void:
	var d := {
		"version": VERSION,
		"best": best, "bank": bank, "runs": runs, "tutorial_runs": tutorial_runs,
		"total_distance": total_distance, "total_drops": total_drops, "best_drops": best_drops,
		"flares": flares, "deepest_dusk": deepest_dusk, "play_seconds": play_seconds,
		"deaths": deaths,
		"daily": daily, "daily_streak": daily_streak, "daily_last": daily_last,
		"glyphs": glyphs, "offering_day": offering_day, "offering_last": offering_last,
		"charms": charms, "owned": owned, "garb": garb, "hue": hue,
		"music": music, "sound": sound, "vibration": vibration,
	}
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

func owns(id: String) -> bool:
	return owned.has(id)

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
