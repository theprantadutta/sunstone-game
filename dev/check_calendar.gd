extends SceneTree
func _init() -> void:
	print("2012-12-21 -> ", MayaCalendar.tzolkin_name("2012-12-21"), " (expect 4 Ajaw)")
	print("2026-10-01 -> ", MayaCalendar.tzolkin_name("2026-10-01"))
	print("day before 2026-03-01 -> ", MayaCalendar.day_before("2026-03-01"))
	print("seed today -> ", MayaCalendar.seed_for("2026-10-01"), " again ", MayaCalendar.seed_for("2026-10-01"))
	quit()
