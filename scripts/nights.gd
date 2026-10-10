class_name Nights
## The shape of a run: the Sunstone is carried through Xibalba one night at a
## time. Each night is three Houses of the underworld (the Popol Vuh's trials),
## then dawn — a stretch of safe road while the sun comes up — then the next,
## harder night.
##
## Everything here is a function of the distance along the road ([s], metres)
## and the run's seed, never of how the player ran: a seed always builds the
## same nights (the daily dusk depends on it), and the server can reason about
## distances alone.

const DAWN_LEN := 48.0 ## metres of safe sunrise road between two nights
const START_CLEAR := 34.0 ## the first metres of a run hold no danger
const MAX_SPEED := 20.0
const LANES := 3
const LANE_W := 2.5 ## metres between lane centres
const ROAD_W := LANES * LANE_W ## the causeway's paved width

## The Houses. Light radii are metres (the Sunstone's glow at full charge),
## [mix] weighs what the road holds there: sun-drops, the four dangers every
## House has (stela, low wall, lintel, pit), obsidian blades, jaguars and
## braziers.
const HOUSES := {
	"dusk": {
		"name": "The dusk causeway", "sub": "The sun is going down",
		"ember": 2.25, "drain": 1.0, "bat": 0.4,
		"mix": {"drop": 1.4, "stela": 1.0, "wall": 0.8, "lintel": 0.6, "pit": 0.5, "blades": 0.0, "jag": 0.2, "brazier": 0.2},
		"earth": Color("#5C7438"), "accent": Color("#E3A82F"), "decor": "jungle",
		"tile": Color("#EFE3C8"), "tile2": Color("#DCCBA6"), "mark": "kin",
	},
	"jaguars": {
		"name": "House of Jaguars", "sub": "They only move in the dark",
		"ember": 2.05, "drain": 1.0, "bat": 0.4,
		"mix": {"drop": 1.0, "stela": 0.8, "wall": 0.7, "lintel": 0.5, "pit": 0.6, "blades": 0.0, "jag": 1.3, "brazier": 0.7},
		"earth": Color("#94532E"), "accent": Color("#E3A82F"), "decor": "jaguars",
		"tile": Color("#F0DDB4"), "tile2": Color("#D9B97E"), "mark": "rosette",
	},
	"bats": {
		"name": "House of Bats", "sub": "Bats hunt bright light",
		"ember": 2.05, "drain": 1.0, "bat": 2.0,
		"mix": {"drop": 1.1, "stela": 0.9, "wall": 0.6, "lintel": 1.0, "pit": 0.6, "blades": 0.0, "jag": 0.4, "brazier": 0.2},
		"earth": Color("#56406A"), "accent": Color("#8A5AA0"), "decor": "bats",
		"tile": Color("#D9CFD8"), "tile2": Color("#B9A9BE"), "mark": "shard",
	},
	"gloom": {
		"name": "House of Gloom", "sub": "Even embers barely glow",
		"ember": 1.45, "drain": 1.0, "bat": 0.5,
		"mix": {"drop": 1.2, "stela": 0.9, "wall": 0.8, "lintel": 0.6, "pit": 0.9, "blades": 0.0, "jag": 0.9, "brazier": 0.7},
		"earth": Color("#5A5C66"), "accent": Color("#9A9FB8"), "decor": "gloom",
		"tile": Color("#C9C8C6"), "tile2": Color("#A9A8A8"), "mark": "crack",
	},
	"knives": {
		"name": "House of Knives", "sub": "Obsidian blades in the road",
		"ember": 2.05, "drain": 1.0, "bat": 0.6,
		"mix": {"drop": 1.0, "stela": 0.5, "wall": 0.6, "lintel": 0.6, "pit": 0.5, "blades": 1.6, "jag": 0.4, "brazier": 0.3},
		"earth": Color("#7A3A30"), "accent": Color("#3A3048"), "decor": "knives",
		"tile": Color("#E2C9B4"), "tile2": Color("#C29C86"), "mark": "obsidian",
	},
	"cold": {
		"name": "House of Cold", "sub": "The stone drains fast",
		"ember": 1.95, "drain": 1.7, "bat": 0.5,
		"mix": {"drop": 1.7, "stela": 0.9, "wall": 0.8, "lintel": 0.7, "pit": 0.7, "blades": 0.0, "jag": 0.6, "brazier": 0.3},
		"earth": Color("#B8D4DA"), "accent": Color("#4A9AB0"), "decor": "cold",
		"tile": Color("#E6F0F2"), "tile2": Color("#BCD6DD"), "mark": "frost",
	},
	"fire": {
		"name": "House of Fire", "sub": "Braziers, and what waits between them",
		"ember": 2.05, "drain": 1.0, "bat": 0.8,
		"mix": {"drop": 1.0, "stela": 0.7, "wall": 0.7, "lintel": 0.6, "pit": 1.2, "blades": 0.2, "jag": 1.1, "brazier": 1.4},
		"earth": Color("#4A2420"), "accent": Color("#B8322A"), "decor": "fire",
		"tile": Color("#8E7F76"), "tile2": Color("#6E625C"), "mark": "lava",
	},
}

