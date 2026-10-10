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
signal dash_pressed
signal update_pressed
signal resume_pressed
signal home_pressed
signal again_pressed
signal settings_changed
signal back_requested
signal account_reset ## signed out or deleted: the phone starts fresh
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
var _email: Control
var _legal: Control
var _legal_doc := "privacy"
var _top := 28.0 ## below the status bar / camera cutout

var _title: Control
var _wordmark: UiKit.Wordmark
var _best: UiKit.PaperSlip
var _hud: Control
var _distance: Label ## "Night 2"
var _house: Label
var _metres: Label
var _dawn: DawnTrack
var _banner: Banner
var _drops: Label
var _meter: UiKit.SunMeter
var _hint: UiKit.HintStrip
var _dash_btn: UiKit.GlyphButton
var _update_btn: UiKit.GlyphButton
var _danger: UiKit.DangerFlash
var _pause: Control
var _settings: Control
var _results: Control
var _records: Control
var _howto: Control
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

## The way to dawn across the top of the HUD: a dotted road, the stretch
## already run inked in ochre, a tick where each House begins, the little sun
## of the runner on it, and "Dawn" at the end.
class DawnTrack:
	extends Control
	var t := 0.0
	var dawn := false
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func set_progress(v: float, at_dawn: bool) -> void:
		if absf(v - t) > 0.001 or at_dawn != dawn:
			t = v
			dawn = at_dawn
			queue_redraw()
	func _draw() -> void:
		var y := size.y - 14.0
		var x0 := 6.0
		var x1 := size.x - 6.0
		var x := 0.0
		while x < x1 - x0:
			draw_line(Vector2(x0 + x, y), Vector2(x0 + minf(x + 10.0, x1 - x0), y), Color(UiKit.STUCCO, 0.35), 4.0, true)
			x += 18.0
		var xp := lerpf(x0, x1, clampf(t, 0.0, 1.0))
		draw_line(Vector2(x0, y), Vector2(xp, y), UiKit.INK, 9.0, true)
		draw_line(Vector2(x0, y), Vector2(xp, y), UiKit.OCHRE, 5.0, true)
		for f in [1.0 / 3.0, 2.0 / 3.0]:
			var hx := lerpf(x0, x1, f)
			draw_line(Vector2(hx, y - 10), Vector2(hx, y + 10), Color(UiKit.STUCCO, 0.8), 3.0, true)
		var font := UiKit.text_font(900)
		draw_string_outline(font, Vector2(x1 - 70, y - 16), "Dawn", HORIZONTAL_ALIGNMENT_RIGHT, 70, 22, 8, UiKit.INK)
		draw_string(font, Vector2(x1 - 70, y - 16), "Dawn", HORIZONTAL_ALIGNMENT_RIGHT, 70, 22, UiKit.OCHRE_LIGHT if dawn else UiKit.STUCCO)
		UiKit.draw_kin(self, Vector2(xp, y), 13.0, 1.0, 3.0)

## A slip of codex that names the House you just entered, then fades.
class Banner:
	extends Control
	var _title := ""
	var _sub := ""
	var _life := 0.0
	var _t := 0.0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		modulate.a = 0.0
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	func show_banner(title: String, sub: String, life := 2.8) -> void:
		_title = title
		_sub = sub
		_life = life
		_t = 0.0
		queue_redraw()
	func _process(delta: float) -> void:
		if _life > 0.0:
			_life -= delta
			_t += delta
			modulate.a = clampf(minf(_t / 0.25, _life / 0.5), 0.0, 1.0)
			pivot_offset = size / 2.0
			scale = Vector2.ONE * (1.0 + 0.04 * maxf(0.0, 1.0 - _t / 0.25))
		elif modulate.a > 0.0:
			modulate.a = 0.0
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var edge := UiKit.torn(r, 71, 1.6)
		var shadow := PackedVector2Array()
		for p in edge:
			shadow.append(p + Vector2(0, 8))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.32))
		UiKit.draw_paper(self, edge)
		UiKit.draw_rule(self, Vector2(14, 10), Vector2(size.x - 14, 10), UiKit.CINNABAR, 3.0, 31)
		UiKit.draw_rule(self, Vector2(14, size.y - 10), Vector2(size.x - 14, size.y - 10), UiKit.CINNABAR, 3.0, 37)
		var big := UiKit.display_font()
		var small := UiKit.text_font(900)
		draw_string(big, Vector2(0, size.y * 0.52), _title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 42, UiKit.INK)
		draw_string(small, Vector2(0, size.y * 0.52 + 44), _sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, UiKit.CINNABAR)

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

## True while a page covers the world (any menu page, pause, results).
func page_open() -> bool:
	for page in [_howto, _legal, _email, _account, _settings, _records, _daily, _glyphs, _offerings, _market, _ranks, _pause, _results]:
		if page and is_instance_valid(page) and page.visible:
			return true
	return false

## Closes whichever title page is open (settings, records...); true when one was.
func close_modal() -> bool:
	for page in [_howto, _legal, _email, _account, _settings, _records, _daily, _glyphs, _offerings, _market, _ranks]:
		if page and is_instance_valid(page) and page.visible:
			page.visible = false
			return true
	return false

## Draws every letter once, invisibly, at the sizes the game uses, so a
## banner, a pop or the results page never stalls rasterising glyphs mid-run.
class FontWarmup:
	extends Control
	var frames := 0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var text := ""
		for c in range(32, 127):
			text += char(c)
		text += "áéíóúñ·’—…"
		var y := 10.0
		for size in [16, 19, 21, 22, 24, 26, 28, 30, 32, 34, 36, 38, 42, 46, 48, 52, 88, 92]:
			draw_string(UiKit.display_font(), Vector2(0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.004))
			y += 4.0
		for weight in [800, 900]:
			for size in [20, 21, 22, 23, 24, 26, 28, 30, 32, 34]:
				draw_string(UiKit.text_font(weight), Vector2(0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.004))
				y += 4.0
	func _process(_delta: float) -> void:
		frames += 1
		if frames > 3:
			queue_free()

func setup(save: SaveData, online: Online, ads: Ads, store: Store) -> void:
	_root().add_child(FontWarmup.new())
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
	_dark.visible = false
	_root().add_child(_dark)
	_root().move_child(_dark, 0)
	_dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flare_rect = ColorRect.new()
	_flare_rect.color = Color("#FFE6A8")
	_flare_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flare_rect.modulate.a = 0.0
	_flare_rect.visible = false
	_root().add_child(_flare_rect)
	_flare_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## The camera-cutout (notch, Dynamic Island) inset, in UI units.
func _safe_top() -> float:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	var vp := get_viewport().get_visible_rect().size
	if screen.y <= 0 or OS.get_name() not in ["Android", "iOS"]:
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
		[UiKit.GlyphIcon.Icon.MARKET, "Shop", _open_market],
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

	# A downloaded update, waiting for a restart (AppUpdates).
	_update_btn = UiKit.GlyphButton.new("Restart to update", UiKit.GlyphButton.Kind.SECONDARY)
	_update_btn.font_size = 26
	_title.add_child(_update_btn)
	_pin(_update_btn, TOP_CENTER, Rect2(-190, _top + 312, 380, 76))
	_update_btn.pressed.connect(func(): update_pressed.emit())
	_update_btn.visible = false

