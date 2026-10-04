class_name Themes
## Everything you can see is data, and this is where it lives: who the runner
## is (characters), what the world looks like (each House's colours, paving,
## scenery, motes), the fire's colour, the title sky — and events that dress
## all of it for a season ("winter": snowy nights, pines, snowmen, a Santa
## hat). Code asks Themes; it never hard-codes a look.
##
## An event is switched on by the server (/config "event"), by its date
## window, or on a test device by `files/dev_event` (holding the event id).
## Its overrides lie over the base data: per House id, or "*" for all Houses.

## Characters: a [look] (face, hair, headwear — see RunnerModel.DEFAULT_LOOK)
## and an [outfit] (palette keys: shirt, scarf, trousers, shoe, hat, band,
## pack). [price]: {"drops": n} for sun-drops, {"product": id} for a store
## product, {} = free. Market garbs still recolour the outfit on top.
const CHARACTERS := [
	{"id": "explorer", "title": "Tomás the explorer", "price": {},
		"look": {}, "outfit": {}},
	{"id": "ixchel", "title": "Ixchel", "price": {"drops": 2500},
		"look": {"skin": Color("#B9774E"), "hair": "ponytail", "hair_col": Color("#1E1410"), "eyes": Color("#5A3420"),
			"hat": "band", "fem": true, "mouth": "grin", "build": 0.92},
		"outfit": {"shirt": Color("#C8402F"), "scarf": Color("#E3A82F"), "trousers": Color("#3A5A7A"), "band": Color("#E3A82F"),
			"shoe": Color("#6A3A22"), "pack": Color("#7A4A2A")}},
	{"id": "kinich", "title": "Kinich", "price": {"drops": 4000},
		"look": {"skin": Color("#8E5A3A"), "hair": "curly", "hair_col": Color("#1A120C"), "eyes": Color("#3A2416"),
			"hat": "none", "mouth": "smile", "build": 1.05, "freckles": false},
		"outfit": {"shirt": Color("#E3A82F"), "scarf": Color("#2F8A6E"), "trousers": Color("#EFE3C8"), "shoe": Color("#3B2618"),
			"pack": Color("#2F6B5A")}},
	{"id": "nina", "title": "Nina", "price": {"product": "char_nina"},
		"look": {"skin": Color("#F2C4A0"), "hair": "buns", "hair_col": Color("#C8602A"), "eyes": Color("#3A7A5A"),
			"hat": "none", "fem": true, "mouth": "grin", "freckles": true, "build": 0.9},
		"outfit": {"shirt": Color("#3FA7B5"), "scarf": Color("#F2E0B0"), "trousers": Color("#5A3A6A"), "shoe": Color("#C8402F"),
			"pack": Color("#E3A82F")}},
]

## Seasonal events. Keys (all optional):
## - name: shown on the title
## - window: [month, day, month, day] when it switches on by itself
## - houses: { house id or "*": overrides of that House's data in Nights.HOUSES }
## - decor_add: { decor set or "*": { band: [[kind, weight], ...] } }
## - motes: { decor set or "*": [colour, fall speed, size] }
## - flame: [outer, core] fire colours; sky: list of 8 band colours (low→high)
## - runner: look overrides for every character (e.g. a Santa hat)
const EVENTS := {
	"winter": {
		"name": "The long winter night",
		"window": [12, 15, 1, 6],
		"houses": {
			"*": {"earth": Color("#DCE8EC"), "tile": Color("#F2F6F7"), "tile2": Color("#D2E2E8"), "mark": "frost"},
			"fire": {"earth": Color("#C9D2D8"), "tile": Color("#9C8F88"), "tile2": Color("#7E726C"), "mark": "lava"},
		},
		"decor_add": {
			"*": {"near": [["snow_mound", 3.0], ["gift", 0.8], ["snowman", 0.5]], "mid": [["pine", 3.0], ["snowman", 0.6]], "far": [["pine", 3.5]]},
		},
		"motes": {"*": [Color("#FFFFFF"), -0.8, 0.09]},
		"sky": [Color("#F6D6B8"), Color("#E9B9A6"), Color("#C99BAA"), Color("#9A7EA6"), Color("#6E6498"), Color("#4C4A84"), Color("#333566"), Color("#22244A")],
		"runner": {"hat": "santa"},
	},
}

static var _event_id := ""
static var _dev_event := FileAccess.get_file_as_string("user://dev_event").strip_edges() if FileAccess.file_exists("user://dev_event") else ""

## Picks the event: a test device's dev_event wins, then the server's word
## ("none" turns events off), then the date.
static func choose_event(server_event: String) -> void:
	if _dev_event != "":
		_event_id = _dev_event if EVENTS.has(_dev_event) else ""
		return
	if server_event == "none":
		_event_id = ""
		return
	if EVENTS.has(server_event):
		_event_id = server_event
		return
	_event_id = _by_date()

static func _by_date() -> String:
	var d := Time.get_date_dict_from_system()
	var today: int = d.month * 100 + d.day
	for id in EVENTS:
		var w: Array = EVENTS[id].get("window", [])
		if w.size() != 4:
			continue
		var a: int = w[0] * 100 + w[1]
		var b: int = w[2] * 100 + w[3]
		if (a <= b and today >= a and today <= b) or (a > b and (today >= a or today <= b)):
			return id
	return ""

static func event_id() -> String:
	if _event_id == "" and _dev_event != "":
		choose_event("")
	return _event_id

static func event() -> Dictionary:
	return EVENTS.get(event_id(), {})

# ------------------------------------------------------------- the world ---

## A House's data with the event's overrides laid over it.
static func house(id: String) -> Dictionary:
	var base: Dictionary = Nights.HOUSES[id]
	var ev := event()
	if ev.is_empty():
		return base
	var over: Dictionary = ev.get("houses", {})
	if not over.has("*") and not over.has(id):
		return base
	var h := base.duplicate()
	h.merge(over.get("*", {}), true)
	h.merge(over.get(id, {}), true)
	return h

## A scenery list for one band of a decor set, plus whatever the event adds.
static func decor(base: Dictionary, set_id: String, band: String) -> Array:
	var list: Array = base[set_id][band]
	var adds: Dictionary = event().get("decor_add", {})
	if adds.is_empty():
		return list
	var out := list.duplicate()
	for key in ["*", set_id]:
		if adds.has(key):
			out.append_array(adds[key].get(band, []))
	return out

static func motes(base: Dictionary, set_id: String) -> Array:
	var m: Dictionary = event().get("motes", {})
	if m.has(set_id):
		return m[set_id]
	if m.has("*"):
		return m["*"]
	return base.get(set_id, base["jungle"])

## Fire colours: [outer, core].
static func flame() -> Array:
	return event().get("flame", [Color("#FF9A3A"), Color("#FFE7A0")])

static func sky() -> Array:
	return event().get("sky", [Color("#F4BE74"), Color("#EDA066"), Color("#E0805A"), Color("#C4605C"), Color("#97476A"), Color("#66376C"), Color("#3E2C5E"), Color("#25204A")])

# ------------------------------------------------------------ characters ---

static func character(id: String) -> Dictionary:
	for c in CHARACTERS:
		if c.id == id:
			return c
	return CHARACTERS[0]

## The look a character runs with right now (the event may add a hat).
static func look_of(id: String) -> Dictionary:
	var l: Dictionary = character(id).look.duplicate()
	l.merge(event().get("runner", {}), true)
	return l
