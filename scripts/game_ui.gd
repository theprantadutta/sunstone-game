class_name GameUI
extends CanvasLayer
## Every screen, composed from UiKit's codex pieces: title, HUD, pause,
## settings, results. The 3D world is always the background; menus are codex
## pages that unfold over it.
##
## Layout is anchor-based throughout, so it holds on any aspect ratio (tall
## 20:9 phones included) and re-flows if the window changes size.

signal run_pressed
signal daily_pressed
signal pause_pressed
signal resume_pressed
signal home_pressed
signal again_pressed
signal settings_changed
signal back_requested
signal account_deleted
signal looks_changed
signal second_wind_accepted
signal second_wind_declined
signal second_wind_by_ad

var _save: SaveData
var _online: Online
var _ads: Ads
var _store: Store
var _ranks: Control
var _ranks_board := "dusk"
var _ranks_body: Control
var _account: Control
var _top := 28.0 ## below the status bar / camera cutout

var _title: Control
var _wordmark: UiKit.Wordmark
var _best: UiKit.PaperSlip
var _hud: Control
var _distance: Label
var _drops: Label
var _meter: UiKit.SunMeter
var _hint: UiKit.HintStrip
var _danger: UiKit.DangerFlash
var _pause: Control
var _settings: Control
var _results: Control
var _records: Control
var _daily: Control
var _glyphs: Control
var _offerings: Control
var _bank: UiKit.PaperSlip
var _menu_icons := {} ## page name → GlyphIcon, for badges
var _market: Control
var _market_body: Control
var _market_tab := 0
var _market_note: Label
var _offer: Control
var _day_tag: Label
var _dark: TextureRect
var _flare_rect: ColorRect

## A freehand cinnabar rule between two registers of a page.
class Rule:
	extends Control
	var seed := 0
	func _init(s := 0) -> void:
		seed = s
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		UiKit.draw_rule(self, Vector2(0, size.y / 2.0), Vector2(size.x, size.y / 2.0), UiKit.CINNABAR, 3.0, seed)

## A number written in Maya bar-and-dot numerals.
class MayaNumber:
	extends Control
	var value := 0
	var unit := 9.0
	var color := UiKit.CINNABAR
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func set_value(v: int) -> void:
		value = v
		queue_redraw()
	func _draw() -> void:
		UiKit.draw_maya_number(self, Vector2.ZERO, value, unit, color)

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_top = _safe_top() + 28.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_BACK:
		_back()
		get_viewport().set_input_as_handled()

## Android delivers one press of back both as a key and as a request, and a
## heavy frame (rebuilding the world) can push the second a frame or more
## later. Count it once: ignore anything within a few frames or 300 ms.
var _last_back := -1000
var _last_back_frame := -1000
func _back() -> void:
	var now := Time.get_ticks_msec()
	var frame := Engine.get_process_frames()
	if now - _last_back < 300 or frame - _last_back_frame <= 4:
		return
	_last_back = now
	_last_back_frame = frame
	back_requested.emit()

## Closes whichever title page is open (settings, records...); true when one was.
func close_modal() -> bool:
	for page in [_account, _settings, _records, _daily, _glyphs, _offerings, _market, _ranks]:
		if page and is_instance_valid(page) and page.visible:
			page.visible = false
			return true
	return false

func setup(save: SaveData, online: Online, ads: Ads, store: Store) -> void:
	_save = save
	_online = online
	_ads = ads
	_store = store
	_store.purchase_finished.connect(func(_id: String, message: String):
		if _market and is_instance_valid(_market) and _market.visible:
			_fill_market()
			if message != "" and _market_note:
				_market_note.text = message
		_refresh_title())
	_build_title()
	_build_hud()
	_danger = UiKit.DangerFlash.new()
	_root().add_child(_danger)
	_danger.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Darkness at the edges: a radial vignette, faded in as the light fails.
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.02, 0.06, 0.0))
	grad.set_color(1, Color(0.02, 0.02, 0.06, 0.95))
	grad.add_point(0.55, Color(0.02, 0.02, 0.06, 0.15))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.55)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.width = 256
	tex.height = 256
	_dark = TextureRect.new()
	_dark.texture = tex
	_dark.stretch_mode = TextureRect.STRETCH_SCALE
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dark.modulate.a = 0.0
	_root().add_child(_dark)
	_root().move_child(_dark, 0)
	_dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flare_rect = ColorRect.new()
	_flare_rect.color = Color("#FFE6A8")
	_flare_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flare_rect.modulate.a = 0.0
	_root().add_child(_flare_rect)
	_flare_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## The camera-cutout inset, in UI units.
func _safe_top() -> float:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	var vp := get_viewport().get_visible_rect().size
	if screen.y <= 0 or OS.get_name() != "Android":
		return 0.0
	return safe.position.y * vp.y / float(screen.y)

var _root_control: Control
func _root() -> Control:
	if _root_control == null:
		_root_control = Control.new()
		_root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_root_control)
		_root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return _root_control

## A full-screen screen layer.
func _layer() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root().add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c

## Pins [c] by anchors (0..1 of the parent) plus pixel offsets.
static func _pin(c: Control, anchors: Rect2, offsets: Rect2) -> void:
	c.anchor_left = anchors.position.x
	c.anchor_top = anchors.position.y
	c.anchor_right = anchors.position.x + anchors.size.x
	c.anchor_bottom = anchors.position.y + anchors.size.y
	c.offset_left = offsets.position.x
	c.offset_top = offsets.position.y
	c.offset_right = offsets.position.x + offsets.size.x
	c.offset_bottom = offsets.position.y + offsets.size.y

const TOP_LEFT := Rect2(0, 0, 0, 0)
const TOP_RIGHT := Rect2(1, 0, 0, 0)
const TOP_CENTER := Rect2(0.5, 0, 0, 0)
const BOTTOM_CENTER := Rect2(0.5, 1, 0, 0)
const CENTER := Rect2(0.5, 0.5, 0, 0)

func _hide_all() -> void:
	for c in [_title, _hud, _pause, _settings, _results, _offer]:
		if c:
			c.visible = false

# ---------------------------------------------------------------- title ---