func show_title(save: SaveData) -> void:
	# Shown again while already up (progress synced, a look changed): no replay.
	var already := _title.visible and not _hud.visible
	_hide_all()
	if save.best > 0:
		_best.set_text("Best %s m" % UiKit.thousands(save.best), save.best)
	else:
		_best.set_text("Carry the sun to dawn")
	_title.visible = true
	if not already:
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
	_distance = UiKit.label("Night 1", UiKit.display_font(), 46, UiKit.STUCCO, 12)
	_hud.add_child(_distance)
	_pin(_distance, TOP_LEFT, Rect2(28, _top - 4, 320, 70))
	_house = UiKit.label("", UiKit.text_font(900), 24, UiKit.OCHRE_LIGHT, 8)
	_hud.add_child(_house)
	_pin(_house, TOP_LEFT, Rect2(30, _top + 58, 300, 36))

	var glyph := UiKit.DropGlyph.new(30)
	_hud.add_child(glyph)
	_pin(glyph, TOP_LEFT, Rect2(32, _top + 100, 30, 30))
	_drops = UiKit.label("0", UiKit.text_font(900), 30, UiKit.OCHRE_LIGHT, 10)
	_hud.add_child(_drops)
	_pin(_drops, TOP_LEFT, Rect2(70, _top + 92, 90, 44))
	_metres = UiKit.label("0 m", UiKit.text_font(900), 26, UiKit.STUCCO, 8)
	_hud.add_child(_metres)
	_pin(_metres, TOP_LEFT, Rect2(150, _top + 96, 180, 40))

	# During a daily dusk, the day's name sits under the sun-drops.
	_day_tag = UiKit.label("", UiKit.text_font(900), 24, UiKit.OCHRE_LIGHT, 8)
	_hud.add_child(_day_tag)
	_pin(_day_tag, TOP_LEFT, Rect2(32, _top + 136, 300, 36))

	_meter = UiKit.SunMeter.new()
	_hud.add_child(_meter)
	_pin(_meter, TOP_CENTER, Rect2(-75, _top - 10, 150, 190))

	var pause := UiKit.GlyphIcon.new(UiKit.GlyphIcon.Icon.PAUSE)
	_hud.add_child(pause)
	_pin(pause, TOP_RIGHT, Rect2(-108, _top, 84, 84))
	pause.pressed.connect(func(): pause_pressed.emit())

	_dawn = DawnTrack.new()
	_hud.add_child(_dawn)
	_pin(_dawn, Rect2(0, 0, 1, 0), Rect2(28, _top + 176, -56, 44))

	_banner = Banner.new()
	_hud.add_child(_banner)
	_pin(_banner, Rect2(0.5, 0.25, 0, 0), Rect2(-270, 0, 540, 140))

	_hint = UiKit.HintStrip.new()
	_hud.add_child(_hint)
	_pin(_hint, Rect2(0.5, 0.74, 0, 0), Rect2(-270, 0, 540, 112))

	# The head start, offered for the first moments of a run.
	_dash_btn = UiKit.GlyphButton.new("Head start")
	_hud.add_child(_dash_btn)
	_pin(_dash_btn, Rect2(0.5, 0.88, 0, 0), Rect2(-170, -50, 340, 96))
	_dash_btn.pressed.connect(func(): dash_pressed.emit())
	_dash_btn.visible = false

## A new version has downloaded: the title offers to restart into it.
func show_update_ready() -> void:
	_update_btn.visible = true

## Offers the head start ([count] held) for a few seconds.
func show_dash(count: int) -> void:
	_dash_btn.text = "Head start  ×%d" % count if count > 1 else "Head start"
	if _dash_btn._label:
		_dash_btn._label.text = _dash_btn.text
	_dash_btn.modulate.a = 1.0
	_dash_btn.visible = true

func hide_dash() -> void:
	if not _dash_btn.visible:
		return
	var tw := _dash_btn.create_tween()
	tw.tween_property(_dash_btn, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func(): _dash_btn.visible = false)

## [day_name] is the tzolk'in day during a daily dusk, "" otherwise.
func show_hud(day_name := "") -> void:
	_hide_all()
	_day_tag.text = "Daily dusk: %s" % day_name if day_name != "" else ""
	_hud.visible = true

func set_run_numbers(metres: int, drop_count: int) -> void:
	_metres.text = "%s m" % UiKit.thousands(metres)
	_drops.text = str(drop_count)

## Which night, which House, and how far to dawn (0..1).
func set_night(n: int, house: String, t: float, dawn: bool) -> void:
	_distance.text = "Night %d" % n
	_house.text = "The sun is rising" if dawn else house
	_dawn.set_progress(1.0 if dawn else t, dawn)

