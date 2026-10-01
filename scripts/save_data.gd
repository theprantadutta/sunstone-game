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

# --- settings ---
var music := true
var sound := true
var vibration := true

func load_from_disk() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		return
	var d: Dictionary = parsed
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
		"music": music, "sound": sound, "vibration": vibration,
	}
	# Write beside, then swap in, so a crash mid-write never loses the save.
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
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

## The cause that has ended the most runs, or "".
func most_common_death() -> String:
	var top := ""
	var n := 0
	for cause in deaths:
		if int(deaths[cause]) > n:
			n = int(deaths[cause])
			top = cause
	return top