func _build_title() -> void:
	_title = _layer()
	_wordmark = UiKit.Wordmark.new()
	_title.add_child(_wordmark)
	_pin(_wordmark, TOP_CENTER, Rect2(-320, _top + 6, 640, 300))

	var run := UiKit.GlyphButton.new("Run", UiKit.GlyphButton.Kind.PRIMARY)
	run.font_size = 48
	_title.add_child(run)
	_pin(run, BOTTOM_CENTER, Rect2(-200, -400, 400, 128))
	run.pressed.connect(func(): run_pressed.emit())

	_best = UiKit.PaperSlip.new()
	_title.add_child(_best)
	_pin(_best, BOTTOM_CENTER, Rect2(-200, -254, 400, 70))

	# The menu: one glyph per page of the codex, labelled underneath.
	var menu := [
		[UiKit.GlyphIcon.Icon.DAILY, "Daily dusk", _open_daily],
		[UiKit.GlyphIcon.Icon.OFFERINGS, "Offerings", _open_offerings],
		[UiKit.GlyphIcon.Icon.MARKET, "Market", _open_market],
		[UiKit.GlyphIcon.Icon.GLYPHS, "Glyphs", _open_glyphs],
		[UiKit.GlyphIcon.Icon.RANKS, "Ranks", _open_ranks],
		[UiKit.GlyphIcon.Icon.RECORDS, "Records", _open_records],
	]
	var gap := 116.0
	var x0 := -gap * (menu.size() - 1) / 2.0
	for i in menu.size():
		var item: Array = menu[i]
		var b := UiKit.GlyphIcon.new(item[0])
		_title.add_child(b)
		_pin(b, BOTTOM_CENTER, Rect2(x0 + gap * i - 42, -158, 84, 84))
		b.pressed.connect(item[2])
		_menu_icons[item[1]] = b
		var l := UiKit.label(item[1], UiKit.text_font(900), 22, UiKit.STUCCO, 8)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title.add_child(l)
		_pin(l, BOTTOM_CENTER, Rect2(x0 + gap * i - 58, -70, 116, 34))

	# The sun-drops you hold, on a paper slip top-left.
	_bank = UiKit.PaperSlip.new()
	_title.add_child(_bank)
	_pin(_bank, TOP_LEFT, Rect2(24, _top + 8, 200, 64))
	var bank_glyph := UiKit.DropGlyph.new(30)
	_bank.add_child(bank_glyph)
	bank_glyph.position = Vector2(18, 17)

	var gear := UiKit.GlyphIcon.new(UiKit.GlyphIcon.Icon.SETTINGS)
	_title.add_child(gear)
	_pin(gear, TOP_RIGHT, Rect2(-108, _top, 84, 84))
	gear.pressed.connect(_open_settings)

func show_title(save: SaveData) -> void:
	_hide_all()
	if save.best > 0:
		_best.set_text("Best %s m" % UiKit.thousands(save.best), save.best)
	else:
		_best.set_text("Outrun the stone jaguars")
	_title.visible = true
	_wordmark.replay()
	_refresh_title()

## Bank and menu badges: what's waiting since you last looked.
func _refresh_title() -> void:
	_bank.set_text("      %s" % UiKit.thousands(_save.bank))
	_menu_icons["Offerings"].badge = _save.offering_ready(MayaCalendar.today_local())
	_menu_icons["Glyphs"].badge = Glyphs.unclaimed(_save) > 0
	var today := MayaCalendar.today_utc()
	_menu_icons["Daily dusk"].badge = _save.daily_best(today) < 0

# ------------------------------------------------------------------ hud ---

func _build_hud() -> void:
	_hud = _layer()
	_distance = UiKit.label("0 m", UiKit.display_font(), 52, UiKit.STUCCO, 12)
	_hud.add_child(_distance)
	_pin(_distance, TOP_LEFT, Rect2(28, _top - 6, 320, 80))

	var glyph := UiKit.DropGlyph.new(34)
	_hud.add_child(glyph)
	_pin(glyph, TOP_LEFT, Rect2(32, _top + 80, 34, 34))
	_drops = UiKit.label("0", UiKit.text_font(900), 34, UiKit.OCHRE_LIGHT, 10)
	_hud.add_child(_drops)
	_pin(_drops, TOP_LEFT, Rect2(76, _top + 70, 200, 50))

	# During a daily dusk, the day's name sits under the sun-drops.
	_day_tag = UiKit.label("", UiKit.text_font(900), 26, UiKit.OCHRE_LIGHT, 8)
	_hud.add_child(_day_tag)
	_pin(_day_tag, TOP_LEFT, Rect2(32, _top + 122, 300, 40))

	_meter = UiKit.SunMeter.new()
	_hud.add_child(_meter)
	_pin(_meter, TOP_CENTER, Rect2(-75, _top - 10, 150, 190))

	var pause := UiKit.GlyphIcon.new(UiKit.GlyphIcon.Icon.PAUSE)
	_hud.add_child(pause)
	_pin(pause, TOP_RIGHT, Rect2(-108, _top, 84, 84))
	pause.pressed.connect(func(): pause_pressed.emit())

	_hint = UiKit.HintStrip.new()
	_hud.add_child(_hint)
	_pin(_hint, Rect2(0.5, 0.62, 0, 0), Rect2(-270, 0, 540, 112))

## [day_name] is the tzolk'in day during a daily dusk, "" otherwise.
func show_hud(day_name := "") -> void:
	_hide_all()
	_day_tag.text = "Daily dusk: %s" % day_name if day_name != "" else ""
	_hud.visible = true

func set_run_numbers(metres: int, drop_count: int) -> void:
	_distance.text = "%s m" % UiKit.thousands(metres)
	_drops.text = str(drop_count)

## The Sunstone's charge, how far night has fallen, and how close the jaguars are.
func set_light(value: float, night: float, chaser_gap: float) -> void:
	_meter.light = value
	_meter.night = night
	_meter.gap = chaser_gap
	# The world closes in from the edges as the light fails at night.
	_dark.modulate.a = clampf((0.45 - value) / 0.45, 0.0, 1.0) * lerpf(0.5, 0.9, night)

func show_hint(text: String, dir: Vector2) -> void:
	_hint.show_hint(text, dir)

func dismiss_hint() -> void:
	_hint.dismiss()

func flash_danger() -> void:
	_danger.flash()

## A warm white burst for the flare.
func flash_flare() -> void:
	_flare_rect.modulate.a = 0.55
	var tw := create_tween()
	tw.tween_property(_flare_rect, "modulate:a", 0.0, 0.45)

# ---------------------------------------------------------------- pages ---

## A dimmed backdrop plus a centred codex page; returns [layer, page].
func _modal(height: float, dim := 0.55) -> Array:
	var root := _layer()
	var shade := ColorRect.new()
	shade.color = Color(UiKit.NIGHT, dim)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := UiKit.Page.new()
	root.add_child(page)
	_pin(page, CENTER, Rect2(-300, -height / 2.0, 600, height))
	return [root, page]