## The launch: the boot splash's sun glyph (same image, same place) rises
## and settles into the title wordmark while the plum behind it fades away,
## then the wordmark's strip unrolls beneath it. Holds a moment first so the
## world's first frames are drawn behind the plum.
func play_splash() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var splash := Splash.new()
	layer.add_child(splash)
	splash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wordmark.sun = UiKit.Wordmark.Sun.HIDDEN
	for i in 4:
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	var target := _wordmark.global_position + Vector2(320, 96)
	var tw := splash.create_tween()
	tw.tween_method(func(t: float): splash.fly(t, target), 0.0, 1.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_wordmark.sun = UiKit.Wordmark.Sun.PLACED
	_wordmark.replay()
	layer.queue_free()

## The splash overlay: the boot splash's plum and its glyph, drawn exactly
## where the engine drew them (the image fitted to the screen, centred).
class Splash:
	extends Control
	const GLYPH_R := 150.0 / 1024.0 ## the glyph's radius in the image (tools/make_splash.py)
	const BG := Color(0.1647, 0.1059, 0.2392)
	var _tex: Texture2D = preload("res://assets/icon/splash.png")
	var _t := 0.0
	var _to := Vector2.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP # no taps reach the title mid-flight

	## [t] 0..1 along the flight to [target] (the wordmark's sun centre).
	func fly(t: float, target: Vector2) -> void:
		_t = t
		_to = target
		queue_redraw()

	func _draw() -> void:
		var d := minf(size.x, size.y)
		var from := size / 2.0
		var c := from.lerp(_to, _t) if _t > 0.0 else from
		# Shrinks to the wordmark's glyph (radius 58).
		var k := lerpf(1.0, 58.0 / (GLYPH_R * d), _t)
		var fade := 1.0 - smoothstep(0.15, 0.85, _t)
		draw_rect(Rect2(Vector2.ZERO, size), Color(BG, fade))
		var side := d * k
		draw_texture_rect(_tex, Rect2(c - Vector2(side, side) / 2.0, Vector2(side, side)), false)

## A short line that pops under the sun meter: "Sun-string +3".
var _pops_live := 0 ## pops on screen now: a new one sits under the last
func pop(text: String) -> void:
	var l := UiKit.label(text, UiKit.display_font(), 34, UiKit.OCHRE_LIGHT, 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(l)
	_pin(l, TOP_CENTER, Rect2(-260, _top + 230 + 52 * (_pops_live % 3), 520, 60))
	_pops_live += 1
	l.tree_exited.connect(func(): _pops_live = maxi(_pops_live - 1, 0))
	l.pivot_offset = Vector2(260, 30)
	l.scale = Vector2.ONE * 0.6
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.7)
	tw.parallel().tween_property(l, "position:y", l.position.y - 30.0, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.35)
	tw.tween_callback(l.queue_free)

## Names the House you just walked into.
func show_banner(title: String, sub: String) -> void:
	_banner.show_banner(title, sub)

## The Sunstone's charge, how far night has fallen, and how close the jaguars are.
## The least light a flare needs (marked on the sun meter's ring).
func set_flare_cost(value: float) -> void:
	_meter.cost = value

func set_light(value: float, night: float, chaser_gap: float) -> void:
	_meter.light = value
	_meter.night = night
	_meter.gap = chaser_gap
	# The world closes in from the edges as the light fails at night.
	_dark.modulate.a = clampf((0.45 - value) / 0.45, 0.0, 1.0) * lerpf(0.5, 0.9, night)
	# A full-screen layer costs a whole pass of fill even when clear: draw it
	# only when it shows.
	_dark.visible = _dark.modulate.a > 0.01

func show_hint(text: String, dir: Vector2) -> void:
	_hint.show_hint(text, dir)

func dismiss_hint() -> void:
	_hint.dismiss()

func flash_danger() -> void:
	_danger.flash()

## A warm white burst for the flare.
func flash_flare() -> void:
	_flare_rect.modulate.a = 0.55
	_flare_rect.visible = true
	var tw := create_tween()
	tw.tween_property(_flare_rect, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func(): _flare_rect.visible = false)

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
	var m := _modal(810)
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
	var how := UiKit.GlyphButton.new("How to play", UiKit.GlyphButton.Kind.SECONDARY)
	how.font_size = 26
	how.position = Vector2(56, y + 246)
	how.size = Vector2(488, 76)
	how.pressed.connect(_open_howto)
	page.add_child(how)
	page.open()

func _open_settings() -> void:
	if _settings:
		_settings.queue_free()
	var m := _modal(862 + (64 if _ads.privacy_options_required() else 0))
	_settings = m[0]
	var page: UiKit.Page = m[1]
	_headline(page, "Settings")
	var y := _settings_rows(page, 140)
	var who: String = _online.player.get("name", "")
	var acc := UiKit.label("Your runner" if who != "" else "Not signed in yet", UiKit.text_font(900), 24, UiKit.CINNABAR)
	acc.position = Vector2(58, y + 6)
	page.add_child(acc)
	var name_l := UiKit.label(who if who != "" else "Offline", UiKit.display_font(), 26, UiKit.INK)
	name_l.position = Vector2(58, y + 40)
	# Long names stop short of the Account button.
	name_l.size = Vector2(300, 44)
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
	var how := UiKit.GlyphButton.new("How to play", UiKit.GlyphButton.Kind.SECONDARY)
	how.font_size = 28
	how.position = Vector2(56, y + 112)
	how.size = Vector2(488, 80)
	how.pressed.connect(_open_howto)
	page.add_child(how)
	y += 92
	var done := UiKit.GlyphButton.new("Done", UiKit.GlyphButton.Kind.PRIMARY)
	done.position = Vector2(56, y + 116)
	done.size = Vector2(488, 112)
	done.pressed.connect(func(): _settings.visible = false)
	page.add_child(done)
	var legal := UiKit.GlyphButton.new("Privacy & terms", UiKit.GlyphButton.Kind.SECONDARY)
	legal.font_size = 22
	legal.position = Vector2(56, y + 238)
	legal.size = Vector2(488, 62)
	legal.pressed.connect(_open_legal)
	page.add_child(legal)
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

## Your runner name, how your progress is kept (guest, Google / Apple, or
## email, and signing out), and deleting the account.
func _open_account() -> void:
	if _account:
		_account.queue_free()
	var guest := _online.is_guest()
	var m := _modal(1004 if guest else 904)
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
	# How progress is kept: a guest's lives on this phone only.
	var kept := UiKit.wrapped(_online.linked_summary() if not guest
			else "Your progress lives on this phone. Sign in to keep it on any phone.",
		UiKit.text_font(800), 24, UiKit.INK, Vector2(58, 440), 486, 64)
	page.add_child(kept)
	var y := 528.0
	if guest:
		var provider := _online.provider_name()
		var link: Control # a GlyphButton, or Apple's own button on iOS; both emit `pressed`
		if provider == "Apple":
			link = _apple_button()
		else:
			var google := UiKit.GlyphButton.new("Sign in with Google", UiKit.GlyphButton.Kind.PRIMARY)
			google.font_size = 26
			link = google
		link.position = Vector2(56, y)
		link.size = Vector2(488, 88)
		link.connect("pressed", func():
			kept.text = "Asking %s…" % provider
			var err := await _online.link_account()
			if err == "" and not _online.is_guest():
				_after_account_change()
			else:
				kept.text = err if err != "" else "Your progress lives on this phone. Sign in to keep it on any phone.")
		page.add_child(link)
		var email := UiKit.GlyphButton.new("Use email", UiKit.GlyphButton.Kind.SECONDARY)
		email.font_size = 26
		email.position = Vector2(56, y + 100)
		email.size = Vector2(488, 80)
		email.pressed.connect(_open_email)
		page.add_child(email)
		y += 206
	else:
		var sign_out := UiKit.GlyphButton.new("Sign out", UiKit.GlyphButton.Kind.SECONDARY)
		sign_out.font_size = 26
		sign_out.position = Vector2(56, y)
		sign_out.size = Vector2(488, 80)
		sign_out.pressed.connect(func():
			kept.text = "Saving your progress…"
			var err := await _online.sign_out()
			if err != "":
				kept.text = err
				return
			_save.reset_all()
			_save.save_to_disk()
			kept.text = "Signed out. Sign in again any time to get your progress back."
			account_reset.emit()
			await get_tree().create_timer(1.6).timeout
			if is_instance_valid(page):
				_account.visible = false)
		page.add_child(sign_out)
		y += 106
	_rule(page, y, 109)
	page.add_child(UiKit.wrapped("Deleting your account removes your runs, ranks and cloud save from the server and starts this phone fresh.",
		UiKit.text_font(800), 24, UiKit.INK, Vector2(58, y + 16), 486, 90))
	var delete := UiKit.GlyphButton.new("Delete account", UiKit.GlyphButton.Kind.SECONDARY)
	delete.font_size = 23
	delete.position = Vector2(56, y + 134)
	delete.size = Vector2(300, 84)
	page.add_child(delete)
	var close := UiKit.GlyphButton.new("Close", UiKit.GlyphButton.Kind.SECONDARY)
	close.font_size = 26
	close.position = Vector2(370, y + 134)
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
			account_reset.emit()
			await get_tree().create_timer(1.4).timeout
			_account.visible = false
			if _settings:
				_settings.visible = false
		else:
			status.text = "Can't reach the temple right now. Try again later.")
	page.open()

## Signed in, linked or switched: the Account page shows the new state and
## the title the account's name and progress.
func _after_account_change() -> void:
	_refresh_title()
	if _settings and is_instance_valid(_settings) and _settings.visible:
		_open_settings() # it shows the runner's name; built first so Account stays on top
	_open_account()

# ----------------------------------------------------------------- email ---

