class_name Glyphs
## The glyphs: Sunstone's achievements. Each is earned at the end of a run and
## pays sun-drops when claimed on the Glyphs page. Order here is display order.
##
## [run] passed to evaluate(): {distance, drops, flares, dusk, daily, recovered,
## nights} where flares = times the Sunstone was blazed, recovered = it nearly
## went out and was lit again, nights = night progress (1.5 = halfway through
## the second night; see Nights.progress).

const DEFS := [
	{"id": "first_steps", "title": "First steps", "text": "Finish a run.", "reward": 25},
	{"id": "far_500", "title": "Past the jaguars", "text": "Reach the House of Bats.", "reward": 40},
	{"id": "far_1000", "title": "First dawn", "text": "Carry the sun through a night.", "reward": 80},
	{"id": "far_2500", "title": "Second dawn", "text": "Survive two nights in one run.", "reward": 150},
	{"id": "far_5000", "title": "Sun bearer", "text": "Survive four nights in one run.", "reward": 300},
	{"id": "drops_50", "title": "Gatherer", "text": "Gather 50 sun-drops in one run.", "reward": 60},
	{"id": "drops_150", "title": "Sun-hoarder", "text": "Gather 150 sun-drops in one run.", "reward": 150},
	{"id": "flare_first", "title": "First light", "text": "Blaze the Sunstone.", "reward": 25},
	{"id": "flares_3", "title": "Many suns", "text": "Blaze forty times in one run.", "reward": 60},
	{"id": "moonrise", "title": "Moonrise", "text": "Reach the House of Jaguars.", "reward": 80},
	{"id": "deep_night", "title": "Deep night", "text": "Reach the last House of the second night.", "reward": 150},
	{"id": "no_flare_1000", "title": "Ember walker", "text": "Run 200 m blazing six times or fewer.", "reward": 120},
	{"id": "close_call", "title": "Close call", "text": "Let the stone nearly go out, then light it again.", "reward": 50},
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
	var nights: float = run.get("nights", 0.0)
	var met := {
		"first_steps": true,
		"far_500": nights >= 2.0 / 3.0,
		"far_1000": nights >= 1.0,
		"far_2500": nights >= 2.0,
		"far_5000": nights >= 4.0,
		"drops_50": drops >= 50,
		"drops_150": drops >= 150,
		"flare_first": flares >= 1,
		"flares_3": flares >= 40,
		"moonrise": nights >= 1.0 / 3.0,
		"deep_night": nights >= 1.0 + 2.0 / 3.0,
		"no_flare_1000": dist >= 200 and flares <= 6,
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