func _headline(page: Control, text: String) -> void:
	var l := UiKit.label(text, UiKit.display_font(), 46, UiKit.INK)
	l.position = Vector2(56, 44)
	page.add_child(l)
	_rule(page, 122, 1)

func _rule(page: Control, y: float, seed: int) -> void:
	var r := Rule.new(seed)
	r.position = Vector2(48, y - 6)
	r.size = Vector2(504, 12)
	page.add_child(r)

func _settings_rows(page: Control, y: float) -> float:
	var i := 0
	for row in [["Music", "music"], ["Sound", "sound"], ["Vibration", "vibration"]]:
		var key: String = row[1]
		var t := UiKit.Toggle.new(row[0], _save.get(key))
		t.position = Vector2(56, y)
		t.size = Vector2(488, 76)
		t.toggled.connect(func(on: bool):
			_save.set(key, on)
			settings_changed.emit())
		page.add_child(t)
		y += 84
		i += 1
	_rule(page, y + 8, 7)
	return y + 16

func show_pause() -> void:
	_hide_all()
	if _pause:
		_pause.queue_free()
	var m := _modal(720)
	_pause = m[0]
	var page: UiKit.Page = m[1]
	_headline(page, "Paused")
	var y := _settings_rows(page, 140)
	var resume := UiKit.GlyphButton.new("Resume", UiKit.GlyphButton.Kind.PRIMARY)
	resume.position = Vector2(56, y + 18)
	resume.size = Vector2(488, 112)
	resume.pressed.connect(func(): resume_pressed.emit())
	page.add_child(resume)
	var home := UiKit.GlyphButton.new("Home", UiKit.GlyphButton.Kind.SECONDARY)
	home.font_size = 30
	home.position = Vector2(56, y + 140)
	home.size = Vector2(488, 96)
	home.pressed.connect(func(): home_pressed.emit())
	page.add_child(home)
	page.open()

func _open_settings() -> void:
	if _settings:
		_settings.queue_free()
	var m := _modal(690 + (64 if _ads.privacy_options_required() else 0))
	_settings = m[0]
	var page: UiKit.Page = m[1]
	_headline(page, "Settings")
	var y := _settings_rows(page, 140)
	var who: String = _online.player.get("name", "")
	var acc := UiKit.label("Your runner" if who != "" else "Not signed in yet", UiKit.text_font(900), 24, UiKit.CINNABAR)
	acc.position = Vector2(58, y + 6)
	page.add_child(acc)
	var name_l := UiKit.label(who if who != "" else "Offline", UiKit.display_font(), 30, UiKit.INK)
	name_l.position = Vector2(58, y + 38)
	page.add_child(name_l)
	var account := UiKit.GlyphButton.new("Account", UiKit.GlyphButton.Kind.SECONDARY)
	account.font_size = 24
	account.position = Vector2(384, y + 18)
	account.size = Vector2(160, 72)
	account.pressed.connect(_open_account)
	page.add_child(account)
	if _ads.privacy_options_required():
		var privacy := UiKit.GlyphButton.new("Ad privacy", UiKit.GlyphButton.Kind.SECONDARY)
		privacy.font_size = 22
		privacy.position = Vector2(384, y + 88)
		privacy.size = Vector2(160, 60)
		privacy.pressed.connect(func(): _ads.show_privacy_options())
		page.add_child(privacy)
		y += 64
	var done := UiKit.GlyphButton.new("Done", UiKit.GlyphButton.Kind.PRIMARY)
	done.position = Vector2(56, y + 116)
	done.size = Vector2(488, 112)
	done.pressed.connect(func(): _settings.visible = false)
	page.add_child(done)
	page.open()

# ---------------------------------------------------------------- daily ---

## Today's dusk: the day named in the Maya count, today's best, the streak.
func _open_daily() -> void:
	if _daily:
		_daily.queue_free()
	var today := MayaCalendar.today_utc()
	var day := MayaCalendar.tzolkin(today)
	var m := _modal(760)
	_daily = m[0]
	var page: UiKit.Page = m[1]
	page.seed = 37
	_headline(page, "Daily dusk")

	# The day, as a scribe would write it: its number in Maya numerals beside
	# its name, in a glyph block.
	var block := DayBlock.new()
	block.number = day[0]
	block.position = Vector2(56, 150)
	block.size = Vector2(150, 150)
	page.add_child(block)
	var name_l := UiKit.label("%d %s" % [day[0], day[1]], UiKit.display_font(), 54, UiKit.INK)
	name_l.position = Vector2(232, 160)
	page.add_child(name_l)
	var date_l := UiKit.label(_friendly_date(today), UiKit.text_font(900), 26, UiKit.CINNABAR)
	date_l.position = Vector2(236, 238)
	page.add_child(date_l)

	var note := UiKit.wrapped("One causeway for everyone, all day. A new one at midnight UTC.",
		UiKit.text_font(800), 26, UiKit.INK, Vector2(58, 320), 486, 80)
	page.add_child(note)
	_rule(page, 418, 41)

	var best := _save.daily_best(today)
	var best_l := UiKit.label("Today's best: %s m" % UiKit.thousands(best) if best >= 0 else "Not run yet today",
		UiKit.text_font(900), 30, UiKit.INK)
	best_l.position = Vector2(58, 438)
	page.add_child(best_l)
	var streak := _save.live_streak(today)
	if streak > 1:
		var st := UiKit.label("%d days in a row" % streak, UiKit.display_font(), 26, UiKit.CINNABAR)
		st.position = Vector2(58, 482)
		page.add_child(st)

	var run := UiKit.GlyphButton.new("Run today's dusk", UiKit.GlyphButton.Kind.PRIMARY)
	run.font_size = 32
	run.position = Vector2(56, 540)
	run.size = Vector2(488, 112)
	run.pressed.connect(func():
		_daily.visible = false
		daily_pressed.emit())
	page.add_child(run)
	var close := UiKit.GlyphButton.new("Close", UiKit.GlyphButton.Kind.SECONDARY)
	close.font_size = 28
	close.position = Vector2(56, 662)
	close.size = Vector2(488, 76)
	close.pressed.connect(func(): _daily.visible = false)
	page.add_child(close)
	page.open()

const MONTHS := ["January", "February", "March", "April", "May", "June", "July",
	"August", "September", "October", "November", "December"]

## "2026-10-01" → "1 October 2026".
static func _friendly_date(key: String) -> String:
	var p := key.split("-")
	return "%d %s %s" % [p[2].to_int(), MONTHS[p[1].to_int() - 1], p[0]]