## Email and password: sign in to an account, create one (this guest's
## progress moves into it), or get a reset link.
func _open_email() -> void:
	if _email:
		_email.queue_free()
	var m := _modal(866)
	_email = m[0]
	var page: UiKit.Page = m[1]
	page.seed = 131
	_headline(page, "Use email")
	page.add_child(UiKit.wrapped("Sign in to your account, or create one to keep this phone's progress.",
		UiKit.text_font(800), 24, UiKit.INK, Vector2(58, 140), 486, 64))
	var email_label := UiKit.label("Email", UiKit.text_font(900), 24, UiKit.CINNABAR)
	email_label.position = Vector2(58, 214)
	page.add_child(email_label)
	var email := UiKit.text_field("")
	email.max_length = 254
	email.placeholder_text = "you@example.com"
	email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	email.add_theme_font_size_override("font_size", 28)
	email.add_theme_color_override("font_placeholder_color", Color(UiKit.INK, 0.35))
	email.position = Vector2(56, 250)
	email.size = Vector2(488, 72)
	page.add_child(email)
	var password_label := UiKit.label("Password", UiKit.text_font(900), 24, UiKit.CINNABAR)
	password_label.position = Vector2(58, 336)
	page.add_child(password_label)
	var password := UiKit.text_field("")
	password.max_length = 128
	password.secret = true
	password.placeholder_text = "at least 6 characters"
	password.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	password.add_theme_font_size_override("font_size", 28)
	password.add_theme_color_override("font_placeholder_color", Color(UiKit.INK, 0.35))
	password.position = Vector2(56, 372)
	password.size = Vector2(488, 72)
	page.add_child(password)
	var note := UiKit.wrapped("", UiKit.text_font(800), 23, UiKit.CINNABAR, Vector2(58, 456), 486, 60)
	page.add_child(note)
	var sign_in := UiKit.GlyphButton.new("Sign in", UiKit.GlyphButton.Kind.PRIMARY)
	sign_in.font_size = 28
	sign_in.position = Vector2(56, 540)
	sign_in.size = Vector2(488, 92)
	page.add_child(sign_in)
	var create := UiKit.GlyphButton.new("Create account", UiKit.GlyphButton.Kind.SECONDARY)
	create.font_size = 26
	create.position = Vector2(56, 644)
	create.size = Vector2(488, 80)
	page.add_child(create)
	var forgot := UiKit.GlyphButton.new("Forgot password?", UiKit.GlyphButton.Kind.SECONDARY)
	forgot.font_size = 21
	forgot.position = Vector2(56, 738)
	forgot.size = Vector2(300, 74)
	page.add_child(forgot)
	var back := UiKit.GlyphButton.new("Back", UiKit.GlyphButton.Kind.SECONDARY)
	back.font_size = 24
	back.position = Vector2(370, 738)
	back.size = Vector2(174, 74)
	back.pressed.connect(func(): _email.visible = false)
	page.add_child(back)
	var busy := [false]
	# One request at a time; the keyboard goes away so the answer shows.
	var run := func(waiting: String, work: Callable) -> void:
		if busy[0]:
			return
		busy[0] = true
		email.release_focus()
		password.release_focus()
		DisplayServer.virtual_keyboard_hide()
		note.text = waiting
		var err: String = await work.call()
		busy[0] = false
		if err != "":
			note.text = err
			return
		_email.visible = false
		_after_account_change()
	sign_in.pressed.connect(func(): run.call("Signing in…",
		func() -> String: return await _online.email_sign_in(email.text, password.text)))
	create.pressed.connect(func(): run.call("Creating your account…",
		func() -> String: return await _online.email_create(email.text, password.text)))
	forgot.pressed.connect(func():
		if busy[0]:
			return
		busy[0] = true
		note.text = "Sending…"
		var err := await _online.email_reset(email.text)
		busy[0] = false
		note.text = err if err != "" else "If that email has an account, a reset link is on its way.")
	email.text_submitted.connect(func(_t: String): password.grab_focus())
	password.text_submitted.connect(func(_t: String): sign_in.pressed.emit())
	page.open()

# ----------------------------------------------------------------- legal ---

## The privacy policy, terms and refund policy, read from legal/*.md (shipped with the game).
func _open_legal() -> void:
	if _legal:
		_legal.queue_free()
	var m := _modal(1060)
	_legal = m[0]
	var page: UiKit.Page = m[1]
	page.seed = 113
	var docs := [["privacy", "Privacy"], ["terms", "Terms"], ["refund", "Refunds"]]
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(48, 150)
	scroll.size = Vector2(504, 800)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.custom_minimum_size = Vector2(488, 0)
	text.mouse_filter = Control.MOUSE_FILTER_PASS
	text.add_theme_font_override("normal_font", UiKit.text_font(800))
	text.add_theme_font_override("bold_font", UiKit.text_font(900))
	text.add_theme_font_size_override("normal_font_size", 22)
	text.add_theme_font_size_override("bold_font_size", 22)
	text.add_theme_color_override("default_color", UiKit.INK)
	scroll.add_child(text)
	var show := func(doc: String) -> void:
		_legal_doc = doc
		text.text = _markdown_to_bbcode(FileAccess.get_file_as_string("res://legal/%s.md" % doc))
		scroll.scroll_vertical = 0
	for i in docs.size():
		var d: Array = docs[i]
		var tab := UiKit.GlyphButton.new(d[1], UiKit.GlyphButton.Kind.SECONDARY)
		tab.font_size = 18
		tab.position = Vector2(56 + i * 120, 52)
		tab.size = Vector2(114, 70)
		tab.pressed.connect(func(): show.call(d[0]))
		page.add_child(tab)
	var close := UiKit.GlyphButton.new("Close", UiKit.GlyphButton.Kind.PRIMARY)
	close.font_size = 24
	close.position = Vector2(420, 52)
	close.size = Vector2(124, 70)
	close.pressed.connect(func(): _legal.visible = false)
	page.add_child(close)
	_rule(page, 136, 117)
	show.call(_legal_doc)
	page.open()

## Just enough Markdown for our legal pages: headings, bold, bullets, paragraphs.
static func _markdown_to_bbcode(md: String) -> String:
	var out := PackedStringArray()
	for line in md.split("\n"):
		var l := line.strip_edges()
		if l.begins_with("# "):
			out.append("[font_size=34][b]%s[/b][/font_size]" % l.substr(2))
		elif l.begins_with("## "):
			out.append("\n[font_size=26][b][color=#B8322A]%s[/color][/b][/font_size]" % l.substr(3))
		else:
			if l.begins_with("- "):
				l = "•  " + l.substr(2)
			var parts := l.split("**")
			var b := ""
			for i in parts.size():
				b += ("[b]%s[/b]" % parts[i]) if i % 2 == 1 else parts[i]
			out.append(b)
	return "\n".join(out)

# ------------------------------------------------------------------ shop ---

