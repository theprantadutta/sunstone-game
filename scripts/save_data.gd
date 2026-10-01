class_name SaveData
extends RefCounted
## Everything the game remembers between launches, in user://save.cfg.

const PATH := "user://save.cfg"

var best := 0 ## best distance, metres
var bank := 0 ## coins collected across all runs
var runs := 0
var tutorial_runs := 0 ## swipe hints show for the first two runs
var music := true
var sound := true
var vibration := true

func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	best = cfg.get_value("progress", "best", 0)
	bank = cfg.get_value("progress", "bank", 0)
	runs = cfg.get_value("progress", "runs", 0)
	tutorial_runs = cfg.get_value("progress", "tutorial_runs", 0)
	music = cfg.get_value("settings", "music", true)
	sound = cfg.get_value("settings", "sound", true)
	vibration = cfg.get_value("settings", "vibration", true)

func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "best", best)
	cfg.set_value("progress", "bank", bank)
	cfg.set_value("progress", "runs", runs)
	cfg.set_value("progress", "tutorial_runs", tutorial_runs)
	cfg.set_value("settings", "music", music)
	cfg.set_value("settings", "sound", sound)
	cfg.set_value("settings", "vibration", vibration)
	cfg.save(PATH)