## A day's number in a glyph block, written in Maya numerals.
class DayBlock:
	extends Control
	var number := 1
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var b := UiKit.glyph_block(r, 43)
		UiKit.draw_paper(self, b, Color(1.0, 0.93, 0.78))
		UiKit.draw_ink(self, b, UiKit.INK, 5.0)
		UiKit.draw_ink(self, UiKit.glyph_block(r.grow(-11), 45, 0.6), UiKit.CINNABAR, 2.0)
		var u := 11.0
		var h := UiKit.maya_height(number, u)
		UiKit.draw_maya_number(self, Vector2(size.x / 2.0 - u * 2.0, (size.y - h) / 2.0), number, u, UiKit.INK)

# ---------------------------------------------------------------- glyphs ---

## The collection: twenty glyphs in a grid; tap one to read it, and take its
## sun-drops once it's earned.
func _open_glyphs() -> void:
	if _glyphs:
		_glyphs.queue_free()
	var m := _modal(1070)
	_glyphs = m[0]
	var page: UiKit.Page = m[1]
	page.seed = 53
	_headline(page, "Glyphs")
	var count := UiKit.label("%d of %d" % [_save.glyphs.size(), Glyphs.DEFS.size()], UiKit.text_font(900), 26, UiKit.CINNABAR)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.position = Vector2(344, 62)
	count.size = Vector2(200, 36)
	page.add_child(count)

	var title := UiKit.label("", UiKit.display_font(), 30, UiKit.INK)
	title.position = Vector2(58, 806)
	page.add_child(title)
	var text := UiKit.wrapped("", UiKit.text_font(800), 26, UiKit.INK, Vector2(58, 848), 486, 70)
	page.add_child(text)
	var take := UiKit.GlyphButton.new("Take", UiKit.GlyphButton.Kind.PRIMARY)
	take.font_size = 30
	take.position = Vector2(56, 940)
	take.size = Vector2(300, 100)
	page.add_child(take)
	var close := UiKit.GlyphButton.new("Close", UiKit.GlyphButton.Kind.SECONDARY)
	close.font_size = 28
	close.position = Vector2(370, 940)
	close.size = Vector2(174, 100)
	close.pressed.connect(func(): _glyphs.visible = false)
	page.add_child(close)
	_rule(page, 790, 59)

	var tiles: Array[UiKit.GlyphTile] = []
	var show := func(i: int) -> void:
		var d: Dictionary = Glyphs.DEFS[i]
		var st: String = _save.glyphs.get(d.id, "")
		for t in tiles:
			t.selected = t.index == i
		title.text = d.title
		text.text = "%s  Pays %d sun-drops." % [d.text, d.reward] if st != "claimed" else "%s  Taken." % d.text
		take.visible = st == "earned"
		take.text = "Take %d" % d.reward
		take.get_child(0).text = take.text
	for i in Glyphs.DEFS.size():
		var d: Dictionary = Glyphs.DEFS[i]
		var tile := UiKit.GlyphTile.new()
		tile.index = i
		tile.state = _save.glyphs.get(d.id, "")
		tile.position = Vector2(58 + (i % 4) * 124, 140 + (i / 4) * 126)
		tile.size = Vector2(114, 114)
		tile.chosen.connect(func(): show.call(i))
		page.add_child(tile)
		tiles.append(tile)
	take.pressed.connect(func():
		for t in tiles:
			if t.selected:
				var id: String = Glyphs.DEFS[t.index].id
				if _save.claim_glyph(id) > 0:
					_save.save_to_disk()
					_online.track("glyph_claim", {"id": id})
					_online.queue_sync()
					t.state = "claimed"
					t.queue_redraw()
					show.call(t.index)
					_refresh_title()
				return)
	# Open on the first glyph waiting to be taken, else the first not yet earned.
	var start := 0
	for i in Glyphs.DEFS.size():
		if _save.glyphs.get(Glyphs.DEFS[i].id, "") == "earned":
			start = i
			break
	show.call(start)
	page.open()

# ------------------------------------------------------------- offerings ---

## The temple's gifts: seven days, one each day you come back; the cycle waits
## for you rather than starting over if you miss a day.
func _open_offerings() -> void:
	if _offerings:
		_offerings.queue_free()
	var today := MayaCalendar.today_local()
	var ready := _save.offering_ready(today)
	var m := _modal(820)
	_offerings = m[0]
	var page: UiKit.Page = m[1]
	page.seed = 61
	_headline(page, "Offerings")
	page.add_child(UiKit.wrapped("The temple leaves a gift each day you return. Miss a day and it waits for you.",
		UiKit.text_font(800), 26, UiKit.INK, Vector2(58, 136), 486, 70))
	var days: Array[UiKit.OfferingDay] = []
	for i in SaveData.OFFERINGS.size():
		var d := UiKit.OfferingDay.new()
		d.day = i + 1
		d.reward = SaveData.OFFERINGS[i]
		var cycle_pos := _save.offering_day
		if i < cycle_pos:
			d.state = "taken"
		elif i == cycle_pos and ready:
			d.state = "today"
		var row := 0 if i < 4 else 1
		var col := i if i < 4 else i - 4
		var x0 := 58.0 if row == 0 else 58.0 + 62.0
		d.position = Vector2(x0 + col * 124, 226 + row * 172)
		d.size = Vector2(110, 150)
		page.add_child(d)
		days.append(d)
	_rule(page, 572, 67)
	var take := UiKit.GlyphButton.new(
		"Take today's gift" if ready else "Come back tomorrow",
		UiKit.GlyphButton.Kind.PRIMARY if ready else UiKit.GlyphButton.Kind.SECONDARY)
	take.font_size = 30
	take.position = Vector2(56, 596)
	take.size = Vector2(488, 112)
	page.add_child(take)
	take.pressed.connect(func():
		if not _save.offering_ready(today):
			_offerings.visible = false
			return
		var got := _save.take_offering(today)
		_save.save_to_disk()
		_online.track("offering_take", {"reward": got})
		_online.queue_sync()
		for d in days:
			if d.state == "today":
				d.state = "taken"
				d.queue_redraw()
		take.get_child(0).text = "+%d sun-drops" % got
		_refresh_title()
		if _ads.rewarded_ready():
			var twice := UiKit.GlyphButton.new("Watch to double it", UiKit.GlyphButton.Kind.SECONDARY)
			twice.font_size = 24
			twice.position = Vector2(56, 716)
			twice.size = Vector2(488, 70)
			twice.pressed.connect(func():
				twice.visible = false
				if await _ads.show_rewarded("double_offering"):
					_save.bank += got
					_save.save_to_disk()
					_online.queue_sync()
					take.get_child(0).text = "+%d sun-drops" % (got * 2)
					_refresh_title())
			page.add_child(twice)
		else:
			get_tree().create_timer(0.9).timeout.connect(func(): _offerings.visible = false))
	page.open()