## A card on a shop shelf: the item's name, a few chips of its colours, and
## its price — sun-drops, a store price, or "Yours" / "Wearing".
class ItemCard:
	extends Control
	signal chosen
	var title := ""
	var chips: Array = [] ## colours to show
	var price := "" ## "" when owned
	var drops_price := false ## price is in sun-drops (draw the drop glyph)
	var state := "" ## "Wearing", "Yours", ""
	var selected := false:
		set(v):
			selected = v
			queue_redraw()
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		custom_minimum_size = Vector2(152, 112)
	func _gui_input(event: InputEvent) -> void:
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and not event.pressed:
			chosen.emit()
			accept_event()
	func _draw() -> void:
		var r := Rect2(Vector2(3, 3), size - Vector2(6, 6))
		var face := UiKit.glyph_block(r, hash(title) % 97, 0.6)
		UiKit.draw_paper(self, face, Color(1, 1, 1) if state == "" else Color(1.0, 0.97, 0.88))
		UiKit.draw_ink(self, face, UiKit.CINNABAR if selected else UiKit.INK, 6.0 if selected else 3.0)
		var big := UiKit.display_font()
		var small := UiKit.text_font(900)
		draw_string(big, Vector2(12, 34), title, HORIZONTAL_ALIGNMENT_CENTER, size.x - 24, 19 if title.length() < 11 else (16 if title.length() < 13 else 14), UiKit.INK)
		var n := chips.size()
		for i in n:
			var c := Vector2(size.x / 2.0 + (i - (n - 1) / 2.0) * 26.0, 58)
			draw_circle(c, 10.0, chips[i], true, -1.0, true)
			draw_arc(c, 10.0, 0.0, TAU, 20, UiKit.INK, 2.0, true)
		if state != "":
			draw_string(small, Vector2(10, size.y - 16), state, HORIZONTAL_ALIGNMENT_CENTER, size.x - 20, 20, UiKit.CINNABAR)
		else:
			var tw := small.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
			var x0 := (size.x - tw - (26.0 if drops_price else 0.0)) / 2.0
			if drops_price:
				UiKit.draw_kin(self, Vector2(x0 + 9, size.y - 23), 9.0, 1.0, 2.0)
				x0 += 24.0
			draw_string(small, Vector2(x0, size.y - 16), price, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, UiKit.INK)

const MARKET_TABS := Shop.SHELVES
var _shop_sel := {} ## shelf → selected item id
var _preview: SubViewport
var _preview_root: Node3D
var _preview_runner: RunnerModel
var _shop_action: UiKit.GlyphButton
var _shop_caption: Label
var _shop_tabs: Array[UiKit.GlyphButton] = []
var _preview_box: SubViewportContainer

## The shop: runners, outfits, hats and stone hues to try on and buy (for
## sun-drops or real money), charms, boosts, and the treasury. Tabs switch
## the shelf; the body rebuilds in place.
func _open_market() -> void:
	if _market:
		_market.queue_free()
	var m := _modal(1100)
	_market = m[0]
	var page: UiKit.Page = m[1]
	page.seed = 71
	_headline(page, "Shop")
	# Tabs and the 3D preview live as long as the page: switching shelves only
	# rebuilds the cards (rebuilding everything froze a phone for ~0.1 s).
	_shop_tabs.clear()
	for i in MARKET_TABS.size():
		var row := 0 if i < 4 else 1
		var col := i if i < 4 else i - 4
		var tab := UiKit.GlyphButton.new(MARKET_TABS[i],
			UiKit.GlyphButton.Kind.PRIMARY if i == _market_tab else UiKit.GlyphButton.Kind.SECONDARY)
		tab.font_size = 19
		tab.position = Vector2(56 + col * 124, 136 + row * 76)
		tab.size = Vector2(116, 68)
		tab.pressed.connect(func():
			if _market_tab != i:
				_market_tab = i
				_fill_market())
		page.add_child(tab)
		_shop_tabs.append(tab)
	_make_preview(page)
	_market_body = Control.new()
	_market_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_market_body.size = Vector2(600, 1100)
	page.add_child(_market_body)
	var close := UiKit.GlyphButton.new("Close", UiKit.GlyphButton.Kind.SECONDARY)
	close.font_size = 28
	close.position = Vector2(56, 996)
	close.size = Vector2(488, 80)
	close.pressed.connect(func():
		_market.visible = false
		_free_preview())
	page.add_child(close)
	_fill_market()
	page.open()

func _free_preview() -> void:
	if _preview_box and is_instance_valid(_preview_box):
		_preview_box.queue_free()
	_preview_box = null
	_preview = null
	_preview_runner = null

## The preview: a little 3D world of its own inside the page, where the
## runner turns wearing whatever card is selected.
func _make_preview(page: Control) -> void:
	_free_preview()
	_preview_box = SubViewportContainer.new()
	_preview_box.stretch = true
	_preview_box.position = Vector2(56, 296)
	_preview_box.size = Vector2(488, 300)
	_preview_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(_preview_box)
	_preview = SubViewport.new()
	_preview.own_world_3d = true
	_preview.transparent_bg = true
	_preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview_box.add_child(_preview)
	_preview_root = Node3D.new()
	_preview.add_child(_preview_root)
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.fov = 26.0
	_preview.add_child(cam)
	cam.position = Vector3(0, 0.95, -3.9)
	cam.look_at(Vector3(0, 0.86, 0))

func _fill_market() -> void:
	for c in _market_body.get_children():
		c.queue_free()
	var body := _market_body
	for i in _shop_tabs.size():
		_shop_tabs[i].set_kind(UiKit.GlyphButton.Kind.PRIMARY if i == _market_tab else UiKit.GlyphButton.Kind.SECONDARY)
	var looks: bool = MARKET_TABS[_market_tab] in ["Runners", "Outfits", "Hats", "Stones"]
	if _preview_box:
		_preview_box.visible = looks
		_preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS if looks else SubViewport.UPDATE_DISABLED
	var held := UiKit.label(UiKit.thousands(_save.bank), UiKit.display_font(), 30, UiKit.INK)
	held.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	held.position = Vector2(300, 52)
	held.size = Vector2(200, 44)
	body.add_child(held)
	var drop := UiKit.DropGlyph.new(32)
	drop.position = Vector2(508, 58)
	body.add_child(drop)
	var shelf: String = MARKET_TABS[_market_tab]
	match shelf:
		"Charms": _fill_charms(body)
		"Boosts": _fill_boosts(body)
		"Treasury": _fill_treasury(body)
		_: _fill_shelf(body, shelf)

## What the player has on, for a looks shelf.
func _worn(shelf: String) -> String:
	match shelf:
		"Runners": return _save.character
		"Outfits": return _save.garb
		"Hats": return _save.hat
		_: return _save.hue

func _owns_item(item: Dictionary) -> bool:
	return Shop.drops_price(item) == 0 or _save.owns(item.id)

func _chips(shelf: String, item: Dictionary) -> Array:
	match shelf:
		"Runners":
			var l: Dictionary = item.look
			var o: Dictionary = item.outfit
			return [l.get("skin", RunnerModel.DEFAULT_LOOK.skin), l.get("hair_col", RunnerModel.DEFAULT_LOOK.hair_col), o.get("shirt", RunnerModel.SHIRT)]
		"Outfits":
			var p: Dictionary = item.palette
			if p.is_empty():
				return []
			return [p.get("shirt", RunnerModel.SHIRT), p.get("scarf", RunnerModel.SCARF), p.get("trousers", RunnerModel.TROUSERS)]
		"Stones":
			return [item.gem, item.light]
		_:
			return []

