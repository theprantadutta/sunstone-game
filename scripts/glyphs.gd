class_name Glyphs
## The glyphs: Sunstone's achievements. Each is earned at the end of a run and
## pays sun-drops when claimed on the Glyphs page. Order here is display order.
##
## [run] passed to evaluate(): {distance, drops, flares, dusk, daily, recovered}
## where recovered = survived a stumble in that run.

const DEFS := [
	{"id": "first_steps", "title": "First steps", "text": "Finish a run.", "reward": 25},
	{"id": "far_500", "title": "Five hundred paces", "text": "Run 500 m in one run.", "reward": 40},
	{"id": "far_1000", "title": "A thousand paces", "text": "Run 1,000 m in one run.", "reward": 80},
	{"id": "far_2500", "title": "Into the night", "text": "Run 2,500 m in one run.", "reward": 150},
	{"id": "far_5000", "title": "Moon's runner", "text": "Run 5,000 m in one run.", "reward": 300},
	{"id": "drops_50", "title": "Gatherer", "text": "Gather 50 sun-drops in one run.", "reward": 60},
	{"id": "drops_150", "title": "Sun-hoarder", "text": "Gather 150 sun-drops in one run.", "reward": 150},
	{"id": "flare_first", "title": "First light", "text": "Flare the Sunstone.", "reward": 25},
	{"id": "flares_3", "title": "Stone again", "text": "Flare three times in one run.", "reward": 60},
	{"id": "moonrise", "title": "Moonrise", "text": "Run until the moon rises.", "reward": 80},
	{"id": "deep_night", "title": "Deep night", "text": "Run into the deep night.", "reward": 150},
	{"id": "no_flare_1000", "title": "No light needed", "text": "Run 1,000 m without a flare.", "reward": 120},
	{"id": "close_call", "title": "Close call", "text": "Stumble and keep running.", "reward": 50},
	{"id": "daily_first", "title": "Today's dusk", "text": "Finish a daily dusk.", "reward": 30},
	{"id": "daily_3", "title": "Three dusks", "text": "Run the daily dusk three days in a row.", "reward": 90},
	{"id": "daily_7", "title": "A week of dusks", "text": "Run the daily dusk seven days in a row.", "reward": 200},
	{"id": "runs_10", "title": "Regular", "text": "Finish 10 runs.", "reward": 40},
	{"id": "runs_50", "title": "Devoted", "text": "Finish 50 runs.", "reward": 120},
	{"id": "total_10k", "title": "Ten thousand paces", "text": "Run 10 km in all.", "reward": 100},
	{"id": "treasury", "title": "Treasury", "text": "Gather 1,000 sun-drops in all.", "reward": 100},
]

static func def(id: String) -> Dictionary:
	for d in DEFS:
		if d.id == id:
			return d
	return {}

## Marks newly earned glyphs in [save] (after the run is recorded) and returns
## their ids, in display order.
static func evaluate(save: SaveData, run: Dictionary) -> Array[String]:
	var dist: int = run.distance
	var drops: int = run.drops
	var flares: int = run.flares
	var dusk: float = run.dusk
	var met := {
		"first_steps": true,
		"far_500": dist >= 500,
		"far_1000": dist >= 1000,
		"far_2500": dist >= 2500,
		"far_5000": dist >= 5000,
		"drops_50": drops >= 50,
		"drops_150": drops >= 150,
		"flare_first": flares >= 1,
		"flares_3": flares >= 3,
		"moonrise": dusk >= 0.6,
		"deep_night": dusk >= 0.9,
		"no_flare_1000": dist >= 1000 and flares == 0,
		"close_call": run.recovered,
		"daily_first": run.daily,
		"daily_3": run.daily and save.daily_streak >= 3,
		"daily_7": run.daily and save.daily_streak >= 7,
		"runs_10": save.runs >= 10,
		"runs_50": save.runs >= 50,
		"total_10k": save.total_distance >= 10000,
		"treasury": save.total_drops >= 1000,
	}
	var earned: Array[String] = []
	for d in DEFS:
		if met.get(d.id, false) and not save.glyphs.has(d.id):
			save.glyphs[d.id] = "earned"
			earned.append(d.id)
	return earned

## How many glyphs wait to be claimed.
static func unclaimed(save: SaveData) -> int:
	var n := 0
	for id in save.glyphs:
		if save.glyphs[id] == "earned":
			n += 1
	return n