# ----------------------------------------------------------------- ranks ---

const RANK_BOARDS := [["dusk", "Dusk"], ["day", "Today"], ["week", "Week"], ["all", "All"]]

## The temple's records: the best distances on each board, and your place.
func _open_ranks() -> void:
	if _ranks:
		_ranks.queue_free()
	var m := _modal(1080)
	_ranks = m[0]
	var page: UiKit.Page = m[1]
	page.seed = 97
	_headline(page, "Ranks")
	_ranks_body = Control.new()
	_ranks_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ranks_body.size = Vector2(600, 1080)
	page.add_child(_ranks_body)
	var close := UiKit.GlyphButton.new("Close", UiKit.GlyphButton.Kind.SECONDARY)
	close.font_size = 28
	close.position = Vector2(56, 970)
	close.size = Vector2(488, 84)
	close.pressed.connect(func(): _ranks.visible = false)
	page.add_child(close)
	page.open()
	_fill_ranks()

func _fill_ranks() -> void:
	for c in _ranks_body.get_children():
		c.queue_free()
	var body := _ranks_body
	for i in RANK_BOARDS.size():
		var b: Array = RANK_BOARDS[i]
		var tab := UiKit.GlyphButton.new(b[1], UiKit.GlyphButton.Kind.PRIMARY if b[0] == _ranks_board else UiKit.GlyphButton.Kind.SECONDARY)
		tab.font_size = 22
		tab.position = Vector2(56 + i * 124, 138)
		tab.size = Vector2(116, 70)
		tab.pressed.connect(func():
			_ranks_board = b[0]
			_fill_ranks())
		body.add_child(tab)
	var period_note := {
		"dusk": "Today's dusk: %s" % MayaCalendar.tzolkin_name(MayaCalendar.today_utc()),
		"day": "Free runs today (UTC)", "week": "Free runs this week", "all": "Every free run, ever",
	}
	var note := UiKit.label(period_note[_ranks_board], UiKit.text_font(900), 24, UiKit.CINNABAR)
	note.position = Vector2(58, 220)
	body.add_child(note)
	var reading := UiKit.label("Reading the records…", UiKit.text_font(800), 26, UiKit.INK)
	reading.position = Vector2(58, 280)
	body.add_child(reading)
	var board := _ranks_board
	var period := MayaCalendar.today_utc() if board == "dusk" else ""
	var data := await _online.leaderboard(board, period)
	if not is_instance_valid(body) or board != _ranks_board:
		return
	reading.queue_free()
	if data.is_empty():
		body.add_child(UiKit.wrapped("The temple's records can't be reached right now. Your runs are kept and sent when they can be.",
			UiKit.text_font(800), 26, UiKit.INK, Vector2(58, 280), 486, 120))
		return
	var top: Array = data.get("top", [])
	if top.is_empty():
		body.add_child(UiKit.wrapped("No one has run this yet. Be the first name in the codex.",
			UiKit.text_font(800), 26, UiKit.INK, Vector2(58, 280), 486, 80))
	var y := 266.0
	for row in top.slice(0, 10):
		_rank_row(body, row, y)
		y += 56.0
	var me: Variant = data.get("me")
	var in_top := false
	for row in top.slice(0, 10):
		if row.get("isMe", false):
			in_top = true
	if me is Dictionary and not in_top:
		_rule(body, y + 10, 101)
		_rank_row(body, me, y + 26)
	elif not me is Dictionary:
		var hint := UiKit.label("Run to take your place here.", UiKit.text_font(800), 24, UiKit.INK)
		hint.position = Vector2(58, maxf(y + 20, 520))
		body.add_child(hint)
	var players := int(data.get("players", 0))
	var count := UiKit.label("%s %s" % [UiKit.thousands(players), "runner" if players == 1 else "runners"], UiKit.text_font(900), 22, UiKit.CINNABAR)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.position = Vector2(344, 222)
	count.size = Vector2(200, 30)
	body.add_child(count)

func _rank_row(body: Control, row: Dictionary, y: float) -> void:
	var mine: bool = row.get("isMe", false)
	var color := UiKit.CINNABAR if mine else UiKit.INK
	var rank := UiKit.label("%d" % int(row.get("rank", 0)), UiKit.display_font(), 26, color)
	rank.position = Vector2(58, y)
	body.add_child(rank)
	var n := UiKit.label(str(row.get("name", "")) + ("  (you)" if mine else ""), UiKit.text_font(900), 26, color)
	n.position = Vector2(126, y + 2)
	n.size = Vector2(250, 40)
	n.clip_text = true
	body.add_child(n)
	var d := UiKit.label("%s m" % UiKit.thousands(int(row.get("distance", 0))), UiKit.display_font(), 26, color)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	d.position = Vector2(364, y)
	d.size = Vector2(180, 40)
	body.add_child(d)

# --------------------------------------------------------------- account ---