## A looks shelf: a live 3D preview of the runner wearing what's selected,
## the cards, and one button that buys or puts it on.
func _fill_shelf(body: Control, shelf: String) -> void:
	var items := Shop.shelf(shelf, _save)
	if not _shop_sel.has(shelf):
		_shop_sel[shelf] = _worn(shelf)
	_shop_caption = UiKit.label("", UiKit.display_font(), 26, UiKit.INK)
	_shop_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_caption.position = Vector2(56, 598)
	_shop_caption.size = Vector2(488, 40)
	body.add_child(_shop_caption)
	# The cards, in a scrolling grid.
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(48, 642)
	scroll.size = Vector2(504, 236)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	var cards := {}
	for item in items:
		var card := ItemCard.new()
		card.title = str(item.title).split(" the ")[0]
		card.chips = _chips(shelf, item)
		var worn: bool = item.id == _worn(shelf)
		if worn:
			card.state = "Wearing" if shelf != "Runners" else "Running"
		elif _owns_item(item):
			card.state = "Yours"
		else:
			var dp := Shop.drops_price(item)
			if dp > 0:
				card.price = UiKit.thousands(dp)
				card.drops_price = true
			else:
				card.price = str(_store.prices.get(Shop.product_of(item), "In store"))
		card.selected = item.id == _shop_sel[shelf]
		var id: String = item.id
		card.chosen.connect(func():
			_shop_sel[shelf] = id
			for k in cards:
				cards[k].selected = k == id
			_shop_choose(shelf))
		grid.add_child(card)
		cards[id] = card
	_shop_action = UiKit.GlyphButton.new("", UiKit.GlyphButton.Kind.PRIMARY)
	_shop_action.font_size = 28
	_shop_action.position = Vector2(56, 892)
	_shop_action.size = Vector2(488, 92)
	body.add_child(_shop_action)
	_shop_action.pressed.connect(func(): _shop_act(shelf))
	_market_note = UiKit.label("", UiKit.text_font(900), 20, UiKit.CINNABAR)
	_market_note.position = Vector2(58, 296)
	body.add_child(_market_note)
	_shop_choose(shelf)

func _shop_item(shelf: String) -> Dictionary:
	for item in Shop.shelf(shelf, _save):
		if item.id == _shop_sel.get(shelf, ""):
			return item
	return {}

## Shows the selected item on the preview runner and sets the button.
func _shop_choose(shelf: String) -> void:
	var item := _shop_item(shelf)
	if item.is_empty():
		return
	var character := _save.character
	var outfit := _save.garb
	var hat := _save.hat
	var hue := _save.hue
	match shelf:
		"Runners": character = item.id
		"Outfits": outfit = item.id
		"Hats": hat = item.id
		"Stones": hue = item.id
	if _preview_runner:
		_preview_runner.queue_free()
	_preview_runner = Shop.dress(character, outfit, hat, hue)
	_preview_root.add_child(_preview_runner)
	_preview_runner.rotation.y = PI + 0.5
	_shop_caption.text = item.title
	var label: Label = _shop_action.get_child(0)
	var worn: bool = item.id == _worn(shelf)
	var dp := Shop.drops_price(item)
	if worn:
		label.text = "Running as %s" % item.title.split(" ")[0] if shelf == "Runners" else ("In the stone" if shelf == "Stones" else "Wearing")
	elif _owns_item(item):
		label.text = ("Run as %s" % item.title.split(" ")[0]) if shelf == "Runners" else ("Use this hue" if shelf == "Stones" else "Wear")
	elif dp > 0:
		label.text = ("Buy for %s" % UiKit.thousands(dp)) if _save.bank >= dp else ("%s sun-drops" % UiKit.thousands(dp))
	elif Shop.product_of(item) != "":
		label.text = "Buy for %s" % _store.prices.get(Shop.product_of(item), "…") if _store.ready_to_sell() else "Treasury closed"
	else:
		label.text = "Patrons only"

## The button: buy (sun-drops or the store), or put on what you own.
func _shop_act(shelf: String) -> void:
	var item := _shop_item(shelf)
	if item.is_empty() or item.id == _worn(shelf):
		return
	if not _owns_item(item):
		var dp := Shop.drops_price(item)
		if dp > 0:
			if not _save.buy_item(item.id, dp):
				_market_note.text = "Not enough sun-drops yet."
				return
			_online.track("market_buy", {"id": item.id, "shelf": shelf, "drops": dp})
		elif Shop.product_of(item) != "":
			_market_note.text = "Opening the store…"
			_store.buy(Shop.product_of(item))
			return
		else:
			return
	match shelf:
		"Runners": _save.character = item.id
		"Outfits": _save.garb = item.id
		"Hats": _save.hat = item.id
		"Stones": _save.hue = item.id
	_save.save_to_disk()
	_online.track("market_wear", {"id": item.id, "shelf": shelf})
	_online.queue_sync()
	looks_changed.emit()
	_fill_market()
	_refresh_title()

func _process(delta: float) -> void:
	if _preview_runner and is_instance_valid(_preview_runner):
		_preview_runner.rotation.y += delta * 0.6
		_preview_runner.animate(delta, 0.0)

## Boosts: used up when they're needed, bought one at a time.
func _fill_boosts(body: Control) -> void:
	_market_note = UiKit.label("", UiKit.text_font(900), 22, UiKit.CINNABAR)
	_market_note.position = Vector2(58, 300)
	body.add_child(_market_note)
	var y := 340.0
	for b in Shop.BOOSTS:
		var t := UiKit.label(b.title, UiKit.display_font(), 28, UiKit.INK)
		t.position = Vector2(58, y)
		body.add_child(t)
		body.add_child(UiKit.wrapped(b.text, UiKit.text_font(800), 23, UiKit.INK, Vector2(58, y + 42), 310, 90))
		var have := UiKit.label("You hold %d" % _save.boosts(b.id), UiKit.text_font(900), 22, UiKit.CINNABAR)
		have.position = Vector2(58, y + 134)
		body.add_child(have)
		var cost: int = b.drops
		var btn := UiKit.GlyphButton.new(UiKit.thousands(cost),
			UiKit.GlyphButton.Kind.PRIMARY if _save.bank >= cost else UiKit.GlyphButton.Kind.SECONDARY)
		btn.font_size = 26
		btn.position = Vector2(384, y + 40)
		btn.size = Vector2(160, 76)
		var id: String = b.id
		btn.pressed.connect(func():
			if _save.buy_boost(id, cost):
				_save.save_to_disk()
				_online.track("boost_buy", {"id": id})
				_online.queue_sync()
				_fill_market()
				_refresh_title()
			else:
				_market_note.text = "Not enough sun-drops yet.")
		body.add_child(btn)
		y += 210.0

## Real-money items through the store, priced by it in local currency.
func _fill_treasury(body: Control) -> void:
	_market_note = UiKit.label("", UiKit.text_font(900), 22, UiKit.CINNABAR)
	_market_note.position = Vector2(58, 300)
	body.add_child(_market_note)
	if not _store.ready_to_sell():
		body.add_child(UiKit.wrapped("The treasury opens soon. Everything here will also be yours on any phone you sign in on.",
			UiKit.text_font(800), 26, UiKit.INK, Vector2(58, 340), 486, 120))
		return
	var y := 336.0
	for p in Shop.TREASURY:
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
				_market_note.text = "Opening the store…"
				_store.buy(id))
		body.add_child(btn)
		y += 104.0
	var restore := UiKit.GlyphButton.new("Restore purchases", UiKit.GlyphButton.Kind.SECONDARY)
	restore.font_size = 22
	restore.position = Vector2(56, 872)
	restore.size = Vector2(488, 62)
	restore.pressed.connect(func():
		_market_note.text = "Asking the store…"
		await _store.restore()
		_market_note.text = "Up to date.")
	body.add_child(restore)

