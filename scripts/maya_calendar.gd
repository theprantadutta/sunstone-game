class_name MayaCalendar
## The 260-day sacred count, the tzolk'in: each day pairs a number (1–13) with
## one of twenty day names. Every daily dusk is named by its tzolk'in day.
## Uses the standard GMT correlation (584283).

const DAY_NAMES := [
	"Imix", "Ik'", "Ak'b'al", "K'an", "Chikchan", "Kimi", "Manik'", "Lamat", "Muluk", "Ok",
	"Chuwen", "Eb'", "B'en", "Ix", "Men", "K'ib'", "Kab'an", "Etz'nab'", "Kawak", "Ajaw",
]
const CORRELATION := 584283

## Julian day number of a Gregorian date.
static func julian_day(year: int, month: int, day: int) -> int:
	var a := (14 - month) / 12
	var y := year + 4800 - a
	var m := month + 12 * a - 3
	return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045

## [number 1..13, day name] for a "yyyy-mm-dd" date.
static func tzolkin(date_key: String) -> Array:
	var p := date_key.split("-")
	var d := julian_day(p[0].to_int(), p[1].to_int(), p[2].to_int()) - CORRELATION
	return [posmod(d + 3, 13) + 1, DAY_NAMES[posmod(d + 19, 20)]]

## "9 K'an".
static func tzolkin_name(date_key: String) -> String:
	var t := tzolkin(date_key)
	return "%d %s" % [t[0], t[1]]

## Today's key in UTC, "yyyy-mm-dd" — the same for every player at once.
static func today_utc() -> String:
	var t := Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02d" % [t.year, t.month, t.day]

## The key of the day before [date_key].
static func day_before(date_key: String) -> String:
	var unix := Time.get_unix_time_from_datetime_string(date_key + "T12:00:00") - 86400
	return Time.get_date_string_from_unix_time(unix)

## A stable 31-bit seed for a day's causeway (FNV-1a).
static func seed_for(date_key: String) -> int:
	var h := 2166136261
	for b in ("sunstone-dusk-" + date_key).to_utf8_buffer():
		h = ((h ^ b) * 16777619) & 0xFFFFFFFF
	return h & 0x7FFFFFFF