## Your runner name (rename it) and the way to delete your account.
func _open_account() -> void:
	if _account:
		_account.queue_free()
	var m := _modal(890)
	_account = m[0]
	var page: UiKit.Page = m[1]
	page.seed = 103
	_headline(page, "Account")
	var label := UiKit.label("Your name on the ranks", UiKit.text_font(900), 24, UiKit.CINNABAR)
	label.position = Vector2(58, 140)
	page.add_child(label)
	var field := UiKit.text_field(str(_online.player.get("name", "")))
	field.position = Vector2(56, 180)
	field.size = Vector2(488, 72)
	page.add_child(field)
	var status := UiKit.wrapped("", UiKit.text_font(800), 24, UiKit.CINNABAR, Vector2(58, 262), 486, 34)
	page.add_child(status)
	var save_name := UiKit.GlyphButton.new("Save name", UiKit.GlyphButton.Kind.PRIMARY)
	save_name.font_size = 28
	save_name.position = Vector2(56, 304)
	save_name.size = Vector2(488, 96)
	save_name.pressed.connect(func():
		status.text = "Saving…"
		var err := await _online.rename(field.text.strip_edges())
		status.text = err if err != "" else "Saved.")
	page.add_child(save_name)
	_rule(page, 426, 107)
	# Keeping progress with Google: survives a new phone or a reinstall.
	var email := _online.google_email()
	var kept := UiKit.wrapped(
		"Kept with Google: %s" % email if email != "" else "Your progress lives on this phone. Sign in with Google to keep it on any phone.",
		UiKit.text_font(800), 24, UiKit.INK, Vector2(58, 440), 486, 64)
	page.add_child(kept)
	if email == "":
		var google := UiKit.GlyphButton.new("Sign in with Google", UiKit.GlyphButton.Kind.PRIMARY)
		google.font_size = 26
		google.position = Vector2(56, 510)
		google.size = Vector2(488, 88)
		google.pressed.connect(func():
			kept.text = "Asking Google…"
			var err := await _online.link_google()
			if err == "" and _online.google_email() != "":
				kept.text = "Kept with Google: %s" % _online.google_email()
				google.visible = false
				field.text = str(_online.player.get("name", ""))
				_refresh_title()
			else:
				kept.text = err if err != "" else "Your progress lives on this phone. Sign in with Google to keep it on any phone.")
		page.add_child(google)
	_rule(page, 616, 109)
	page.add_child(UiKit.wrapped("Deleting your account removes your runs, ranks and cloud save from the server and starts this phone fresh.",
		UiKit.text_font(800), 24, UiKit.INK, Vector2(58, 632), 486, 90))
	var delete := UiKit.GlyphButton.new("Delete account", UiKit.GlyphButton.Kind.SECONDARY)
	delete.font_size = 23
	delete.position = Vector2(56, 750)
	delete.size = Vector2(300, 84)
	page.add_child(delete)
	var close := UiKit.GlyphButton.new("Close", UiKit.GlyphButton.Kind.SECONDARY)
	close.font_size = 26
	close.position = Vector2(370, 750)
	close.size = Vector2(174, 84)
	close.pressed.connect(func(): _account.visible = false)
	page.add_child(close)
	var armed := [false]
	delete.pressed.connect(func():
		# Two taps: the first arms it, the second deletes.
		if not armed[0]:
			armed[0] = true
			delete.get_child(0).text = "Tap to confirm"
			status.text = "This can't be undone."
			return
		status.text = "Deleting…"
		if await _online.delete_account():
			_save.reset_all()
			_save.save_to_disk()
			status.text = "Deleted. This phone starts fresh."
			account_deleted.emit()
			await get_tree().create_timer(1.4).timeout
			_account.visible = false
			if _settings:
				_settings.visible = false
		else:
			status.text = "Can't reach the temple right now. Try again later.")
	page.open()

# ---------------------------------------------------------------- market ---

const MARKET_TABS := ["Charms", "Garbs", "Hues", "Treasury"]

## The market: charms (permanent upgrades), garbs and stone hues, paid for
## in sun-drops. Tabs switch the register; the body rebuilds in place.
func _open_market() -> void:
	if _market:
		_market.queue_free()
	var m := _modal(1080)
	_market = m[0]
	var page: UiKit.Page = m[1]
	page.seed = 71
	_headline(page, "Market")
	_market_body = Control.new()
	_market_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_market_body.size = Vector2(600, 1080)
	page.add_child(_market_body)
	var close := UiKit.GlyphButton.new("Close", UiKit.GlyphButton.Kind.SECONDARY)
	close.font_size = 28
	close.position = Vector2(56, 970)
	close.size = Vector2(488, 84)
	close.pressed.connect(func(): _market.visible = false)
	page.add_child(close)
	_fill_market()
	page.open()

func _fill_market() -> void:
	for c in _market_body.get_children():
		c.queue_free()
	var body := _market_body
	var held := UiKit.label(UiKit.thousands(_save.bank), UiKit.display_font(), 30, UiKit.INK)
	held.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	held.position = Vector2(300, 52)
	held.size = Vector2(200, 44)
	body.add_child(held)
	var drop := UiKit.DropGlyph.new(32)
	drop.position = Vector2(508, 58)
	body.add_child(drop)
	for i in MARKET_TABS.size():
		var tab := UiKit.GlyphButton.new(MARKET_TABS[i],
			UiKit.GlyphButton.Kind.PRIMARY if i == _market_tab else UiKit.GlyphButton.Kind.SECONDARY)
		tab.font_size = 21
		tab.position = Vector2(56 + i * 124, 138)
		tab.size = Vector2(116, 74)
		tab.pressed.connect(func():
			_market_tab = i
			_fill_market())
		body.add_child(tab)
	match _market_tab:
		0: _fill_charms(body)
		1: _fill_looks(body, "garb", Market.GARBS)
		2: _fill_looks(body, "hue", Market.HUES)
		3: _fill_treasury(body)

## Real-money items through Google Play, priced by Play in local currency.
func _fill_treasury(body: Control) -> void:
	_market_note = UiKit.label("", UiKit.text_font(900), 22, UiKit.CINNABAR)
	_market_note.position = Vector2(58, 228)
	body.add_child(_market_note)
	if not _store.ready_to_sell():
		body.add_child(UiKit.wrapped("The treasury opens soon. Everything here will also be yours on any phone you sign in on.",
			UiKit.text_font(800), 26, UiKit.INK, Vector2(58, 262), 486, 120))
		return
	var y := 258.0
	for p in Store.PRODUCTS:
		var owned: bool = (p.id == "sunstone_remove_ads" and _save.has_entitlement("no_ads")) \
			or (p.id == "sunstone_patron" and _save.has_entitlement("patron"))
		var t := UiKit.label(p.title, UiKit.display_font(), 24, UiKit.INK)
		t.position = Vector2(58, y)
		body.add_child(t)
		body.add_child(UiKit.wrapped(p.text, UiKit.text_font(800), 21, UiKit.INK, Vector2(58, y + 34), 300, 56))
		var btn := UiKit.GlyphButton.new("Yours" if owned else str(_store.prices.get(p.id, "…")),
			UiKit.GlyphButton.Kind.SECONDARY if owned else UiKit.GlyphButton.Kind.PRIMARY)
		btn.font_size = 22
		btn.position = Vector2(384, y + 6)
		btn.size = Vector2(160, 66)
		var id: String = p.id
		if not owned:
			btn.pressed.connect(func():
				_market_note.text = "Opening Google Play…"
				_store.buy(id))
		body.add_child(btn)
		y += 108.0
	var restore := UiKit.GlyphButton.new("Restore purchases", UiKit.GlyphButton.Kind.SECONDARY)
	restore.font_size = 22
	restore.position = Vector2(56, 806)
	restore.size = Vector2(488, 62)
	restore.pressed.connect(func():
		_market_note.text = "Asking Google Play…"
		await _store.restore()
		_market_note.text = "Up to date.")
	body.add_child(restore)