func _fill_charms(body: Control) -> void:
	var y := 312.0
	for ch in Market.CHARMS:
		var tier := _save.charm_tier(ch.id)
		var t := UiKit.label(ch.title, UiKit.display_font(), 28, UiKit.INK)
		t.position = Vector2(58, y)
		body.add_child(t)
		body.add_child(UiKit.wrapped(ch.text, UiKit.text_font(800), 23, UiKit.INK, Vector2(58, y + 40), 486, 60))
		var marks := UiKit.TierMarks.new()
		marks.tier = tier
		marks.position = Vector2(58, y + 118)
		marks.size = Vector2(120, 32)
		body.add_child(marks)
		var now := UiKit.label(ch.effects[tier - 1] if tier > 0 else "Not yet", UiKit.text_font(900), 22, UiKit.CINNABAR)
		now.position = Vector2(184, y + 120)
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
		btn.position = Vector2(384, y + 104)
		btn.size = Vector2(160, 72)
		body.add_child(btn)
		y += 212.0

## Apple's own look for its button (App Review checks it): black, rounded,
## the Apple logo and "Sign in with Apple" in the system font. The logo is
## U+F8FF, which only Apple's system font draws — fine, this is iOS only.
func _apple_button() -> Button:
	var b := Button.new()
	b.text = "  Sign in with Apple"
	var font := SystemFont.new()
	font.font_names = PackedStringArray([".AppleSystemUIFont", "SF Pro Text", "Helvetica Neue"])
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 30)
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color.BLACK if state != "pressed" else Color(0.18, 0.18, 0.18)
		box.set_corner_radius_all(14)
		b.add_theme_stylebox_override(state, box)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	return b

# ------------------------------------------------------------- gift offer ---

signal _offer_answer(watch: bool)

## The intro AdMob requires before a rewarded interstitial: what you'd get,
## a clear "No thanks", and time to choose. Returns true to watch (tapped, or
## the countdown ran out), false if declined.
func show_reward_offer(reward: int) -> bool:
	var m := _modal(560, 0.5)
	var layer: Control = m[0]
	var page: UiKit.Page = m[1]
	page.seed = 127
	_headline(page, "The temple's gift")
	page.add_child(UiKit.wrapped("Watch a short ad and the temple gives you %d sun-drops. Or carry on without it." % reward,
		UiKit.text_font(800), 26, UiKit.INK, Vector2(58, 140), 330, 150))
	var ring := UiKit.Countdown.new()
	ring.seconds = 5.0
	ring.left = 5.0
	ring.position = Vector2(410, 140)
	ring.size = Vector2(130, 130)
	page.add_child(ring)
	var watch := UiKit.GlyphButton.new("Watch for +%d" % reward, UiKit.GlyphButton.Kind.PRIMARY)
	watch.font_size = 28
	watch.position = Vector2(56, 330)
	watch.size = Vector2(488, 100)
	page.add_child(watch)
	var no := UiKit.GlyphButton.new("No thanks", UiKit.GlyphButton.Kind.SECONDARY)
	no.font_size = 30
	no.position = Vector2(56, 444)
	no.size = Vector2(488, 96)
	page.add_child(no)
	var answered := [false]
	var answer := func(yes: bool) -> void:
		if answered[0]:
			return
		answered[0] = true
		layer.queue_free()
		_offer_answer.emit(yes)
	watch.pressed.connect(func(): answer.call(true))
	no.pressed.connect(func(): answer.call(false))
	ring.expired.connect(func(): answer.call(true))
	page.open()
	return await _offer_answer

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
## How deep into the nights a distance reaches: "Night 2, 40% to dawn".
static func night_name(metres: float) -> String:
	var at := Nights.locate(maxf(metres, 0.0))
	if at.dawn:
		return "Dawn of night %d" % at.n
	return "Night %d, %d%% to dawn" % [at.n, int(at.t * 100.0)]

static func duration_text(seconds: float) -> String:
	var m := int(seconds / 60.0)
	if m < 60:
		return "%d min" % m
	return "%d h %d min" % [m / 60, m % 60]

## The record book: every count the codex keeps, one register per line.
# ---------------------------------------------------------- how to play ---

## Each rule of the game beside an inked sign: [sign, heading, text].
const HOWTO := [
	["lanes", "Swipe left or right", "Change lane. Go round fallen stelae, obsidian blades and stone jaguars."],
	["up", "Swipe up", "Jump over low walls and pits."],
	["down", "Swipe down", "Slide under stone lintels and diving bats. In the air, it drops you straight down."],
	["tap", "Tap to flare", "Your light reaches far down the road and jaguars freeze to stone. Each flare costs light: below the red mark on the sun it only fizzles."],
	["sun", "Your light", "It's how far you can see, and it fades as you run. Run through sun-drops to feed it. A whole line pays a bonus."],
	["pack", "The pack behind you", "Stone jaguars follow you. They close in when your light is low or you stumble. If your light goes out, they catch you."],
	["hit", "One wrong move", "Run into anything head-on and the night is over. Clip something while changing lanes and you stumble; stumble twice in a row and the pack has you."],
	["close", "Close calls", "Dodge at the very last moment for extra sun-drops. Several in a row pay more."],
	["dawn", "Make it to dawn", "Each night is three Houses of Xibalba, each with its own dangers. Survive them and the sun rises; then the next night begins, faster."],
]

## How to play: the swipes, the flare, the light and the pack, on one
## scrolling codex page.
func _open_howto() -> void:
	if _howto:
		_howto.queue_free()
	var vp := get_viewport().get_visible_rect().size
	var height := minf(1180.0, vp.y - 120.0)
	var m := _modal(height, 0.7)
	_howto = m[0]
	var page: UiKit.Page = m[1]
	page.seed = 53
	_headline(page, "How to play")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.position = Vector2(40, 136)
	scroll.size = Vector2(520, height - 136 - 150)
	page.add_child(scroll)
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(content)
	var y := 8.0
	for i in HOWTO.size():
		var row: Array = HOWTO[i]
		var sign := HowSign.new()
		sign.kind = row[0]
		sign.position = Vector2(14, y + 4)
		sign.size = Vector2(104, 104)
		content.add_child(sign)
		var head := UiKit.label(row[1], UiKit.display_font(), 30, UiKit.CINNABAR if i == 3 else UiKit.INK)
		head.position = Vector2(136, y)
		content.add_child(head)
		var text: String = row[2]
		var lines := ceili(text.length() / 24.0)
		var body := UiKit.wrapped(text, UiKit.text_font(800), 24, UiKit.INK, Vector2(136, y + 44), 370, lines * 32.0)
		content.add_child(body)
		y += maxf(124.0, 52.0 + lines * 32.0) + 18.0
		if i < HOWTO.size() - 1:
			var r := Rule.new(60 + i)
			r.position = Vector2(14, y - 16)
			r.size = Vector2(490, 12)
			content.add_child(r)
	content.custom_minimum_size = Vector2(520, y)
	# A fade at the foot of the text: there's more below.
	var more := UiKit.label("Scroll for more", UiKit.text_font(900), 22, Color(UiKit.CINNABAR, 0.8))
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	more.position = Vector2(56, height - 150)
	more.size = Vector2(488, 30)
	page.add_child(more)
	scroll.get_v_scroll_bar().value_changed.connect(func(v: float):
		more.visible = v < y - scroll.size.y - 40.0)
	var done := UiKit.GlyphButton.new("Got it", UiKit.GlyphButton.Kind.PRIMARY)
	done.position = Vector2(56, height - 116)
	done.size = Vector2(488, 96)
	done.pressed.connect(func(): _howto.visible = false)
	page.add_child(done)
	page.open()

