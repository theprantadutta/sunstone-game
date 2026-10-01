extends SceneTree
## Two phones' saves merge without losing or duplicating progress.
func _init() -> void:
	var a := SaveData.new()
	a.bank = 1000 # earned 1000
	a.best = 800
	a.glyphs = {"first_steps": "claimed", "far_500": "earned"}
	var cloud := a.to_dict()
	# Phone A spends 700 and buys a charm; the cloud still has the old copy.
	a.bank -= 700
	a.charms = {"ember_heart": 1}
	# Phone B (from the old cloud copy) earns 50 more and runs further.
	var b := SaveData.new()
	b.merge_from(cloud)
	b.bank += 50
	b.best = 1200
	# A takes in B's progress.
	a.merge_from(b.to_dict())
	print("bank %d (expect 350: 1050 earned - 700 spent)" % a.bank)
	print("best %d (expect 1200), charm %d (expect 1), glyph %s (expect earned)" % [a.best, a.charm_tier("ember_heart"), a.glyphs["far_500"]])
	quit()