func _fill_charms(body: Control) -> void:
	var y := 238.0
	for ch in Market.CHARMS:
		var tier := _save.charm_tier(ch.id)
		var t := UiKit.label(ch.title, UiKit.display_font(), 28, UiKit.INK)
		t.position = Vector2(58, y)
		body.add_child(t)
		body.add_child(UiKit.wrapped(ch.text, UiKit.text_font(800), 24, UiKit.INK, Vector2(58, y + 42), 486, 60))
		var marks := UiKit.TierMarks.new()
		marks.tier = tier
		marks.position = Vector2(58, y + 124)
		marks.size = Vector2(120, 32)
		body.add_child(marks)
		var now := UiKit.label(ch.effects[tier - 1] if tier > 0 else "Not yet", UiKit.text_font(900), 22, UiKit.CINNABAR)
		now.position = Vector2(184, y + 126)
		body.add_child(now)
		var costs: Array = ch.costs
		var btn: UiKit.GlyphButton
		if tier >= costs.size():
			btn = UiKit.GlyphButton.new("Complete", UiKit.GlyphButton.Kind.SECONDARY)
		else:
			var cost: int = costs[tier]
			btn = UiKit.GlyphButton.new(UiKit.thousands(cost),
				UiKit.GlyphButton.Kind.PRIMARY if _save.bank >= cost else UiKit.GlyphButton.Kind.SECONDARY)
			var id: String = ch.id
			btn.pressed.connect(func():
				if _save.buy_charm(id):
					_save.save_to_disk()
					_online.track("market_buy", {"id": id, "tier": _save.charm_tier(id)})
					_online.queue_sync()
					_fill_market()
					_refresh_title())
		btn.font_size = 26
		btn.position = Vector2(384, y + 110)
		btn.size = Vector2(160, 72)
		body.add_child(btn)
		y += 236.0

func _fill_looks(body: Control, kind: String, list: Array) -> void:
	var worn := _save.garb if kind == "garb" else _save.hue
	var action := UiKit.GlyphButton.new("", UiKit.GlyphButton.Kind.PRIMARY)
	var swatches: Array[UiKit.Swatch] = []
	var choose := func(sw: UiKit.Swatch) -> void:
		for o in swatches:
			o.selected = o == sw
		var id: String = sw.item.id
		var cost: int = sw.item.cost
		var label: Label = action.get_child(0)
		if id == worn:
			label.text = "Wearing" if kind == "garb" else "In the stone"
		elif _save.owns(id):
			label.text = "Wear" if kind == "garb" else "Use this hue"
		elif cost < 0:
			label.text = "Patrons only"
		elif _save.bank >= cost:
			label.text = "Buy for %s" % UiKit.thousands(cost)
		else:
			label.text = "%s sun-drops" % UiKit.thousands(cost)
	for i in list.size():
		var sw := UiKit.Swatch.new()
		sw.kind = kind
		sw.item = list[i]
		sw.owned = _save.owns(list[i].id)
		sw.worn = list[i].id == worn
		var three := list.size() > 4
		sw.position = Vector2(56 + (i % 3) * 168, 236 + (i / 3) * 236) if three else Vector2(76 + (i % 2) * 254, 238 + (i / 2) * 312)
		sw.size = Vector2(150, 190) if three else Vector2(196, 240)
		sw.chosen.connect(func(): choose.call(sw))
		body.add_child(sw)
		swatches.append(sw)
	action.font_size = 28
	action.position = Vector2(56, 862)
	action.size = Vector2(488, 92)
	body.add_child(action)
	action.pressed.connect(func():
		for sw in swatches:
			if not sw.selected:
				continue
			var id: String = sw.item.id
			if not _save.owns(id) and (sw.item.cost < 0 or not _save.buy_item(id, sw.item.cost)):
				return
			if kind == "garb":
				_save.garb = id
			else:
				_save.hue = id
			_save.save_to_disk()
			_online.track("market_wear", {"id": id})
			_online.queue_sync()
			looks_changed.emit()
			_fill_market()
			_refresh_title()
			return)
	# Start on what you wear.
	for sw in swatches:
		if sw.worn:
			choose.call(sw)

# ----------------------------------------------------------- second wind ---

## After a fall or a crash: rise again for sun-drops, while the ring counts down.
func show_second_wind(cost: int, held: int) -> void:
	_hide_all()
	if _offer:
		_offer.queue_free()
	var m := _modal(560, 0.35)
	_offer = m[0]
	var page: UiKit.Page = m[1]
	page.seed = 83
	_headline(page, "Second wind")
	page.add_child(UiKit.wrapped("Rise again where you fell, with the jaguars driven off and the stone relit.",
		UiKit.text_font(800), 26, UiKit.INK, Vector2(58, 140), 330, 140))
	var ring := UiKit.Countdown.new()
	ring.position = Vector2(410, 140)
	ring.size = Vector2(130, 130)
	page.add_child(ring)
	var held_l := UiKit.label("You hold %s" % UiKit.thousands(held), UiKit.text_font(900), 24, UiKit.CINNABAR)
	held_l.position = Vector2(58, 296)
	page.add_child(held_l)
	var can_pay := held >= cost
	var rise := UiKit.GlyphButton.new("Rise for %d" % cost, UiKit.GlyphButton.Kind.PRIMARY)
	rise.font_size = 22 if _ads.rewarded_ready() else 30
	rise.position = Vector2(56, 342)
	rise.size = Vector2(238 if _ads.rewarded_ready() else 488, 108)
	rise.visible = can_pay
	page.add_child(rise)
	var watch := UiKit.GlyphButton.new("Watch to rise", UiKit.GlyphButton.Kind.PRIMARY)
	watch.font_size = 22 if can_pay else 30
	watch.position = Vector2(306 if can_pay else 56, 342)
	watch.size = Vector2(238 if can_pay else 488, 108)
	watch.visible = _ads.rewarded_ready()
	page.add_child(watch)
	var no := UiKit.GlyphButton.new("Let it end", UiKit.GlyphButton.Kind.SECONDARY)
	no.font_size = 26
	no.position = Vector2(56, 460)
	no.size = Vector2(488, 80)
	page.add_child(no)
	var done := [false]
	var finish := func(accepted: bool) -> void:
		if done[0]:
			return
		done[0] = true
		_offer.visible = false
		if accepted:
			second_wind_accepted.emit()
		else:
			second_wind_declined.emit()
	rise.pressed.connect(func(): finish.call(true))
	watch.pressed.connect(func():
		if done[0]:
			return
		ring.set_process(false) # the ad is the player's choice; don't let the clock run out under it
		var earned := await _ads.show_rewarded("second_wind")
		if done[0]:
			return
		done[0] = true
		_offer.visible = false
		if earned:
			second_wind_by_ad.emit()
		else:
			second_wind_declined.emit())
	no.pressed.connect(func(): finish.call(false))
	ring.expired.connect(func(): finish.call(false))
	page.open()