## The sign beside each rule: a glyph block with the move inked on it.
class HowSign:
	extends Control
	var kind := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var block := UiKit.glyph_block(rect, kind.length() * 7)
		UiKit.draw_paper(self, block, Color.WHITE)
		UiKit.draw_ink(self, block, UiKit.INK, 4.0)
		var c := size / 2.0
		var u := size.x / 100.0
		match kind:
			"lanes":
				_arrow(c + Vector2(-6, 0) * u, Vector2(-1, 0), 30 * u)
				_arrow(c + Vector2(6, 0) * u, Vector2(1, 0), 30 * u)
			"up":
				_arrow(c + Vector2(0, 16) * u, Vector2(0, -1), 40 * u)
				draw_line(c + Vector2(-26, 30) * u, c + Vector2(26, 30) * u, UiKit.INK, 5.0 * u, true)
			"down":
				_arrow(c + Vector2(0, -22) * u, Vector2(0, 1), 36 * u)
				draw_line(c + Vector2(-28, -28) * u, c + Vector2(28, -28) * u, UiKit.INK, 7.0 * u, true)
			"tap":
				for k in 3:
					draw_arc(c, (10 + k * 11) * u, 0.0, TAU, 32, Color(UiKit.CINNABAR if k > 0 else UiKit.INK, 1.0 - k * 0.25), 4.0 * u, true)
				draw_circle(c, 7 * u, UiKit.INK, true, -1.0, true)
			"sun":
				UiKit.draw_kin(self, c, 26 * u, 1.0, 3.0 * u)
			"pack", "hit", "close", "dawn":
				_special(c, u)

	func _special(c: Vector2, u: float) -> void:
		match kind:
			"pack":
				# Jaguar eyes in the dark.
				for side in [-1.0, 1.0]:
					var ec := c + Vector2(side * 18, 0) * u
					var eye := UiKit.ellipse(ec, 14 * u, 7 * u, side * 0.25, 18)
					draw_colored_polygon(eye, UiKit.OCHRE)
					draw_polyline(UiKit.closed(eye), UiKit.INK, 3.0 * u, true)
					draw_line(ec + Vector2(0, -6) * u, ec + Vector2(0, 6) * u, UiKit.INK, 3.5 * u, true)
			"hit":
				# A stela, struck.
				draw_rect(Rect2(c + Vector2(-14, -30) * u, Vector2(28, 60) * u), UiKit.STUCCO.darkened(0.15))
				draw_rect(Rect2(c + Vector2(-14, -30) * u, Vector2(28, 60) * u), UiKit.INK, false, 3.5 * u)
				for k in 4:
					var a := TAU * k / 4.0 + PI / 4.0
					var d := Vector2(cos(a), sin(a))
					draw_line(c + d * 24 * u, c + d * 40 * u, UiKit.CINNABAR, 4.5 * u, true)
			"close":
				# A runner's path just missing a block.
				draw_rect(Rect2(c + Vector2(6, -22) * u, Vector2(24, 44) * u), UiKit.STUCCO.darkened(0.15))
				draw_rect(Rect2(c + Vector2(6, -22) * u, Vector2(24, 44) * u), UiKit.INK, false, 3.5 * u)
				var pts := PackedVector2Array()
				for k in 13:
					var t := k / 12.0
					pts.append(c + Vector2(-30 + 6.0 * sin(t * PI) * 3.0, 34 - t * 68) * u + Vector2(-4, 0) * u)
				draw_polyline(pts, UiKit.CINNABAR, 4.5 * u, true)
			"dawn":
				# The sun rising over the line of the earth.
				draw_arc(c + Vector2(0, 14) * u, 22 * u, PI, TAU, 24, UiKit.OCHRE, 7.0 * u, true)
				for k in 5:
					var a := PI + PI * (k + 0.5) / 5.0
					var d := Vector2(cos(a), sin(a))
					draw_line(c + Vector2(0, 14) * u + d * 30 * u, c + Vector2(0, 14) * u + d * 40 * u, UiKit.INK, 4.0 * u, true)
				draw_line(c + Vector2(-38, 16) * u, c + Vector2(38, 16) * u, UiKit.INK, 5.0 * u, true)

	func _arrow(from: Vector2, dir: Vector2, length: float) -> void:
		var tip := from + dir * length
		draw_line(from, tip, UiKit.INK, length * 0.16, true)
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([tip + dir * length * 0.32, tip + side * length * 0.3, tip - side * length * 0.3]), UiKit.CINNABAR)
		draw_polyline(PackedVector2Array([tip + dir * length * 0.32, tip + side * length * 0.3, tip - side * length * 0.3, tip + dir * length * 0.32]), UiKit.INK, 3.0, true)

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
		["Deepest night", night_name(_save.best) if _save.runs > 0 else "-"],
		["Time in Xibalba", duration_text(_save.play_seconds)],
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
func show_results(cause: String, metres: int, drop_count: int, best: int, is_best: bool, daily := {}, new_glyphs: Array[String] = [], night_line := "") -> void:
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
	_pin(page, BOTTOM_CENTER, Rect2(-310, -800, 620, 744))

	var night_l := UiKit.label(night_line, UiKit.text_font(900), 24, UiKit.CINNABAR)
	night_l.position = Vector2(58, 40)
	page.add_child(night_l)
	var head := UiKit.wrapped(cause, UiKit.display_font(), 36, UiKit.INK, Vector2(56, 74), 508, 96)
	page.add_child(head)
	_rule(page, 172, 21)

	var dist := UiKit.label("0 m", UiKit.display_font(), 88, UiKit.INK)
	dist.position = Vector2(52, 180)
	page.add_child(dist)
	var maya := MayaNumber.new()
	maya.position = Vector2(510, 196)
	maya.size = Vector2(40, 120)
	page.add_child(maya)

	var glyph := UiKit.DropGlyph.new(36)
	glyph.position = Vector2(58, 326)
	page.add_child(glyph)
	var drops := UiKit.label("+%d sun-drops" % drop_count, UiKit.text_font(900), 32, UiKit.INK)
	drops.position = Vector2(106, 318)
	page.add_child(drops)
	if drop_count > 0 and _ads.rewarded_ready():
		var twice := UiKit.GlyphButton.new("Watch: double", UiKit.GlyphButton.Kind.PRIMARY)
		twice.font_size = 20
		twice.position = Vector2(384, 310)
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
	best_l.position = Vector2(58, 372)
	page.add_child(best_l)
	if not new_glyphs.is_empty():
		var g_text := "New glyph: %s" % Glyphs.def(new_glyphs[0]).title if new_glyphs.size() == 1 else "%d new glyphs" % new_glyphs.size()
		var g := UiKit.label(g_text, UiKit.display_font(), 24, UiKit.CINNABAR)
		g.position = Vector2(58, 414)
		page.add_child(g)
	_rule(page, 460, 23)

	var again := UiKit.GlyphButton.new("Run again", UiKit.GlyphButton.Kind.PRIMARY)
	again.position = Vector2(56, 484)
	again.size = Vector2(508, 116)
	again.pressed.connect(func(): again_pressed.emit())
	page.add_child(again)
	var home := UiKit.GlyphButton.new("Home", UiKit.GlyphButton.Kind.SECONDARY)
	home.font_size = 30
	home.position = Vector2(56, 614)
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
