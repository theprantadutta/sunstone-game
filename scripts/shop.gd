class_name Shop
## The catalog: everything a player can buy, by shelf. Looks (runners,
## outfits, hats, stone hues) are owned for good; boosts are used up; the
## treasury sells sun-drop packs and bundles for real money.
##
## Prices: "drops" in sun-drops (−1 = not sold for sun-drops), "product" =
## a store product id (real money, verified by the server, which grants the
## item's id as an entitlement — see sunstone-api Purchases/Products.cs; the
## two lists must match, and Play Console / App Store Connect too).
## "event" = only on sale while that seasonal event runs (Themes).

const SHELVES := ["Runners", "Outfits", "Hats", "Stones", "Charms", "Boosts", "Treasury"]

## Runners are Themes.CHARACTERS; their prices live there.

## Outfits recolour whoever runs: palette keys shirt, scarf, trousers, shoe,
## hat, band, pack. "" keeps the runner's own clothes.
const OUTFITS := [
	{"id": "explorer", "title": "Their own", "drops": 0, "palette": {}},
	{"id": "scribe", "title": "Scribe", "drops": 600, "palette": {
		"shirt": Color("#EFE6D2"), "scarf": Color("#B8322A"), "trousers": Color("#3B2618"),
		"hat": Color("#6B4426"), "band": Color("#B8322A"), "pack": Color("#7A1D17")}},
	{"id": "ranger", "title": "Jungle ranger", "drops": 900, "palette": {
		"shirt": Color("#5E7A3A"), "scarf": Color("#E3A82F"), "trousers": Color("#7A5A3A"),
		"hat": Color("#4A5A2A"), "band": Color("#E3A82F"), "pack": Color("#3A4A22"), "shoe": Color("#3A2A1A")}},
	{"id": "night", "title": "Night runner", "drops": 1200, "palette": {
		"shirt": Color("#2A2F5C"), "scarf": Color("#3FA7B5"), "trousers": Color("#1E2238"),
		"hat": Color("#2B2A3A"), "band": Color("#E3A82F"), "pack": Color("#3B3550")}},
	{"id": "ajaw", "title": "Ajaw gold", "drops": 2500, "palette": {
		"shirt": Color("#E3A82F"), "scarf": Color("#2F6B5A"), "trousers": Color("#EFE6D2"),
		"hat": Color("#7A1D17"), "band": Color("#3FA7B5"), "pack": Color("#7A1D17")}},
	{"id": "serpent", "title": "Feathered serpent", "drops": -1, "product": "sunstone_outfit_serpent", "palette": {
		"shirt": Color("#2FA07A"), "scarf": Color("#E3402F"), "trousers": Color("#1E5A6A"),
		"hat": Color("#2FA07A"), "band": Color("#E3402F"), "pack": Color("#E3A82F"), "shoe": Color("#E3A82F")}},
	{"id": "winter_coat", "title": "Winter coat", "drops": 800, "event": "winter", "palette": {
		"shirt": Color("#C8202A"), "scarf": Color("#FFFFFF"), "trousers": Color("#2E4A3A"),
		"hat": Color("#C8202A"), "band": Color("#FFFFFF"), "pack": Color("#6A3A22"), "shoe": Color("#2A1A12")}},
]

## Hats replace the runner's own headwear ("own" keeps it).
const HATS := [
	{"id": "own", "title": "Their own", "drops": 0, "hat": ""},
	{"id": "fedora", "title": "Fedora", "drops": 400, "hat": "fedora"},
	{"id": "cap", "title": "Cap", "drops": 500, "hat": "cap"},
	{"id": "beanie", "title": "Beanie", "drops": 600, "hat": "beanie"},
	{"id": "bare", "title": "No hat", "drops": 0, "hat": "none"},
	{"id": "crown", "title": "Quetzal crown", "drops": -1, "product": "sunstone_hat_crown", "hat": "crown"},
	{"id": "santa", "title": "Santa hat", "drops": 300, "event": "winter", "hat": "santa"},
]

## Boosts: used up, one at a time, when they're needed.
const BOOSTS := [
	{"id": "shield", "title": "Ember shield", "drops": 250,
		"text": "The first time the Sunstone goes out, it relights."},
	{"id": "ward", "title": "Jaguar ward", "drops": 300,
		"text": "The first jaguar to catch you turns to stone instead."},
]

## Real-money items in the treasury (consumable packs and bundles). The
## permanent looks sold for money show on their own shelves.
const TREASURY := [
	{"id": "sunstone_drops_small", "title": "A pouch of sun-drops", "text": "1,000 sun-drops."},
	{"id": "sunstone_drops_medium", "title": "A jar of sun-drops", "text": "5,500 sun-drops."},
	{"id": "sunstone_drops_large", "title": "A chest of sun-drops", "text": "12,000 sun-drops."},
	{"id": "sunstone_remove_ads", "title": "Remove ads", "text": "No more ads between runs. Offers you choose stay."},
	{"id": "sunstone_patron", "title": "Patron of the temple", "text": "No ads, 2,500 sun-drops and the Obsidian hue."},
]

## The items on a looks shelf, as shown right now (event items only while
## their event runs, unless already owned).
static func shelf(name: String, save: SaveData) -> Array:
	var src: Array
	match name:
		"Runners": src = Themes.CHARACTERS
		"Outfits": src = OUTFITS
		"Hats": src = HATS
		"Stones": src = Market.HUES
		_: return []
	var out := []
	for item in src:
		var ev: String = item.get("event", "")
		if ev != "" and ev != Themes.event_id() and not save.owns(item.id):
			continue
		out.append(item)
	return out

## Sun-drop price of an item (−1 = not for sun-drops, 0 = free).
static func drops_price(item: Dictionary) -> int:
	if item.has("price"): # runners
		var p: Dictionary = item.price
		if p.is_empty():
			return 0
		return int(p.get("drops", -1))
	if item.has("cost"): # stone hues
		return int(item.cost)
	return int(item.get("drops", -1))

static func product_of(item: Dictionary) -> String:
	if item.has("price"):
		return str(item.price.get("product", ""))
	return str(item.get("product", ""))

## Every store product id the game sells (for asking the store its prices).
static func product_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for t in TREASURY:
		ids.append(t.id)
	for list in [Themes.CHARACTERS, OUTFITS, HATS]:
		for item in list:
			var p := product_of(item)
			if p != "" and not ids.has(p):
				ids.append(p)
	return ids

## A runner dressed as chosen: [character], [outfit_id], [hat_id] and the
## stone's [hue_id]. Used by the game and by the shop's preview, so what you
## try on is exactly what runs. A chosen hat beats the season's; "own" lets
## the season (a Santa hat in winter) or the character decide.
static func dress(character: String, outfit_id: String, hat_id: String, hue_id: String) -> RunnerModel:
	var who := Themes.character(character)
	var r: RunnerModel = RunnerModel.new()
	r.look = Themes.look_of(character)
	var h: String = hat(hat_id).hat
	if h != "":
		r.look["hat"] = h
	r.palette = who.outfit.duplicate()
	r.palette.merge(outfit(outfit_id).palette, true)
	r.palette["gem"] = Market.find(Market.HUES, hue_id).gem
	return r

static func outfit(id: String) -> Dictionary:
	for o in OUTFITS:
		if o.id == id:
			return o
	return OUTFITS[0]

static func hat(id: String) -> Dictionary:
	for h in HATS:
		if h.id == id:
			return h
	return HATS[0]