# -------------------------------------------------------------- records ---

## How deep into the night a run reached, in words.
static func night_name(d: float) -> String:
	if d < 0.3:
		return "Sunset"
	if d < 0.6:
		return "Twilight"
	if d < 0.9:
		return "Moonrise"
	return "Deep night"

static func duration_text(seconds: float) -> String:
	var m := int(seconds / 60.0)
	if m < 60:
		return "%d min" % m
	return "%d h %d min" % [m / 60, m % 60]

## The record book: every count the codex keeps, one register per line.
func _open_records() -> void:
	if _records:
		_records.queue_free()
	var rows := [
		["Best distance", "%s m" % UiKit.thousands(_save.best)],
		["Runs", UiKit.thousands(_save.runs)],
		["Distance run", "%.1f km" % (_save.total_distance / 1000.0)],
		["Sun-drops gathered", UiKit.thousands(_save.total_drops)],
		["Most in one run", UiKit.thousands(_save.best_drops)],
		["Flares", UiKit.thousands(_save.flares)],
		["Deepest night", night_name(_save.deepest_dusk) if _save.runs > 0 else "-"],
		["Time in the temple", duration_text(_save.play_seconds)],
	]
	var top := _save.most_common_death()
	var height := 210.0 + rows.size() * 64.0 + (96.0 if top != "" else 0.0) + 150.0
	var m := _modal(height)
	_records = m[0]
	var page: UiKit.Page = m[1]
	page.seed = 29
	_headline(page, "Records")
	var y := 146.0
	for row in rows:
		var name_l := UiKit.label(row[0], UiKit.text_font(900), 28, UiKit.INK)
		name_l.position = Vector2(58, y)
		page.add_child(name_l)
		var val := UiKit.label(row[1], UiKit.display_font(), 28, UiKit.CINNABAR if row[0] == "Best distance" else UiKit.INK)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.position = Vector2(300, y - 2)
		val.size = Vector2(244, 40)
		page.add_child(val)
		y += 64.0
	if top != "":
		_rule(page, y + 4, 31)
		var t := UiKit.wrapped("Most runs end: %s" % top.to_lower(), UiKit.text_font(900), 26, UiKit.INK, Vector2(58, y + 24), 486, 60)
		page.add_child(t)
		y += 96.0
	var done := UiKit.GlyphButton.new("Done", UiKit.GlyphButton.Kind.PRIMARY)
	done.position = Vector2(56, y + 24)
	done.size = Vector2(488, 104)
	done.pressed.connect(func(): _records.visible = false)
	page.add_child(done)
	page.open()

# -------------------------------------------------------------- results ---

## The run, recorded as a codex entry: what ended it, the distance in our
## numerals and in Maya ones, the sun-drops gathered, and the way back in.
## [daily] is {name, best, is_best} after a daily dusk, empty otherwise.
func show_results(cause: String, metres: int, drop_count: int, best: int, is_best: bool, daily := {}, new_glyphs: Array[String] = []) -> void:
	_hide_all()
	if _results:
		_results.queue_free()
	_results = _layer()
	var shade := ColorRect.new()
	shade.color = Color(UiKit.NIGHT, 0.4)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_results.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var page := UiKit.Page.new()
	page.seed = 19
	_results.add_child(page)
	_pin(page, BOTTOM_CENTER, Rect2(-310, -780, 620, 724))

	var head := UiKit.wrapped(cause, UiKit.display_font(), 38, UiKit.INK, Vector2(56, 44), 508, 100)
	page.add_child(head)
	_rule(page, 150, 21)

	var dist := UiKit.label("0 m", UiKit.display_font(), 92, UiKit.INK)
	dist.position = Vector2(52, 160)
	page.add_child(dist)
	var maya := MayaNumber.new()
	maya.position = Vector2(510, 176)
	maya.size = Vector2(40, 120)
	page.add_child(maya)

	var glyph := UiKit.DropGlyph.new(36)
	glyph.position = Vector2(58, 306)
	page.add_child(glyph)
	var drops := UiKit.label("+%d sun-drops" % drop_count, UiKit.text_font(900), 32, UiKit.INK)
	drops.position = Vector2(106, 298)
	page.add_child(drops)
	if drop_count > 0 and _ads.rewarded_ready():
		var twice := UiKit.GlyphButton.new("Watch: double", UiKit.GlyphButton.Kind.PRIMARY)
		twice.font_size = 20
		twice.position = Vector2(384, 290)
		twice.size = Vector2(170, 60)
		twice.pressed.connect(func():
			twice.visible = false
			if await _ads.show_rewarded("double_drops"):
				_save.bank += drop_count
				_save.save_to_disk()
				_online.queue_sync()
				drops.text = "+%d sun-drops" % (drop_count * 2))
		page.add_child(twice)

	var best_text := "New best" if is_best else "Best %s m" % UiKit.thousands(best)
	var highlight := is_best
	if not daily.is_empty():
		highlight = daily.is_best
		best_text = ("New best for %s" % daily.name) if daily.is_best else ("Best for %s: %s m" % [daily.name, UiKit.thousands(daily.best)])
	var best_l := UiKit.label(best_text,
		UiKit.display_font() if highlight else UiKit.text_font(900), 30, UiKit.CINNABAR if highlight else UiKit.INK)
	best_l.position = Vector2(58, 352)
	page.add_child(best_l)
	if not new_glyphs.is_empty():
		var g_text := "New glyph: %s" % Glyphs.def(new_glyphs[0]).title if new_glyphs.size() == 1 else "%d new glyphs" % new_glyphs.size()
		var g := UiKit.label(g_text, UiKit.display_font(), 24, UiKit.CINNABAR)
		g.position = Vector2(58, 394)
		page.add_child(g)
	_rule(page, 440, 23)

	var again := UiKit.GlyphButton.new("Run again", UiKit.GlyphButton.Kind.PRIMARY)
	again.position = Vector2(56, 464)
	again.size = Vector2(508, 116)
	again.pressed.connect(func(): again_pressed.emit())
	page.add_child(again)
	var home := UiKit.GlyphButton.new("Home", UiKit.GlyphButton.Kind.SECONDARY)
	home.font_size = 30
	home.position = Vector2(56, 594)
	home.size = Vector2(508, 96)
	home.pressed.connect(func(): home_pressed.emit())
	page.add_child(home)

	# The one orchestrated moment: the page unfolds, then the distance is
	# counted out — in both kinds of numerals.
	page.open()
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_method(func(v: float):
		dist.text = "%s m" % UiKit.thousands(int(v))
		maya.set_value(int(v)), 0.0, float(metres), 0.8).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