const LATER := ["gloom", "knives", "cold", "jaguars", "bats", "fire"]

## Seconds a night lasts at its own pace; nights grow longer and faster.
static func duration(n: int) -> float:
	return minf(80.0, 50.0 + 6.0 * (n - 1))

## Running speed [t] (0..1) of the way through night [n].
static func speed(n: int, t: float) -> float:
	return minf(MAX_SPEED, 10.0 + 1.25 * (n - 1) + 1.5 * clampf(t, 0.0, 1.0))

## Metres of road in night [n].
static func length(n: int) -> float:
	return duration(n) * (speed(n, 0.0) + speed(n, 1.0)) * 0.5

## Where night [n] begins (night 1 at 0).
static func start(n: int) -> float:
	var s := 0.0
	for k in range(1, n):
		s += length(k) + DAWN_LEN
	return s

## Where on the run [s] falls: {n, t (0..1 through the night), dawn (bool),
## dawn_t (0..1 through the sunrise road), house (0..2)}.
static func locate(s: float) -> Dictionary:
	var n := 1
	var s0 := 0.0
	while true:
		var l := length(n)
		if s < s0 + l:
			var t := clampf((s - s0) / l, 0.0, 1.0)
			return {"n": n, "t": t, "dawn": false, "dawn_t": 0.0, "house": mini(2, int(t * 3.0))}
		if s < s0 + l + DAWN_LEN:
			return {"n": n, "t": 1.0, "dawn": true, "dawn_t": (s - s0 - l) / DAWN_LEN, "house": 2}
		s0 += l + DAWN_LEN
		n += 1
	return {}

## Night progress as one number: 2.4 = forty percent into night 3.
static func progress(s: float) -> float:
	var at := locate(maxf(s, 0.0))
	return (at.n - 1) + at.t

static func speed_at(s: float) -> float:
	var at := locate(maxf(s, 0.0))
	return speed(at.n, at.t)

## The three Houses of night [n]. The first night always teaches: the dusk
## causeway, then jaguars, then bats.
static func plan(n: int, seed: int) -> Array:
	if n == 1:
		return ["dusk", "jaguars", "bats"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, n, "houses"])
	var pool := LATER.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, 3)

## The House id at [s] (the last House of the night during its dawn).
static func house_id(s: float, seed: int) -> String:
	var at := locate(maxf(s, 0.0))
	return plan(at.n, seed)[at.house]

## The House at [s] as it looks now (any seasonal event laid over it).
static func house(s: float, seed: int) -> Dictionary:
	return Themes.house(house_id(s, seed))

## Where each House of night [n] begins.
static func house_starts(n: int) -> Array:
	var s0 := start(n)
	var l := length(n)
	return [s0, s0 + l / 3.0, s0 + l * 2.0 / 3.0]

## The road's width at [s]: always three lanes.
static func width(_s: float, _seed: int) -> float:
	return ROAD_W
